#Requires -Version 5.1
<#
  seller-check.ps1 - seller-side pre-screening for pc-doctor
  A seller runs this on Windows BEFORE the buyer travels, saves the
  output file and sends it (WhatsApp/e-mail). READ-ONLY, installs nothing.

  How to run (copy-paste into PowerShell):
    Set-ExecutionPolicy Bypass -Scope Process -Force
    .\seller-check.ps1
  Output: seller-check-<serial>-<date>.txt on the Desktop.
#>
$ErrorActionPreference = "SilentlyContinue"
$Out = @()
$Out += "PC-DOCTOR seller-check v1.0 - $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
$Out += "Machine: $((Get-CimInstance Win32_ComputerSystem).Manufacturer) $((Get-CimInstance Win32_ComputerSystem).Model)  S/N: $((Get-CimInstance Win32_BIOS).SerialNumber)"
$Out += "BIOS: $((Get-CimInstance Win32_BIOS).SMBIOSBIOSVersion) $(Get-Date ((Get-CimInstance Win32_BIOS).ReleaseDate) -Format 'yyyy-MM-dd' 2>$null)"
$Out += "OS: $((Get-CimInstance Win32_OperatingSystem).Caption) (installed approx $((Get-CimInstance Win32_OperatingSystem).InstallDate.ToString('yyyy-MM-dd')))"
$cpu = Get-CimInstance Win32_Processor
$Out += "CPU: $($cpu.Name)  cores:$($cpu.NumberOfCores) threads:$($cpu.NumberOfLogicalProcessors)"
$Out += "RAM installed: {0:N1} GB" -f ((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB)
Get-CimInstance Win32_PhysicalMemory | ForEach-Object { $Out += ("  slot {0}: {1:N0} GB @ {2:N0} MT/s" -f $_.DeviceLocator, ($_.Capacity/1GB), $_.ConfiguredClockSpeed) }
$Out += ""
$Out += "STORAGE:"
Get-PhysicalDisk | ForEach-Object {
  $rel = $_ | Get-StorageReliabilityCounter
  $Out += ("  {0} | {1} {2} | {3:N0} GB | wear:{4}% | hours:{5} | temp:{6}C" -f $_.FriendlyName,$_.BusType,$_.MediaType,($_.Size/1GB),$rel.Wear,$rel.PowerOnHours,$rel.Temperature)
}
$Out += ""
$Out += "GPU: " + ((Get-CimInstance Win32_VideoController | ForEach-Object Name) -join ' + ')
$bat = Get-CimInstance -Namespace root/wmi -ClassName BatteryStaticData
$bst = Get-CimInstance -Namespace root/wmi -ClassName BatteryStatus
if ($bat) {
  $h = [int](100 * $bst.FullChargedCapacity / $bat.DesignedCapacity)
  $Out += ("BATTERY: design {0} mWh, full-charge {1} mWh -> health {2}%" -f $bat.DesignedCapacity,$bst.FullChargedCapacity,$h)
}
$Out += ""
$Out += "Recent hardware errors (30 days, WHEA/disk):"
$whea = Get-WinEvent -FilterHashtable @{LogName='System'; Level=1,2; StartTime=(Get-Date).AddDays(-30)} -MaxEvents 200 |
        Where-Object { $_.ProviderName -match 'WHEA|disk|stornvme|storahci' }
if ($whea) { $whea | Select-Object -First 5 | ForEach-Object { $Out += ("  [{0}] {1}: {2}" -f $_.TimeCreated.ToString('MM-dd'),$_.ProviderName,($_.Message -split "`n")[0]) } } else { $Out += "  none" }
$Out += ""
$Out += "Battery trend report: $((powercfg /batteryreport /output "$env:TEMP\batt.html" 2>$null); if(Test-Path "$env:TEMP\batt.html")){ 'saved to %TEMP%\batt.html - attach it' }"
$Out += "TIP for buyer-side proof: buyer will verify everything with a bootable USB anyway."
$Desk = [Environment]::GetFolderPath('Desktop')
$File = Join-Path $Desk ("seller-check-{0}-{1}.txt" -f (Get-CimInstance Win32_BIOS).SerialNumber, (Get-Date -Format 'yyyyMMdd'))
$Out | Out-File -FilePath $File -Encoding UTF8
Write-Host "`nSaved: $File" -ForegroundColor Green
Write-Host "Send that file (plus %TEMP%\batt.html) to the buyer." -ForegroundColor Green
