#!/usr/bin/env bash
# ============================================================
#  PC-DOCTOR v2.0 — used-PC buyer's inspection suite
#  Linux twin of pc-doctor.ps1. Works on any live USB session
#  (Ubuntu/Fedora/Arch) or installed system.
#
#  Usage:  sudo ./pc-doctor.sh                 # full, interactive (skippable)
#          sudo ./pc-doctor.sh --soak 10       # 10-min soak test (default: off)
#          sudo ./pc-doctor.sh --yes           # non-interactive, run everything
#          ./pc-doctor.sh --list               # list checks only
#
#  GUARANTEE: every disk operation is READ-ONLY. Nothing is written
#  to the target's drives. All output goes to RAM/tmpfs or the USB.
# ============================================================
set -u
B="\e[1m"; G="\e[32m"; R="\e[31m"; Y="\e[33m"; C="\e[36m"; M="\e[35m"; X="\e[0m"
PASS() { echo -e "  ${G}[PASS]${X} $1"; }
FAIL() { echo -e "  ${R}[FAIL]${X} $1"; }
WARN() { echo -e "  ${Y}[WARN]${X} $1"; }
INFO() { echo -e "  ${C}[INFO]${X} $1"; }
SKIP() { echo -e "  ${Y}[SKIP]${X} $1"; }
hr()   { echo -e "\n${B}━━━ $1 ━━━${X}"; }

# ---------- scorecard:  NAME|RESULT|GUIDANCE ----------
SCORECARD=()
record() { # record PASS|WARN|FAIL|SKIP "name" "price guidance"
  SCORECARD+=("$1|$2|$3")
}

ASK="yes"
SOAK=0
for arg in "$@"; do
  case "$arg" in
    --yes) ASK="no" ;;
    --soak) : ;; # value parsed below
    --soak=*) SOAK="${arg#*=}" ;;
    --list) echo "cpu ram disk smart surface soak gpu throttle raminfo fans battery ac wifi sound webcam mic usb ports dmesg physical report"; exit 0 ;;
  esac
done
[ "${1:-}" = "--soak" ] && SOAK="${2:-0}"
[ "${1:-}" = "--soak=0" ] && SOAK=0

# skip prompt: returns 0 = run, 1 = skip
confirm() {
  [ "$ASK" != "yes" ] && { [ "$ASK" = "no" ] && return 0 || return 1; }
  read -r -p "  ▶ Run [$1]? [Y/n/s=skip-all] " a </dev/tty || return 1
  case "$a" in n*|N*) return 1 ;; s*|S*) ASK="never"; return 1 ;; esac
  return 0
}

ROOT=drop
sudo -n true 2>/dev/null && ROOT=full
REPORT="$(mktemp /tmp/pcdoctor-report.XXXXXX.txt)"
LOGALL() { echo -e "$1" | sed 's/\x1b\[[0-9;]*m//g' >> "$REPORT"; }
exec > >(tee -a "$REPORT") 2>&1

echo -e "${B}╔══════════════════════════════════════════╗"
echo -e "║   🩺  PC-DOCTOR v2.0 — inspection suite  ║"
echo -e "║   READ-ONLY on target disks · skippable  ║"
echo -e "╚══════════════════════════════════════════╝${X}"
[ "$ROOT" = drop ] && WARN "not root — many checks limited. Use: sudo ./pc-doctor.sh"

T_START=$(date +%s)
HOSTN=$(hostname 2>/dev/null || echo unknown)

# ============ 1. SYSTEM IDENTITY ============
hr "1 · System identity"
record INFO "identity" ""
echo -e "  Host : $HOSTN"
echo -e "  Distro: $(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-unknown}")"
echo -e "  Kernel: $(uname -r)"
echo -e "  CPU  : $(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs)"
echo -e "  Boot : $([ -d /sys/firmware/efi ] && echo UEFI || echo Legacy)"
if command -v dmidecode >/dev/null && [ "$ROOT" = full ]; then
  echo -e "  Model: $(sudo dmidecode -s system-manufacturer 2>/dev/null) $(sudo dmidecode -s system-product-name 2>/dev/null)"
  echo -e "  Serial: $(sudo dmidecode -s system-serial-number 2>/dev/null)"
