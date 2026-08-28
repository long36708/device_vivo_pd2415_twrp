# pd2415 recovery_vendor_hal 精准提取脚本
# 只拉取 crypto 链所需的 .so + HAL 二进制 + TA，避免全量 /vendor/lib64 (1.7G)
# Usage: powershell -ExecutionPolicy Bypass -File extract-hal-minimal.ps1

$ErrorActionPreference = "Stop"
$hal = "f:\learn-front\learn-hook\vivo-twrp\device_vivo_pd2415_twrp\prebuilt\recovery_vendor_hal"

# === 1. HAL 二进制（直接复制，不通过 readelf 依赖分析）===
$halBins = @(
    "/vendor/bin/hw/android.hardware.security.keymint@3.0-service.trustonic",
    "/vendor/bin/hw/android.hardware.gatekeeper-service.trustonic",
    "/vendor/bin/hw/android.hardware.boot-service.mtk",
    "/vendor/bin/hw/android.hardware.secure_element@1.2-service",
    "/vendor/bin/hw/android.hardware.secure_element@1.2-service-mediatek",
    "/vendor/bin/hw/vendor.trustonic.tee-service"
)

# === 2. crypto 链所需 .so 列表（从 readelf 递归 + dali 参考树对照）===
# 已知直接依赖（4 个 HAL 的 readelf -d 输出）:
#   libhidlbase.so libbinder_ndk.so libbinder.so libbase.so libcutils.so
#   liblog.so libutils.so libselinux.so libhardware.so libhardware_legacy.so
#   libMcClient.so libmtk_bsg.so libchrome.so
#   android.hardware.security.keymint-V3-ndk.so
#   android.hardware.security.rkp-V3-ndk.so
#   android.hardware.security.sharedsecret-V1-ndk.so
#   android.hardware.security.secureclock-V1-ndk.so
#   android.hardware.gatekeeper-V1-ndk.so
#   android.hardware.boot-V1-ndk.so android.hardware.boot@1.1.so
#   android.hardware.secure_element@1.0.so android.hardware.secure_element@1.1.so
#   android.hardware.secure_element@1.2.so
#   android.hardware.common-V2-ndk.so
#   vendor.trustonic.tui-V1-ndk.so vendor.trustonic.tee-V1-ndk.so
#   ese_spi_nxp.so vendor.nxp.nxpese@1.0.so vendor.nxp.nxpnfc@2.0.so
#   se_extn_client.so ls_client.so jcos_client.so
#   android.hardware.nfc@1.0.so android.hardware.nfc@1.1.so android.hardware.nfc@1.2.so
#   libc++.so libc.so libm.so libdl.so (system libs - provided by recovery root, skip)
#
# 间接依赖（从 dali 参考树对照，crypto 链常见间接依赖）:
#   libcrypto.so libkeymaster_messages.so libkeymaster_portable.so
#   libkeymint.so libgatekeeper.so libcppbor.so libcppbor_external.so
#   libcppcose_rkp.so libpuresoftkeymasterdevice.so libsoft_attestation_cert.so
#   lib_android_keymaster_keymint_utils.so libteecli.so libtrusty.so
#   libhidlbase.so libhwbinder.so libmemunreachable.so
#   android.hardware.weaver-V2-ndk.so android.se.omapi-V1-ndk.so
#   android.system.suspend-V1-ndk.so
#   libclang_rt.ubsan_standalone-aarch64-android.so

