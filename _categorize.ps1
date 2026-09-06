$base='f:/learn-front/learn-hook/vivo-twrp/device_vivo_pd2415_twrp'
$mods = Get-ChildItem "$base/prebuilt/recovery_modules/*.ko" | ForEach-Object { $_.Name }
$dropPatterns = @(
 'cam','seninf','imgsys','camsys',
 'clk-mt6991-img','vcodec','vdec','venc',
 'audclk','nvtclk','mtk-afe','mt6685-audclk','mt6685-nvtclk','mt6375-auxadc','mt6379-adc','mt6379s','industrialio','kfifo_buf','snd',
 'wifi','wlan','cfg80211','bluetooth','btmtk','conn','ccci','fm','mtk_connsys','vivo_wifi_driver',
 'mac80211','rfkill','ccmni','mddp','vivo_hr',
 'adsp','slbc','mtk_bp_thl',
 'sensor','gsensor','alsps','gyro','baro','mag','sar','prox','tmf','step','pedo',
 'fp_dispatch','fingerprint','goodix_fp',
 'charger','adapter','ufcs','vfcs','pd_dbg','mtk_pd','mtk_pep','mtk_charger','mtk_2p_charger','rt_pd_manager','mt6379-battery','mt6379-chg',
 'aee','mrdump','monitor_hang','bootprof','log_store','mmprofile','systracker','pie_driver','kprobe',
 'vivo_mm_debug','vivo_slowpath_opt','vivo_fs_trace','vivo_rms','vivo_rsc','vivo_tcp','vivo_netstats',
 'sch_','vpsnh','vr','vklp','vne','vsed','lz4m','shrinker_proxy','thp_pool','zcache','v_zsmalloc','pkvm',
 'slc-parity','cache-parity','gic-ram-parity','bus-parity','mtk-swpm','arm_dsu_pmu','mediatek-cpufreq','mtk_cpu_power',
 'mtk-mminfra-debug','v4l2','usb_meta','mtk-mmc-dbg','ufs-mediatek-dbg','mtk-smi-dbg','clk-dbg-mt6991'
)
$keepOverride = @('dbgtop-drm')
function MatchPattern($name){
  $hits=@()
  foreach($p in $dropPatterns){ if($name -like "*$p*"){ $hits+=$p } }
  return $hits
}
$keep=@(); $drop=@()
foreach($m in $mods){
  if($keepOverride | Where-Object { $m -like "*$_*" }){ $keep+=$m; continue }
  $hits=MatchPattern $m
  if($hits.Count -gt 0){ $drop+=$m; Write-Host ("DROP $m  <= $($hits -join ',')") }
  else { $keep+=$m }
}
$keepRaw=(Get-ChildItem "$base/prebuilt/recovery_modules/*.ko" | Where-Object { $keep -contains $_.Name } | Measure-Object -Property Length -Sum).Sum
$dropRaw=(Get-ChildItem "$base/prebuilt/recovery_modules/*.ko" | Where-Object { $drop -contains $_.Name } | Measure-Object -Property Length -Sum).Sum
$ratio=15.8/70.5
Write-Host ("KEEP: $($keep.Count) modules, raw $([math]::Round($keepRaw/1MB,1)) MB, est gzip ~$([math]::Round($keepRaw/1MB*$ratio,1)) MB")
Write-Host ("DROP: $($drop.Count) modules, raw $([math]::Round($dropRaw/1MB,1)) MB, est gzip ~$([math]::Round($dropRaw/1MB*$ratio,1)) MB")
Write-Host "--- DROP list ---"
$drop | Sort-Object | ForEach-Object { Write-Host ("  $_") }
Write-Host "--- KEEP list ---"
$keep | Sort-Object | ForEach-Object { Write-Host ("  $_") }
$keep | Sort-Object | Set-Content -Encoding ascii "$base/prebuilt/recovery_modules/essential_modules.txt"
Write-Host ("wrote essential_modules.txt with $($keep.Count) entries")