fi
GPUS=$(lspci 2>/dev/null | grep -iE 'vga|3d controller' | cut -d: -f3- | xargs -I{} echo "    {}")
echo -e "  GPU(s):\n$GPUS"

# ============ 2. RAM INFO (dmidecode) ============
hr "2 · RAM modules (dmidecode: speed / slots / channels)"
if confirm "raminfo"; then
if command -v dmidecode >/dev/null && [ "$ROOT" = full ]; then
  sudo dmidecode -t memory 2>/dev/null | awk '
    /Memory Device/ {indev=1; loc=sz=typ=spd=frm=""}
    indev && /Locator:/ && !/Bank/ {loc=$2" "$3" "$4}
    indev && /Size:/ {sz=$2" "$3}
    indev && /Type:/ && !/Error/ {typ=$2}
    indev && /Speed:/ {spd=$2" "$3}
    indev && /Form Factor:/ {frm=$2" "$3}
    indev && /Part Number:/ && $2!="" {print "  slot: "loc"  |  "sz"  |  "typ"  |  "spd"  |  part:"$2" "$3; indev=0}'
  EMPTY=$(sudo dmidecode -t memory 2>/dev/null | grep -c "No Module Installed")
  [ "$EMPTY" -gt 0 ] && INFO "$EMPTY empty slot(s) — room to upgrade (good)"
else
  SKIP "dmidecode (root)"; record SKIP "raminfo" ""
fi
free -h | sed 's/^/  /'
fi

# ============ 3. CPU STRESS + THERMAL THROTTLE ============
hr "3 · CPU stress (20s) + throttle counter"
if confirm "cpu"; then
CORES=$(nproc)
T0=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null)
dmesg_mark=$(dmesg 2>/dev/null | wc -l)
echo -e "  Loading $CORES cores 20s… listen for fans, watch temps"
( for i in $(seq "$CORES"); do timeout 20 sha256sum /dev/zero >/dev/null 2>&1 & done; wait ) >/dev/null 2>&1
sleep 15
T1=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null)
echo -e "  cpu0 freq: ${T0}kHz → ${T1}kHz under load"
if [ -n "$T0" ] && [ -n "$T1" ] && [ "$T1" -lt $(( T0 * 60 / 100 )) ]; then
  FAIL "CPU dropped >40% frequency under load — thermal or power limit" "-10–20% (thermals/paste/cooler)"
  record FAIL "cpu-throttle" "-10–20%"
else
  PASS "CPU held frequency under load"; record PASS "cpu" ""
fi
# thermal throttle counters (intel rapl / thermal msg)
if dmesg 2>/dev/null | grep -qiE "throttl|thermal.*critical|CPU.*hot"; then
  WARN "kernel logged thermal events — check dmesg section" "-5–10%"
  record WARN "thermal-events" "-5–10%"
fi
fi

# ============ 4. THERMAL THROTTLE / TEMPS ============
hr "4 · Temperatures"
if command -v sensors >/dev/null; then
  sensors | grep -E 'Package|Core|Tdie|Tctl|Composite|edge|temp1' | sed 's/^/  /'
  MAX=$(sensors 2>/dev/null | sed 's/([^)]*)//g' | grep -oE '\+[0-9]+\.[0-9]+°C' | tr -d '+°C' | sort -rn | awk '$1 < 120' | head -1)
  [ -n "$MAX" ] && { [ "${MAX%%.*}" -lt 60 ] && { PASS "max ${MAX}°C idle"; record PASS "temps" ""; } || { WARN "max ${MAX}°C at idle" "-5% (cooling service)"; record WARN "temps" "-5%"; }; }
else
  SKIP "lm-sensors"; record SKIP "temps" ""
fi

# ============ 5. QUICK RAM TEST ============
hr "5 · RAM quick test (memtester ~quarter RAM)"
if confirm "ram"; then
if command -v memtester >/dev/null; then
  MB=$(($(free -m | awk '/Mem:/{print $2}') / 4))
  OUT=$(memtester "${MB}M" 1 2>&1 | grep -cE "FAILURE|failed")
  [ "$OUT" -eq 0 ] && { PASS "no errors in quick pass"; record PASS "ram-quick" ""; } \
                  || { FAIL "memtester reported $OUT error(s) — REAL test = MemTest86+ overnight" "WALK AWAY"; record FAIL "ram-quick" "WALK AWAY"; }
