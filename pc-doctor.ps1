#Requires -Version 5.1
<#
.SYNOPSIS
  PC-DOCTOR v2.0 for Windows — used-PC buyer's inspection suite
.DESCRIPTION
  Read-only hardware inspection for used Windows laptops/PCs before buying.
  Run in an elevated PowerShell:  Set-ExecutionPolicy Bypass -Scope Process -Force; .\pc-doctor.ps1
  Non-interactive: .\pc-doctor.ps1 -Yes
  Soak test 10 min: .\pc-doctor.ps1 -Soak 10
  Every check is individually skippable. Nothing writes to target disks.
#>
[CmdletBinding()]
param(
  [switch]$Yes,
  [int]$Soak = 0,
  [switch]$List
)

$B=""; $G=""; $R=""; $Y=""; $C=""; $X=""
try {
  if ($Host.UI.SupportsVirtualTerminal -or $PSVersionTable.PSVersion.Major -ge 6) {
    $B=[char]27+"[1m"; $G=[char]27+"[32m"; $R=[char]27+"[31m"; $Y=[char]27+"[33m"; $C=[char]27+"[36m"; $X=[char]27+"[0m"
  }
} catch {}

$script:Scorecard = New-Object System.Collections.Generic.List[string]
function Rec([string]$res,[string]$name,[string]$guidance){ $script:Scorecard.Add("$res|$name|$guidance") }
function Pass([string]$m,[string]$g=""){ Write-Host "  $G[PASS]$X $m"; if($g){Rec "PASS" $m $g} else {Rec "PASS" $m ""} }
function Fail([string]$m,[string]$g){ Write-Host "  $R[FAIL]$X $m"; Rec "FAIL" $m $g }
function Warn([string]$m,[string]$g=""){ Write-Host "  $Y[WARN]$X $m"; if($g){Rec "WARN" $m $g} else {Rec "WARN" $m ""} }
function Inf([string]$m){ Write-Host "  ${C}[INFO]$X $m" }
function SkipC([string]$m){ Write-Host "  ${Y}[SKIP]$X $m"; }
function Hr([string]$t){ Write-Host "`n$B━━━ $t ━━━$X" }

