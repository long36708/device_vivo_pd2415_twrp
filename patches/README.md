# Device-specific patch series (optional)

Place `*.patch` files here; `apply-patches.sh` applies them in order (git apply
with `patch --fuzz=3` fallback for whitespace/context drift). Give patches a
`NNNN-slug.patch` numbering and keep each focused on one change.

Once the series spans multiple repos (`bootable/recovery`,
`system/core/fs_mgr`, `system/update_engine`, ...) or needs per-patch strip
levels (`-p1`/`-p3`) or `--recount`, replace the default lexicographic loop in
`apply-patches.sh` with an explicit pinned `apply_one` list, exactly like
`device_xiaomi_dali_twrp/apply-patches.sh`.

Whole-repo cumulative diffs (`git diff HEAD` snapshots) belong in
`patches/source/` (reference only — NOT applied by apply-patches.sh).