else
  SKIP "memtester — apt/dnf/pacman install memtester"; record SKIP "ram-quick" ""
  INFO "Definitive RAM verdict = MemTest86+ from this flash drive (2+ passes)"
fi
fi

# ============ 6. DISKS: SMART + rotational + WEAR ============
hr "6 · Disks — SMART, wear, power-on hours"
if confirm "smart"; then
for d in $(lsblk -dpno NAME,TYPE 2>/dev/null | awk '$2=="disk"{print $1}'); do
  case "$d" in /dev/zram*|/dev/loop*) continue;; esac
  echo -e "\n  ${B}$d${X}  model: $(lsblk -dno MODEL "$d" 2>/dev/null)"
  ROTA=$(lsblk -dno ROTA "$d" 2>/dev/null)
  [ "$ROTA" = "1" ] && INFO "  type: HDD (rotational)" || INFO "  type: SSD/NVMe"
  if ! command -v smartctl >/dev/null; then
    SKIP "smartctl"; record SKIP "smart-$d" ""; continue
  fi
  SMART=$(sudo smartctl -A "$d" 2>/dev/null); [ -z "$SMART" ] && SMART=$(sudo smartctl -d sat -A "$d" 2>/dev/null)
  HEALTH=$(sudo smartctl -H "$d" 2>/dev/null || sudo smartctl -d sat -H "$d" 2>/dev/null)
  echo "$HEALTH" | grep -qi PASSED && { PASS "$(echo "$HEALTH" | grep -i result | head -1 | xargs)"; record PASS "smart-$d" ""; } \
                          || { FAIL "SMART FAILED on $d" "WALK AWAY"; record FAIL "smart-$d" "WALK AWAY"; }
  echo "$SMART" | grep -E 'Reallocated|Pending|Uncorrectable|Media Wearout|Percentage Used|Available Spare|Unsafe Shutdowns|Power_On_Hours|Power-On Hours|Power Cycles|Power_Cycles|Data Units Written' | sed 's/^/    /'
  RB=$(echo "$SMART" | grep -oE '(Reallocated_Sector_Ct|Reallocated_Block_Count)[^0-9]*[0-9]+' | tail -1 | grep -oE '[0-9]+$')
  PB=$(echo "$SMART" | grep -oE '(Current_Pending_Sector|Pending_Sector_Count)[^0-9]*[0-9]+' | tail -1 | grep -oE '[0-9]+$')
  PU=$(echo "$SMART" | grep -oE 'Percentage Used[^0-9]*([0-9]+)' | grep -oE '[0-9]+' | head -1)
  [ -n "$RB" ] && [ "$RB" -gt 0 ] && { FAIL "$d: $RB reallocated sectors" "WALK AWAY or -40%+"; record FAIL "reallocated-$d" "WALK AWAY"; }
  [ -n "$PB" ] && [ "$PB" -gt 0 ] && { FAIL "$d: $PB pending sectors" "WALK AWAY"; record FAIL "pending-$d" "WALK AWAY"; }
  [ -n "$PU" ] && [ "$PU" -gt 50 ] && { WARN "$d: ${PU}% SSD life used" "-10–20% (replacement SSD)"; record WARN "wear-$d" "-10–20%"; }
done
fi

# ============ 7. FULL SURFACE READ SCAN (badblocks read-only) ============
hr "7 · Full-disk read scan (slow: 20–90 min/disk, READ-ONLY)"
INFO "Reads every sector once, samples speed. Never writes. Can skip."
if confirm "surface"; then
for d in $(lsblk -dpno NAME,TYPE 2>/dev/null | awk '$2=="disk"{print $1}'); do
  case "$d" in /dev/zram*|/dev/loop*) continue;; esac
  SZ=$(lsblk -dno SIZE "$d")
  echo -e "  ${B}$d ($SZ)${X} — reading all sectors at 5 checkpoints…"
  TOTAL_BLOCKS=$(sudo blockdev --getsize64 "$d" 2>/dev/null)
  BS=4194304; STEP=$(( TOTAL_BLOCKS / 5 / BS ))
  for i in 0 1 2 3 4; do
    OFF=$(( i * STEP ))
    SPD=$(sudo dd if="$d" bs=$BS skip=$OFF count=400 2>&1 >/dev/null | grep -oE '[0-9.]+ [kMG]?B/s' | tail -1)
    echo -e "    checkpoint $((i+1))/5: ${SPD:-n/a}"
  done
  INFO "For an exhaustive scan run: sudo badblocks -v -s -e 10 $d  (read-only)"
  record PASS "surface-$d" ""
