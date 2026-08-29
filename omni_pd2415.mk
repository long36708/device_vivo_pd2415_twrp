# Copyright (C) 2025 The OrangeFox for pd2415 contributors
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Minimal product makefile, mirroring device_xiaomi_dali_twrp/omni_dali.mk.
# TW_/OF_/FOX_ build flags live in BoardConfig.mk; this file only wires the
# inherit chain and the product identity.

LOCAL_PATH := device/vivo/pd2415

$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)
$(call inherit-product, vendor/orangefox/config/common.mk)
$(call inherit-product, $(LOCAL_PATH)/device.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota/vabc_features.mk)
PRODUCT_FULL_TREBLE_OVERRIDE := true

PRODUCT_DEVICE := pd2415
PRODUCT_NAME := omni_pd2415
PRODUCT_BRAND := vivo
PRODUCT_MODEL := vivo X200 Pro mini
PRODUCT_MANUFACTURER := vivo
