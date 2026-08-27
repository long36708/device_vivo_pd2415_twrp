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
-

### Fixed
-

### Removed
-