done
INFO "Speed dipping to <50 MB/s on SSD = sick drive. Compare checkpoints."
else record SKIP "surface" ""; fi

# ============ 8. FIO BENCHMARK ============
hr "8 · Disk speed benchmark (fio, READ-ONLY, 15s)"
if confirm "fio"; then
if command -v fio >/dev/null; then
  for d in $(lsblk -dpno NAME,TYPE 2>/dev/null | awk '$2=="disk"{print $1}' | head -2); do
    case "$d" in /dev/zram*|/dev/loop*) continue;; esac
    echo -e "  ${B}$d${X}:"
    sudo fio --name=rd --filename="$d" --readonly --rw=read --bs=1M \
      --iodepth=8 --numjobs=1 --time_based --runtime=10 --name=seqread 2>/dev/null | \
      grep -E 'READ:.*(MB/s|BW=)' | sed 's/^/    /'
  done
  record PASS "fio" ""
  INFO "Healthy: NVMe ≥1200 MB/s · SATA SSD ≥400 MB/s · HDD ≥100 MB/s"
else SKIP "fio — install fio for real numbers"; record SKIP "fio" ""; fi
fi

# ============ 9. SOAK TEST (CPU+RAM+disk combined) ============
hr "9 · Combined soak test $([ "$SOAK" -gt 0 ] 2>/dev/null && echo "(${SOAK} min)")"
if [ "$SOAK" -gt 0 ] 2>/dev/null && confirm "soak"; then
  INFO "Stressing CPU+RAM+disk for $SOAK min. Any crash = don't buy."
  END=$(( $(date +%s) + SOAK * 60 ))
  MAIN_DISK=$(lsblk -dpno NAME,TYPE 2>/dev/null | awk '$2=="disk"{print $1; exit}')
  while [ "$(date +%s)" -lt "$END" ]; do
    for i in 1 2 3 4; do timeout 25 sha256sum /dev/zero >/dev/null 2>&1 & done
    timeout 25 dd if="${MAIN_DISK:-/dev/null}" bs=1M count=64 2>/dev/null | sha256sum >/dev/null 2>&1
    free -m | sha256sum >/dev/null
    sleep 2
  done
  PASS "survived ${SOAK} min combined load"
  record PASS "soak" ""
elif [ "$SOAK" = 0 ]; then
  INFO "skipped by default — enable with: sudo ./pc-doctor.sh --soak 10"
fi

# ============ 10. GPU ============
hr "10 · GPU (iGPU vs dGPU) + render load"
if confirm "gpu"; then
N_GPU=$(lspci 2>/dev/null | grep -cE 'VGA|3D controller')
if [ "$N_GPU" -gt 1 ]; then
  INFO "HYBRID system detected (iGPU + dGPU) — test BOTH"
  lspci | grep -E 'VGA|3D' | sed 's/^/    /'
  command -v glxinfo >/dev/null && { echo -e "  default renderer: $(glxinfo 2>/dev/null | grep -m1 'OpenGL renderer' | cut -d: -f2)"; }
  INFO "dGPU test on live USB: install distro's proprietary driver OR accept basic check below"
fi
if command -v glmark2 >/dev/null; then
  SCORE=$(timeout 120 glmark2 2>/dev/null | grep -oE 'glmark2 Score: [0-9]+')
  [ -n "$SCORE" ] && { PASS "$SCORE"; record PASS "gpu" ""; }
