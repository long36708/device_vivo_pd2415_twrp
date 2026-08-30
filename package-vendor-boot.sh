#!/bin/sh
# Copyright (C) 2025 The OrangeFox for pd2415 contributors
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Assemble the final vendor_boot v4 image from the Soong-built vendor_boot
# (produced by `m vendorboot`):
#   vendor_ramdisk00 = platform fragment (stock vendor ramdisk, safe-trimmed of
#                      entries byte-identical to the official recovery ramdisk)
#   vendor_ramdisk01 = recovery fragment (the built recovery ramdisk, gzip -9)
# then append the AVB hash footer and verify the complete layout + payload.
#
# Modeled on device_xiaomi_dali_twrp/package-vendor-boot.sh. The SHA constants
# are device contracts: regenerate them from the official images (sha256sum)
# for every new device — never reuse the reference values.
#
# Usage: sh package-vendor-boot.sh /absolute/path/to/source /absolute/path/to/vendor_boot.img

set -eu
export LC_ALL=C

PARTITION_SIZE=134217728
# avbtool 的 --salt 要的是 **hex**, 32 字节即 64 个十六进制字符。
# 别把官方 JSON 里那段 base64 直接搬过来 —— vendor_boot.avb.json / avbtool
# info_image 之外的解包器 (unpack_bootimg 的配套 json、mkbootimg 系列) 会把
# 二进制字段按 base64 输出, 那段字符串里有 + / = 这些非十六进制字符, 喂给
# avbtool 只会在打包的最后一步抛:
#     Adding hash_footer failed: Non-hexadecimal digit found
# 换算: python3 -c "import base64,binascii;print(binascii.hexlify(base64.b64decode('...')).decode())"
AVB_SALT=aee087a5be3b982978c923f566a94613496b417f2af592639bc80d141e34dfe7
AVB_FINGERPRINT=vivo/PD2415/PD2415:15/AP3A.240905.015.A1/compiler11071704:user/release-keys
# 官方 footer 的第二个属性描述符 (见 vendor_boot.avb.json / avbtool info_image)。
# 注意两点:
#   1) key 字面量是 **boot**, 不是 vendor_boot —— AOSP 由 BOOT_SECURITY_PATCH
#      生成, key 固定用 boot, 即使这个 footer 长在 vendor_boot 分区上。
#   2) 值是 2025-09-01, 不等于 Android 大版本的 SPL (AP3A.240905.015.A1 对应
#      2024-09-05)。厂商会单独抬高 BOOT_SECURITY_PATCH, 两者不可互相推导。
AVB_SECURITY_PATCH=2025-09-01
PLATFORM_GZIP_SHA256=54b170229d11aac8e64c09ffd0a16a109d36520e3b48b94d685451d4e4c367e4    # prebuilt/vendor_ramdisk/platform.cpio.gz
PLATFORM_CPIO_SHA256=d2430c1b623f2c2be3c8d36cc8546632b9ad60c54cbb7cf8dbf64cb83ccc446f    # gunzipped platform cpio
OFFICIAL_RECOVERY_CPIO_SHA256=d49d53bccb39bfa66a51613bc4109e87702b598d0a12d5f5f47baa078a69bee5    # prebuilt/vendor_ramdisk/official_recovery.cpio.gz
DTB_SHA256=5da60d8425114cac3ac86b2724b6178354615d4042343375f0e3dd1d235bf050              # prebuilt/dtb/pd2415.dtb
# Add one require_sha256 constant per staged module / firmware / HAL input and
# verify them before packaging, exactly like the reference script does.

die() {
    echo "$*" >&2
    exit 1
}

