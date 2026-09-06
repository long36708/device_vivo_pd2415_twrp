#!/system/bin/sh
# Copyright (C) 2025 The OrangeFox for pd2415 contributors
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Multi-pass insmod for kernel modules listed in modules.dep.
# modules.dep entries are not topologically sorted, so a module may
# appear before its dependencies. Retry up to 5 passes so that once
# deps load in an earlier pass, the dependent module succeeds in the next.
mods=$(cat /lib/modules/modules.dep | while read line; do echo ${line%%:*}; done)
for pass in 1 2 3 4 5; do
    changed=0
    for m in $mods; do
        if insmod $m 2>/dev/null; then
            changed=1
        fi
    done
    [ "$changed" = "0" ] && break
done
