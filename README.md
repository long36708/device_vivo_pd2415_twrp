# OrangeFox / TWRP device tree for `vivo X200 Pro mini` (`pd2415`)

This device tree follows the **OrangeFox 14.1** layout (modeled on
`device_xiaomi_dali_twrp`). It builds a recovery ramdisk packed into a
`vendor_boot` v4 image with a dual fragment (platform + recovery), assembled
and AVB-footered by `package-vendor-boot.sh`.

Every device-derived artifact is extracted from the official OTA and
SHA-verified — never hand-written.

## Device info

| Item | Value |
|---|---|
| Device | vivo X200 Pro mini (PD2415) |
| SoC | MediaTek MT6991 (Dimensity 9400) |
| Android | 15 (AP3A.240905.015.A1) |
| vendor_boot header | v4 |
| AVB | 1.0 (avbtool 1.3.0, sha256, algorithm NONE) |
| Kernel arch | arm64 / armv9-a |
| FBE | aes-256-xts:aes-256-cts:v2+inlinecrypt_optimized |
| Maintainer | LongMo |

## Layout

```
device_vivo_pd2415_twrp/
  AndroidProducts.mk    lunch: twrp_pd2415-ap3a-eng
  BoardConfig.mk        arch, v4 offsets, AB_OTA, TW_/OF_/FOX_ flags,
                        BOARD_RECOVERY_IMAGE_PREPARE hook, module config
  Android.mk            phony guard package (fails build when prebuilts are missing)
  device.mk             PRODUCT_USE_DYNAMIC_PARTITIONS only
  twrp_pd2415.mk        minimal product makefile: inherit chain + identity
  recovery.fstab        curated recovery-only partition inventory
  apply-patches.sh      ordered patch application (git apply + patch --fuzz=3)
  extract-official-prebuilts.sh   pull prebuilts + stock fstab/rc from the OTA
  package-vendor-boot.sh          assemble + verify the final vendor_boot v4
  patches/recovery/     device-specific *.patch series (optional)
  prebuilt/             kernel, dtb, recovery_modules, recovery_properties,
                        recovery_vendor_hal, recovery_firmware, vendor_ramdisk
  recovery/
    prepare-ramdisk.sh  BOARD_RECOVERY_IMAGE_PREPARE hook: stages modules /
                        firmware / vendor HAL closure, rewrites prop.default
    root/               first_stage_ramdisk, init.recovery.*.rc, system/etc/*
  sepolicy/             file_contexts, property_contexts, genfs_contexts,
                        pd2415_*.te
```

## Required binaries (NOT in-tree)

Extract from the official firmware with `extract-official-prebuilts.sh` and
place under `prebuilt/`:

| File | Source |
|---|---|
| `prebuilt/kernel` | stock `boot` image kernel (NOT in vendor_boot — extract separately) |
| `prebuilt/dtb/pd2415.dtb` | stock `vendor_boot` dtb (mod/dtb) |
| `prebuilt/recovery_modules/*.ko` + `modules.dep` + `modules.sha256` | stock platform ramdisk (mod/root.1/lib/modules/) |
| `prebuilt/recovery_properties/system.build.prop` | mod/root.1/system/etc/ramdisk/build.prop |
| `prebuilt/recovery_properties/vendor.build.prop` | OTA vendor partition payload |
| `prebuilt/recovery_vendor_hal/` (bin/, lib64/, TA dirs) | vendor HAL crypto closure (tee-supplicant, keymint, gatekeeper, weaver, secure_element, boot HAL) |
| `prebuilt/recovery_firmware/` (*.bin, *.wmfw) | haptic / touch firmware |
| `prebuilt/vendor_ramdisk/platform.cpio.gz` | stock `vendor_boot` ramdisk.1 (lz4 -> gzip) |
| `prebuilt/vendor_ramdisk/official_recovery.cpio.gz` | stock `vendor_boot` ramdisk.2 (recovery, cpio -> gzip) |
| `recovery/root/first_stage_ramdisk/fstab.mt6991` | stock first-stage fstab (verbatim) |
| `recovery/root/init.recovery.mt6991.rc` | SoC init (same MT6991 as dali) |

Record the SHA256 sums of every input in `package-vendor-boot.sh` as device
contracts before building.

## Build

```bash
# 1. apply the OrangeFox base patches (when porting the same base)
sh <device-tree>/apply-patches.sh          # from the OrangeFox source root

# 2. build the stock-layout vendor_boot (recovery fragment included)
source build/envsetup.sh
lunch twrp_pd2415-ap3a-eng
m vendorboot

# 3. assemble + verify the final image
sh <device-tree>/package-vendor-boot.sh "$(pwd)" "$(pwd)/out/target/product/pd2415/vendor_boot-final.img"
```

## Notes

- No `init/init_pd2415.cpp` and no flat `system.prop` — properties are set
  via `twrp_pd2415.mk` and the `init.recovery.*.rc` files; `prepare-ramdisk.sh`
  rewrites `prop.default` from the official build props.
- TW_/OF_/FOX_ flags live in `BoardConfig.mk`; `twrp_pd2415.mk` is minimal.
- `recovery.fstab` is the curated recovery-only inventory; early mount uses
  `recovery/root/first_stage_ramdisk/fstab.mt6991` (stock, verbatim) and persist
  mounts via `recovery/root/system/etc/fstab.pd2415.persist`.
- Kernel modules: `TW_LOAD_VENDOR_BOOT_MODULES := true` +
  `TW_LOAD_VENDOR_MODULES := "<list>"` in BoardConfig.mk; the files are staged
  into `/lib/modules` by `recovery/prepare-ramdisk.sh` (never PRODUCT_COPY_FILES).
- The crypto HAL wiring in `init.recovery.project.rc` and `sepolicy/` is
  device-specific; copy the structure from `device_xiaomi_dali_twrp` and adjust
  service names / node paths.

## Pre-built vendor_boot source

The official vendor_boot is already unpacked at
`F:\learn-front\learn-hook\vivo-x200-pm-vendor-boot\mod` (via
Android_boot_image_editor). Run:

```bash
sh extract-official-prebuilts.sh /absolute/path/to/vivo-x200-pm-vendor-boot/mod
```

to populate `prebuilt/` from that directory.
