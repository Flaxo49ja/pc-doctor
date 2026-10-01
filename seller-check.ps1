#Requires -Version 5.1
<#
  seller-check.ps1 v1.1 - seller-side pre-screening for pc-doctor
  A seller runs this on Windows BEFORE the buyer travels (or on-site as the
  fallback when USB boot is refused). READ-ONLY, installs nothing.

  All output is written to THE DRIVE THIS SCRIPT RUNS FROM (your USB stick),
  never the target's disk.

  How to run (copy-paste into PowerShell):
    Set-ExecutionPolicy Bypass -Scope Process -Force
    .\seller-check.ps1
  Output: seller-check-<serial>-<date>.txt next to this script + PASS/WARN/FAIL summary.
#>
$ErrorActionPreference = "SilentlyContinue"
$Out = @()
$script:Result = 0   # 0=PASS 1=WARN 2=FAIL
function Note([string]$level, [string]$text) {
  $Out += "[$level] $text"
  switch ($level) {
    "FAIL" { if ($script:Result -lt 2) { $script:Result = 2 } }
    "WARN" { if ($script:Result -lt 1) { $script:Result = 1 } }
  }
}

$Out += "PC-DOCTOR seller-check v1.1 - $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
$cs = Get-CimInstance Win32_ComputerSystem
$bios = Get-CimInstance Win32_BIOS
$Out += "Machine: $($cs.Manufacturer) $($cs.Model)  S/N: $($bios.SerialNumber)"
$Out += "BIOS: $($bios.SMBIOSBIOSVersion) $(Get-Date $bios.ReleaseDate -Format 'yyyy-MM-dd' 2>$null)"
$os = Get-CimInstance Win32_OperatingSystem
$Out += "OS: $($os.Caption) (installed approx $($os.InstallDate.ToString('yyyy-MM-dd')))"
$cpu = Get-CimInstance Win32_Processor
$Out += "CPU: $($cpu.Name)  cores:$($cpu.NumberOfCores) threads:$($cpu.NumberOfLogicalProcessors)"
$Out += ("RAM installed: {0:N1} GB" -f ($cs.TotalPhysicalMemory/1GB))
Get-CimInstance Win32_PhysicalMemory | ForEach-Object {
  $Out += ("  slot {0}: {1:N0} GB @ {2:N0} MT/s" -f $_.DeviceLocator, ($_.Capacity/1GB), $_.ConfiguredClockSpeed)
}
$Out += ""
$Out += "STORAGE:"
Get-PhysicalDisk | ForEach-Object {
  $d = $_
  $rel = $d | Get-StorageReliabilityCounter
  $Out += ("  {0} | {1} {2} | {3:N0} GB | wear:{4}% | hours:{5} | temp:{6}C" -f
           $d.FriendlyName, $d.BusType, $d.MediaType, ($d.Size/1GB), $rel.Wear, $rel.PowerOnHours, $rel.Temperature)
  if ($rel.Wear -ge 50) { Note "WARN" "SSD wear $($rel.Wear)% on $($d.FriendlyName) - budget replacement" }
  elseif ($null -ne $rel.Wear) { Note "PASS" "SSD wear $($rel.Wear)% on $($d.FriendlyName)" }
  else { Note "WARN" "SMART wear unavailable for $($d.FriendlyName) (verify with CrystalDiskInfo)" }
  if ($rel.ReadErrorsTotal -gt 0 -or $rel.WriteErrorsTotal -gt 0) {
    Note "WARN" "disk errors: read=$($rel.ReadErrorsTotal) write=$($rel.WriteErrorsTotal)"
  }
}
$Out += ""
$Out += "GPU: " + ((Get-CimInstance Win32_VideoController | ForEach-Object Name) -join ' + ')
$bat = Get-CimInstance -Namespace root/wmi -ClassName BatteryStaticData
$bst = Get-CimInstance -Namespace root/wmi -ClassName BatteryStatus
if ($bat -and $bst.FullChargedCapacity) {
  $h = [int](100 * $bst.FullChargedCapacity / $bat.DesignedCapacity)
  $Out += ("BATTERY: design {0} mWh, full-charge {1} mWh -> health {2}%" -f $bat.DesignedCapacity, $bst.FullChargedCapacity, $h)
  if ($h -ge 80)      { Note "PASS" "battery health $h%" }
  elseif ($h -ge 60)  { Note "WARN" "battery health $h% - replacement soon" }
  else                { Note "FAIL" "battery health $h% - dying" }
}
$Out += ""
$Out += "Recent hardware errors (30 days, WHEA/disk):"
$whea = Get-WinEvent -FilterHashtable @{LogName='System'; Level=1,2; StartTime=(Get-Date).AddDays(-30)} -MaxEvents 200 |
        Where-Object { $_.ProviderName -match 'WHEA|disk|stornvme|storahci' }
if ($whea) {
  $whea | Select-Object -First 5 | ForEach-Object {
    $Out += ("  [{0}] {1}: {2}" -f $_.TimeCreated.ToString('MM-dd'), $_.ProviderName, ($_.Message -split "`n")[0]) }
  if ($whea | Where-Object ProviderName -match 'WHEA') { Note "FAIL" "WHEA hardware errors logged - CPU/board red flag" }
  else { Note "WARN" "$($whea.Count) disk/thermal error events in 30 days" }
} else { Note "PASS" "no WHEA/disk critical events in 30 days" }

# battery trend report -> same drive as this script
$powercfg = Join-Path $env:SystemRoot 'System32\powercfg.exe'
$scriptDrive = Split-Path -Parent $MyInvocation.MyCommand.Path
$batt = Join-Path $scriptDrive "battery-report.html"
& $powercfg /batteryreport /output $batt | Out-Null
$Out += "Battery trend: $(if (Test-Path $batt) { "battery-report.html saved next to this script" } else { 'could not generate' })"

$Out += ""
switch ($script:Result) {
  0 { $Out += "SUMMARY: [PASS] nothing alarming found - buyer will still verify with bootable USB" }
  1 { $Out += "SUMMARY: [WARN] minor issues found - see [WARN] lines above" }
  2 { $Out += "SUMMARY: [FAIL] serious issues found - see [FAIL] lines above" }
}

$File = Join-Path $scriptDrive ("seller-check-{0}-{1}.txt" -f $bios.SerialNumber, (Get-Date -Format 'yyyyMMdd-HHmm'))
$Out | Out-File -FilePath $File -Encoding UTF8
Write-Host ""
Write-Host ($Out | Select-Object -Last 3)
Write-Host "Saved: $File" -ForegroundColor Green
Write-Host "Send that file (plus battery-report.html) to the buyer." -ForegroundColor Green
