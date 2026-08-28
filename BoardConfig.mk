# Copyright (C) 2025 The OrangeFox for pd2415 contributors
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Modeled on device_xiaomi_dali_twrp/BoardConfig.mk. TW_/OF_/FOX_ build flags
# live HERE; twrp_pd2415.mk stays a minimal product makefile.

DEVICE_PATH := device/vivo/pd2415
TARGET_COPY_OUT_VENDOR := vendor
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/recovery.fstab
BOARD_VENDOR_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy
TW_USES_VENDOR_LIBS := true

# --- arch --------------------------------------------------------------------
TARGET_ARCH := arm64
# MediaTek MT6991 (Dimensity 9400) kernel is armv9-a (same SoC as dali).
TARGET_ARCH_VARIANT := armv9-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := generic
TARGET_SUPPORTS_64_BIT_APPS := true

TARGET_NO_BOOTLOADER := true
TARGET_NO_RADIOIMAGE := true
TARGET_NO_RECOVERY := true

# --- A/B ---------------------------------------------------------------------
AB_OTA_UPDATER := true
OF_USE_AIDL_BOOT_CONTROL := 1
# Match the device's dynamic partition set (from stock fstab.mt6991).
AB_OTA_PARTITIONS := boot dtbo init_boot odm odm_dlkm product system system_dlkm system_ext vbmeta vbmeta_system vbmeta_vendor vendor vendor_boot vendor_dlkm

# --- boot image (vendor_boot v4) ---------------------------------------------
# Sizes/offsets/cmdline copied verbatim from the stock vendor_boot.img
# (unpack_bootimg --boot_img stock_vendor_boot.img).
# Source: F:\learn-front\learn-hook\vivo-x200-pm-vendor-boot\mod\vendor_boot.json
BOARD_BOOT_HEADER_VERSION := 4
# From /proc/partitions on device: boot_b=98304 blocks, init_boot_b=8192 blocks
BOARD_BOOTIMAGE_PARTITION_SIZE := 100663296
BOARD_INIT_BOOT_IMAGE_PARTITION_SIZE := 8388608
BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE := 134217728

BOARD_KERNEL_BASE := 0x80000000
BOARD_KERNEL_PAGESIZE := 4096
BOARD_KERNEL_CMDLINE := bootopt=64S3,32N2,64N2 product.version=PD2415_A_15.0.33.7.W10 fingerprint.abbr=15/AP3A.240905.015.A1 region_ver=W10 product.solution=MTK
BOARD_MKBOOTIMG_ARGS := --header_version 4 --kernel_offset 0x00000000 --ramdisk_offset 0xa4d00000 --tags_offset 0x87c80000 --dtb_offset 0x87c80000

TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/kernel
BOARD_INCLUDE_DTB_IN_BOOTIMG := true
BOARD_PREBUILT_DTBIMAGE_DIR := $(DEVICE_PATH)/prebuilt/dtb

# Recovery resources + ramdisk are packed into vendor_boot, not boot.
BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT := true
BOARD_INCLUDE_RECOVERY_RAMDISK_IN_VENDOR_BOOT := true

# --- display -------------------------------------------------------------------
TW_THEME := portrait_hdpi
TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888
TW_BRIGHTNESS_PATH := "/sys/class/leds/lcd-backlight/brightness"
# TODO: read from the stock panel — Dimensity 9400 panels typically use 12-bit
# (4095 or 2047). dali uses 2047; confirm on PD2415.
TW_MAX_BRIGHTNESS := 2047
TW_DEFAULT_BRIGHTNESS := 512

# --- size budget (the platform fragment shares vendor_boot) --------------------
TW_EXCLUDE_DEFAULT_USB_INIT := true
TW_EXCLUDE_BASH := true
TW_EXCLUDE_NANO := true
TW_EXCLUDE_TZDATA := true
TW_EXCLUDE_LPDUMP := true
TW_EXCLUDE_LPTOOLS := true
TW_EXCLUDE_APEX := true
TW_USE_LEGACY_BATTERY_SERVICES := true

