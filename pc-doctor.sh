#!/usr/bin/env bash
# ============================================================
#  PC-DOCTOR v1.0 — used-PC health checker
#  Run on any live Linux (Ubuntu/Fedora/Arch USB) or installed system.
#  Usage:  sudo ./pc-doctor.sh          (full checks, interactive)
#          ./pc-doctor.sh               (limited, no root)
#  Tests: CPU, RAM load, temps, disks + SMART, battery,
#         keyboard, display, wifi, sound, webcam, USB, ports
# ============================================================
set -u
B="\e[1m"; G="\e[32m"; R="\e[31m"; Y="\e[33m"; C="\e[36m"; X="\e[0m"
PASS() { echo -e "  ${G}[PASS]${X} $1"; }
FAIL() { echo -e "  ${R}[FAIL]${X} $1"; }
WARN() { echo -e "  ${Y}[WARN]${X} $1"; }
INFO() { echo -e "  ${C}[INFO]${X} $1"; }
SKIP() { echo -e "  ${Y}[SKIP]${X} $1 (tool missing)"; }
hr()   { echo -e "\n${B}━━━ $1 ━━━${X}"; }

ROOT=drop
sudo -n true 2>/dev/null && ROOT=full

echo -e "${B}╔══════════════════════════════════════╗"
echo -e "║        🩺  PC-DOCTOR v1.0            ║"
echo -e "║   used-PC buyer's health check       ║"
echo -e "╚══════════════════════════════════════╝${X}"
[ "$ROOT" = drop ] && WARN "Running without root — some checks need 'sudo ./pc-doctor.sh'"

# ---------- 1. SYSTEM IDENTITY ----------
hr "1 · System identity"
echo -e "  Host : $(hostname)"
echo -e "  Distro: $(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-unknown}")"
echo -e "  Kernel: $(uname -r)"
echo -e "  CPU  : $(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs)"
echo -e "  GPU  : $(lspci 2>/dev/null | grep -iE 'vga|3d' | cut -d: -f3- | xargs)"
echo -e "  Boot mode: $([ -d /sys/firmware/efi ] && echo UEFI || echo Legacy/BIOS)"
echo -e "  Battery cycles + health: see section 8"

# ---------- 2. CPU STRESS ----------
hr "2 · CPU stress test (~20s)"
CORES=$(nproc)
INFO "$CORES threads @ $(grep -m1 MHz /proc/cpuinfo | awk '{print $4}') MHz baseline"
BEFORE_TEMP=$(sensors 2>/dev/null | awk '/Package id 0|Tdie|Core 0/{print $NF; exit}' | tr -d '+°C')
echo -e "  Loading all cores for 20s — listen for fan scream, watch for throttling..."
( for i in $(seq "$CORES"); do
    timeout 20 sha256sum /dev/zero >/dev/null 2>&1 || \
    timeout 20 bash -c 'while :; do :; done' &
  done; wait ) >/dev/null 2>&1 &
STRESS_PID=$!
sleep 18
FREQ_NOW=$(grep -m1 MHz /proc/cpuinfo | awk '{print $4}')
AFTER_TEMP=$(sensors 2>/dev/null | awk '/Package id 0|Tdie|Core 0/{print $NF; exit}' | tr -d '+°C')
wait $STRESS_PID 2>/dev/null
echo -e "  Freq under load: ${FREQ_NOW:-?} MHz (baseline above)"
[ -n "$AFTER_TEMP" ] && [ -n "$BEFORE_TEMP" ] && \
  echo -e "  Temp: ${BEFORE_TEMP:-?}°C → ${AFTER_TEMP}°C under load"
INFO "Now LISTEN: fans should spin up smoothly, no coil whine, no clicks."
INFO "If the machine froze or rebooted → CPU/power delivery problem. WALK AWAY."
PASS "CPU survived 20s all-core load"

# ---------- 3. MEMORY ----------
hr "3 · RAM"
free -h | sed 's/^/  /'
MEM_TOTAL=$(free -m | awk '/Mem:/{print $2}')
if command -v memtester >/dev/null; then
  MB=$(( MEM_TOTAL / 4 ))
  INFO "memtester: ${MB}MB (~35s) — watch for 'FAILURE' lines"
  sudo -n memtester "${MB}M" 1 2>/dev/null | tail -4 || memtester "${MB}M" 1 2>&1 | tail -4