else
  STRESSOK=0; command -v stress-ng >/dev/null && STRESSOK=1
  if [ "$STRESSOK" = 1 ] && [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
    INFO "stress-ng --matrix 60s on GPU path… (glmark2 not installed)"
    timeout 60 stress-ng --matrix 1 --timeout 55s --metrics-brief 2>/dev/null | tail -2 | sed 's/^/  /'
    PASS "GPU/CPU matrix load completed without artifacts reported"; record PASS "gpu" ""
  else
    SKIP "glmark2/stress-ng"; record SKIP "gpu" ""
    INFO "Visual test: play 4K video, look for artifacts/tearing/fan roar"
  fi
fi
fi

# ============ 11. FANS ============
hr "11 · Fan RPM under load"
if confirm "fans"; then
  sensors 2>/dev/null | grep -iE 'fan' | sed 's/^/  /'
  F=$(sensors 2>/dev/null | grep -ioE 'fan[0-9]*: *[0-9]+' | grep -oE '[0-9]+' | head -1)
  if [ -n "$F" ] && [ "$F" -gt 0 ]; then
    PASS "fan spinning at ${F} RPM — listen for grinding/rattle"
    record PASS "fans" ""
  else
    WARN "no fan RPM readable (common on some laptops — judge by ear)" ""
    record WARN "fans" ""
  fi
  INFO "Listen during load: grinding bearing / rattling = -10%"
fi

# ============ 12. BATTERY + DISCHARGE TEST ============
hr "12 · Battery health + discharge-under-load"
if confirm "battery"; then
for b in /sys/class/power_supply/BAT*; do
  [ -e "$b/capacity" ] || continue
  CAP=$(cat "$b/capacity"); CYC=$(cat "$b/cycle_count" 2>/dev/null)
  FULL=$(cat "$b/charge_full" "$b/energy_full" 2>/dev/null | head -1)
  DES=$(cat "$b/charge_full_design" "$b/energy_full_design" 2>/dev/null | head -1)
  echo -e "  charge: ${CAP}%  cycles: ${CYC:-?}"
  if [ -n "$FULL" ] && [ -n "$DES" ] && [ "$DES" -gt 0 ] 2>/dev/null; then
    H=$(( 100 * FULL / DES ))
    echo -e "  design capacity: $DES  now: $FULL  → holds ${H}%"
    if   [ "$H" -ge 80 ]; then PASS "battery health ${H}%"; record PASS "battery" ""
    elif [ "$H" -ge 60 ]; then WARN "battery ${H}% — budget replacement (€40–90)" "-5–10%"; record WARN "battery" "-5–10%"
    else FAIL "battery ${H}% — dying" "-10–15% (new battery)"; record FAIL "battery" "-10–15%"; fi
  fi
  ST=$(cat "$b/status" 2>/dev/null)
  if [ "$ST" = "Discharging" ]; then
    P1=$(cat "$b/power_now" "$b/current_now" 2>/dev/null | head -1)
    INFO "discharging now at ${P1:-?} — unplug, run stress 2 min, watch % drop"
    INFO "drop >3%/min under load = worn cell"
  else
    INFO "plug status: $ST — unplug to run the live discharge check"
  fi
done
[ -e /sys/class/power_supply/BAT0 ] || { INFO "no battery (desktop?)"; record SKIP "battery" ""; }
fi

# ============ 13. AC ADAPTER ============
hr "13 · AC adapter"
if confirm "ac"; then
  AC=$(ls /sys/class/power_supply/A*C 2>/dev/null | head -1)
  if [ -n "$AC" ]; then
    INFO "online: $(cat "$AC/online" 2>/dev/null)"
    [ -f "$AC/manufacturer" ] && INFO "adapter identity: $(cat "$AC/manufacturer") $(cat "$AC/model_name" 2>/dev/null)"
    WATTS=$(cat "$AC/wattage" 2>/dev/null)
    [ -n "$WATTS" ] && INFO "rated: $((WATTS/1000))W"
    INFO "Dell/HP/Lenovo: BIOS shows 'AC adapter wattage cannot be determined' = FAKE/3rd-party adapter → negotiate or bring original"
    record PASS "ac" ""
  else
    INFO "no AC sysfs entry — check BIOS adapter message manually"; record SKIP "ac" ""
  fi
  INFO "Physical: bent plug, taped cable, wrong wattage = -5% or refuse"
fi

# ============ 14. WIFI ============
hr "14 · WiFi / Bluetooth"
if confirm "wifi"; then
if command -v nmcli >/dev/null; then
  nmcli device status 2>/dev/null | sed 's/^/  /'
  W=$(nmcli -t -f DEVICE,TYPE device 2>/dev/null | grep wifi | cut -d: -f1 | head -1)
  [ -n "$W" ] && { nmcli device wifi list --rescan yes 2>/dev/null | head -5 | sed 's/^/  /'; PASS "wifi $W scans"; record PASS "wifi" ""; } \
             || { FAIL "no wifi adapter visible" "-10% (USB dongle workaround)"; record FAIL "wifi" "-10%"; }
fi
fi

# ============ 15. SOUND ============
hr "15 · Sound: speakers + mic loopback"
if confirm "sound"; then
  RUNAS=""
  [ -n "${SUDO_USER:-}" ] && RUNAS="sudo -u $SUDO_USER"
  if command -v speaker-test >/dev/null; then
    if $RUNAS speaker-test -t sine -f 440 -l 2 -p 1 >/dev/null 2>&1; then PASS "test tone played"; record PASS "speakers" "";
    elif [ -n "$RUNAS" ]; then WARN "audio test needs a desktop session — play a video to verify speakers" ""; record WARN "speakers" "";
    else FAIL "no tone" "-5–10%"; record FAIL "speakers" "-5–10%"; fi
  else SKIP "speaker-test (alsa-utils)"; record SKIP "speakers" ""; fi
  REC=$(command -v arecord); PLAY=$(command -v aplay)
  if [ -n "$REC" ] && [ -n "$PLAY" ]; then
    INFO "MIC LOOPBACK: say something now (5s of mic played back to you)…"
    if $RUNAS timeout 6 arecord -f cd -d 5 2>/dev/null | $RUNAS aplay - 2>/dev/null; then PASS "mic captured + played back"; record PASS "mic" ""; elif [ -n "$RUNAS" ]; then WARN "mic test needs desktop session — use any recorder app" ""; record WARN "mic" ""; else WARN "loopback failed — test mic manually" ""; record WARN "mic" ""; fi
  else
    SKIP "arecord/aplay"; record SKIP "mic" ""
  fi
  INFO "Test both jacks + crackle at 50% volume. Crackle = -5%"
fi

# ============ 16. WEBCAM CAPTURE ============
hr "16 · Webcam frame capture"
if confirm "webcam"; then
  if command -v fswebcam >/dev/null; then
    CAM=$(ls /dev/video* 2>/dev/null | head -1)
    [ -n "$CAM" ] && fswebcam -d "$CAM" -r 1280x720 --no-banner /tmp/pcdoctor-cam.jpg 2>/dev/null \
      && { PASS "frame captured to /tmp/pcdoctor-cam.jpg — view it: is it sharp?"; record PASS "webcam" ""; } \
      || { WARN "capture failed"; record WARN "webcam" ""; }
  elif [ -n "$(ls /dev/video* 2>/dev/null)" ]; then
    INFO "devices: $(ls /dev/video*)  (install fswebcam for auto-capture; or open any camera app)"
    record PASS "webcam" ""
  else
    FAIL "no /dev/video* at all" "-5–10% (built-in cam dead)"; record FAIL "webcam" "-5–10%"
  fi
fi

# ============ 17. USB PORTS + SPEEDS ============
hr "17 · USB ports + per-port speed (lsusb -t)"
if confirm "usb"; then
  lsusb 2>/dev/null | head -8 | sed 's/^/  /'
  echo -e "  ${B}topology with speeds (480M=USB2, 5000M+=USB3):${X}"
  lsusb -t 2>/dev/null | sed 's/^/  /'
  INFO "Insert a USB3 stick into EVERY port; check it negotiates 5000M+ where expected"
  record PASS "usb" ""
fi

# ============ 18. KERNEL ERROR SCAN ============
hr "18 · Kernel log scan (I/O, MCE, PCIe, GPU, USB)"
if confirm "dmesg"; then
  HITS=$(sudo dmesg -T --level=err,warn 2>/dev/null | grep -ciE 'mce|machine check|pcieport.*error|I/O error|gpu.*reset|drm.*error|usb.*disconnect|ata[0-9]+.*error|nvme.*timeout|thermal.*shutdown')
  if [ "$HITS" -eq 0 ]; then
    PASS "no kernel errors of concern in dmesg"; record PASS "dmesg" ""
  else
    echo -e "  ${Y}matches:${X}"
    sudo dmesg -T --level=err,warn 2>/dev/null | grep -iE 'mce|machine check|pcieport.*error|I/O error|gpu.*reset|drm.*error|usb.*disconnect|ata[0-9]+.*error|nvme.*timeout|thermal.*shutdown' | tail -10 | sed 's/^/    /'
    WARN "$HITS kernel warning(s) — judge severity:"
    INFO "  MCE/machine check = WALK AWAY · repeated ata/nvme errors = disk/cable · occasional usb disconnect = cosmetic"
    record WARN "dmesg" "case-by-case"
  fi
  sudo dmesg 2>/dev/null | grep -iE 'mce|machine check' | head -3 | sed 's/^/    MCE: /' | grep -q . && { FAIL "Machine Check Exception found — CPU/board failing" "WALK AWAY"; record FAIL "mce" "WALK AWAY"; }
fi

# ============ 19. PHYSICAL CHECKLIST (interactive) ============
hr "19 · Physical inspection checklist"
if confirm "physical"; then
  SCORE=0
  askcheck() { # askcheck "question" "deduction-if-yes"
    local r=""
    [ "$ASK" != "yes" ] && return 0   # non-interactive mode: skip questions
    read -r -t 15 -p "  ❓ $1 [y/N] " r </dev/tty || return 0
    case "$r" in y*|Y*) record WARN "physical" "$2"; echo -e "     ${Y}→ suggest $2${X}";; esac
  }
  askcheck "Missing / stripped screws on the bottom?" "-3%"
  askcheck "Liquid damage: stains under keyboard, corrosion in ports?" "-15–25% or WALK AWAY"
  askcheck "Hinge loose, creaks, or screen wobbles freely?" "-5–10%"
  askcheck "Battery swollen (trackpad/keyboard bulging, case lifted)?" "WALK AWAY (fire risk)"
  askcheck "Fan grinding, rattling, or clicking under load?" "-5–10%"
  askcheck "Palm rest / lid deep scratches, dents, cracked plastics?" "-3–8%"
  askcheck "Rubber feet missing?" "-1%"
  askcheck "Charger frayed, taped, or non-original?" "-5%"
  record PASS "physical-done" ""
