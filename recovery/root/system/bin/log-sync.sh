#!/system/bin/sh
# Copyright (C) 2025 The OrangeFox for pd2415 contributors
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Keep copying TWRP's own boot log (/tmp/recovery.log, tmpfs — lost on
# reboot) to the persist partition so it survives the auto-reboot and can
# be pulled from the running system.  This is the only reliable way to see
# where the recovery binary hangs when the UI never comes up and adb in
# recovery is unavailable.

while true; do
    if [ -f /tmp/recovery.log ] && [ -d /mnt/vendor/persist ]; then
        cp -f /tmp/recovery.log /mnt/vendor/persist/recovery_log.txt 2>/dev/null
    fi
    sleep 5
done
