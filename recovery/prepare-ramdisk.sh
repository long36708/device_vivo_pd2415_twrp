#!/bin/sh
# Copyright (C) 2025 The OrangeFox for pd2415 contributors
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Ramdisk preparation hook wired via BOARD_RECOVERY_IMAGE_PREPARE
# (BoardConfig.mk). Runs after ordinary Recovery relinking and before mkbootfs
# packages the final root; stages the device prebuilts into the recovery root.
#
# This scaffold mirrors the argument contract and staging order of
# device_xiaomi_dali_twrp/recovery/prepare-ramdisk.sh. Implemented here:
# prop.default rewrite from the official build props with SPL stripping
# (below). The reference additionally: swaps in the Soong-built
# servicemanager/libvintf (parsed from the Soong bridge mk), removes the
# incompatible Recovery libc++ (the platform copy must win), stages
# libminuitwrp + dmctl, trims languages/fonts, slims unused libraries and
# verifies every NEEDED library — port those sections from the reference when
# the device needs them.

set -eu

die() {
    echo "pd2415 recovery ramdisk preparation: $*" >&2
    exit 2
}

if [ "$#" -ne 7 ]; then
    die "usage: $0 recovery-root soong-bridge llvm-readobj recovery-module-inputs recovery-property-inputs recovery-vendor-hal-inputs recovery-firmware-inputs (all absolute)"
fi

input_root=$1
input_bridge=$2
input_llvm_readobj=$3
input_module_dir=$4
input_property_dir=$5
input_vendor_hal_dir=$6
input_firmware_dir=$7
for path in "$input_root" "$input_bridge" "$input_llvm_readobj" \
    "$input_module_dir" "$input_property_dir" "$input_vendor_hal_dir" \
    "$input_firmware_dir"