# 提前拦住格式错误的 salt。avbtool 自己的报错 ("Non-hexadecimal digit found")
# 出现在打包的最后一步, 而且不指明是哪个常量出问题; 这里在动工前就说清楚。
require_hex_salt() {
    case "$AVB_SALT" in
        ''|*[!0-9a-fA-F]*) die "AVB_SALT must be 64 hex characters (got base64?)" ;;
    esac
    [ "${#AVB_SALT}" -eq 64 ] ||
        die "AVB_SALT must be 64 hex characters, got ${#AVB_SALT}"
}
require_hex_salt

file_sha256() {
    sha256sum "$1" | awk '{print $1}'
}

require_sha256() {
    expected=$1
    input=$2
    actual=$(file_sha256 "$input")
    [ "$actual" = "$expected" ] || die "hash mismatch: $input"
}

extract_vendor_ramdisk() {
    fragment=$1
    destination=$2
    mkdir -p "$destination"
    cpio_input="$destination/.pd2415-vendor-ramdisk.cpio"
    gzip -dc "$fragment" > "$cpio_input"
    (
        cd "$destination"
        cpio -idmu --quiet < "$cpio_input"
    )
    rm -f -- "$cpio_input"
}

# Safe-Trim: remove platform entries that are byte-identical to the official
# recovery ramdisk (they would be overridden by the recovery fragment anyway),
# then normalize metadata for a reproducible cpio.
trim_platform_fragment() {
    platform_input=$1
    official_recovery_cpio=$2
    output_gzip=$3
    platform_root="$work/platform-root"
    official_recovery_root="$work/official-recovery-root"
    mkdir -p "$platform_root" "$official_recovery_root"
    gzip -dc "$platform_input" > "$work/platform-original.cpio"
    cpio -idmu --quiet -D "$platform_root" < "$work/platform-original.cpio"
    cpio -idmu --quiet -D "$official_recovery_root" < "$official_recovery_cpio"
    python3 - "$platform_root" "$official_recovery_root" <<'PYTRIM'
import os
import stat
import sys

platform_root, official_recovery_root = sys.argv[1:]
removed = 0
removed_bytes = 0

def kind(path):
    mode = os.lstat(path).st_mode
    if stat.S_ISDIR(mode):
        return "directory"
    if stat.S_ISREG(mode):
        return "file"
    if stat.S_ISLNK(mode):
        return "symlink"
    return "other"

def identical(left, right):
    lk = kind(left)
    rk = kind(right)
    if lk != rk:
        return False
    if lk == "symlink":
        return os.readlink(left) == os.readlink(right)
    if lk == "file":
        return os.path.getsize(left) == os.path.getsize(right) and open(left, "rb").read() == open(right, "rb").read()
    return False

for current, directories, files in os.walk(official_recovery_root, topdown=True, followlinks=False):
    paths = [os.path.join(current, name) for name in files]
    for name in list(directories):
        path = os.path.join(current, name)
        if os.path.islink(path):
            directories.remove(name)
        paths.append(path)
    for recovery_path in paths:
        relative = os.path.relpath(recovery_path, official_recovery_root)
        platform_path = os.path.join(platform_root, relative)
        if not os.path.lexists(platform_path):
            continue
        if kind(recovery_path) == "directory":
            continue
        if identical(platform_path, recovery_path):
            if kind(platform_path) == "file":
                removed_bytes += os.lstat(platform_path).st_size
            os.unlink(platform_path)
            removed += 1

for current, directories, files in os.walk(platform_root, topdown=False, followlinks=False):
    for name in directories + files:
        path = os.path.join(current, name)
        try:
            os.utime(path, (0, 0), follow_symlinks=False)
        except OSError as error:
            raise SystemExit("unable to normalize platform metadata for {}: {}".format(path, error))
try:
    os.utime(platform_root, (0, 0), follow_symlinks=False)
except OSError as error:
    raise SystemExit("unable to normalize platform metadata for {}: {}".format(platform_root, error))

print("safe-trimmed platform overrides: {} entries, {} regular-file bytes".format(removed, removed_bytes))
PYTRIM
    (cd "$platform_root" && find . -print0 | sort -z | cpio --null --reproducible -o -H newc > "$work/platform-trimmed.cpio")
    gzip -9 -n -c "$work/platform-trimmed.cpio" > "$output_gzip"
    gzip -t "$output_gzip"
}

