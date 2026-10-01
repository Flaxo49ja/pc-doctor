# 🩺 PC-DOCTOR v2.0 — used-PC buyer's inspection suite

Dual-OS hardware inspection kit for **checking a computer before you buy it used**. Run it from a flash drive on the seller's machine — Linux or Windows — get a scorecard with price-negotiation guidance and a SHA256-signed report.

> Rule of thumb: **RAM and disk must be perfect. Everything else is negotiable.**

- **Linux targets** → `pc-doctor.sh` (bash, any live USB: Ubuntu/Fedora/Arch)
- **Windows targets** → `pc-doctor.ps1` (PowerShell 5.1+, built into Win 10/11)

**Safety:** every disk operation is **read-only** (badblocks-style reads, SMART queries, raw sector sampling — never writes). Every check is **individually skippable** (`n` = skip one, `s` = skip all).

## What it checks (both versions)

| Area | Linux | Windows |
|---|---|---|
| System identity, serial, GPUs | dmidecode/lspci | CIM/WMI |
| RAM: slots, speeds, part numbers | dmidecode -t memory | Win32_PhysicalMemory |
| CPU stress + throttle check | all-core load + freq drop + dmesg | all-core jobs + thermal zones + WHEA log |
| Kernel/event error scan | dmesg: MCE, I/O, PCIe, GPU reset, USB disconnect | Event Log: WHEA, disk, stornvme, thermal (30 days) |
| Disks: SMART, wear, hours, **rotational vs SSD** | smartctl (SAT fallback) | Get-StorageReliabilityCounter |
| Full-disk **read-only** surface scan w/ speed sampling | dd at 5 checkpoints + badblocks hint | raw \\.\PhysicalDrive reads at 5 offsets |
| Disk benchmark | fio sequential read | timed raw reads |
| Combined **soak test** (CPU+RAM+disk) | `--soak 10` | `-Soak 10` |
| GPU: iGPU vs dGPU detection + render load | glxinfo/glmark2/stress-ng | dual-GPU detect + render loop |
| Fans | sensors RPM + listen test | listen test |
| Battery: design %, cycles + **discharge-under-load** | /sys/class/power_supply | WMI battery + powercfg report |
| AC adapter genuineness | sysfs + BIOS hint | BIOS hint (Dell/HP/Lenovo) |
| WiFi/BT scan | nmcli | netsh |
| Speakers + **mic loopback** | speaker-test + arecord→aplay | guidance + Camera/Voice Recorder |
| Webcam **frame capture** | fswebcam → jpg | device probe + Camera app |
| USB per-port **speed topology** | lsusb -t | device list |
| Keyboard live test | evtest reader | Notepad protocol |
| **Physical checklist** (screws, liquid damage, hinge, swelling, fan, charger) | interactive → scorecard | interactive → scorecard |
| **Verdict + price-deduction sheet** | ✅ | ✅ |
| Report **SHA256** | ✅ | ✅ |

## Flash-drive recipe (works on both)

1. Flash [Ventoy](https://www.ventoy.net) to a ≥16 GB stick
2. Drop onto it:
   - Ubuntu (or Fedora) live ISO
   - `memtest86plus` ISO — the definitive RAM test (2+ passes)
   - this repo: `pc-doctor.sh`, `pc-doctor.ps1`, README
   - [smartmontools for Windows](https://www.smartmontools.org) portable + `glmark2`/`fio` if you want full benchmarks on Windows
3. On the used PC: boot Ventoy
   - **Windows laptop:** boot the ISO anyway (Linux checks run fine on most hardware), *or* from Windows: copy the repo, then in PowerShell:
     ```powershell
     Set-ExecutionPolicy Bypass -Scope Process -Force
     .\pc-doctor.ps1            # interactive
     .\pc-doctor.ps1 -Yes       # run everything
     .\pc-doctor.ps1 -Soak 10   # + 10-minute soak test
     ```
   - **Linux live session:**
     ```bash
     sudo ./pc-doctor.sh
     sudo ./pc-doctor.sh --soak 10   # add soak test
     sudo ./pc-doctor.sh --list      # see all checks
     ```
4. At the end you get a **PASS/WARN/FAIL scorecard, a price-deduction sheet, and a SHA256-hashed report** — copy the report to the USB stick and negotiate with evidence.

## Negotiation cheat-sheet (what the script tells you)

| Finding | Suggested move |
|---|---|
| RAM errors (memtester/MemTest) | **WALK AWAY** |
| Reallocated/pending sectors > 0 | **WALK AWAY** or −40%+ |
| WHEA / MCE machine-check errors | **WALK AWAY** |
| Battery < 60% design | −10–15% |
| Battery 60–80% | −5–10% |
| SSD wear > 50% | −10–20% |
| Dead keys / bad hinge / fan grinding | −5–15% |
| Liquid damage / swollen battery | walk away |
| Non-original charger (BIOS flags it) | −5% or refuse |

## License

MIT — see [LICENSE](LICENSE)
