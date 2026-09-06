$base='f:/learn-front/learn-hook/vivo-twrp/device_vivo_pd2415_twrp'
$bc=Join-Path $base 'BoardConfig.mk'
$t=[System.IO.File]::ReadAllText($bc)
$t=$t -replace "`r`n","`n"
[System.IO.File]::WriteAllText($bc,$t)
Write-Host "BoardConfig.mk normalized to LF"