else
  SKIP "memtester"
  INFO "This is a quick check only. THE REAL RAM TEST IS MemTest86+ from USB (see README)."
  INFO "Quick pass = no red flags, but never buy on this alone."
fi

# ---------- 4. TEMPERATURES ----------
hr "4 · Temperatures (idle)"
if command -v sensors >/dev/null; then
  sensors | grep -E 'Package|Core|Tdie|Tctl|temp1|Composite|edge' | sed 's/^/  /'
  MAX=$(sensors 2>/dev/null | grep -oE '\+[0-9]+\.[0-9]+°C' | tr -d '+°C' | sort -rn | head -1)
  [ -n "$MAX" ] && { [ "${MAX%%.*}" -lt 60 ] && PASS "max sensor ${MAX}°C at idle" || WARN "something reads ${MAX}°C at idle — investigate"; }
else
  SKIP "lm-sensors"
fi

# ---------- 5. DISKS + SMART ----------
hr "5 · Disks (the most important check)"
lsblk -do NAME,SIZE,MODEL,ROTA,TYPE | grep -v zram | sed 's/^/  /'
for d in $(lsblk -dpno NAME,TYPE | awk '$2=="disk"{print $1}'); do
  [ "$d" = "/dev/zram0" ] && continue
  echo -e "\n  ${B}$d${X}"
  if ! command -v smartctl >/dev/null; then
    SKIP "smartctl"
    INFO "Debian/Ubuntu live USB:  sudo apt install -y smartmontools"
    INFO "Fedora:  sudo dnf install -y smartmontools"
    continue
  fi
  sudo -n smartctl -H "$d" >/dev/null 2>&1 || { sudo -n smartctl -d sat -H "$d" >/dev/null 2>&1 || { WARN "SMART unreadable on $d"; continue; }; }
  OVERALL=$(sudo -n smartctl -H "$d" 2>/dev/null | grep -iE 'result|PASSED|FAILED' | head -1 | sed 's/^[[:space:]]*//')
  echo "$OVERALL" | grep -qi PASSED && PASS "$OVERALL" || FAIL "$OVERALL"
  if sudo -n smartctl -A "$d" >/dev/null 2>&1; then
    ATTRS=$(sudo -n smartctl -A "$d" 2>/dev/null)
    echo "$ATTRS" | grep -E 'Reallocated_Sector|Reallocated_Block' | sed 's/^/    /'
    echo "$ATTRS" | grep -E 'Pending_Sector|Current_Pending' | sed 's/^/    /'
    echo "$ATTRS" | grep -E 'Media_Wearout_Indicator|SSD_Life_Left|Percentage Used|Percentage Used' | sed 's/^/    /'
    RB=$(echo "$ATTRS" | grep -oE 'Reallocated_Sector_Ct[^0-9]*([0-9]+)' | grep -oE '[0-9]+$')
    PB=$(echo "$ATTRS" | grep -oE 'Current_Pending_Sector[^0-9]*([0-9]+)' | grep -oE '[0-9]+$')
    PU=$(echo "$ATTRS" | grep -oE 'Percentage Used[^0-9]*([0-9]+)' | grep -oE '[0-9]+$' | head -1)
    [ -n "$RB" ] && [ "$RB" -gt 0 ]  && FAIL "$RB reallocated sectors — drive is dying" || true
    [ -n "$PB" ] && [ "$PB" -gt 0 ]  && FAIL "$PB pending sectors — data loss risk"    || true
    [ -n "$PU" ] && [ "$PU" -gt 50 ] && WARN "SSD ${PU}% life used"                    || true
  fi
  echo -e "  Power-on hours + cycles:"
  sudo -n smartctl -A "$d" 2>/dev/null | grep -E 'Power_On_Hours|Power_Cycles|Power-On Hours|Power Cycles' | sed 's/^/    /'
done
INFO "Zero reallocated/pending sectors = healthy drive. ANY red = negotiate hard or walk."

