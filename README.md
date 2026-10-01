# 🩺 PC-DOCTOR — used-PC health checker

A single interactive script that stress-tests and health-checks a computer **before you buy it used**. Built for running from a bootable flash drive, works on any Linux live session (Ubuntu, Fedora, Arch...).

> Rule of thumb: **RAM and disk must be perfect. Everything else is negotiable.**

## What it checks

| # | Check | Method |
|---|---|---|
| 1 | System identity | CPU, GPU, distro, UEFI/Legacy |
| 2 | CPU stability | 20s all-core stress + temps + frequency |
| 3 | RAM | memtester quick pass (real test = MemTest86+ ISO) |
| 4 | Temperatures | idle temps via lm-sensors |
| 5 | Disks ⭐ | SMART: reallocated/pending sectors, SSD wear, power-on hours |
| 6 | Keyboard | live evtest key reader — press every key |
| 7 | Display | dead-pixel color sweep + hinge-wiggle test |
| 8 | Battery | capacity vs design %, cycle count |
| 9 | WiFi/BT | adapter + network scan on live USB |
| 10 | Sound | speaker-test tones + headphone jacks |
| 11 | Webcam | v4l2 device probe |
| 12 | USB ports | every port with two known-good sticks |
| 13 | Final protocol | BIOS check, cold-boot watch, MemTest86+ |

## Quick start (on the used PC)

```bash
sudo ./pc-doctor.sh
```

Missing tools are detected and the script prints the exact install command for the live distro you booted.

## Build the flash drive

1. Flash [Ventoy](https://www.ventoy.net/en/download.html) to a ≥8 GB USB stick
2. Drop onto the stick:
   - an Ubuntu or Fedora live ISO
   - `memtest86plus` ISO (from your distro repo or memtest.org)
   - this `pc-doctor.sh` + `README.md`
3. Boot the used PC from the stick → pick the live ISO → run the script from the Ventoy partition

## Tips for the buy

- Run checks **before** handing over money; sellers expect it
- Reallocated or pending sectors on the disk → walk away or negotiate hard
- A battery under 60% design capacity → budget a replacement
- Type every single key; dead keys are not cheaply fixable
- Wiggle the display hinge while watching for flicker

## License

MIT — see [LICENSE](LICENSE)