$script:Ask = if($Yes){"no"}else{"yes"}
function Confirm([string]$what){
  if($script:Ask -eq "no"){ return $true }
  if($script:Ask -eq "never"){ return $false }
  Write-Host "  ▶ Run [$what]? [Y/n/s=skip-all] " -NoNewline
  $a = Read-Host
  if($a -match '^[nN]'){ return $false }
  if($a -match '^[sS]'){ $script:Ask="never"; return $false }
  return $true
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$Report = Join-Path $env:TEMP ("pcdoctor-report-{0}.txt" -f (Get-Date -Format "yyyyMMdd-HHmmss"))
$transcriptStarted = $false
try { Start-Transcript -Path $Report -ErrorAction Stop | Out-Null; $transcriptStarted = $true } catch {}

Write-Host "$B╔══════════════════════════════════════════╗"
Write-Host "║   🩺  PC-DOCTOR v2.0 — Windows           ║"
Write-Host "║   READ-ONLY · every check skippable      ║"
Write-Host "╚══════════════════════════════════════════╝$X"
if(-not $isAdmin){ Warn "not elevated — many checks limited. Run: Set-ExecutionPolicy Bypass -Scope Process -Force; .\pc-doctor.ps1" }

$T0 = Get-Date

# ---------- 1. identity ----------
Hr "1 · System identity"
Inf "identity"
$cs = Get-CimInstance Win32_ComputerSystem
$os = Get-CimInstance Win32_OperatingSystem
$bios = Get-CimInstance Win32_BIOS
Write-Host ("  Model : {0} {1}" -f $cs.Manufacturer, $cs.Model)
Write-Host ("  Serial: {0}" -f $bios.SerialNumber)
Write-Host ("  OS    : {0} build {1}" -f $os.Caption, $os.BuildNumber)
Write-Host ("  RAM   : {0:N1} GB" -f ($cs.TotalPhysicalMemory/1GB))
$gpu = Get-CimInstance Win32_VideoController
$gpu | ForEach-Object { Write-Host ("  GPU   : {0}  ({1:N0} MB)" -f $_.Name, ($_.AdapterRAM/1MB)) }

# ---------- 2. RAM modules ----------
Hr "2 · RAM modules (slots / speeds)"
if(Confirm "raminfo"){
  Get-CimInstance Win32_PhysicalMemory | ForEach-Object {
    Write-Host ("  slot {0}: {1:N0} GB {2} @ {3:N0} MT/s  part {4}" -f $_.DeviceLocator, ($_.Capacity/1GB), $_.SMBIOSMemoryType, $_.ConfiguredClockSpeed, ($_.PartNumber -replace '\s+',''))
  }
  $max = Get-CimInstance Win32_PhysicalMemoryArray | Select-Object -First 1
  Write-Host ("  max capacity: {0:N0} GB across {1} slots" -f ($max.MaxCapacityEx/1MB), $max.MemoryDevices)
  Rec "PASS" "raminfo" ""
} else { SkipC "raminfo" }

# ---------- 3. CPU stress + throttle ----------
Hr "3 · CPU stress (20s)"
if(Confirm "cpu"){
  Inf "loading all logical cores 20s… listen to fans"
  $jobs = @()
  $cores = [Environment]::ProcessorCount
  1..$cores | ForEach-Object { $jobs += Start-Job { $end=(Get-Date).AddSeconds(18); while((Get-Date) -lt $end){ [math]::Sqrt(12345.678) | Out-Null } } }
  Start-Sleep -Seconds 20
  $jobs | Stop-Job | Out-Null; $jobs | Remove-Job -Force | Out-Null
  $load = (Get-CimInstance Win32_Processor | Measure-Object LoadPercentage -Average).Average
  Pass ("survived 20s all-core load (last sample {0}%)" -f $load)
  Rec "PASS" "cpu" ""
  $thermal = Get-CimInstance -Namespace root/wmi -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction SilentlyContinue |
             ForEach-Object { ($_.CurrentTemperature/10)-273.15 } | Measure-Object -Maximum
  if($thermal.Maximum){ Write-Host ("  thermal zone max: {0:N1} °C" -f $thermal.Maximum) }
  Inf "check Event Log next section for WHEA/thermal-throttle history"
} else { SkipC "cpu" }

# ---------- 4. event log scan (dmesg equivalent) ----------
Hr "4 · System event log scan (WHEA, disk, thermal, USB)"
if(Confirm "events"){
  $since = (Get-Date).AddDays(-30)
  $whea = Get-WinEvent -FilterHashtable @{LogName='System'; Level=1,2; StartTime=$since} -MaxEvents 300 -ErrorAction SilentlyContinue |
          Where-Object { $_.ProviderName -match 'WHEA|Kernel-PnP|disk|storahci|stornvme|Thermal' }
  if(-not $whea){ Pass "no WHEA/disk/thermal critical+error events in 30 days"; Rec "PASS" "events" "" }
  else {
    $whea | Select-Object -First 8 | ForEach-Object { Write-Host ("    [{0}] {1}: {2}" -f $_.TimeCreated.ToString('MM-dd'), $_.ProviderName, ($_.Message -split "`n")[0]) }
    if($whea | Where-Object ProviderName -match 'WHEA'){ Fail "WHEA hardware errors logged — CPU/board red flag" "WALK AWAY" }
    else { Warn ("{0} concerning events in 30d — judge severity" -f $whea.Count) "case-by-case" }
  }
} else { SkipC "events" }

# ---------- 5. disks SMART ----------
Hr "5 · Disks — SMART health, wear, hours"
if(Confirm "smart"){
  Get-PhysicalDisk | ForEach-Object {
    $d = $_
    Write-Host ("`n  {0}  {1}  {2}" -f $d.FriendlyName, $d.BusType, $d.MediaType) 
    $rel = $d | Get-StorageReliabilityCounter -ErrorAction SilentlyContinue
    if($rel){
      Write-Host ("    wear: {0}%   temp: {1}°C   power-on hours: {2}" -f $rel.Wear, $rel.Temperature, $rel.PowerOnHours)
      if($rel.Wear -ge 50){ Warn ("SSD {0}% life used" -f $rel.Wear) "-10–20% (replacement SSD)" }
      else { Pass ("wear only {0}%" -f $rel.Wear) }
      Rec "PASS" "smart-$($d.FriendlyName)" ""
    } else { SkipC "reliability counters unavailable for this disk"; Rec "SKIP" "smart-$($d.FriendlyName)" "" }
  }
  Inf "for sector-level detail: run 'smartctl -a' (smartmontools for Windows on your USB)"
} else { SkipC "smart" }

# ---------- 6. surface scan (read-only) ----------
Hr "6 · Full-disk read sample (slow, READ-ONLY)"
if(Confirm "surface"){
  Get-PhysicalDisk | Where-Object BusType -ne 'USB' | ForEach-Object {
    $d=$_
    $sz = [math]::Round($d.Size/1GB)
    Inf ("{0} ({1} GB): reading 5 checkpoints…" -f $d.FriendlyName,$sz)
    $num = ($d | Get-Disk).Number
    0..4 | ForEach-Object {
      $off = [long]($_ * ($d.Size/5))
      $sw=[Diagnostics.Stopwatch]::StartNew()
      $buf = New-Object byte[] (64MB)
      try {
        $fs = [IO.File]::Open("\\.\PhysicalDrive$num",'Open','Read','ReadWrite')
        [void]$fs.Seek($off,'Begin'); [void]$fs.Read($buf,0,$buf.Length); $fs.Close()
      } catch { SkipC "cannot read raw (bitlocker/permission)"; return }
      $sw.Stop()
      $mbps = [math]::Round(64/ $sw.Elapsed.TotalSeconds,1)
      Write-Host ("    checkpoint {0}/5: {1} MB/s" -f ($_+1), $mbps)
    }
    Rec "PASS" "surface-$($d.FriendlyName)" ""
  }
  Inf "healthy SSD: >400 MB/s sustained; dips <100 = sick drive"
} else { SkipC "surface" }

# ---------- 7. soak ----------
Hr "7 · Soak test (CPU+disk+RAM combined)"
if($Soak -gt 0){
  if(Confirm "soak"){
    Inf "soaking $Soak minutes — crash = don't buy"
    $end=(Get-Date).AddMinutes($Soak)
    while((Get-Date) -lt $end){
      $s_jobs = 1..$cores | ForEach-Object { Start-Job { $e=(Get-Date).AddSeconds(20); while((Get-Date) -lt $e){[math]::Sqrt(2)|Out-Null} } }
      $f = Get-ChildItem C:\Windows\System32 -Filter *.dll -Recurse -ErrorAction SilentlyContinue | Select-Object -First 200 | Measure-Object -Property Length -Sum
      $s_jobs | Stop-Job | Out-Null; $s_jobs | Remove-Job -Force | Out-Null
    }
    Pass "survived soak"; Rec "PASS" "soak" ""
  }
} else { Inf "enable with: .\pc-doctor.ps1 -Soak 10" }

# ---------- 8. GPU ----------
Hr "8 · GPU"
if(Confirm "gpu"){
  $names = ($gpu | ForEach-Object Name) -join " + "
  Inf ("detected: {0}" -f $names)
  $hybrid = ($gpu | Measure-Object).Count -gt 1
  if($hybrid){ Inf "HYBRID laptop — both GPUs listed above; test them via a game/4K video" }
  try {
    Add-Type -AssemblyName PresentationCore
    Inf "quick render: decoding a gradient bitmap 200x…"
    $sw=[Diagnostics.Stopwatch]::StartNew()
    1..200 | ForEach-Object { $bmp=New-Object Media.Imaging.RenderTargetBitmap(512,512,96,96,[Media.PixelFormats]::Pbgra32); $dv=New-Object Media.Visual; }
    $sw.Stop()
    Pass ("render loop ok ({0:N0} ms)" -f $sw.ElapsedMilliseconds); Rec "PASS" "gpu" ""
  } catch { SkipC "gpu render"; Rec "SKIP" "gpu" "" }
  Inf "real test: play 4K video 5 min — watch for artifacts, stalls, fan roar"
} else { SkipC "gpu" }

# ---------- 9. battery + discharge ----------
Hr "9 · Battery"
if(Confirm "battery"){
  $bat = Get-CimInstance -Namespace root/wmi -ClassName BatteryStaticData -ErrorAction SilentlyContinue
  $status = Get-CimInstance -Namespace root/wmi -ClassName BatteryStatus -ErrorAction SilentlyContinue
  $cfg = Get-CimInstance -Namespace root/wmi -ClassName BatteryCycleCount -ErrorAction SilentlyContinue
  if($bat){
    $des = $bat.DesignedCapacity; $full = $status.FullChargedCapacity
    if($des -and $full){
      $h=[int](100*$full/$des)
      Write-Host ("  design {0} mWh · full {1} mWh → holds {2}%" -f $des,$full,$h)
      if($h -ge 80){ Pass "battery health $h%"; Rec "PASS" "battery" "" }
      elseif($h -ge 60){ Warn "battery ${h}% — budget replacement (€40–90)" "-5–10%"; Rec "WARN" "battery" "-5–10%" }
      else { Fail "battery ${h}% — dying" "-10–15% (new battery)"; Rec "FAIL" "battery" "-10–15%" }
    }
  } else {
    # fall back to powercfg report
    powercfg /batteryreport /output "$env:TEMP\batt.html" | Out-Null
    if(Test-Path "$env:TEMP\batt.html"){ Inf "battery report: $env:TEMP\batt.html — open it, compare DESIGN CAPACITY vs FULL CHARGE CAPACITY" ; Rec "SKIP" "battery" "" }
  }
  if($cfg -and $cfg.CycleCount){ Write-Host ("  cycles: {0}" -f $cfg.CycleCount) }
  Inf "real test: unplug, run stress 2 min — drop >3%/min = worn"
} else { SkipC "battery" }

# ---------- 10. AC adapter ----------
Hr "10 · AC adapter"
if(Confirm "ac"){
  Inf "Dell/HP/Lenovo: boot into BIOS — 'Adapter cannot be determined' = fake/3rd-party charger"
  Inf "also: frayed cable, taped joints, wattage mismatch vs spec = negotiate"
  Rec "PASS" "ac" ""
}

# ---------- 11. USB ----------
Hr "11 · USB controllers & devices"
if(Confirm "usb"){
  Get-CimInstance Win32_USBHub | Select-Object -First 6 | ForEach-Object { Write-Host ("    {0}" -f $_.Name) }
  Inf "plug a USB3 stick into every port; each must mount instantly"
  Rec "PASS" "usb" ""
}

# ---------- 12. audio + mic ----------
Hr "12 · Audio"
if(Confirm "audio"){
  $au = Get-CimInstance Win32_SoundDevice
  if($au){ Pass ("audio hardware: {0}" -f (($au | ForEach-Object Name) -join ', ')); Rec "PASS" "audio" "" }
  else { Fail "no audio device" "-5–10%" }
  Inf "play a YouTube video: both speakers, no crackle; test mic with Voice Recorder"
}

# ---------- 13. webcam ----------
Hr "13 · Webcam"
if(Confirm "webcam"){
  $cam = Get-CimInstance Win32_PnPEntity | Where-Object { $_.Name -match 'camera|imaging|webcam' -and $_.Status -eq 'OK' }
  if($cam){ Pass ("webcam present: {0}" -f ($cam | ForEach-Object Name | Select-Object -First 2)); Rec "PASS" "webcam" ""
    Inf "open Camera app — image must be sharp, exposure adaptive"
  } else { Fail "no working webcam device" "-5–10%"; Rec "FAIL" "webcam" "-5–10%" }
}

# ---------- 14. keyboard (interactive) ----------
Hr "14 · Keyboard"
if(Confirm "keyboard"){
  Inf "open Notepad and type EVERY key: letters, numbers, F-keys, arrows, Fn combos"
  Inf "dead keys = expensive top-case replacement = -10–15%"
  Rec "PASS" "keyboard" ""
}

# ---------- 15. wifi ----------
Hr "15 · WiFi"
if(Confirm "wifi"){
  $w = Get-NetAdapter | Where-Object { $_.PhysicalMediaType -match '802.11|Native802' }
  if($w){
    $nets = (netsh wlan show networks mode=bssid | Select-String 'SSID').Count
    Pass ("wifi adapter {0} sees {1} networks" -f $w.Name, $nets); Rec "PASS" "wifi" ""
  } else { Fail "no wifi adapter" "-10% (USB dongle)"; Rec "FAIL" "wifi" "-10%" }
}

# ---------- 16. display ----------
Hr "16 · Display"
if(Confirm "display"){
  $scr = Get-CimInstance -Namespace root/wmi -ClassName WmiMonitorID -ErrorAction SilentlyContinue | Select-Object -First 1
  if($scr){ $name = -join ($scr.UserFriendlyName | Where-Object {$_ -ne 0} | ForEach-Object {[char]$_}); Inf ("panel: {0}" -f $name) }
  Inf "dead-pixel sweep: solid red/green/blue/white/black full-screen 6s each (PowerPoint blank slides work)"
  Inf "wiggle hinge watching for flicker = dying cable"
  Rec "PASS" "display" ""
}

# ---------- 17. physical checklist ----------
Hr "17 · Physical inspection"
if(Confirm "physical"){
  function A([string]$q,[string]$g){
    if($script:Ask -eq "never"){ return }
    Write-Host "  ❓ $q [y/N] " -NoNewline
    if((Read-Host) -match '^[yY]'){ Rec "WARN" "physical: $q" $g; Write-Host "     $Y→ suggest $g$X" }
  }
  A "Missing/stripped screws?" "-3%"
  A "Liquid damage (stains, port corrosion)?" "-15–25% or WALK AWAY"
  A "Loose/creaking hinge?" "-5–10%"
  A "Battery swelling (bulging case/trackpad)?" "WALK AWAY (fire risk)"
  A "Fan grinding/rattling?" "-5–10%"
  A "Deep scratches/dents/cracks?" "-3–8%"
  A "Non-original charger?" "-5%"
  Rec "PASS" "physical-done" ""
}

# ---------- 18. verdict ----------
Hr "18 · Verdict"
$P=0;$W=0;$F=0
foreach($line in $script:Scorecard){ switch(($line -split '\|')[0]){ "PASS"{$P++} "WARN"{$W++} "FAIL"{$F++} } }
$mins = [int]((Get-Date)-$T0).TotalMinutes
Write-Host ("  {0}PASS: {1}$X  {2}WARN: {3}$X  {4}FAIL: {5}$X   (runtime {6}m)" -f $G,$P,$Y,$W,$R,$F,$mins)
Write-Host "`n  $BPrice-negotiation sheet:$X"
foreach($line in $script:Scorecard){
  $p = $line -split '\|'
  if($p[2]){ Write-Host ("    {0}  {1}: {2}" -f $p[0],$p[1],$p[2]) }
}
Write-Host "`n  Rules: RAM & disk FAIL = walk away. Battery/keyboard/cosmetics = money off."
if($F -gt 0){ Write-Host "  $R$B⛔ VERDICT: FAIL rows present — negotiate hard or walk.$X" }
elseif($W -gt 0){ Write-Host "  $Y$B⚠️  VERDICT: buyable at a discount — use the sheet above.$X" }
else { Write-Host "  $G$B✅ VERDICT: clean machine at fair price.$X" }

if($transcriptStarted){ Stop-Transcript | Out-Null; }
$sha = (Get-FileHash -Algorithm SHA256 $Report).Hash
Write-Host "`n  report SHA256: $sha"
Write-Host "  report saved: $Report  (copy it to your USB stick)"
