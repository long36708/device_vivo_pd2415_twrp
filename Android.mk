# Copyright (C) 2025 The OrangeFox for pd2415 contributors
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Phony guard package modeled on device_xiaomi_dali_twrp/Android.mk: every
# prebuilt and ramdisk input is enumerated as a dependency, so `m vendorboot`
# fails early when an extraction step was skipped or a file is missing.
# The prebuilts are consumed in place (by prepare-ramdisk.sh and
# package-vendor-boot.sh), so nothing is installed — this module only guards.

LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_MODULE := pd2415_recovery_prepare_marker
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_PATH := $(TARGET_RECOVERY_ROOT_OUT)
# Expand the module list from BoardConfig.mk into explicit paths: a missing
# .ko then fails the build early ("No rule to make target") instead of being
# silently swallowed by $(wildcard). Keep this list in sync with
# TW_LOAD_VENDOR_MODULES.
#
# prepare-ramdisk.sh stages only the modules the platform fragment does NOT
# already provide (see BoardConfig.mk), so in practice nothing is copied from
# here. These files stay declared as dependencies deliberately: if a future
# platform ramdisk drops a module, the delta is picked up from this directory
# and a missing file still fails the build instead of yielding a recovery that
# cannot load it.
#
# IMPORTANT: the list below is the BARE module names (space-separated,
# NO surrounding quotes) — it must match the value substituted into
# prepare-ramdisk.sh's `for module in ...` loop. The BoardConfig.mk
# TW_LOAD_VENDOR_MODULES := "..." keeps its own literal quotes, but
# Android.mk / prepare-ramdisk.sh / extract-official-prebuilts.sh strip them.
# Pasting the quoted BoardConfig value here yields ".../\"scp.ko" paths.
KO_FILES := $(foreach ko,8250_mtk.ko adapter_class.ko aee_aed.ko aee_hangdet.ko aee_rs.ko arm_dsu_pmu.ko arm_smmu_v3.ko blk-enhance.ko blocktag.ko bootprof.ko bus-parity.ko cache-parity.ko clk-chk-mt6991.ko clk-common.ko clk-dbg-mt6991.ko clk-fmeter-mt6991.ko clk-mt6991-adsp.ko clk-mt6991-bus.ko clk-mt6991-cam.ko clk-mt6991-img.ko clk-mt6991-mdpsys.ko clk-mt6991-mmsys.ko clk-mt6991-peri.ko clk-mt6991-vcodec.ko clk-mt6991.ko clkbuf.ko cmdq-platform-mt6991.ko cmdq_helper_inf.ko cqhci.ko dbg_error_flag.ko dbgtop-drm.ko device-apc-common.ko device-apc-mt6991.ko drm_display_helper.ko drm_dma_helper.ko emi-mpu.ko emi-slb.ko emi.ko event_track.ko extcon-mtk-usb.ko extdev_io_class.ko ffa_v11.ko fp_dispatch_event.ko gic-ram-parity.ko handshake_counter.ko i2c-mt65xx.ko industrialio-triggered-buffer.ko iommu_debug.ko irq-dbg.ko ise-trusty-ipc.ko ise-trusty-log.ko ise-trusty-virtio.ko ise-trusty.ko ise_lpm.ko isee-ffa.ko kfifo_buf.ko last_bus.ko leds-mtk-disp.ko leds-mtk-pwm.ko leds-mtk.ko libarc4.ko load_track.ko log_store.ko mcDrvModule-ffa.ko mdp_drv_mt6991.ko mediatek-cpufreq-hw.ko mediatek-drm.ko mkp.ko mm-fake-engine.ko mmprofile.ko mmqos-common.ko mmqos-mt6991.ko monitor_hang.ko mrdump.ko mt6316-regulator.ko mt6363-regulator.ko mt6373-regulator.ko mt6375-auxadc.ko mt6379-adc.ko mt6379-regulator.ko mt6379s.ko mt6681-auxadc.ko mt6681-core.ko mt6681-regulator.ko mt6991_dcm.ko mtk-afe-external.ko mtk-cmdq-drv-ext.ko mtk-dvfsrc-devfreq.ko mtk-dvfsrc-helper.ko mtk-dvfsrc-regulator.ko mtk-dvfsrc.ko mtk-emi.ko mtk-hw-semaphore.ko mtk-i3c-i2c-wrap.ko mtk-i3c-master-mt69xx.ko mtk-icc-core.ko mtk-ise-mailbox.ko mtk-mbox-mailbox.ko mtk-mbox.ko mtk-mmc-dbg.ko mtk-mmc.ko mtk-mmdebug-vcp.ko mtk-mmdvfs-debug.ko mtk-mmdvfs-ftrace.ko mtk-mmdvfs-v3-start.ko mtk-mmdvfs-v3.ko mtk-mmdvfs.ko mtk-mminfra-debug.ko mtk-mminfra-imax.ko mtk-mml-mt6991.ko mtk-mml.ko mtk-pmic-keys.ko mtk-pmic-wrap.ko mtk-scpsys-mt6991-mmpc.ko mtk-scpsys-mt6991-spm.ko mtk-scpsys.ko mtk-smi-dbg.ko mtk-smi.ko mtk-socinfo.ko mtk-spmi-pmic-adc.ko mtk-spmi-pmic.ko mtk-swpm-perf-arm-pmu.ko mtk-uart-apdma.ko mtk-vmm-notifier-mt6991.ko mtk_battery_oc_throttling.ko mtk_bp_thl.ko mtk_cpu_power_throttling.ko mtk_dcm.ko mtk_disp_notify.ko mtk_dpc_v2.ko mtk_dramc.ko mtk_iommu_util.ko mtk_low_battery_throttling.ko mtk_panel_ext.ko mtk_printk_ctrl.ko mtk_rpmsg_mbox.ko mtk_slbc.ko mtk_sync.ko mtk_tinysys_ipi.ko mtk_vdisp_v2.ko mtk_wdt.ko mtu3.ko mux_switch.ko nvmem-mt6681-efuse.ko nvmem_mtk-devinfo.ko panel-alpha-jdi-nt36672e-cphy-vdo.ko panel-alpha-jdi-nt36672e-vdo-120hz.ko panel-alpha-jdi-nt36672e-vdo-60hz.ko panel-nt37801-cmd-fhd-plus.ko panel-nt37801-cmd-fhd.ko panel-truly-nt35595-cmd.ko panel-truly-td4330-cmd.ko panel_common.ko panel_virtual.ko pcie-mediatek-gen3.ko pd-chk-mt6991.ko pd_dbg_info.ko phy-mtk-mt6379-eusb2-repeater.ko phy-mtk-nxp-eusb2-repeater.ko phy-mtk-pcie.ko phy-mtk-ufs.ko phy-mtk-xsphy.ko pidmap.ko pie_driver.ko pinctrl-mt6363.ko pinctrl-mt6373.ko pinctrl-mt6991.ko pinctrl-mtk-common-v2_debug.ko pinctrl-mtk-v2.ko pkvm_mgmt.ko pkvm_mkp.ko pkvm_smmu.ko pkvm_tmem.ko pmic_lbat_service.ko pmic_lvsys_notify.ko ps5170.ko pwm-mtk-disp.ko reboot-mode.ko regulator-vibrator.ko reset-ti-syscon.ko rpmb-mtk.ko rpmb.ko rt4803.ko rt4831a_drv.ko rt6160-regulator.ko rtc-mt6685.ko sec-rng.ko sec.ko sensors_class.ko shrinker_proxy.ko slbc_ipi.ko slbc_trace.ko slc-parity.ko smap-mt6991.ko smmu_secure.ko smpu-hook-v1.ko smpu.ko sn100.ko sn100_spi.ko spi-mt65xx.ko spmi-mtk-pmif.ko symphony.ko syscon-reboot-mode.ko system_heap.ko systracker.ko tcpc_class.ko tcpci_late_sync.ko teeperf.ko thp_pool.ko timer-mediatek.ko tinysys-scmi.ko ufs-mediatek-dbg.ko ufs-mediatek-mod-ise.ko usb_boost.ko usb_dp_selector.ko usb_meta.ko v4l2-flash-led-class.ko v_zsmalloc.ko vcp_status_v2.ko vcp_v2.ko vfcs-misc-core.ko vfcs-vpsy.ko vivo_board_info.ko vivo_board_info_detect.ko vivo_bsp_engine.ko vivo_display.ko vivo_rpk_ctrl.ko vivo_rsc.ko vivo_rsmc_driver.ko vivo_tcp.ko vivo_ts.ko vivo_wifi_driver.ko vkyber-iosched.ko vsed.ko xhci-mtk-hcd-v2.ko zcache.ko,$(LOCAL_PATH)/prebuilt/recovery_modules/$(ko))
LOCAL_ADDITIONAL_DEPENDENCIES := \
    $(LOCAL_PATH)/recovery/prepare-ramdisk.sh \
    $(LOCAL_PATH)/prebuilt/kernel \
    $(LOCAL_PATH)/prebuilt/dtb/pd2415.dtb \
    $(LOCAL_PATH)/prebuilt/recovery_modules/modules.dep \
    $(LOCAL_PATH)/prebuilt/recovery_modules/modules.sha256 \
    $(KO_FILES) \
    $(LOCAL_PATH)/prebuilt/recovery_properties/system.build.prop \
    $(LOCAL_PATH)/prebuilt/recovery_properties/vendor.build.prop \
    $(wildcard $(LOCAL_PATH)/prebuilt/recovery_vendor_hal/*) \
    $(wildcard $(LOCAL_PATH)/prebuilt/recovery_firmware/*) \
    $(LOCAL_PATH)/prebuilt/vendor_ramdisk/platform.cpio.gz \
    $(LOCAL_PATH)/prebuilt/vendor_ramdisk/official_recovery.cpio.gz \
    $(LOCAL_PATH)/recovery/root/init.recovery.usb.rc \
    $(LOCAL_PATH)/recovery/root/init.recovery.project.rc \
    $(LOCAL_PATH)/recovery/root/init.recovery.mt6991.rc \
    $(LOCAL_PATH)/recovery/root/system/etc/fstab.pd2415.persist \
    $(LOCAL_PATH)/recovery/root/system/etc/ueventd.rc \
    $(LOCAL_PATH)/recovery/root/system/etc/twrp.flags \
    $(wildcard $(LOCAL_PATH)/recovery/root/system/bin/*) \
    $(wildcard $(LOCAL_PATH)/recovery/root/system/etc/init/*) \
    $(wildcard $(LOCAL_PATH)/recovery/root/odm/*) \
    $(wildcard $(LOCAL_PATH)/recovery/root/first_stage_ramdisk/*)
# Add per device (reference lines):
#   $(LOCAL_PATH)/recovery/patch-ap-touch-modules.py
#   $(LOCAL_PATH)/recovery/root/system/etc/ld.config.pd2415-crypto.txt
#   $(LOCAL_PATH)/recovery/root/twres/languages/zh_CN.xml
include $(BUILD_PHONY_PACKAGE)
