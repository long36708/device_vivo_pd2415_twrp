$enc=[System.Text.Encoding]::ASCII
$base='f:/learn-front/learn-hook/vivo-twrp/device_vivo_pd2415_twrp'
function GzSize($dir){
  $total=0; $count=0
  Get-ChildItem -Path $dir -Recurse -File | ForEach-Object {
    $b=[System.IO.File]::ReadAllBytes($_.FullName)
    $ms=New-Object System.IO.MemoryStream(,$b)
    $tmp=Join-Path $env:TEMP ("gz_"+[System.Guid]::NewGuid().ToString()+".gz")
    $fs=[System.IO.File]::Create($tmp)
    $gz=New-Object System.IO.Compression.GzipStream($fs,[System.IO.Compression.CompressionMode]::Compress,[System.IO.Compression.CompressionLevel]::Optimal)
    $ms.CopyTo($gz)
    $gz.Dispose(); $fs.Dispose()
    $total+=(Get-Item $tmp).Length; Remove-Item $tmp
    $count++
  }
  return $total,$count
}
($m,$c)=GzSize "$base/prebuilt/recovery_modules"
Write-Host ("modules gzip-opt total: $m bytes ($([math]::Round($m/1MB,1)) MB) files:$c")
($h,$hc)=GzSize "$base/prebuilt/recovery_vendor_hal"
Write-Host ("hal gzip-opt total: $h bytes ($([math]::Round($h/1MB,1)) MB) files:$hc")
($f,$fc)=GzSize "$base/prebuilt/recovery_firmware"
Write-Host ("firmware gzip-opt total: $f bytes ($([math]::Round($f/1MB,1)) MB) files:$fc")
Write-Host '--- gt989x in .ko (touch panel firmware hint) ---'
Get-ChildItem "$base/prebuilt/recovery_modules/*.ko" | ForEach-Object {
  $b=[System.IO.File]::ReadAllBytes($_.FullName)
  $s=$enc.GetString($b)
  $mm=[regex]::Matches($s,'gt989[a-z0-9]*')|ForEach-Object{$_.Value}|Sort -Unique
  if($mm){ Write-Host ($_.Name+': '+($mm -join ',')) }
}
Write-Host '--- raw (uncompressed) sizes ---'
$pd="$base/prebuilt/recovery_modules"; $raw=(Get-ChildItem $pd -Filter *.ko | Measure-Object -Property Length -Sum).Sum
Write-Host ("modules raw: $([math]::Round($raw/1MB,1)) MB")