# ---------- 6. KEYBOARD ----------
hr "6 · Keyboard (interactive)"
INFO "Opening a live key reader. Type EVERY key: letters, numbers, F-keys, arrows, Esc, Tab, Ctrl, Shift, Alt, Fn combos, space, enter."
INFO "Missing keys usually CAN'T be fixed cheaply — test them all now."
if command -v evtest >/dev/null && [ "$ROOT" = full ]; then
  KBD=$(evtest 2>/dev/null | grep -iE 'AT Translated|keyboard' | grep -oE '/dev/input/event[0-9]+' | head -1)
  if [ -n "$KBD" ]; then
    INFO "Reading: $KBD — press Ctrl+C to finish"
    echo -e "  ${B}── type now ──${X}"
    timeout 90 evtest "$KBD" 2>/dev/null | grep -E 'KEY_[A-Z0-9]+.*value 1' | \
      awk '{print "    pressed:", $3}' | uniq | head -60
    PASS "done — did every key register above? If a key shows nothing = dead key."
  else
    SKIP "no keyboard event device found"
  fi
else
  SKIP "evtest"
  INFO "Debian/Ubuntu live USB:  sudo apt install -y evtest   then re-run with sudo"
  INFO "Fallback: open a text editor and mash every key."
fi

# ---------- 7. DISPLAY ----------
hr "7 · Display (interactive)"
RES=$(xrandr 2>/dev/null | grep -E '\* \+' | awk '{print $1}' | head -1)
[ -z "$RES" ] && RES=$(kscreen-doctor -o 2>/dev/null | grep -oE '[0-9]+x[0-9]+' | head -1)
[ -n "$RES" ] && INFO "current resolution: $RES" || INFO "resolution: (graphical tool unavailable)"
INFO "DEAD PIXEL TEST: the screen goes SOLID COLOR for 6s each."
INFO "Look for: black dots (dead), colored dots (stuck), lines, backlight bleed."
echo -e "  ${B}starting color sweep… step back and look${X}"
if [ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]; then
  for c in "#FF0000" "#00FF00" "#0000FF" "#FFFFFF" "#000000"; do
    if command -v xdotool >/dev/null 2>&1 && [ -n "$DISPLAY" ]; then
      xdotool key --clearmodifiers F11 2>/dev/null
    fi
    if command -v feh >/dev/null; then
      convert -size 800x800 xc:"$c" /tmp/pd.png 2>/dev/null && feh -F /tmp/pd.png 2>/dev/null &
    fi
    sleep 1.2
  done
  sleep 5; pkill feh 2>/dev/null
  WARN "feh preview was brief — for a REAL test boot the flash-drive live session and run the sweep fullscreen, or visit a dead-pixel test site on the spot."
else
  INFO "No graphical session here — run the color sweep from the live USB desktop."
fi
INFO "Also: wiggle the hinge while watching the screen — flicker = dying cable."

# ---------- 8. BATTERY ----------
hr "8 · Battery health (laptops)"
BAT=""
for b in /sys/class/power_supply/BAT*; do
  [ -e "$b/capacity" ] || continue
  BAT="$b"
  CAP=$(cat "$b/capacity")
  FULL=$(cat "$b/charge_full" "$b/energy_full" 2>/dev/null | head -1)
  DES=$(cat "$b/charge_full_design" "$b/energy_full_design" 2>/dev/null | head -1)
  CYC=$(cat "$b/cycle_count" 2>/dev/null)
  echo -e "  Charge now : ${CAP}%"
  echo -e "  Cycle count: ${CYC:-unknown}"
  if [ -n "$FULL" ] && [ -n "$DES" ] && [ "$DES" -gt 0 ]; then
    H=$(echo "100 * $FULL / $DES" | bc 2>/dev/null)
    echo -e "  Design vs full capacity: ${DES} → ${FULL}"
    if [ -n "$H" ]; then
      if   [ "$H" -ge 80 ]; then PASS "battery holds ${H}% of design capacity"
      elif [ "$H" -ge 60 ]; then WARN "battery at ${H}% — usable, budget for replacement"
      else FAIL "battery at ${H}% — needs replacement soon"; fi
    fi
  else
    INFO "capacity data unavailable via sysfs"
  fi
