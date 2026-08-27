# PD2415 prebuilt 提取操作指南

> vivo X200 Pro mini (PD2415) TWRP 设备树 prebuilt 提取步骤
> 环境：已 root 手机 + Windows + adb + WSL/Linux（ramdisk 转换）

## 前置条件

- 手机已 root，USB 调试已开启
- Windows 已安装 adb（`adb devices` 能看到设备）
- 手机型号：vivo X200 Pro mini (PD2415)
- 活动槽位：`_b`（`getprop ro.boot.slot_suffix` 返回 `_b`）
- 分区路径：`boot_b` → `/dev/block/sdc75`，`init_boot_b` → `/dev/block/sdc77`

## 已知分区大小（从 /proc/partitions 读取）

| 分区 | 块设备 | 大小（bytes） | 说明 |
|---|---|---|---|
| boot_b | /dev/block/sdc75 | 100663296 (96 MiB) | 含 kernel |
| init_boot_b | /dev/block/sdc77 | 8388608 (8 MiB) | GKI init_boot |
| vendor_boot_b | /dev/block/sdc76 | 134217728 (128 MiB) | 双分片 ramdisk + dtb |

---

## 步骤 1：dump boot + init_boot 分区 ✅ 已完成

```powershell
adb shell "su -c 'dd if=/dev/block/by-name/boot_b of=/data/local/tmp/pd2415_boot.img bs=8M && dd if=/dev/block/by-name/init_boot_b of=/data/local/tmp/pd2415_init_boot.img bs=8M && chmod 644 /data/local/tmp/pd2415_boot.img /data/local/tmp/pd2415_init_boot.img'"
$dest = "f:\learn-front\learn-hook\vivo-twrp\device_vivo_pd2415_twrp\prebuilt\kernel_source"
New-Item -ItemType Directory -Force -Path $dest | Out-Null
adb pull /data/local/tmp/pd2415_boot.img $dest
adb pull /data/local/tmp/pd2415_init_boot.img $dest
adb shell "su -c 'rm /data/local/tmp/pd2415_boot.img /data/local/tmp/pd2415_init_boot.img'"
```