$soList = @(
    # --- Trustonic Trusty/MobiCore ---
    "libMcClient.so",
    "libteecli.so",
    "libtrusty.so",
    # --- KeyMint chain ---
    "android.hardware.security.keymint-V3-ndk.so",
    "android.hardware.security.rkp-V3-ndk.so",
    "android.hardware.security.sharedsecret-V1-ndk.so",
    "android.hardware.security.secureclock-V1-ndk.so",
    "android.hardware.weaver-V2-ndk.so",
    "lib_android_keymaster_keymint_utils.so",
    "libkeymaster_messages.so",
    "libkeymaster_portable.so",
    "libkeymint.so",
    "libpuresoftkeymasterdevice.so",
    "libsoft_attestation_cert.so",
    "libcppbor.so",
    "libcppbor_external.so",
    "libcppcose_rkp.so",
    # --- Gatekeeper ---
    "android.hardware.gatekeeper-V1-ndk.so",
    "libgatekeeper.so",
    # --- Boot HAL ---
    "android.hardware.boot-V1-ndk.so",
    "android.hardware.boot@1.1.so",
    "libmtk_bsg.so",
    # --- Secure Element / OMAPI ---
    "android.hardware.secure_element-V1-ndk.so",
    "android.hardware.secure_element@1.0.so",
    "android.hardware.secure_element@1.1.so",
    "android.hardware.secure_element@1.2.so",
    "android.se.omapi-V1-ndk.so",
    "ese_spi_nxp.so",
    "vendor.nxp.nxpese@1.0.so",
    "vendor.nxp.nxpnfc@2.0.so",
    "se_extn_client.so",
    "ls_client.so",
    "jcos_client.so",
    "android.hardware.nfc@1.0.so",
    "android.hardware.nfc@1.1.so",
    "android.hardware.nfc@1.2.so",
    # --- Trustonic TEE service ---
    "vendor.trustonic.tui-V1-ndk.so",
    "vendor.trustonic.tee-V1-ndk.so",
    "android.hardware.common-V2-ndk.so",
    # --- Core runtime (recovery may or may not provide; pull to be safe) ---
    "libhidlbase.so",
    "libhwbinder.so",
    "libbinder_ndk.so",
    "libbinder.so",
    "libbase.so",
    "libcutils.so",
    "liblog.so",
    "libutils.so",
    "libhardware.so",
    "libhardware_legacy.so",
    "libselinux.so",
    "libchrome.so",
    "libcrypto.so",
    "libmemunreachable.so",
    "libclang_rt.ubsan_standalone-aarch64-android.so",
    "android.system.suspend-V1-ndk.so"
    # NOTE: libc.so libm.so libdl.so libc++.so are system libs — recovery root provides them
)

# === 3. 在手机端递归解析依赖，补全 soList 漏掉的间接依赖 ===
Write-Host "[*] 递归解析 HAL 依赖，收集完整 .so 列表 ..."
$resolved = New-Object System.Collections.Generic.HashSet[string]
$queue = New-Object System.Collections.Generic.Queue[string]
foreach ($so in $soList) { [void]$queue.Enqueue($so); [void]$resolved.Add($so) }

while ($queue.Count -gt 0) {
    $so = $queue.Dequeue()
    $soPath = "/vendor/lib64/$so"
    # readelf -d 读取 NEEDED
    $output = adb shell "su -c 'readelf -d $soPath 2>/dev/null | grep NEEDED'" 2>&1
    foreach ($line in $output) {
        if ($line -match "Shared library: \[([^\]]+)\]") {
            $dep = $matches[1]
            if (-not $resolved.Contains($dep)) {
                [void]$resolved.Add($dep)
                [void]$queue.Enqueue($dep)
                Write-Host "    + $dep (via $so)"
            }
        }
    }
}
Write-Host "[+] 递归解析完成: $($resolved.Count) 个 .so"

# === 4. 在手机端复制所需 .so 到 /data/local/tmp，然后 pull ===
Write-Host "[*] 复制 .so 到 /data/local/tmp ..."
adb shell "su -c 'mkdir -p /data/local/tmp/hal_lib64 && chmod 777 /data/local/tmp/hal_lib64'" 2>&1 | Out-Null

$found = 0
$missing = @()
foreach ($so in $resolved) {
    $check = adb shell "su -c 'test -f /vendor/lib64/$so && echo FOUND || echo MISSING'" 2>&1
    if ($check -match "FOUND") {
        adb shell "su -c 'cp /vendor/lib64/$so /data/local/tmp/hal_lib64/$so && chmod 644 /data/local/tmp/hal_lib64/$so'" 2>&1 | Out-Null
        $found++
    } else {
        $missing += $so
    }
}
Write-Host "[+] Found: $found / $($resolved.Count) .so in /vendor/lib64"
if ($missing.Count -gt 0) {
    Write-Host "[!] Missing (may be in /system/lib64, recovery provides them):"
    foreach ($m in $missing) { Write-Host "    - $m" }
}

