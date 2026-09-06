#!/system/bin/sh
# Copyright (C) 2025 The OrangeFox for pd2415 contributors
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Mount the persist partition WITHOUT relying on /dev/block/by-name
# symlinks: those are only created for partitions listed in the (first
# stage) fstab, and ours does not include persist.  Fast path by-name,
# fallback: scan /sys/class/block for the partition with PARTNAME=persist.

if [ -e /dev/block/by-name/persist ]; then
    mount ext4 /dev/block/by-name/persist /mnt/vendor/persist && exit 0
fi

for d in /sys/class/block/*/uevent; do
    [ -f "$d" ] || continue
    if grep -q '^PARTNAME=persist$' "$d" 2>/dev/null; then
        dev=$(basename "${d%/uevent}")
        mount ext4 "/dev/block/$dev" /mnt/vendor/persist && exit 0
    fi
done

echo "mount-persist: persist partition not found" >&2
exit 1