# --- ramdisk preparation hook --------------------------------------------------
# Runs after ordinary Recovery relinking and the initial manifests, before
# mkbootfs packages the final root; stages modules / props / HAL / firmware.
BOARD_RECOVERY_IMAGE_PREPARE = $(DEVICE_PATH)/recovery/prepare-ramdisk.sh $(TARGET_RECOVERY_ROOT_OUT) $(SOONG_OUT_DIR)/Android-$(TARGET_PRODUCT).mk $(abspath $(LLVM_READOBJ)) $(abspath $(DEVICE_PATH)/prebuilt/recovery_modules) $(abspath $(DEVICE_PATH)/prebuilt/recovery_properties) $(abspath $(DEVICE_PATH)/prebuilt/recovery_vendor_hal) $(abspath $(DEVICE_PATH)/prebuilt/recovery_firmware)

# pd2415_recovery_prepare_marker is the phony guard package in Android.mk.
TARGET_RECOVERY_DEVICE_MODULES += servicemanager.recovery pd2415_recovery_prepare_marker dmctl

TW_RECOVERY_ADDITIONAL_RELINK_LIBRARY_FILES += $(TARGET_OUT_SHARED_LIBRARIES)/libsysutils.so

# --- flashlight -------------------------------------------------------------------
# TODO: find the correct sysfs paths on PD2415 before enabling.
#   OF_FLASHLIGHT_ENABLE := 1
#   OF_FL_PATH1 := /sys/class/leds/white:flash-1
#   OF_FL_PATH2 := /sys/class/leds/white:flash-2

# --- status bar ---------------------------------------------------------------------
# TODO: confirm indent values on PD2415 panel.
#   OF_STATUS_INDENT_LEFT := 130
#   OF_STATUS_INDENT_RIGHT := 130
# Recovery ships without tzdata (TW_EXCLUDE_TZDATA); use POSIX TZ string.
OF_DEFAULT_TIMEZONE := TAIST-8

# --- crypto ---------------------------------------------------------------------
TW_INCLUDE_CRYPTO := true
# TODO: enable if PD2415 has an eSE/OMAPI service.
# TW_INCLUDE_OMAPI := true
# $(call soong_config_set,omapi,uuid,<OMAPI_UUID>)