**目标**：`prebuilt\kernel_source\`（`pd2415_boot.img` + `pd2415_init_boot.img` + `kernel.decompressed`）

> `kernel.decompressed` 是用户已用 `unpack_bootimg` 解包出的 kernel，已复制到 `prebuilt/kernel`。

---

## 步骤 2：vendor/build.prop ✅ 已完成

已保存到 `prebuilt\recovery_properties\vendor.build.prop`（30624 字节）。

关键属性：
- `ro.vendor.build.fingerprint=vivo/PD2415/PD2415:15/AP3A.240905.015.A1/compiler11071704:user/release-keys`
- `ro.vendor.build.security_patch=2025-09-01`
- `ro.vendor.build.id=AP3A.240905.015.A1`
- TEE: `ro.hardware.kmsetkey=trustonic` / `ro.hardware.gatekeeper=trustonic`
- `ro.vendor.mtk_trustonic_tee_support=1`

---

## 步骤 3：vendor HAL 闭包（crypto 链）✅ 已完成

### 3.1 关键 HAL 二进制（6 个，0.6 MB）

已提取到 `prebuilt\recovery_vendor_hal\bin\hw\`：

| 文件 | 说明 |
|---|---|
| `android.hardware.security.keymint@3.0-service.trustonic` | KeyMint |
| `android.hardware.gatekeeper-service.trustonic` | Gatekeeper |
| `android.hardware.boot-service.mtk` | Boot HAL |
| `android.hardware.secure_element@1.2-service` | Secure Element |
| `android.hardware.secure_element@1.2-service-mediatek` | SE (MediaTek) |
| `vendor.trustonic.tee-service` | Trustonic TEE 服务 |

> **注意**：PD2415 **没有** `/vendor/bin/tee-supplicant`（与 dali 不同）
> TEE 走 `vendor.trustonic.tee-service`，而非传统的 tee-supplicant

### 3.2 lib64 依赖库（30 个 .so，3.5 MB）

**重要**：**不要全量 `adb pull /vendor/lib64`**（1.7 GB，1758 个无关文件）。
只拉取 crypto 链所需的 30 个 .so。

已提取到 `prebuilt\recovery_vendor_hal\lib64\`，列表包括：
- Trustonic: `libMcClient.so` `libtrusty.so`
- KeyMint 链: `android.hardware.security.keymint-V3-ndk.so` 等
- Gatekeeper: `android.hardware.gatekeeper-V1-ndk.so` `libgatekeeper.so`
- Boot HAL: `android.hardware.boot-V1-ndk.so` `android.hardware.boot@1.1.so` `libmtk_bsg.so`
- Secure Element / OMAPI: `android.hardware.secure_element-V1-ndk.so` `ese_spi_nxp.so` 等
- Trustonic TEE: `vendor.trustonic.tee-V1-ndk.so` `vendor.trustonic.tui-V1-ndk.so`
- 核心运行时: `libhidlbase.so` `libbinder.so` `libcrypto.so` `libchrome.so` 等

### 3.3 提取方式（精准提取脚本）

运行 `extract-hal-minimal.ps1`，它会：
1. 用 `readelf -d` 递归解析 4 个 crypto HAL 二进制的全部依赖
2. 只复制所需的 .so（30 个）+ 6 个 HAL 二进制 + Trustonic TA 目录
3. 自动跳过 system 库（recovery root 自带）

```powershell
powershell -ExecutionPolicy Bypass -File "extract-hal-minimal.ps1"
```

### 3.4 Trustonic TA 信任应用（67 个，26.3 MB）

已提取到 `prebuilt\recovery_vendor_hal\mcRegistry\`（67 个 `.tabin`/`.drbin`/`.tlbin` 文件）。

```powershell
$hal = "prebuilt\recovery_vendor_hal"
adb shell "su -c 'mkdir -p /data/local/tmp/mcRegistry && cp -r /vendor/app/mcRegistry/* /data/local/tmp/mcRegistry/ && chmod -R 644 /data/local/tmp/mcRegistry/'"
adb pull /data/local/tmp/mcRegistry $hal
adb shell "su -c 'rm -rf /data/local/tmp/mcRegistry'"
```

---

## 步骤 4：vendor/firmware ✅ 已完成（精准清理）

### 提取方式

```powershell
$fw = "prebuilt\recovery_firmware"
adb pull /vendor/firmware $fw
```

### 精准清理（删除无关固件）

全量拉取 `/vendor/firmware/` 会得到 2282 个文件（142 MB），其中绝大部分是
振动马达波形文件（`A_*.bin`/`G_*.bin`/`N_*.bin`/`R_*.bin`/`S_*.bin` 等），
recovery 不需要。只保留触觉驱动固件 + 触摸屏固件。

**清理命令**（PowerShell）：
```powershell
cd "prebuilt\recovery_firmware"
Get-ChildItem -File | Where-Object {
    $_.Name -notmatch '^(TP-|gt9895_|gt9896s_|gt9916|touch_firmwares|st_fts_|vivo_ram_haptic|aw8|tfa98xx)' -and
    $_.Extension -notin '.ftb','.wmfw'
} | ForEach-Object { $_.Delete() }
```

或运行 Python 脚本 `clean_firmware.py`：
```bash
python clean_firmware.py
```

### 清理结果

| | 清理前 | 清理后 |
|---|---|---|
| 文件数 | 2282 | **104** |
| 体积 | 142.1 MB | **7.7 MB** |

保留的文件类别：
- 触摸屏固件：`TP-FW-*.bin` `TP-CONFIG-FW-*.bin` `TP-THPCFG-FW-*.bin` `TP-VENDORCFG-FW-*.bin`
- Goodix 触摸固件：`gt9895_*.bin` `gt9896s_*.bin` `gt9916*.bin`
- ST FTS 触摸固件：`st_fts_*.ftb`
- 触觉固件：`vivo_ram_haptic*.bin` `aw8*.bin` `tfa98xx*.cnt`

---

## 步骤 5：ramdisk 转换 ✅ 已完成

已有官方 vendor_boot 解包产物：
- `F:\learn-front\learn-hook\vivo-x200-pm-vendor-boot\mod\ramdisk.1.lz4`（PLATFORM，lz4）
- `F:\learn-front\learn-hook\vivo-x200-pm-vendor-boot\mod\ramdisk.2`（RECOVERY，cpio）

在 **WSL/Linux** 中转换为 gzip 格式：

```bash
lz4 -dc /mnt/f/learn-front/learn-hook/vivo-x200-pm-vendor-boot/mod/ramdisk.1.lz4 \
  | gzip -9 -n > prebuilt/vendor_ramdisk/platform.cpio.gz