# Final payload checks on the merged root; extend with the device's module
# closure exactly like the reference (sha256 per module, modules.dep sanity,
# recovery binary requests the touch modules).
validate_recovery_payload() {
    recovery_root=$1
    module_root="$recovery_root/lib/modules"
    recovery_binary="$recovery_root/system/bin/recovery"

    [ -d "$module_root" ] || die "final Recovery root has no module directory"
    [ -f "$recovery_binary" ] || die "final Recovery executable is missing"
}

[ "$#" -eq 2 ] || die "usage: $0 /absolute/path/to/source /absolute/path/to/vendor_boot.img"
source_root=$1
output_image=$2
case "$source_root" in
    /*) ;;
    *) die "source path must be absolute" ;;
esac
case "$output_image" in
    /*) ;;
    *) die "output path must be absolute" ;;
esac

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
platform_gzip="$script_dir/prebuilt/vendor_ramdisk/platform.cpio.gz"
official_recovery_gzip="$script_dir/prebuilt/vendor_ramdisk/official_recovery.cpio.gz"
dtb="$script_dir/prebuilt/dtb/pd2415.dtb"
prebuilt_kernel="$script_dir/prebuilt/kernel"
built_vendor_boot="$source_root/out/target/product/pd2415/vendor_boot.img"
mkbootimg="$source_root/system/tools/mkbootimg/mkbootimg.py"
unpack_bootimg="$source_root/system/tools/mkbootimg/unpack_bootimg.py"
avbtool="$source_root/external/avb/avbtool.py"
for input in "$platform_gzip" "$official_recovery_gzip" "$dtb" "$prebuilt_kernel" "$built_vendor_boot" "$mkbootimg" "$unpack_bootimg" "$avbtool"
do
    [ -f "$input" ] || die "missing input: $input"
done

gzip -t "$platform_gzip"
require_sha256 "$PLATFORM_GZIP_SHA256" "$platform_gzip"
require_sha256 "$OFFICIAL_RECOVERY_CPIO_SHA256" "$official_recovery_gzip"
require_sha256 "$DTB_SHA256" "$dtb"
output_dir=$(dirname -- "$output_image")
mkdir -p "$output_dir"
work=$(mktemp -d "$output_dir/.pd2415-vendor-boot.XXXXXX")
cleanup() {
    if [ -d "$work" ]; then
        rm -rf -- "$work"
    fi
}
trap cleanup EXIT HUP INT TERM

gzip -dc "$platform_gzip" > "$work/platform.cpio"
require_sha256 "$PLATFORM_CPIO_SHA256" "$work/platform.cpio"
# --calc_max_image_size 目前会忽略 --prop (avbtool 只解析不消费), 这里照样传,
# 是为了让两处调用保持对称 —— 属性每多一个, footer 就大一分。
max_preavb_size=$(python3 "$avbtool" add_hash_footer \
    --partition_size "$PARTITION_SIZE" \
    --partition_name vendor_boot \
    --hash_algorithm sha256 \
    --salt "$AVB_SALT" \
    --algorithm NONE \
    --prop "com.android.build.vendor_boot.fingerprint:$AVB_FINGERPRINT" \
    --prop "com.android.build.boot.security_patch:$AVB_SECURITY_PATCH" \
    --calc_max_image_size)

# Unpack the Soong-built vendor_boot; the recovery fragment must be the v4
# vendor_ramdisk01 (type 0x2, name "recovery").
python3 "$unpack_bootimg" --boot_img "$built_vendor_boot" --out "$work/built" > "$work/built-info.txt"
recovery_fragment="$work/built/vendor_ramdisk01"
awk '
    /^vendor boot image header version: 4$/ { header_v4 = 1 }
    /^    vendor_ramdisk01: \{$/ { recovery = 1; next }
    recovery && /^        type: 0x2$/ { recovery_type = 1 }
    recovery && /^        name: recovery$/ { recovery_name = 1 }
    recovery && /^    }$/ { recovery = 0 }
    END { exit !(header_v4 && recovery_type && recovery_name) }
' "$work/built-info.txt" ||
    die "built vendor_boot does not contain the expected v4 recovery fragment"
[ -f "$recovery_fragment" ] || die "built recovery fragment is missing"
gzip -t "$recovery_fragment"

# Re-compress the recovery fragment deterministically.
gzip -dc "$recovery_fragment" > "$work/recovery.cpio"
optimized_recovery_fragment="$work/recovery-gzip9.cpio.gz"
gzip -9 -n -c "$work/recovery.cpio" > "$optimized_recovery_fragment"
gzip -t "$optimized_recovery_fragment"
gzip -dc "$optimized_recovery_fragment" > "$work/recovery-gzip9.cpio"
cmp "$work/recovery.cpio" "$work/recovery-gzip9.cpio"

# Platform fragment: use the FULL official platform ramdisk as-is.
#
# Earlier this script ran `trim_platform_fragment` to drop files that were
# byte-identical between the platform and recovery ramdisks. That deletion
# removed early-boot essentials such as /init, /default.prop, /sepolicy and the
# *_file_contexts files, because the recovery ramdisk ships identical copies.
# On a virtual A/B device the stock boot image still relies on the vendor_boot
# platform fragment's /init to bring up the system, so trimming it made the
# device hang at the logo — even with the stock boot image. We now keep the
# complete platform ramdisk (the recovery fragment's own /init simply overlays
# it in recovery mode).
trimmed_platform_gzip="$platform_gzip"

# Repack: platform fragment unnamed (type 0x1), recovery fragment named
# "recovery" (type 0x2). Offsets/cmdline must match the stock image.
#
# IMPORTANT: the numbers in vendor_boot.json are ABSOLUTE load addresses
# (kernelLoadAddr=0x80000000, ramdisk=0xa4d00000, tags=0x87c80000,
# dtb=0x87c80000), but --*_offset are RELATIVE to --base. mkbootimg writes
# kernel_addr/ramdisk_addr/tags_addr as 32-bit 'I' fields computed as
# base + offset, so passing the absolute values as offsets overflows 2^32
# (0x80000000+0xa4d00000 = 0x124D00000) and aborts with
# "struct.error: 'I' format requires 0 <= number <= 4294967295".
# Subtract the base so the resulting absolute addresses match stock exactly:
#   kernel  : 0x80000000 - 0x80000000 = 0x00000000
#   ramdisk : 0xa4d00000 - 0x80000000 = 0x24d00000
#   tags    : 0x87c80000 - 0x80000000 = 0x07c80000
#   dtb     : 0x87c80000 - 0x80000000 = 0x07c80000
python3 "$mkbootimg" \
    --header_version 4 \
    --pagesize 4096 \
    --base 0x80000000 \
    --kernel_offset 0x00000000 \
    --kernel "$prebuilt_kernel" \
    --ramdisk_offset 0x24d00000 \
    --tags_offset 0x07c80000 \
    --dtb_offset 0x07c80000 \
    --vendor_cmdline "bootopt=64S3,32N2,64N2 product.version=PD2415_A_15.0.33.7.W10 fingerprint.abbr=15/AP3A.240905.015.A1 region_ver=W10 product.solution=MTK" \
    --dtb "$dtb" \
    --vendor_ramdisk "$trimmed_platform_gzip" \
    --ramdisk_type RECOVERY \
    --ramdisk_name recovery \
    --vendor_ramdisk_fragment "$optimized_recovery_fragment" \
    --vendor_boot "$work/vendor_boot.preavb.img"

preavb_size=$(stat -c '%s' "$work/vendor_boot.preavb.img")
[ "$preavb_size" -le "$PARTITION_SIZE" ] || die "vendor_boot exceeds the partition before AVB: $preavb_size"
[ "$preavb_size" -le "$max_preavb_size" ] ||
    die "vendor_boot exceeds the AVB maximum before footer creation: $preavb_size > $max_preavb_size"
cp "$work/vendor_boot.preavb.img" "$work/vendor_boot.img"
python3 "$avbtool" add_hash_footer \
    --image "$work/vendor_boot.img" \
    --partition_size "$PARTITION_SIZE" \
    --partition_name vendor_boot \
    --hash_algorithm sha256 \
    --salt "$AVB_SALT" \
    --algorithm NONE \
    --prop "com.android.build.vendor_boot.fingerprint:$AVB_FINGERPRINT" \
    --prop "com.android.build.boot.security_patch:$AVB_SECURITY_PATCH"
[ "$(stat -c '%s' "$work/vendor_boot.img")" -eq "$PARTITION_SIZE" ] || die "unexpected final image size"

# Verify the final layout: header v4, fragment types/names, byte-identical
# fragments and dtb, then the merged-root payload and the AVB footer.
python3 "$unpack_bootimg" --boot_img "$work/vendor_boot.img" --out "$work/output" > "$work/output-info.txt"
awk '
    /^vendor boot image header version: 4$/ { header_v4 = 1 }
    /^    vendor_ramdisk00: \{$/ { fragment = 1; next }
    /^    vendor_ramdisk01: \{$/ { fragment = 2; next }
    fragment == 1 && /^        type: 0x1$/ { platform_type = 1 }
    fragment == 1 && /^        name: $/ { platform_name = 1 }
    fragment == 2 && /^        type: 0x2$/ { recovery_type = 1 }
    fragment == 2 && /^        name: recovery$/ { recovery_name = 1 }
    fragment && /^    }$/ {
        if (fragment == 1) {
            platform = platform_type && platform_name
        } else if (fragment == 2) {
            recovery = recovery_type && recovery_name
        }
        fragment = 0
    }
    END {
        exit !(header_v4 && platform && recovery)
    }
' "$work/output-info.txt" ||
    die "final vendor_boot layout does not match the official v4 contract"
cmp "$trimmed_platform_gzip" "$work/output/vendor_ramdisk00"
cmp "$optimized_recovery_fragment" "$work/output/vendor_ramdisk01"
cmp "$dtb" "$work/output/dtb"
merged_root="$work/merged-root"
extract_vendor_ramdisk "$work/output/vendor_ramdisk00" "$merged_root"
extract_vendor_ramdisk "$work/output/vendor_ramdisk01" "$merged_root"
validate_recovery_payload "$merged_root"
python3 "$avbtool" info_image --image "$work/vendor_boot.img" > "$work/avb-info.txt"
grep -F "Algorithm:                NONE" "$work/avb-info.txt" >/dev/null
grep -F "Hash Algorithm:        sha256" "$work/avb-info.txt" >/dev/null
grep -F "Partition Name:        vendor_boot" "$work/avb-info.txt" >/dev/null
grep -F "Salt:                  $AVB_SALT" "$work/avb-info.txt" >/dev/null
grep -F "Prop: com.android.build.vendor_boot.fingerprint -> '$AVB_FINGERPRINT'" "$work/avb-info.txt" >/dev/null
grep -F "Prop: com.android.build.boot.security_patch -> '$AVB_SECURITY_PATCH'" "$work/avb-info.txt" >/dev/null

install -m 0644 "$work/vendor_boot.img" "$output_image"
sha256sum "$output_image" > "$output_image.sha256"
printf 'pre-AVB size: %s (AVB maximum: %s)\n' "$preavb_size" "$max_preavb_size"
printf 'created %s\n' "$output_image"
