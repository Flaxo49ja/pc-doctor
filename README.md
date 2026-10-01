# 🩺 PC-DOCTOR v3.0 — used-PC buyer's inspection suite

Prove the real specs and health of a used computer **in ~10 minutes, at the seller's place, offline**.

## Why this exists

In Mozambique (and most of the second-hand world), laptops are sold via Facebook Marketplace by people who often don't know — or don't say — the real specs. RAM is "8GB" until you look. The "new battery" has 300 cycles. The "i7" is an i5 from 2013. There is no trust infrastructure: no returns, no warranty, no trade unions of sellers. The only protection is **verification at the point of sale**.

PC-DOCTOR is a bootable USB toolkit that turns any used-PC meetup into a forensic inspection: claimed specs vs detected reality, disk health, battery wear, anti-fraud checks (serial swaps, anti-theft locks, remote-access software), and a deterministic BUY / NEGOTIATE / WALK AWAY verdict with a price-deduction sheet — plus a report you photograph as evidence.

**Strictly read-only on the seller's disks.** Nothing is installed, nothing is written to their machine.

## Features (v3.0)

- **Listing-vs-reality mode** — enter seller claims; get a PASS/FAIL table (RAM, storage type/size, CPU generation, screen, age vs power-on hours)
- **Rule-based verdict** — BUY / NEGOTIATE / WALK AWAY + top reasons + per-check price-deduction hints. Deterministic, never an LLM.
- **Disk forensics** — SMART + nvme-cli (reallocated/pending sectors, wear, media errors, power-on hours vs claimed age), rotational proof (SSD vs HDD lie detector), read-only surface scan with speed sampling, fio benchmark vs expected speed for drive type, f3probe fake-capacity detection for USB sticks
- **CPU/RAM/thermal** — stress + throttling counters + turbostat, dmidecode RAM map (speed/slots/soldered), EDAC/ECC errors, memtester quick pass, 10-minute combined soak test
- **GPU/display** — iGPU vs dGPU, glmark2/stress-ng load, EDID panel manufacture date vs BIOS date (replaced-screen detector), touchscreen check, dead-pixel sweep
- **Battery/power** — health %, cycles, 5-min discharge-under-load, AC adapter genuineness, swollen-battery safety check
- **Anti-fraud** — serial consistency across system/board/chassis, BIOS date vs claimed age, Secure Boot/TPM/efibootmgr review, Absolute/Computrace flags, Intel ME, OEM Windows key (MSDM), read-only scan of installed OS for TeamViewer/AnyDesk + install-date estimation
- **Ports/IO** — per-port USB speed topology, 5 GHz WiFi scan, Bluetooth, ethernet link speed, mic loopback, webcam frame capture, HDMI/touchpad/card-reader manual protocol
- **UX** — whiptail TUI, colour tags, English + **Portuguese (pt-MZ)** plain-language results, `--seller` mode, fully offline
- **Optional LLM layer** (`--explain` / `--chat`) — sends a *serial-scrubbed* report JSON to an LLM at runtime (key typed per session, never stored); offline it falls back to built-in strings. The LLM can never override the rule-based verdict.
- **Reports** — `pc-doctor-report-<serial>-<date>.txt` + `.json` + SHA256, written next to the script (i.e. on your own USB)

## Quick start

### On the used PC (from your USB)

```bash
sudo ./pc-doctor.sh                 # full interactive
sudo ./pc-doctor.sh --quick         # 10-minute version
sudo ./pc-doctor.sh --seller        # seller-friendly screens
LANG=pt ./pc-doctor.sh              # Portuguese
./pc-doctor.sh --explain            # after a run: LLM summary (online only)
```

### Building the flash drive

Option A — **existing OS USB**: add `pc-doctor.sh` next to any Linux live ISO via [Ventoy](https://ventoy.net), plus MemTest86+.

Option B — **dedicated live ISO** (<1 GB, auto-launches the tool, no internet needed):

```bash
sudo apt install live-build        # on a Debian 13 host/container
cd live && sudo ./build.sh
# -> pc-doctor-live.iso + pc-doctor-live.iso.sha256
```

Flash with `dd`/Ventoy/Rufus. Boots UEFI and legacy. MemTest86+ is in the boot menu.

### When you can't boot USB

Don't depend on the target's OS — boot your own stick. The custom ISO carries every tool, so it behaves identically on Windows or Linux machines and can't be fooled by a rigged Windows install. If the seller refuses USB boot or the BIOS is locked, **that itself is a red flag** (the script records it as WARN when you report it). Fall back to the [windows-tools/](windows-tools/) kit: CrystalDiskInfo, HWiNFO, CPU-Z, OCCT, BatteryInfoView (all portable, official links inside), `dead-pixel.html`, MemTest86, plus built-in PowerShell one-liners — everything saved to your own stick, nothing installed on theirs. `seller-check.ps1` doubles as the on-site fallback and prints a PASS/WARN/FAIL summary.

**Missing-tool rule:** any check whose tool is absent is marked `NOT TESTED` (never a silent PASS), the install command is printed, all NOT TESTED checks are listed in the report — and the verdict **cannot be BUY** while RAM or disk SMART is unproven (it becomes `INCOMPLETE`).

### Selling your own machine?


Run [`seller-check.ps1`](seller-check.ps1) on Windows (PowerShell, read-only, installs nothing) and send the output to the buyer before they travel. For sellers who won't reboot to USB, document CrystalDiskInfo / HWiNFO screenshots as a *courtesy* — the buyer still verifies with PC-DOCTOR.

## Sample report (excerpt)

```
  [PASS] Disk: GOOD. zero bad sectors (realloc=0 pending=0)
  [PASS] power-on hours: 1043  cycles: 311
  [FAIL] LISTING LIE: RAM claimed 16GB > real 8GB -- LISTING LIE
  [WARN] battery: worn but usable (67%)
  ── Verdict ──────────────────────────────
  PASS: 14   WARN: 3   FAIL: 1
  VERDICT: NEGOTIATE -- use the price-deduction sheet below.
  report SHA256: 9e1baccd7470bfdab349dd535617db4ac9996f64fa93acb2a620b8eefb9f8f42
```

## Safety rules baked in

- Every disk operation is read-only (SMART queries, sector reads, `mount -o ro`)
- f3probe only ever offered for removable USB drives, never the system disk
- The LLM layer is opt-in, online-only, key never stored, output cannot change the verdict
- Swollen battery / MCE errors → automatic WALK AWAY with safety warning

## Community

See [reports/](reports/) for anonymized per-model submissions, and
[CHECKLIST.md](CHECKLIST.md) / [CHECKLIST.pt.md](CHECKLIST.pt.md) for the
meeting protocol in English and Portuguese.

## License

MIT — see [LICENSE](LICENSE)