done
if [ -z "$BAT" ]; then
  if command -v upower >/dev/null; then
    UP=$(upower -e 2>/dev/null | grep -m1 BAT)
    if [ -n "$UP" ]; then
      upower -i "$UP" | grep -E 'capacity|cycles|energy-full|state' | sed 's/^/  /'
    else INFO "no battery detected (desktop? or removed)"; fi
  else SKIP "upower"; fi
fi
INFO "Real-world test: unplug and watch drain — a worn battery drops fast."

# ---------- 9. WIFI / BT ----------
hr "9 · Wireless"
if command -v nmcli >/dev/null; then
  nmcli device status 2>/dev/null | sed 's/^/  /'
  WIFI=$(nmcli -t -f DEVICE,TYPE device 2>/dev/null | grep wifi | cut -d: -f1 | head -1)
  if [ -n "$WIFI" ]; then
    INFO "scanning with $WIFI…"
    nmcli device wifi list --rescan yes 2>/dev/null | head -6 | sed 's/^/  /'
    PASS "wifi adapter scans networks"
  fi
else SKIP "nmcli"; fi
INFO "If this is a LIVE USB: wifi works here == wifi works on this machine. If no networks appear, walk."

# ---------- 10. SOUND ----------
hr "10 · Sound (interactive)"
INFO "A test tone will play. SPEAKERS should be audible; plug headphones into each jack too."
if command -v speaker-test >/dev/null; then
  speaker-test -t sine -f 440 -l 2 -p 1 2>/dev/null | grep -E 'Time per period' >/dev/null && PASS "tone played on default output" || FAIL "tone failed — check volume or drivers"
else
  SKIP "speaker-test (alsa-utils)"
  INFO "Debian/Ubuntu live USB:  sudo apt install -y alsa-utils"
  INFO "Fallback: play any YouTube video."
fi

# ---------- 11. WEBCAM ----------
hr "11 · Webcam"
if command -v v4l2-ctl >/dev/null; then
  v4l2-ctl --list-devices 2>/dev/null | sed 's/^/  /'
  CAM=$(v4l2-ctl --list-devices 2>/dev/null | grep -B1 -m1 -iE 'camera|video' | grep -oE '/dev/video[0-9]+' | head -1)
  if [ -n "$CAM" ]; then
    FORM=$(v4l2-ctl -d "$CAM" -V 2>/dev/null | grep -E 'Format|Size' | head -2 | sed 's/^/  /')
    [ -n "$FORM" ] && PASS "webcam responds: $FORM"
  else INFO "no /dev/video device — missing webcam or driver"; fi
else
  SKIP "v4l-utils"
  ls /dev/video* 2>/dev/null | sed 's/^/  found: /' || INFO "no /dev/video* devices"
fi
INFO "Visual check: open any camera app and confirm the image is sharp, not cloudy."

# ---------- 12. USB PORTS ----------
hr "12 · USB ports (interactive)"
lsusb 2>/dev/null | sed 's/^/  /' | head -8
INFO "Bring TWO known-good USB sticks. Plug into EVERY port (left, right, back)."
INFO "Each must mount instantly. A dead port = expensive motherboard repair."

# ---------- 13. PORTS & BOOT ----------
hr "13 · Other hardware"
HDMI=$(lspci 2>/dev/null | grep -icE 'vga|display')
[ "$HDMI" -gt 0 ] && INFO "display controllers: $HDMI (test HDMI/DP with the seller's cable)"
lsmod 2>/dev/null | grep -cE '^snd' >/dev/null && INFO "audio modules loaded: $(lsmod | grep -c '^snd')"
[ -d /sys/class/bluetooth ] && INFO "bluetooth: present ($(ls /sys/class/bluetooth | head -1))" || INFO "bluetooth: not exposed"
INFO "FINAL 3-STEP: (1) reboot into BIOS — check total power-on hours there too,
        (2) watch it cold-boot from OFF — slow/failed boots are a red flag,
        (3) run MemTest86+ from this flash drive for 2+ passes."

echo -e "\n${G}${B}✅ PC-DOCTOR sweep complete.${X}"
echo -e "Judge with this rule: RAM & disk must be PERFECT; everything else is negotiable."
echo -e "Boot-level RAM test: run 'memtest86plus' ISO from the same flash drive (see README next to this script)."
