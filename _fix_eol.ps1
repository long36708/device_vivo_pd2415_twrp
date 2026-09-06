$base='f:/learn-front/learn-hook/vivo-twrp/device_vivo_pd2415_twrp'
foreach($f in @('BoardConfig.mk','recovery/prepare-ramdisk.sh')){
  $p=Join-Path $base $f
  $t=[System.IO.File]::ReadAllText($p)
  $t=$t -replace "`r`n","`n"
  $t=$t -replace "`n","`r`n"
  [System.IO.File]::WriteAllText($p,$t)
}
Write-Host "converted BoardConfig.mk and prepare-ramdisk.sh to CRLF"
