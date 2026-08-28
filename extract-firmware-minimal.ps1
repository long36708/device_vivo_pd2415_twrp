# pd2415 recovery_firmware 精准提取脚本
# 只保留 recovery 需要的触觉驱动固件 + 触摸屏固件
# 删除振动马达波形（A_*/G_*/N_*/R_*/S_*/T_*/vivo_ram_haptic*）、相机/蓝牙/WiFi/充电等无关固件

$fw = "f:\learn-front\learn-hook\vivo-twrp\device_vivo_pd2415_twrp\prebuilt\recovery_firmware"

# 触觉驱动固件 + 触摸屏固件
$keepPatterns = @(
    "TP-FW-*",
    "TP-CONFIG-FW-*",
    "TP-THPCFG-FW-*",
    "TP-VENDORCFG-FW-*",
    "gt9895_*",
    "gt9896s_*",
    "gt9916*",
    "gt9764*",
    "touch_firmwares.bin",
    "st_fts_*.ftb",
    "*.wmfw",
    "cs40l26-*",
    "aw8*",
    "tfa98xx*"
)

$allFiles = Get-ChildItem -Path $fw -File
Write-Host "总文件数: $($allFiles.Count)"
$totalSize = ($allFiles | Measure-Object -Property Length -Sum).Sum
Write-Host ("总体积: {0:N1} MB" -f ($totalSize/1MB))

$keepFiles = @()
$deleteFiles = @()

foreach ($file in $allFiles) {
    $keep = $false
    foreach ($pattern in $keepPatterns) {
        if ($file.Name -like $pattern) {
            $keep = $true
            break
        }
    }
    if ($keep) {
        $keepFiles += $file
    } else {
        $deleteFiles += $file
    }
}

$keepSize = ($keepFiles | Measure-Object -Property Length -Sum).Sum
$deleteSize = ($deleteFiles | Measure-Object -Property Length -Sum).Sum
Write-Host "`n保留: $($keepFiles.Count) 文件, $([math]::Round($keepSize/1MB,1)) MB"
Write-Host "删除: $($deleteFiles.Count) 文件, $([math]::Round($deleteSize/1MB,1)) MB"
Write-Host "`n保留文件列表:"
foreach ($f in $keepFiles) {
    Write-Host ("  {0,-60} {1,8:N1} KB" -f $f.Name, ($f.Length/1KB))
}

Write-Host "`n[*] 删除无关固件 ..."
foreach ($f in $deleteFiles) {
    Remove-Item -Path $f.FullName -Force
}
Write-Host "[+] 完成。保留 $($keepFiles.Count) 个文件。"

$finalFiles = Get-ChildItem -Path $fw -File
$finalSize = ($finalFiles | Measure-Object -Property Length -Sum).Sum
Write-Host "`n=== 最终结果 ==="
Write-Host ("文件数: {0}" -f $finalFiles.Count)
Write-Host ("体积:   {0:N1} MB" -f ($finalSize/1MB))