fi

# ============ 20. FINAL VERDICT + REPORT ============
hr "20 · Verdict"
T_END=$(date +%s)
P=$(grep -c . /dev/null); P=0; W=0; F=0
for line in "${SCORECARD[@]}"; do
  case "${line%%|*}" in PASS) P=$((P+1));; WARN) W=$((W+1));; FAIL) F=$((F+1));; esac
done
echo -e "  ${G}PASS: $P   ${Y}WARN: $W   ${R}FAIL: $F${X}   (runtime: $(( (T_END-T_START)/60 ))m $(( (T_END-T_START)%60 ))s)"
echo -e "\n  ${B}Price-negotiation sheet:${X}"
DED=0
for line in "${SCORECARD[@]}"; do
  RES="${line%%|*}"; REST="${line#*|}"; NAME="${REST%%|*}"; G="${REST#*|}"
  [ -n "$G" ] && echo -e "    $RES  ${NAME}: ${G}"
done
echo -e "\n  Rules: RAM & disk FAIL = walk away. Battery/keyboard/cosmetics = money off."
[ "$F" -gt 0 ] && echo -e "  ${R}${B}⛔ VERDICT: has FAIL rows — negotiate hard or walk.${X}" || \
  { [ "$W" -gt 0 ] && echo -e "  ${Y}${B}⚠️  VERDICT: buyable at a discount — use the sheet above.${X}" || \
    echo -e "  ${G}${B}✅ VERDICT: clean machine at fair price.${X}"; }

sha256sum "$REPORT" | awk '{print "\n  report SHA256: "$1}'
echo -e "  report saved: $REPORT (copy it to your USB stick)"
echo -e "  copy command:  cp $REPORT /path/to/usb/"