do
    case "$path" in
        /*) ;;
        *) die "all inputs must be absolute: $path" ;;
    esac
done

root=$(readlink -f -- "$input_root") || die "failed to canonicalize recovery root"
bridge=$(readlink -f -- "$input_bridge") || die "failed to canonicalize Soong bridge"
llvm_readobj=$(readlink -f -- "$input_llvm_readobj") || die "failed to canonicalize llvm-readobj"
module_dir=$(readlink -f -- "$input_module_dir") || die "failed to canonicalize recovery module input directory"
property_dir=$(readlink -f -- "$input_property_dir") || die "failed to canonicalize recovery property input directory"
vendor_hal_dir=$(readlink -f -- "$input_vendor_hal_dir") || die "failed to canonicalize recovery vendor HAL input directory"
firmware_dir=$(readlink -f -- "$input_firmware_dir") || die "failed to canonicalize recovery firmware input directory"
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
device_root=$(dirname -- "$script_dir")

case "$module_dir" in
    "$device_root"/prebuilt/recovery_modules) ;;
    *) die "unexpected recovery module input directory: $module_dir" ;;
esac
case "$property_dir" in
    "$device_root"/prebuilt/recovery_properties) ;;
    *) die "unexpected recovery property input directory: $property_dir" ;;
esac
case "$vendor_hal_dir" in
    "$device_root"/prebuilt/recovery_vendor_hal) ;;
    *) die "unexpected recovery vendor HAL input directory: $vendor_hal_dir" ;;
esac
case "$firmware_dir" in
    "$device_root"/prebuilt/recovery_firmware) ;;
    *) die "unexpected recovery firmware input directory: $firmware_dir" ;;
esac

test -d "$root" || die "missing recovery root"
test -f "$bridge" || die "missing Soong bridge"
test -x "$llvm_readobj" || die "missing llvm-readobj"
test -f "$property_dir/system.build.prop" || die "missing official system build properties"
test -f "$property_dir/vendor.build.prop" || die "missing official vendor build properties"
# Incremental-build guard: the previous run's manifests must exist so the
# payload verifier can compare against them (reference: dali checks both).
for manifest in ramdisk-files.txt ramdisk-files.sha256sum
do
    test -f "$root/$manifest" || die "missing recovery manifest: $root/$manifest (first build? this is normal; otherwise the recovery root is stale)"
done

# 1. Re-install the rc files with explicit modes (the recovery-root copy may
#    carry stale or wrongly-permissioned entries).
install -m 0644 "$script_dir/root/init.recovery.usb.rc" "$root/init.recovery.usb.rc"

# 2. Stage ONLY the kernel modules the platform fragment does not already ship.
#    Recovery mode loads BOTH vendor_ramdisk00 (platform) and vendor_ramdisk01
#    (recovery), and the stock platform ramdisk already carries the complete
#    /lib/modules closure (337 .ko — the official recovery ramdisk contains no
#    .ko at all and relies on the platform copy). Duplicating them inflated the
#    recovery fragment by ~70 MB and pushed vendor_boot past the LK's load
#    window. Anything the platform is missing is still staged here (together
#    with modules.dep), so a partial platform ramdisk cannot silently break
#    module loading.
platform_gzip="$device_root/prebuilt/vendor_ramdisk/platform.cpio.gz"
test -f "$platform_gzip" || die "missing platform ramdisk gzip: $platform_gzip"
# Only the gzip-compressed platform ramdisk is committed; the uncompressed
# .cpio is gitignored (too large to track) and is absent on a fresh CI clone.
# Decompress it to a temp file so the parser below can read it (mirrors what
# package-vendor-boot.sh does when it re-assembles vendor_ramdisk00).
platform_cpio=$(mktemp)
gzip -dc "$platform_gzip" > "$platform_cpio" || die "failed to decompress platform ramdisk: $platform_gzip"
platform_module_list=$(mktemp)
trap 'rm -f -- "$platform_cpio" "$platform_module_list"' EXIT HUP INT TERM
python3 - "$platform_cpio" "$platform_module_list" <<'PY'
import os
import sys

cpio_path, list_path = sys.argv[1:]
MAGIC = b"070701"
TRAILER = "TRAILER!!!"
MODULE_PREFIX = "lib/modules/"

if os.path.getsize(cpio_path) == 0:
    raise SystemExit("platform ramdisk is empty: " + cpio_path)

modules = []
with open(cpio_path, "rb") as stream:
    while True:
        header = stream.read(110)
        if len(header) != 110:
            raise SystemExit("truncated cpio header in " + cpio_path)
        if header[0:6] != MAGIC:
            raise SystemExit(
                "unsupported cpio format in {} (expected newc magic 070701)".format(cpio_path)
            )
        # newc header field order (each 8 hex chars):
        #   [0:6]  magic  [6:14]  ino      [14:22] mode   [22:30] uid
        #   [30:38] gid   [38:46] nlink    [46:54] mtime  [54:62] filesize
        #   [62:70] devmajor  [70:78] devminor  [78:86] rdevmajor
        #   [86:94] rdevminor  [94:102] namesize  [102:110] check
        filesize = int(header[54:62], 16)
        namesize = int(header[94:102], 16)
        raw_name = stream.read(namesize)
        if len(raw_name) != namesize:
            raise SystemExit("truncated cpio name in " + cpio_path)
        name = raw_name.rstrip(b"\0").decode("utf-8", "surrogateescape")
        # header(110) + name are padded to a 4-byte boundary, then the payload.
        stream.seek((-(110 + namesize)) % 4, os.SEEK_CUR)
        if name == TRAILER:
            break
        if name.startswith(MODULE_PREFIX):
            modules.append(name)
        stream.seek(filesize + ((-filesize) % 4), os.SEEK_CUR)

with open(list_path, "w", encoding="utf-8", errors="surrogateescape") as out:
    for name in modules:
        out.write(name + "\n")
PY
staged_modules=0
skipped_modules=0
# Iterate over every .ko in the module input directory (matches BoardConfig).
for ko in "$module_dir"/*.ko
do
    [ -e "$ko" ] || continue
    module=$(basename "$ko")
    test -f "$module_dir/$module" || die "missing module input: $module"
    if grep -Fxq "lib/modules/$module" "$platform_module_list"
    then
        skipped_modules=$((skipped_modules + 1))
        continue
    fi
    install -d -m 0755 "$root/lib/modules"
    install -m 0644 "$module_dir/$module" "$root/lib/modules/$module"
    staged_modules=$((staged_modules + 1))
done
if [ "$staged_modules" -gt 0 ]
then
    test -f "$module_dir/modules.dep" || die "missing modules.dep"
    install -m 0644 "$module_dir/modules.dep" "$root/lib/modules/modules.dep"
fi
printf 'kernel modules: %d staged, %d already provided by the platform fragment\n' \
    "$staged_modules" "$skipped_modules"

# 3. Stage firmware into /vendor/firmware so the kernel firmware loader works
#    without mounting the real vendor partition (reference: CS40L26 haptics).
if [ -d "$firmware_dir" ] && [ -n "$(ls -A "$firmware_dir")" ]
then
    install -d -m 0755 "$root/vendor/firmware"
    cp -a -- "$firmware_dir/." "$root/vendor/firmware/"
fi

# 4. Stage the vendor HAL closure into /vendor (bin/, lib64/, TA directories)
#    so the crypto chain runs from the ramdisk without mounting vendor
#    (reference: tee-supplicant, keymint, gatekeeper, weaver, secure_element,
#    boot HAL + mitee/ta trustlets).
if [ -d "$vendor_hal_dir" ] && [ -n "$(ls -A "$vendor_hal_dir")" ]
then
    rm -rf -- "$root/vendor/bin" "$root/vendor/lib64"
    install -d -m 0755 "$root/vendor"
    cp -a -- "$vendor_hal_dir/." "$root/vendor/"
fi

# 5. Rewrite prop.default from the official build props while stripping SPLs.
#    KeyMint validates FBE metadata key blobs against the Recovery-reported OS
#    and vendor patchlevels. After an OTA bumps the ROM's SPL, a blob upgraded
#    by the new system is newer than this Recovery build's baked SPL and
#    KeyMint rejects it with INVALID_KEY_BLOB (-33). Recovery therefore does
#    not bake SPLs into prop.default; a boot-time script (see
#    init.recovery.project.rc) sets them from the installed system instead.
#    prop.default itself is generated by the Android build into the recovery
#    root, so only rewriting is required here.
python3 - "$property_dir/system.build.prop" "$property_dir/vendor.build.prop" \
    "$root/prop.default" "$root/default.prop" <<'PY'
import os
import re
import stat
import sys
import tempfile

system_props, vendor_props, target_path, default_link = sys.argv[1:]
keys = (
    "ro.build.version.release",
)
# KeyMint validates FBE metadata key blobs against the Recovery-reported OS
# and vendor patchlevels. After an OTA bumps the ROM's SPL, a blob upgraded by
# the new system is newer than this Recovery build's baked SPL and KeyMint
# rejects it with INVALID_KEY_BLOB (-33). Recovery therefore does not bake SPLs
# into prop.default; pd2415-spl-override.sh sets them at boot from the
# installed system (see init.recovery.project.rc).
spl_keys = (
    "ro.build.version.security_patch",
    "ro.vendor.build.security_patch",
)


def values_from(path, wanted):
    values = {key: [] for key in wanted}
    with open(path, "r", encoding="utf-8", newline="") as stream:
        for raw in stream:
            line = raw.rstrip("\r\n")
            if "=" not in line or line.startswith("#"):
                continue
            key, value = line.split("=", 1)
            if key in values:
                values[key].append(value)
    result = {}
    for key, candidates in values.items():
        if not candidates or len(set(candidates)) != 1:
            raise SystemExit(
                "official property input must provide one unambiguous value for {}".format(key)
            )
        result[key] = candidates[0]
    return result


expected = {}
expected.update(values_from(system_props, keys))
# vendor.build.prop is staged by extract-official-prebuilts.sh; its SPL is
# applied at boot from the installed ROM instead of being baked here.

if not os.path.islink(default_link) or os.readlink(default_link) != "prop.default":
    raise SystemExit("default.prop must remain a prop.default symlink")

with open(target_path, "r", encoding="utf-8", newline="") as stream:
    original = stream.readlines()

seen = {key: 0 for key in keys}
seen_spl = {key: 0 for key in spl_keys}
rewritten = []
for raw in original:
    line = raw.rstrip("\r\n")
    ending = raw[len(line):]
    if "=" in line and not line.startswith("#"):
        key, _ = line.split("=", 1)
        if key in expected:
            seen[key] += 1
            rewritten.append("{}={}{}".format(key, expected[key], ending))
            continue
        if key in seen_spl:
            seen_spl[key] += 1
            continue
    rewritten.append(raw)

if any(count != 1 for count in seen.values()):
    raise SystemExit("Recovery prop.default must contain each target property exactly once")
if any(count > 1 for count in seen_spl.values()):
    raise SystemExit(
        "Recovery prop.default SPL properties must appear at most once for removal"
    )

mode = stat.S_IMODE(os.stat(target_path).st_mode)
directory = os.path.dirname(target_path)
fd, temporary = tempfile.mkstemp(prefix=".prop.default.", dir=directory)
try:
    with os.fdopen(fd, "w", encoding="utf-8", newline="") as stream:
        stream.writelines(rewritten)
    os.chmod(temporary, mode)
    os.replace(temporary, target_path)
finally:
    if os.path.exists(temporary):
        os.unlink(temporary)

actual = values_from(target_path, keys)
if actual != expected:
    raise SystemExit("Recovery prop.default post-write verification failed")
with open(target_path, "r", encoding="utf-8", newline="") as stream:
    remaining = stream.read()
for key in seen_spl:
    if re.search(r"(?m)^" + re.escape(key) + r"=", remaining):
        raise SystemExit("SPL property still present in prop.default: " + key)
if not os.path.islink(default_link) or os.readlink(default_link) != "prop.default":
    raise SystemExit("default.prop symlink changed during property update")

PY

# 6. Record the final ramdisk inventory (consumed by package-vendor-boot.sh
#    verification and incremental builds).
cd "$root"
find . | sed "s/.\\///" > ramdisk-files.txt
find -type f | sed "s/.\\/ramdisk-files.sha256sum//" | sed "/prop.default/d" |
    xargs sha256sum > ramdisk-files.sha256sum