# --- modules ----------------------------------------------------------------------
# Boolean switch + quoted module name list. The .ko files are staged into the
# ramdisk /lib/modules by recovery/prepare-ramdisk.sh (never PRODUCT_COPY_FILES).
# Module list copied verbatim from stock platform ramdisk modules.load
# (F:\learn-front\learn-hook\vivo-x200-pm-vendor-boot\mod\root.1\lib\modules\modules.load).
TW_LOAD_VENDOR_BOOT_MODULES := true
TW_LOAD_VENDOR_MODULES := "bootprof.ko mrdump.ko aee_aed.ko vivo_bsp_engine.ko monitor_hang.ko mkp.ko dbgtop-drm.ko irq-dbg.ko dbg_error_flag.ko bus-parity.ko last_bus.ko mtk_sync.ko mtk_disp_notify.ko log_store.ko mtk_printk_ctrl.ko nvmem_mtk-devinfo.ko mtk_wdt.ko timer-mediatek.ko aee_hangdet.ko v_zsmalloc.ko zcache.ko sec-rng.ko device-apc-common.ko device-apc-mt6991.ko mtk-mbox-mailbox.ko tinysys-scmi.ko ise_lpm.ko pinctrl-mtk-v2.ko pinctrl-mt6991.ko smap-mt6991.ko mtk-dvfsrc-regulator.ko mtk-emi.ko mtk-dvfsrc.ko mtk-scpsys.ko mt6991_dcm.ko mtk_dcm.ko clk-common.ko clk-fmeter-mt6991.ko iommu_debug.ko smmu_secure.ko arm_smmu_v3.ko mm-fake-engine.ko clk-chk-mt6991.ko mtk-scpsys-mt6991-spm.ko vcp_status_v2.ko vcp_v2.ko clk-mt6991.ko clk-mt6991-adsp.ko clk-mt6991-cam.ko clk-mt6991-img.ko clk-mt6991-mmsys.ko clk-mt6991-peri.ko clk-mt6991-mdpsys.ko clk-mt6991-bus.ko clk-mt6991-vcodec.ko mtk-ise-mailbox.ko ise-trusty.ko ise-trusty-log.ko ise-trusty-ipc.ko ise-trusty-virtio.ko sn100.ko sn100_spi.ko mtk-pmic-wrap.ko mtk-spmi-pmic.ko spmi-mtk-pmif.ko mt6316-regulator.ko mt6363-regulator.ko mt6373-regulator.ko pinctrl-mt6373.ko pinctrl-mt6363.ko pinctrl-mtk-common-v2_debug.ko mt6379-regulator.ko mt6681-regulator.ko mtk-dvfsrc-helper.ko mtk-dvfsrc-devfreq.ko mtk-scpsys-mt6991-mmpc.ko mtk-vmm-notifier-mt6991.ko pd-chk-mt6991.ko mtk_dramc.ko mtk-hw-semaphore.ko mtk-smi.ko mtk-smi-dbg.ko mtk-icc-core.ko mtk-mmdvfs-ftrace.ko mtk-mmdvfs-v3.ko mtk-mmdvfs.ko mtk-mmdvfs-debug.ko mmqos-common.ko mmqos-mt6991.ko mtk-mmdebug-vcp.ko mtk_iommu_util.ko system_heap.ko mtk-cmdq-drv-ext.ko cmdq-platform-mt6991.ko mdp_drv_mt6991.ko mtk-mml.ko symphony.ko vkyber-iosched.ko blk-enhance.ko mtk-mml-mt6991.ko cmdq_helper_inf.ko rt4831a_drv.ko mtk_panel_ext.ko vivo_display.ko panel_common.ko panel_virtual.ko panel-truly-td4330-cmd.ko panel-truly-nt35595-cmd.ko panel-alpha-jdi-nt36672e-vdo-60hz.ko panel-alpha-jdi-nt36672e-vdo-120hz.ko panel-nt37801-cmd-fhd.ko panel-nt37801-cmd-fhd-plus.ko panel-alpha-jdi-nt36672e-cphy-vdo.ko mtk-afe-external.ko drm_dma_helper.ko drm_display_helper.ko mediatek-drm.ko aee_rs.ko mmprofile.ko mtk_vdisp_v2.ko mtk_dpc_v2.ko mtk-uart-apdma.ko 8250_mtk.ko mt6685-core.ko mt6685-audclk.ko mt6685-nvtclk.ko mt6681-core.ko mt6681-auxadc.ko nvmem-mt6681-efuse.ko clkbuf.ko ffa_v11.ko teeperf.ko mcDrvModule-ffa.ko isee-ffa.ko mtk-spmi-pmic-adc.ko mt6379s.ko industrialio-triggered-buffer.ko kfifo_buf.ko mt6379-adc.ko mt6375-auxadc.ko rpmb.ko rpmb-mtk.ko cqhci.ko mtk-mmc-dbg.ko mtk-mmc.ko pmic_lbat_service.ko pmic_lvsys_notify.ko mtk_low_battery_throttling.ko mtk_battery_oc_throttling.ko phy-mtk-ufs.ko ufs-mediatek-mod-ise.ko ufs-mediatek-dbg.ko blocktag.ko pidmap.ko mtk-pmic-keys.ko regulator-vibrator.ko mtk-i3c-i2c-wrap.ko i2c-mt65xx.ko mtk-i3c-master-mt69xx.ko mtk_dramc.ko spi-mt65xx.ko phy-mtk-nxp-eusb2-repeater.ko phy-mtk-mt6379-eusb2-repeater.ko phy-mtk-xsphy.ko xhci-mtk-hcd-v2.ko mtu3.ko usb_boost.ko mux_switch.ko ps5170.ko usb_dp_selector.ko extdev_io_class.ko rt4803.ko rt6160-regulator.ko rtc-mt6685.ko vivo_rpk_ctrl.ko vivo_rsmc_driver.ko vivo_board_info.ko vivo_board_info_detect.ko adapter_class.ko charger_class.ko mtk_charger_algorithm_class.ko ufcs_class.ko ufcs_mt6379.ko mt6379-chg.ko pd_dbg_info.ko tcpc_class.ko tcpc_mt6379.ko mtk_chg_type_det.ko mtk_pd_adapter.ko mtk_ufcs_adapter.ko mtk_pep40.ko mtk_pep45.ko mtk_pd_charging.ko mtk_pep20.ko mtk_pep.ko mtk_charger_framework.ko mtk_2p_charger.ko rt_pd_manager.ko vfcs-vpsy.ko vfcs-misc-core.ko vfcs-bq28z610.ko vfcs-sm5602.ko vfcs-multi-fg-core.ko mt6379-battery.ko vfcs-battery.ko vfcs-battery_id.ko vfcs-fuelsummary.ko vivo_tshell.ko vfcs-chg.ko vfcs-bq25601d.ko vfcs-bq2579x.ko vfcs-bq25890h.ko vfcs-mp2762.ko vfcs-rt9467.ko vfcs-sc89601d.ko vfcs-cms-core.ko vfcs-core.ko vfcs-cp-dev.ko vfcs-pi-dev.ko vfcs-fchg-core.ko vfcs-reserved-block-core.ko vfcs-meter.ko vfcs-fg-common-core.ko vfcs-max77932.ko vfcs-sc8510.ko vfcs-max77929.ko vfcs-wls-monitor.ko vfcs-vivo-wls-idtp9415.ko vfcs-vivo-wls-cps4041.ko pwm-mtk-disp.ko phy-mtk-pcie.ko pcie-mediatek-gen3.ko leds-mtk.ko leds-mtk-disp.ko leds-mtk-pwm.ko v4l2-flash-led-class.ko extcon-mtk-usb.ko tcpci_late_sync.ko mtk-mminfra-debug.ko mtk-mminfra-imax.ko reset-ti-syscon.ko adsp.ko mtk_slbc.ko slbc_ipi.ko slbc_trace.ko mtk_bp_thl.ko pie_driver.ko mediatek-cpufreq-hw.ko mtk_cpu_power_throttling.ko arm_dsu_pmu.ko mtk-swpm-perf-arm-pmu.ko emi.ko emi-mpu.ko smpu.ko smpu-hook-v1.ko emi-slb.ko slc-parity.ko usb_meta.ko mediatek-cpufreq-hw.ko mtk-socinfo.ko cache-parity.ko gic-ram-parity.ko systracker.ko pkvm_tmem.ko pkvm_mgmt.ko pkvm_smmu.ko pkvm_mkp.ko mtk_battery_manager.ko vsed.ko vne.ko vivo_netstats.ko sch_cfg.ko sch_ufifo.ko sch_uprio.ko vpsnh.ko vr.ko vklp.ko vivo_rsc.ko vivo_tcp.ko lz4m.ko shrinker_proxy.ko vivo_mm_debug.ko vivo_slowpath_opt.ko vivo_wifi_driver.ko kprobe_fs_special.ko vivo_rms.ko thp_pool.ko vivo_fs_trace.ko"

# --- identity / localization ------------------------------------------------------
OF_MAINTAINER := LongMo
TW_DEFAULT_LANGUAGE := zh_CN
FOX_USE_DATA_RECOVERY_FOR_SETTINGS := 1
