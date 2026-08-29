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
AVB_SALT=ruCHpb47mCl4ySP1ZqlGE0lrQX8q9ZJjm8gNFB403+c=
AVB_FINGERPRINT=vivo/PD2415/PD2415:15/AP3A.240905.015.A1/compiler11071704:user/release-keys
PLATFORM_GZIP_SHA256=41975e4ae3f4c0f29711cbf6e1adb311daf101b83112ee400990a1ab6413d98d    # prebuilt/vendor_ramdisk/platform.cpio.gz
PLATFORM_CPIO_SHA256=6ddca715bd7f6224768ad14b7665a7d31841a79ff41fbc5a2e757057ae5fd7ba    # gunzipped platform cpio
OFFICIAL_RECOVERY_CPIO_SHA256=2eb8207bf3d0a401b7f548c2b8d147effbf18071e3c01244f4b3edae20ec8189    # prebuilt/vendor_ramdisk/official_recovery.cpio.gz
DTB_SHA256=5da60d8425114cac3ac86b2724b6178354615d4042343375f0e3dd1d235bf050              # prebuilt/dtb/pd2415.dtb
# Add one require_sha256 constant per staged module / firmware / HAL input and
# verify them before packaging, exactly like the reference script does.

die() {
    echo "$*" >&2
    exit 1
}

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
built_vendor_boot="$source_root/out/target/product/pd2415/vendor_boot.img"
mkbootimg="$source_root/system/tools/mkbootimg/mkbootimg.py"
unpack_bootimg="$source_root/system/tools/mkbootimg/unpack_bootimg.py"
avbtool="$source_root/external/avb/avbtool.py"
for input in "$platform_gzip" "$official_recovery_gzip" "$dtb" "$built_vendor_boot" "$mkbootimg" "$unpack_bootimg" "$avbtool"
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
max_preavb_size=$(python3 "$avbtool" add_hash_footer \
    --partition_size "$PARTITION_SIZE" \
    --partition_name vendor_boot \
    --hash_algorithm sha256 \
    --salt "$AVB_SALT" \
    --algorithm NONE \
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

# Safe-Trim the platform fragment against the official recovery ramdisk.
trimmed_platform_gzip="$work/platform-trimmed.cpio.gz"
gzip -dc "$official_recovery_gzip" > "$work/official-recovery.cpio"
trim_platform_fragment "$platform_gzip" "$work/official-recovery.cpio" "$trimmed_platform_gzip"

# Repack: platform fragment unnamed (type 0x1), recovery fragment named
# "recovery" (type 0x2). Offsets/cmdline must match the stock image.
# Source: vendor_boot.json (kernelLoadAddr=0x80000000, ramdisk=0xa4d00000,
# tags=0x87c80000, dtb=0x87c80000, cmdline from vendor_boot.json).
python3 "$mkbootimg" \
    --header_version 4 \
    --pagesize 4096 \
    --base 0x80000000 \
    --kernel_offset 0x00000000 \
    --ramdisk_offset 0xa4d00000 \
    --tags_offset 0x87c80000 \
    --dtb_offset 0x87c80000 \
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
    --prop "com.android.build.vendor_boot.fingerprint:$AVB_FINGERPRINT"
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

install -m 0644 "$work/vendor_boot.img" "$output_image"
sha256sum "$output_image" > "$output_image.sha256"
printf 'pre-AVB size: %s (AVB maximum: %s)\n' "$preavb_size" "$max_preavb_size"
printf 'created %s\n' "$output_image"
