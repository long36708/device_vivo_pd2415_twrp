#!/bin/sh
# Copyright (C) 2025 The OrangeFox for pd2415 contributors
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Re-apply the device patch series on top of a pristine OrangeFox sync.
# Run from the OrangeFox source root:
#   sh /path/to/device_vivo_pd2415_twrp/apply-patches.sh
#
# Modeled on device_xiaomi_dali_twrp/apply-patches.sh: every patch is applied
# in a pinned order against its target repo (bootable/recovery,
# system/core/fs_mgr, system/update_engine, or the source root "."), with
# per-patch strip levels and --recount for drifted hunk headers, falling back
# to `patch -p1 --fuzz=3` on whitespace/context drift.

set -eu

PATCH_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/patches/recovery"

[ -d bootable/recovery ] || {
    echo "error: run from the OrangeFox source root (bootable/recovery not found)" >&2
    exit 1
}

# apply_one <repo-or-.> <git-apply-extra-args> <patch-file>
apply_one() {
    repo=$1
    shift
    extra=$1
    shift
    patch_file=$1
    if [ "$repo" = "." ]; then
        if git apply $extra "$patch_file"; then
            return 0
        fi
    else
        if git -C "$repo" apply $extra "$patch_file"; then
            return 0
        fi
    fi
    echo "git apply failed for $(basename "$patch_file"), retrying with patch --fuzz=3" >&2
    if [ "$repo" = "." ]; then
        patch -p1 --fuzz=3 --forward < "$patch_file"
    else
        (cd "$repo" && patch -p1 --fuzz=3 --forward < "$patch_file")
    fi
}

# Default: apply every patch in lexicographic order against the source root.
# Once the series grows or spans multiple repos, replace this loop with an
# explicit pinned list, e.g.:
#   apply_one bootable/recovery "-p1" "$PATCH_DIR/0001-....patch"
#   apply_one system/core/fs_mgr "-p1" "$PATCH_DIR/0002-....patch"
#   apply_one bootable/recovery "--recount" "$PATCH_DIR/0003-....patch"
for p in "$PATCH_DIR"/*.patch
do
    [ -e "$p" ] || continue
    echo "[*] applying $(basename "$p")"
    apply_one . "-p1" "$p"
done

echo "All patches applied."
