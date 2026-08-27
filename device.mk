# Copyright (C) 2025 The OrangeFox for pd2415 contributors
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Minimal device makefile, mirroring device_xiaomi_dali_twrp/device.mk. The
# recovery ramdisk content is staged by recovery/prepare-ramdisk.sh (the
# BOARD_RECOVERY_IMAGE_PREPARE hook) — do NOT add PRODUCT_COPY_FILES here.

LOCAL_PATH := device/vivo/pd2415

PRODUCT_USE_DYNAMIC_PARTITIONS := true