gzip -9 -n -c /mnt/f/learn-front/learn-hook/vivo-x200-pm-vendor-boot/mod/ramdisk.2 \
  > prebuilt/vendor_ramdisk/official_recovery.cpio.gz
```

**目标**：
- `prebuilt\vendor_ramdisk\platform.cpio.gz`
- `prebuilt\vendor_ramdisk\official_recovery.cpio.gz`

> `.cpio` 中间文件被 `.gitignore` 排除，不提交 git。

---

## 步骤 6：从 boot.img 提取 kernel ✅ 已完成

用户已用 `unpack_bootimg` 从 `pd2415_boot.img` 解包出 `kernel.decompressed`，
并复制到 `prebuilt\kernel`（34.7 MB）。

```bash
python3 system/tools/mkbootimg/unpack_bootimg.py \
    --boot_img prebuilt/kernel_source/pd2415_boot.img \
    --out /tmp/pd2415_boot_unpacked
cp /tmp/pd2415_boot_unpacked/kernel prebuilt/kernel
```

---

## 最终文件清单

```
prebuilt/
├── kernel                              ← 34.7 MB ✅
├── kernel_source/                      ← .gitignore 排除（138.7 MB）
│   ├── pd2415_boot.img
│   ├── pd2415_init_boot.img
│   └── kernel.decompressed
├── dtb/
│   └── pd2415.dtb                      ← 0.5 MB ✅
├── recovery_modules/
│   ├── *.ko (337 个)                   ← 70.6 MB ✅
│   ├── modules.dep
│   └── modules.sha256
├── recovery_properties/
│   ├── system.build.prop               ← ✅
│   └── vendor.build.prop               ← 30 KB ✅
├── recovery_vendor_hal/
│   ├── bin/hw/ (6 个 HAL, 0.6 MB)      ← ✅
│   ├── lib64/ (30 个 .so, 3.5 MB)      ← ✅
│   └── mcRegistry/ (67 个 TA, 26.3 MB) ← ✅
├── recovery_firmware/ (104 个, 7.7 MB) ← ✅
└── vendor_ramdisk/
    ├── platform.cpio.gz                ← ✅
    ├── platform.cpio                   ← .gitignore 排除
    ├── official_recovery.cpio.gz       ← ✅
    └── official_recovery.cpio          ← .gitignore 排除