# === 5. 复制 HAL 二进制 ===
Write-Host "[*] 复制 HAL 二进制到 /data/local/tmp ..."
adb shell "su -c 'mkdir -p /data/local/tmp/hal_bin/hw'" 2>&1 | Out-Null
foreach ($bin in $halBins) {
    $name = Split-Path $bin -Leaf
    $check = adb shell "su -c 'test -f $bin && echo FOUND || echo MISSING'" 2>&1
    if ($check -match "FOUND") {
        adb shell "su -c 'cp $bin /data/local/tmp/hal_bin/hw/$name && chmod 644 /data/local/tmp/hal_bin/hw/$name'" 2>&1 | Out-Null
        Write-Host "    + $name"
    } else {
        Write-Host "    [!] $name not found"
    }
}

# === 6. 检查 TA 目录 ===
Write-Host "[*] 检查 Trustonic TA 目录 ..."
$taDirs = @("/vendor/app/mcRegistry", "/vendor/trustonic", "/vendor/etc/tas", "/vendor/lib64/ta")
foreach ($ta in $taDirs) {
    $check = adb shell "su -c 'test -d $ta && echo FOUND || echo MISSING'" 2>&1
    if ($check -match "FOUND") {
        $size = (adb shell "su -c 'du -sh $ta 2>/dev/null'" 2>&1).Trim()
        Write-Host "    Found: $ta ($size)"
        adb shell "su -c 'cp -r $ta /data/local/tmp/$(Split-Path $ta -Leaf) && chmod -R 644 /data/local/tmp/$(Split-Path $ta -Leaf)'" 2>&1 | Out-Null
    }
}

# === 7. Pull 到本地 ===
Write-Host "`n[*] Pulling to local ..."
New-Item -ItemType Directory -Force -Path "$hal\bin\hw", "$hal\lib64" | Out-Null

adb pull /data/local/tmp/hal_bin/hw "$hal\bin\hw" 2>&1 | ForEach-Object { Write-Host "    $_" }
adb pull /data/local/tmp/hal_lib64 "$hal\lib64" 2>&1 | ForEach-Object { Write-Host "    $_" }

# Pull TA dirs if they were copied
foreach ($ta in $taDirs) {
    $taName = Split-Path $ta -Leaf
    $remoteTmpPath = "/data/local/tmp/$taName"
    $check = adb shell "su -c 'test -d $remoteTmpPath && echo FOUND || echo MISSING'" 2>&1
    if ($check -match "FOUND") {
        Write-Host "[*] Pulling $taName ..."
        adb pull $remoteTmpPath $hal 2>&1 | ForEach-Object { Write-Host "    $_" }
    }
}

# === 8. 清理 ===
Write-Host "[*] 清理手机端临时文件 ..."
adb shell "su -c 'rm -rf /data/local/tmp/hal_lib64 /data/local/tmp/hal_bin /data/local/tmp/mcRegistry /data/local/tmp/trustonic /data/local/tmp/tas /data/local/tmp/ta'" 2>&1 | Out-Null

# === 9. 统计 ===
Write-Host "`n=== Summary ==="
$libCount = (Get-ChildItem "$hal\lib64" -File -ErrorAction SilentlyContinue).Count
$binCount = (Get-ChildItem "$hal\bin\hw" -File -ErrorAction SilentlyContinue).Count
$libSize = (Get-ChildItem "$hal\lib64" -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
Write-Host "  bin/hw:  $binCount files"
Write-Host "  lib64:   $libCount files, $([math]::Round($libSize/1MB,1)) MB"
Write-Host "  Target:  $hal"
Write-Host "[+] Done."
