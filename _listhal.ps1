$hal='f:/learn-front/learn-hook/vivo-twrp/device_vivo_pd2415_twrp/prebuilt/recovery_vendor_hal'
Write-Output '=== bin/hw services (name, KB) ==='
Get-ChildItem -Path (Join-Path $hal 'bin') -Recurse -File | ForEach-Object {
  '{0}  {1} KB' -f $_.Name, [math]::Round($_.Length/1KB,1)
} | Sort-Object
Write-Output '=== lib64 total ==='
$g=Get-ChildItem -Path (Join-Path $hal 'lib64') -Recurse -File | Measure-Object -Property Length -Sum
'lib64: {0} MB, {1} files' -f [math]::Round($g.Sum/1MB,1), $g.Count
Write-Output '=== mcRegistry total ==='
$m=Get-ChildItem -Path (Join-Path $hal 'mcRegistry') -Recurse -File | Measure-Object -Property Length -Sum
'mcRegistry: {0} MB, {1} files' -f [math]::Round($m.Sum/1MB,1), $m.Count
