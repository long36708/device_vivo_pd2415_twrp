#!/bin/sh
# Copyright (C) 2025 The OrangeFox for pd2415 contributors
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Extract the recovery-relevant binaries from the official pd2415 vendor_boot
# into prebuilt/ and the stock recovery configuration into the tree. Modeled on
# device_xiaomi_dali_twrp/extract-official-prebuilts.sh.
#
# Usage: sh extract-official-prebuilts.sh /absolute/path/to/official-vendor-boot/mod
#
# For pd2415 the official vendor_boot is already unpacked at
# F:\learn-front\learn-hook\vivo-x200-pm-vendor-boot\mod (Android_boot_image_editor).
# Pass that mod/ directory as the source root.
#
# NOTE: prebuilt/kernel must be extracted from the stock boot.img (not
# vendor_boot). Run unpack_bootimg on stock boot.img separately and copy
# the kernel to prebuilt/kernel before building.

set -eu

if [ "$#" -ne 1 ]; then
    echo "usage: $0 /absolute/path/to/official-vendor-boot/mod" >&2
    exit 2
fi

source_root=$(readlink -f -- "$1") || {
    echo "failed to canonicalize official extraction root: $1" >&2
    exit 2
}

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
out="$script_dir/prebuilt"

# --- dtb ----------------------------------------------------------------------
install -D -m 0644 "$source_root/dtb" "$out/dtb/pd2415.dtb"

# --- platform ramdisk (cpio -> gzip) -------------------------------------------
# NOTE: the official vendor_boot platform ramdisk is shipped as TWO artifacts in
# mod/: `ramdisk.1` (a plain newc cpio, header "0707...") and `ramdisk.1.lz4`.
# `ramdisk.1.lz4` uses vivo/MTK's private lz4 variant (magic 02 21 4C 18), which
# the stock `lz4` binary CANNOT decompress — using `lz4 -dc` on it produced a
# truncated platform fragment (missing /init, /sepolicy, *_file_contexts, ...),
# which made the device hang at the logo even on the stock boot image. Always
# take the already-extracted plain cpio `ramdisk.1` instead.
platform_dir="$out/vendor_ramdisk"
mkdir -p "$platform_dir"
platform_gzip="$platform_dir/platform.cpio.gz"
platform_gzip_tmp=$(mktemp "$platform_dir/.platform.cpio.gz.XXXXXX")
cleanup() {
    rm -f "$platform_gzip_tmp"
}
trap cleanup EXIT HUP INT TERM
if [ -f "$source_root/ramdisk.1" ]; then
    gzip -9 -n -c "$source_root/ramdisk.1" > "$platform_gzip_tmp"
elif [ -f "$source_root/ramdisk.1.lz4" ]; then
    echo "[!] ramdisk.1.lz4 is vivo/MTK private lz4 and cannot be decompressed by" >&2
    echo "    stock lz4; use the plain cpio ramdisk.1 instead." >&2
    exit 1
else
    echo "[!] neither ramdisk.1 nor ramdisk.1.lz4 found in $source_root" >&2
    exit 1
fi
mv "$platform_gzip_tmp" "$platform_gzip"

# --- official recovery ramdisk (cpio -> gzip) ---------------------------------
official_recovery_raw="$source_root/ramdisk.2"
official_recovery_gzip="$platform_dir/official_recovery.cpio.gz"
official_recovery_gzip_tmp=$(mktemp "$platform_dir/.official_recovery.cpio.gz.XXXXXX")
gzip -9 -n -c "$official_recovery_raw" > "$official_recovery_gzip_tmp"
mv "$official_recovery_gzip_tmp" "$official_recovery_gzip"

# --- first-stage fstab --------------------------------------------------------
install -D -m 0644 "$source_root/root.1/first_stage_ramdisk/fstab.mt6991" \
    "$script_dir/recovery/root/first_stage_ramdisk/fstab.mt6991"

# --- recovery modules (from platform ramdisk root.1/lib/modules) -------------
recovery_modules="$out/recovery_modules"
mkdir -p "$recovery_modules"
for ko in "$source_root/root.1/lib/modules"/*.ko
do
    [ -e "$ko" ] || continue
    install -m 0644 "$ko" "$recovery_modules/$(basename "$ko")"
done
if [ -f "$source_root/root.1/lib/modules/modules.dep" ]; then
    install -m 0644 "$source_root/root.1/lib/modules/modules.dep" \
        "$recovery_modules/modules.dep"
fi
(cd "$recovery_modules" && sha256sum *.ko modules.dep > modules.sha256)

# --- build props --------------------------------------------------------------
install -D -m 0644 "$source_root/root.1/system/etc/ramdisk/build.prop" \
    "$out/recovery_properties/system.build.prop"
# vendor.build.prop must be extracted from the OTA vendor partition payload.
if [ -f "$source_root/vendor/build.prop" ]; then
    install -D -m 0644 "$source_root/vendor/build.prop" \
        "$out/recovery_properties/vendor.build.prop"
else
    echo "[!] vendor.build.prop not found in vendor_boot mod" >&2
    echo "    Extract it from the OTA vendor partition payload." >&2
fi

# --- vendor HAL closure (crypto chain) -----------------------------------------
# Copy the vendor HAL executables, lib64 closure and TA directories the
# recovery crypto chain needs. Source: root.2/vendor/ (recovery ramdisk already
# ships them) or the OTA vendor partition.
mkdir -p "$out/recovery_vendor_hal"
if [ -d "$source_root/root.2/vendor" ]; then
    cp -a -- "$source_root/root.2/vendor/." "$out/recovery_vendor_hal/" 2>/dev/null ||
        echo "[!] vendor HAL inputs not found in root.2/vendor" >&2
else
    echo "[!] vendor HAL closure not found — extract from OTA vendor partition" >&2
fi

# --- firmware (haptics / touch) --------------------------------------------------
mkdir -p "$out/recovery_firmware"
if [ -d "$source_root/root.2/vendor/firmware" ]; then
    cp -a -- "$source_root/root.2/vendor/firmware/." "$out/recovery_firmware/" 2>/dev/null ||
        echo "[!] firmware inputs not found in root.2/vendor/firmware" >&2
fi

echo "[+] Done. Record the SHA256 sums below in package-vendor-boot.sh as device contracts."
(cd "$out" && find . -type f -exec sha256sum {} +)
