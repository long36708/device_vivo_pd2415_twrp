$base='f:/learn-front/learn-hook/vivo-twrp/device_vivo_pd2415_twrp/prebuilt/recovery_modules'
$keep = Get-Content (Join-Path $base 'essential_modules.txt')
$all  = Get-ChildItem (Join-Path $base '*.ko')
$kf = @($all | Where-Object { $keep -contains $_.Name })
$df = @($all | Where-Object { $keep -notcontains $_.Name })
$ks = ($kf | Measure-Object -Property Length -Sum).Sum
$ds = ($df | Measure-Object -Property Length -Sum).Sum
$ratio = 15.8 / 70.5
Write-Output ('KEEP  count=' + $kf.Count + '  raw=' + [math]::Round($ks/1MB,1) + ' MB  est-gzip=' + [math]::Round($ks/1MB*$ratio,1) + ' MB')
Write-Output ('DROP  count=' + $df.Count + '  raw=' + [math]::Round($ds/1MB,1) + ' MB  est-gzip=' + [math]::Round($ds/1MB*$ratio,1) + ' MB')
Write-Output ('TOTAL count=' + $all.Count + '  raw=' + [math]::Round(($ks+$ds)/1MB,1) + ' MB')
Write-Output '--- DROP list ---'
foreach ($f in $df) { Write-Output ('  ' + $f.Name) }