```

### 最终体积统计

| 目录 | 体积 | 文件数 | 提交 git？ |
|---|---|---|---|
| `kernel` | 34.7 MB | 1 | ✅ 提交 |
| `kernel_source/` | 138.7 MB | 3 | ❌ .gitignore 排除 |
| `dtb/` | 0.5 MB | 1 | ✅ 提交 |
| `recovery_modules/` | 70.6 MB | 339 | ✅ 提交 |
| `recovery_properties/` | 0.03 MB | 2 | ✅ 提交 |
| `recovery_vendor_hal/` | 30.4 MB | 103 | ✅ 提交 |
| `recovery_firmware/` | 7.7 MB | 104 | ✅ 提交 |
| `vendor_ramdisk/` | ~180 MB | 2 | ✅ 提交（.cpio 被 .gitignore 排除） |
| **合计（提交 git）** | **~324 MB** | 552 | |

---

## 已自动完成的后续操作

1. ✅ **BoardConfig.mk** 已更新：
   - `BOARD_BOOTIMAGE_PARTITION_SIZE := 100663296`
   - `BOARD_INIT_BOOT_IMAGE_PARTITION_SIZE := 8388608`
   - `BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE := 134217728`

2. ✅ **package-vendor-boot.sh** SHA 占位符已填入真实值：
   - `PLATFORM_GZIP_SHA256=41975e4a...`
   - `PLATFORM_CPIO_SHA256=6ddca715...`
   - `OFFICIAL_RECOVERY_CPIO_SHA256=2eb8207b...`
   - `DTB_SHA256=5da60d84...`

3. ✅ **init.recovery.project.rc** 已适配 Trustonic TEE：
   - 服务名：`vendor.trustonic.tee-service`（不是 `tee-supplicant`）
   - KeyMint：`android.hardware.security.keymint@3.0-service.trustonic`
   - Gatekeeper：`android.hardware.gatekeeper-service.trustonic`

4. ✅ **sepolicy/file_contexts** 已标签 Trustonic HAL：
   - `/vendor/bin/hw/vendor.trustonic.tee-service → tee_supplicant_exec`
   - `/vendor/bin/hw/android.hardware.security.keymint@3.0-service.trustonic → hal_keymint_default_exec`
   - `/vendor/bin/hw/android.hardware.gatekeeper-service.trustonic → hal_gatekeeper_default_exec`

5. ✅ **.gitignore** 已创建：
   ```
   prebuilt/kernel_source/
   __pycache__/
   prebuilt/vendor_ramdisk/*.cpio
   ```

---

## 辅助脚本

| 脚本 | 用途 |
|---|---|
| `extract-official-prebuilts.sh` | 从官方 vendor_boot 解包产物提取 dtb/modules/build.prop/ramdisk（WSL） |
| `extract-hal-minimal.ps1` | 精准提取 vendor HAL 闭包（readelf 递归解析依赖，只拉 30 个 .so） |
| `clean_firmware.py` | 精准清理 recovery_firmware（删除振动马达波形，只保留触觉+触摸固件） |
| `extract-from-phone.ps1` | 从已 root 手机一键提取 boot/init_boot/vendor.build.prop/HAL/firmware |

---

## 关键设备参数

| 参数 | 值 | 来源 |
|---|---|---|
| 设备型号 | vivo X200 Pro mini (PD2415) | — |
| SoC | MediaTek MT6991 (Dimensity 9400) | `ro.board.platform` |
| Android | 15 (AP3A.240905.015.A1) | `ro.bootimage.build.id` |
| Kernel arch | arm64 / armv9-a | 同 dali（MT6991） |
| TEE | Trustonic | `ro.hardware.kmsetkey=trustonic` |
| FBE spec | `aes-256-xts:aes-256-cts:v2+inlinecrypt_optimized` | fstab.mt6991 第 87 行 |
| AVB SALT | `ruCHpb47mCl4ySP1ZqlGE0lrQX8q9ZJjm8gNFB403+c=` | vendor_boot.avb.json |
| AVB FINGERPRINT | `vivo/PD2415/PD2415:15/AP3A.240905.015.A1/compiler11071704:user/release-keys` | vendor_boot.avb.json |
| Kernel base | `0x80000000` | vendor_boot.json |
| Ramdisk offset | `0xa4d00000` | vendor_boot.json |
| Tags offset | `0x87c80000` | vendor_boot.json |
| DTB offset | `0x87c80000` | vendor_boot.json |
| Cmdline | `bootopt=64S3,32N2,64N2 product.version=PD2415_A_15.0.33.7.W10 fingerprint.abbr=15/AP3A.240905.015.A1 region_ver=W10 product.solution=MTK` | vendor_boot.json |
| Maintainer | LongMo | — |
