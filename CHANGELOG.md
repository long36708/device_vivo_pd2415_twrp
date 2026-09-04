# Changelog

All notable changes to the vivo X200 Pro mini (pd2415) TWRP/OrangeFox device
tree. Keep the same format as device_xiaomi_dali_twrp/CHANGELOG.md when
filling per-device entries.

## [Unreleased]

### Added
- Initial device tree scaffold generated from create-twrp-device-tree.
- vivo X200 Pro mini (PD2415) / MediaTek MT6991 (Dimensity 9400) / Android 15.
- vendor_boot v4 dual-fragment layout (platform + recovery), AVB 1.0 hash
  footer with stock salt + fingerprint.
- 289 kernel modules from the stock platform ramdisk (modules.load).
- FBE spec: aes-256-xts:aes-256-cts:v2+inlinecrypt_optimized (from stock
  fstab.mt6991 line 87, copied verbatim).
- Recovery-only recovery.fstab with curated partition inventory; persist via
  fstab.pd2415.persist (not formattable).
- sepolicy scaffold (pd2415_recovery.te, file_contexts, genfs_contexts,
  property_contexts) using platform-defined types (persist_data_file, ...).
- extract-official-prebuilts.sh adapted for the pre-unpacked vendor_boot mod
  at F:\learn-front\learn-hook\vivo-x200-pm-vendor-boot\mod.

### TODO (before first build)
- Extract prebuilt/kernel from stock boot.img (not in vendor_boot).
- Read BOARD_INIT_BOOT_IMAGE_PARTITION_SIZE from stock init_boot.img.
- Fill SHA_PLACEHOLDER constants in package-vendor-boot.sh from the actual
  prebuilt files (sha256sum).
- Wire the crypto HAL chain in init.recovery.project.rc (tee-supplicant,
  keymint, gatekeeper, weaver, secure_element) — port from dali reference.
- Confirm TW_MAX_BRIGHTNESS (2047 vs 4095) on the PD2415 panel.
- Confirm OF_STATUS_INDENT_LEFT/RIGHT on the PD2415 panel.
- Extract vendor.build.prop from the OTA vendor partition payload.

### Changed
- Vendor ramdisk fragments are written as lz4-legacy (the stock format) instead
  of gzip. gzip remains available via `PD2415_FRAGMENT_COMPRESSION=gzip` and as
  an automatic fallback when no `lz4` binary is on the build host.

### Fixed
- `--ramdisk_offset` 0x24d00000 -> 0x24b00000 in both `BoardConfig.mk` and
  `package-vendor-boot.sh`. `vendor_boot.json` publishes the load address as
  DECIMAL (`2762997760` = 0xA4B00000); the old value put the vendor ramdisk
  2 MiB above the stock address, which broke normal boot *and* recovery.
- The recovery ramdisk no longer duplicates the 337 platform kernel modules.
  Recovery mode loads `vendor_ramdisk00` (platform) **and** `vendor_ramdisk01`,
  and the stock platform ramdisk already ships the full `/lib/modules` closure
  (the official recovery ramdisk contains no `.ko` at all). `prepare-ramdisk.sh`
  now stages only the modules the platform fragment is missing (~70 MB less in
  the recovery fragment).

### Removed
-
