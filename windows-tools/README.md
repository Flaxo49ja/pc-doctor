# Windows fallback kit — when the seller won't boot your USB

A locked BIOS, a Secure Boot block, or a plain refusal to boot USB means you
cannot verify with pc-doctor proper. **Treat that itself as a red flag** —
note it in your meeting checklist (the script also scores it WARN when you
report it during the anti-fraud section).

When it happens, use the tools below *on the seller's Windows session*. All
output is saved to **your own USB stick** (usually `E:`), never their disk.
Download each tool **from the official site only** — never from "mirror" sites.

| Need | Tool | Official source |
|---|---|---|
| Disk health (SMART) | CrystalDiskInfo **portable** | https://crystalmark.info/en/software/crystaldiskinfo/ |
| Full specs, temps, sensors | HWiNFO **portable** | https://www.hwinfo.com/download/ |
| CPU/board/RAM details | CPU-Z **portable** (zip) | https://www.cpuid.com/softwares/cpu-z.html |
| CPU/RAM/GPU stress | OCCT portable | https://www.ocbase.com/ |
| Battery detail | BatteryInfoView (NirSoft, portable) | https://www.nirsoft.net/utils/battery_information_view.html |
| RAM (the real test) | MemTest86 — boot from the stick | https://www.memtest86.com/ |
| Dead pixels | `dead-pixel.html` in this folder — open in any browser, fullscreen (F11) | (offline file) |

## Rules

1. Save every output file to your stick, e.g. `E:\evidence\`
2. Never install anything on the seller's machine — portable versions only
3. Photos of every screen > screenshots you were shown
4. Run `..\seller-check.ps1` from the stick for the automated one-shot report

## Built-in Windows commands (nothing to install)

Run in **admin PowerShell**, replace `E:` with your stick's letter:

```powershell
Get-CimInstance Win32_ComputerSystem,Win32_BIOS,Win32_Processor,Win32_VideoController,Win32_PhysicalMemory,Win32_DiskDrive |
  fl Manufacturer,Model,SerialNumber,Name,Capacity,Speed,SMBIOSBIOSVersion,ReleaseDate,Size,MediaType |
  Out-File E:\specs.txt

Get-PhysicalDisk | Get-StorageReliabilityCounter |
  Select DeviceId,Wear,Temperature,PowerOnHours,ReadErrorsTotal,WriteErrorsTotal |
  Out-File E:\disk.txt

powercfg /batteryreport /output E:\battery.html
```

Some drives report blank SMART fields via CIM — confirm with CrystalDiskInfo.
