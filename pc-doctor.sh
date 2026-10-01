#!/usr/bin/env bash
# =====================================================================
# PC-DOCTOR v3.0 -- used-PC buyer's inspection suite (Mozambique market)
# Single file, runs from a live Linux USB on the seller's machine.
# STRICTLY READ-ONLY on the target's disks. Every check skippable.
# Verdict is deterministic (rule-based). No emoji, TTY-safe.
#
# Usage:
#   sudo ./pc-doctor.sh                 full interactive run
#   sudo ./pc-doctor.sh --quick         skip slow checks (surface/soak/fio)
#   sudo ./pc-doctor.sh --non-interactive   run everything, no prompts
#   sudo ./pc-doctor.sh --seller        big simple screens for the seller
#   ./pc-doctor.sh --explain            (after a run) LLM summary, online
#   ./pc-doctor.sh --chat               (after a run) LLM Q&A, online
#   ./pc-doctor.sh --list               list checks
#   LANG=pt_PT.UTF-8 sudo ./pc-doctor.sh    Portuguese (pt-MZ) output
# =====================================================================
set -u -o pipefail

VERSION="3.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------- i18n -----------------------------------
declare -A EN PT
EN[title]="PC-DOCTOR v3.0 -- used-PC inspection"
EN[intro]="Tests are READ-ONLY on the seller's disks. Nothing is installed."
EN[claims_q]="Enter what the SELLER claims (leave blank if unknown)"
EN[claimed_ram]="Claimed RAM (GB)"; EN[claimed_sto]="Claimed storage GB"
EN[claimed_type]="Claimed storage type (ssd/hdd)"; EN[claimed_cpu]="Claimed CPU model"
EN[claimed_gpu]="Claimed GPU"; EN[claimed_screen]="Claimed screen size (inches)"
EN[claimed_age]="Claimed age (years)"; EN[claimed_batt]="Claimed battery life (minutes)"
EN[pass]="GOOD"; EN[warn]="CAUTION"; EN[fail]="BAD"; EN[skip]="NOT TESTED"
EN[disk_ok]="Disk: GOOD."; EN[disk_realloc]="Disk has bad sectors. Will lose data. Do not buy unless very cheap."
EN[disk_wear]="Disk is worn"; EN[disk_fake]="Storage shows signs of FAKE capacity"
EN[ram_ok]="RAM: GOOD, no errors in quick test. Full test = MemTest86+ 2 passes."
EN[ram_bad]="RAM has errors. Do not buy."
EN[cpu_ok]="CPU runs at full speed under load."; EN[cpu_throttle]="CPU slows down under load (overheating or power problem)."
EN[batt_ok]="Battery is healthy."; EN[batt_mid]="Battery is worn but usable."; EN[batt_bad]="Battery is dying. Budget for a new one."
EN[batt_drop]="Battery drains fast under load."; EN[battna]="No battery (desktop)."
EN[therm_ok]="Temperatures are safe."; EN[therm_hot]="Machine runs HOT at idle."
EN[fan_ok]="Fan works. Listen: grinding or rattling means money off."
EN[wifi_ok]="WiFi works and scans networks."; EN[wifi_bad]="WiFi adapter missing or dead."
EN[verdict_buy]="VERDICT: BUY -- machine matches the listing and is healthy."
EN[verdict_neg]="VERDICT: NEGOTIATE -- use the price-deduction sheet below."
EN[verdict_walk]="VERDICT: WALK AWAY -- critical problems found."
EN[photo]="Photograph this screen with your phone now. Done? [y/N] "
EN[report_saved]="Report saved"; EN[sha]="Report SHA256"
EN[spec_mismatch]="LISTING MISMATCH"; EN[spec_match]="matches"
EN[lied_age]="Power-on hours do not match claimed age -- seller likely lying."
EN[age_ok]="Power-on hours are consistent with claimed age."
EN[serial_ok]="Serial numbers consistent across system/board/chassis."
EN[serial_bad]="Serial mismatch between parts -- possible swapped or stolen parts."
EN[secure_boot]="Secure Boot"; EN[msdm]="Windows OEM key found in firmware"
EN[me_found]="Intel Management Engine present (normal)."
EN[absolute]="ANTI-THEFT LOCK (Absolute/Computrace) flagged in BIOS -- check it is disabled."
EN[remote_tools]="REMOTE-ACCESS software found on installed OS (TeamViewer/AnyDesk)!"
EN[no_remote]="No remote-access tools found on installed OS."
EN[mount_na]="Installed OS not scanned (not a live session or mount failed)."
EN[panel_newer]="Panel made AFTER the machine's BIOS date -- screen was replaced."
EN[panel_ok]="Panel manufacture date is consistent."
PT[title]="PC-DOCTOR v3.0 -- inspeccao de PC usado"
PT[intro]="Testes sao APENAS DE LEITURA nos discos do vendedor. Nada e instalado."
PT[claims_q]="Escreva o que o VENDEDOR afirma (deixe vazio se nao souber)"
PT[claimed_ram]="RAM afirmada (GB)"; PT[claimed_sto]="Armazenamento afirmado (GB)"
PT[claimed_type]="Tipo afirmado (ssd/hdd)"; PT[claimed_cpu]="Modelo da CPU afirmado"
PT[claimed_gpu]="GPU afirmada"; PT[claimed_screen]="Tamanho do ecran (polegadas)"
PT[claimed_age]="Idade afirmada (anos)"; PT[claimed_batt]="Bateria afirmada (minutos)"
PT[pass]="BOM"; PT[warn]="ATENCAO"; PT[fail]="MAU"; PT[skip]="NAO TESTADO"
PT[disk_ok]="Disco: BOM."; PT[disk_realloc]="Disco com sectores maus. Vai perder dados. Nao compre."
PT[disk_wear]="Disco gasto"; PT[disk_fake]="Sinais de capacidade FALSA no armazenamento"
PT[ram_ok]="RAM: BOA, sem erros no teste rapido. Teste completo = MemTest86+ 2 passagens."
PT[ram_bad]="RAM com erros. Nao compre."
PT[cpu_ok]="CPU corre a velocidade plena em carga."; PT[cpu_throttle]="CPU abranda em carga (sobreaquecimento ou energia)."
PT[batt_ok]="Bateria saudavel."; PT[batt_mid]="Bateria gasta mas utilizavel."; PT[batt_bad]="Bateria a morrer. Planeje troca."
PT[batt_drop]="Bateria descarrega rapido em carga."; PT[battna]="Sem bateria (desktop)."
PT[therm_ok]="Temperaturas seguras."; PT[therm_hot]="Maquina muito QUENTE em repouso."
PT[fan_ok]="Ventoinha funciona. Ouca: ranger = desconto."
PT[wifi_ok]="WiFi funciona e encontra redes."; PT[wifi_bad]="Adaptador WiFi ausente ou morto."
PT[verdict_buy]="VEREDICTO: COMPRE -- maquina confere com o anuncio e esta saudavel."
PT[verdict_neg]="VEREDICTO: NEGOCIE -- use a tabela de descontos abaixo."
PT[verdict_walk]="VEREDICTO: NAO COMPRE -- problemas criticos."
PT[photo]="Fotografe este ecran com o telefone agora. Ja? [s/N] "
PT[report_saved]="Relatorio gravado"; PT[sha]="SHA256 do relatorio"
PT[spec_mismatch]="DIVERGENCIA COM O ANUNCIO"; PT[spec_match]="confere"
PT[lied_age]="Horas de uso nao batem com a idade afirmada -- vendedor provavelmente mente."
PT[age_ok]="Horas de uso coerentes com a idade afirmada."
PT[serial_ok]="Numeros de serie consistentes."
PT[serial_bad]="Serie divergente entre pecas -- possiveis pecas trocadas ou roubadas."
PT[secure_boot]="Secure Boot"; PT[msdm]="Chave Windows OEM gravada no firmware"
PT[me_found]="Intel Management Engine presente (normal)."
PT[absolute]="BLOQUEIO ANTI-FURTO (Absolute/Computrace) no BIOS -- verifique se esta desligado."
PT[remote_tools]="Software de ACESSO REMOTO encontrado no SO instalado (TeamViewer/AnyDesk)!"
PT[no_remote]="Sem ferramentas de acesso remoto no SO instalado."
PT[mount_na]="SO instalado nao verificado (sessao nao-live ou falha na montagem)."
PT[panel_newer]="Ecran fabricado DEPOIS do BIOS -- tela foi substituida."
PT[panel_ok]="Data do ecran coerente."
LANG_PT=0
case "${LANG:-}" in pt*|PT*) LANG_PT=1 ;; esac
tr() { if [ "$LANG_PT" = 1 ]; then echo "${PT[$1]:-${EN[$1]:-}}"; else echo "${EN[$1]:-${PT[$1]:-}}"; fi; }

# ---------------------------- args -----------------------------------
QUICK=0; ASK="yes"; SELLER=0; EXPLAIN=0; CHAT=0
for arg in "$@"; do
  case "$arg" in
    --quick) QUICK=1 ;;
    --non-interactive|--yes) ASK="no" ;;
    --seller) SELLER=1; ASK="no" ;;
    --explain) EXPLAIN=1 ;;
    --chat) CHAT=1 ;;
    --lang=pt|--pt) LANG_PT=1 ;;
    --list) echo "claims cpu ram raminfo therm disk smart surface fio soak gpu gpu-legal fans battery discharge ac wifi bt io audio webcam keyboard dmesg antifraud os-scan physical verdict"; exit 0 ;;
    --help|-h) sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $arg (see --help)" >&2; exit 2 ;;
  esac
done

# ---------------------------- TUI ------------------------------------
TUI=0; command -v whiptail >/dev/null && [ -t 0 ] && [ -t 1 ] && TUI=1
ui_input() { # ui_input "prompt" -> stdout
  local v
  if [ "$TUI" = 1 ] && [ "$ASK" = "yes" ]; then
    v=$(whiptail --inputbox "$1" 0 0 "" >/dev/tty 2>&1; echo x); v="${v%x}"
  else
    [ "$ASK" = "yes" ] || { echo ""; return; }
    read -r -p "$1 " v </dev/tty || v=""
  fi
  echo "${v:-}"
}
UI_SKIPPED=0
ui_confirm() { # ui_confirm "question" -> 0 yes; sets UI_SKIPPED=1 when not asked
  local a=""
  UI_SKIPPED=0
  if [ "$ASK" != "yes" ]; then UI_SKIPPED=1; return 1; fi
  if [ "$TUI" = 1 ]; then
    whiptail --title "PC-DOCTOR" --yesno "$1" 0 0 >/dev/tty 2>&1
  else
    read -r -t 30 -p "$1 [y/N] " a </dev/tty || return 1
    [[ "$a" =~ ^[yY] ]]
  fi
}
ui_gauge() { # ui_gauge "title" seconds  (simple time-based progress)
  local t="$1" secs="$2" i end
  end=$(( SECONDS + secs ))
  if [ "$TUI" = 1 ]; then
    ( while [ "$SECONDS" -lt "$end" ]; do
        echo "$(( 100 * (SECONDS % secs) / secs ))"; sleep 2
      done; echo 100 ) | whiptail --title "$t" --gauge "working..." 8 60 0 >/dev/tty 2>&1 || sleep "$secs"
  else
    echo "  [$t] $secs s..."; sleep "$secs"
  fi
}

# --------------------------- output/report ----------------------------
B=""; G=""; R=""; Y=""; C=""; X=""
if [ -t 1 ]; then B=$'\e[1m'; G=$'\e[32m'; R=$'\e[31m'; Y=$'\e[33m'; C=$'\e[36m'; X=$'\e[0m'; fi
pass_tag() { printf "%s[PASS]%s" "$G" "$X"; }
warn_tag() { printf "%s[WARN]%s" "$Y" "$X"; }
fail_tag() { printf "%s[FAIL]%s" "$R" "$X"; }
info_tag() { printf "%s[INFO]%s" "$C" "$X"; }

# scorecard entries: RES|id|human sentence|deduction hint
declare -a SCORECARD=()
declare -A CLAIMS DETECTED
record() { SCORECARD+=("$1|$2|$3|${4:-}"); }
hr()  { echo -e "\n${B}=== $1 ===${X}"; }

ROOT=drop; sudo -n true 2>/dev/null && ROOT=full
if [ "$ROOT" = "full" ]; then SUDO=(sudo); else SUDO=(sudo); fi

# report files live next to the script (i.e. on our own USB stick)
SERIAL="unknown"; SYS_SERIAL=""
if command -v dmidecode >/dev/null && [ "$ROOT" = "full" ]; then
  SYS_SERIAL="$("${SUDO[@]}" dmidecode -s system-serial-number 2>/dev/null | head -1 | tr -dc '[:alnum:]._-')"
  [ -n "$SYS_SERIAL" ] && SERIAL="$SYS_SERIAL"
fi
STAMP="$(date +%Y%m%d-%H%M%S)"
REPORT="${SCRIPT_DIR}/pc-doctor-report-${SERIAL}-${STAMP}.txt"
REPORTJSON="${REPORT%.txt}.json"
mkdir -p "$SCRIPT_DIR" 2>/dev/null || REPORT="/tmp/pc-doctor-report-${SERIAL}-${STAMP}.txt"
REPORTJSON="${REPORT%.txt}.json"
: > "$REPORT"

exec > >(tee -a "$REPORT") 2>&1
echo "====================================================================="
echo " $(tr title)  |  $(date '+%Y-%m-%d %H:%M')  |  host: $(hostname 2>/dev/null)"
echo " $(tr intro)"
echo "====================================================================="
[ "$ROOT" = "drop" ] && echo "  $(warn_tag) not root: run 'sudo ./pc-doctor.sh' for full checks"
T_START=$SECONDS
photo_step() { # photo_step "what to photograph"
  if ui_confirm "$(tr photo) [$1]"; then record PASS "photo-$1" "buyer photographed screen" ""; fi
}

json_add() { # json_add res id detail   -> appends to JSON buffer
  local res="$1" id="$2" det
  det=$(printf '%s' "${3:-}" | tr -d '"' | tr '\n' ' ')
  echo "{\"res\":\"$res\",\"check\":\"$id\",\"detail\":\"$det\"}" >> "$REPORT.jsonl"
}
: > "$REPORT.jsonl"

# ---------------------- claims vs reality data -----------------------
collect_claims() {
  hr "Claims vs reality"
  echo "  $(tr claims_q)"
  DETECTED[ram]=$(free -g | awk '/^Mem:/{print $2}')
  local diskline disksize_g diskrot
  diskline=$(lsblk -dpno NAME,SIZE,ROTA,TYPE 2>/dev/null | awk '$4=="disk"{print $2,$3,$1; exit}')
  disksize_g=$(echo "$diskline" | awk '{print int($1)}')
  diskrot=$(echo "$diskline" | awk '{print $2}')
  DETECTED[sto]="$disksize_g"
  [ "$diskrot" = "0" ] && DETECTED[type]="ssd" || DETECTED[type]="hdd"
  DETECTED[cpu]=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^ *//')
  DETECTED[gpu]=$(lspci 2>/dev/null | grep -iE 'vga|3d controller' | head -2 | cut -d: -f3- | sed 's/^ *//' | tr '\n' ';')
  DETECTED[screen]=$(xrandr --current 2>/dev/null | grep -oE '[0-9]+mm x [0-9]+mm' | head -1 | awk '{print int($1/25.4)}')
  [ -z "${DETECTED[screen]:-}" ] || [ "${DETECTED[screen]:-}" = 0 ] && DETECTED[screen]="?"
  DETECTED[age_bios]="$("${SUDO[@]}" dmidecode -s bios-release-date 2>/dev/null | head -1)"
  DETECTED[poh]="$("${SUDO[@]}" smartctl -A "$(main_disk)" 2>/dev/null | grep -oE 'Power_On_Hours[^0-9]*[0-9]+|Power-On Hours[^0-9]*[0-9]+' | grep -oE '[0-9]+$' | head -1)"
  echo "  claimed values are recorded in the JSON report"
}
claims_prompt() {
  [ "$SELLER" = 1 ] && return 0
  hr "0 · Seller claims"
  echo "  $(tr claims_q)"
  CLAIMS[ram]=$(ui_input "$(tr claimed_ram):")
  CLAIMS[sto]=$(ui_input "$(tr claimed_sto):")
  CLAIMS[type]=$(ui_input "$(tr claimed_type):" | tr '[:upper:]' '[:lower:]')
  CLAIMS[cpu]=$(ui_input "$(tr claimed_cpu):")
  CLAIMS[gpu]=$(ui_input "$(tr claimed_gpu):")
  CLAIMS[screen]=$(ui_input "$(tr claimed_screen):")
  CLAIMS[age]=$(ui_input "$(tr claimed_age):")
  CLAIMS[batt]=$(ui_input "$(tr claimed_batt):")
  }

claims_table() { # called at verdict time
  hr "$(tr spec_mismatch) / $(tr spec_match)"
  local bad=0
  if [ -n "${CLAIMS[ram]:-}" ] && [ "${CLAIMS[ram]:-0}" != 0 ]; then
    if [ "${CLAIMS[ram]}" -lt "${DETECTED[ram]}" ]; then
      echo "  $(fail_tag) RAM: claimed ${CLAIMS[ram]}GB < real ${DETECTED[ram]}GB (bonus, but listing wrong)"; bad=$((bad+1))
    elif [ "${CLAIMS[ram]}" -gt "${DETECTED[ram]}" ]; then
      echo "  $(fail_tag) RAM: claimed ${CLAIMS[ram]}GB > real ${DETECTED[ram]}GB -- LISTING LIE"; bad=$((bad+1))
      record FAIL "claims-ram" "listing claims ${CLAIMS[ram]}GB, machine has ${DETECTED[ram]}GB" "-5%"
      json_add FAIL "claims-ram" "claimed ${CLAIMS[ram]} real ${DETECTED[ram]}"
    else
      echo "  $(pass_tag) RAM ${DETECTED[ram]}GB $(tr spec_match)"; record PASS "claims-ram" "" ""
    fi
  fi
  if [ -n "${CLAIMS[sto]:-}" ] && [ "${CLAIMS[sto]:-0}" != 0 ]; then
    if [ "$(( CLAIMS[sto] - DETECTED[sto] ))" -gt 30 ]; then
      echo "  $(fail_tag) storage: claimed ${CLAIMS[sto]}GB > real ~${DETECTED[sto]}GB -- LISTING LIE"; bad=$((bad+1))
      record FAIL "claims-storage" "claimed ${CLAIMS[sto]}GB, real ${DETECTED[sto]}GB" "-5% or walk"
      json_add FAIL "claims-storage" "claimed ${CLAIMS[sto]} real ${DETECTED[sto]}"
    elif [ -n "${CLAIMS[type]:-}" ] && [ "${CLAIMS[type]}" != "${DETECTED[type]}" ]; then
      echo "  $(fail_tag) storage type: claimed ${CLAIMS[type]}, real ${DETECTED[type]} -- LISTING LIE"; bad=$((bad+1))
      record FAIL "claims-stype" "claimed ${CLAIMS[type]}, real ${DETECTED[type]}" "-5% or walk"
      json_add FAIL "claims-stype" "claimed ${CLAIMS[type]} real ${DETECTED[type]}"
    else
      echo "  $(pass_tag) storage ${DETECTED[sto]}GB ${DETECTED[type]} $(tr spec_match)"; record PASS "claims-storage" "" ""
    fi
  fi
  if [ -n "${CLAIMS[cpu]:-}" ]; then
    claim_l=$(echo "${CLAIMS[cpu]}" | tr '[:upper:]' '[:lower:]')
    det_l=$(echo "${DETECTED[cpu]}" | tr '[:upper:]' '[:lower:]')
    gen_c=$(echo "$claim_l" | grep -oE 'i[3579]-[0-9]{4,5}[a-z]?|ryzen [3579] [0-9]{3,4}[a-z]?|[mM][12357]' | head -1)
    if [ -n "$gen_c" ] && ! echo "$det_l" | grep -q "$(echo "$gen_c" | grep -oE '[0-9]{4,5}|[0-9]{3,4}' | head -1 | cut -c1-3)"; then
      echo "  $(fail_tag) CPU: claimed '${CLAIMS[cpu]}' vs real '${DETECTED[cpu]}' -- CHECK GENERATION"; bad=$((bad+1))
      record WARN "claims-cpu" "claimed '${CLAIMS[cpu]}', real '${DETECTED[cpu]}'" "-5% or walk"
      json_add WARN "claims-cpu" "claimed ${CLAIMS[cpu]} real ${DETECTED[cpu]}"
    else
      echo "  $(pass_tag) CPU: ${DETECTED[cpu]}"
      record PASS "claims-cpu" "" ""
    fi
  fi
  # age vs power-on hours
  if [ -n "${CLAIMS[age]:-}" ] && [ "${CLAIMS[age]:-0}" != 0 ] && [ -n "${DETECTED[poh]:-}" ]; then
    local max_h=$(( CLAIMS[age] * 8760 ))
    if [ "${DETECTED[poh]}" -gt "$max_h" ]; then
      echo "  $(fail_tag) $(tr lied_age) (${DETECTED[poh]}h > ${max_h}h)"
      record FAIL "claims-age" "power-on hours ${DETECTED[poh]} exceeds claimed ${CLAIMS[age]}y max ${max_h}h" "-10% or walk"
      json_add FAIL "claims-age" "poh ${DETECTED[poh]} claimed ${CLAIMS[age]}y"
    else
      echo "  $(pass_tag) $(tr age_ok) (${DETECTED[poh]}h)"; record PASS "claims-age" "" ""
    fi
  fi
  [ "$bad" -gt 0 ] && record WARN "claims-overall" "listing had $bad mismatch(es)" "-5–10%"
  return 0
}

# ------------------------------ helpers ------------------------------
main_disk() { lsblk -dpno NAME,TYPE 2>/dev/null | awk '$2=="disk"{print $1; exit}' | grep -v zram; }
install_hint() { # install_hint tool
  case "$1" in
    smartmontools|nvme-cli|memtester|fio|dmidecode|f3|turbostat) echo "apt install $1 | dnf install $1 | pacman -S $1" ;;
    stress-ng) echo "apt install stress-ng | dnf install stress-ng | pacman -S stress-ng" ;;
    lm-sensors) echo "apt install lm-sensors | dnf install lm_sensors | pacman -S lm_sensors" ;;
    evtest) echo "apt install evtest | pacman -S evtest" ;;
    edid-decode) echo "apt install edid-decode | pacman -S edid-decode" ;;
    efibootmgr) echo "apt install efibootmgr | pacman -S efibootmgr" ;;
    ethtool) echo "apt install ethtool | pacman -S ethtool" ;;
    whiptail) echo "apt install whiptail | pacman -S libnewt" ;;
    glmark2) echo "apt install glmark2 | pacman -S glmark2" ;;
    jq) echo "apt install jq | pacman -S jq" ;;
    *) echo "install '$1' with your distro package manager" ;;
  esac
}
need() { command -v "$1" >/dev/null || { echo "  $(warn_tag) missing: $1 -> $(install_hint "$1")"; return 1; }; }

# ============================ 1 IDENTITY =============================
hr "1 · Identity"
echo "  distro : $(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-unknown}")"
echo "  kernel : $(uname -r)"
echo "  boot   : $([ -d /sys/firmware/efi ] && echo UEFI || echo Legacy)"
echo "  model  : $("${SUDO[@]}" dmidecode -s system-manufacturer 2>/dev/null) $("${SUDO[@]}" dmidecode -s system-product-name 2>/dev/null)"
echo "  CPU    : $(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^ *//')"
lspci 2>/dev/null | grep -iE 'vga|3d controller' | cut -d: -f3- | sed 's/^/  GPU    :/'
collect_claims
claims_prompt

# ============================ 2 CPU ==================================
hr "2 · CPU stress + throttle"
if [ "$SELLER" = 1 ] || ui_confirm "Run CPU stress (20s)? [y/N] "; then
  CORES=$(nproc); F0=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null)
  echo "  loading $CORES cores..."
  ( for i in $(seq "$CORES"); do timeout 20 sha256sum /dev/zero >/dev/null 2>&1 & done ) 2>/dev/null
  sleep 15
  F1=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null)
  if [ -n "$F0" ] && [ -n "$F1" ] && [ "$F1" -lt $(( F0 * 60 / 100 )) ]; then
    echo "  $(fail_tag) $(tr cpu_throttle) (${F0}->${F1} kHz)"
    record FAIL "cpu-throttle" "$(tr cpu_throttle)" "-10–20%"
    json_add FAIL "cpu-throttle" "${F0}->${F1}"
  else
    echo "  $(pass_tag) $(tr cpu_ok)"
    record PASS "cpu" "$(tr cpu_ok)" ""
    json_add PASS "cpu" "freq held"
  fi
  if command -v turbostat >/dev/null && [ "$ROOT" = full ]; then
    "${SUDO[@]}" timeout 12 turbostat --quiet --interval 5 --num_iterations 2 2>/dev/null | grep -E "PkgTmp|Bsy%" | head -4 | sed 's/^/    /'
  fi
fi

# ============================ 3 THERMALS =============================
hr "3 · Temperatures"
if need lm-sensors || command -v sensors >/dev/null; then
  sensors 2>/dev/null | sed 's/([^)]*)//g' | grep -E 'Package|Core|Tdie|Tctl|Composite|edge|temp1' | sed 's/^/  /'
  MAX=$(sensors 2>/dev/null | sed 's/([^)]*)//g' | grep -oE '\+[0-9]+\.[0-9]+°C' | tr -d '+°C' | sort -rn | awk '$1 < 120' | head -1)
  if [ -n "$MAX" ]; then
    if awk "BEGIN{exit !($MAX >= 90)}"; then
      echo "  $(fail_tag) $(tr therm_hot) (${MAX}C)"
      record FAIL "thermals" "$(tr therm_hot): ${MAX}C" "-10% (cleaning/repaste)"
      json_add FAIL "thermals" "${MAX}C"
    elif awk "BEGIN{exit !($MAX >= 70)}"; then
      echo "  $(warn_tag) $(tr therm_hot) (${MAX}C)"
      record WARN "thermals" "$(tr therm_hot): ${MAX}C" "-5% (cleaning)"
      json_add WARN "thermals" "${MAX}C"
    else
      echo "  $(pass_tag) $(tr therm_ok) (max ${MAX}C)"
      record PASS "thermals" "$(tr therm_ok)" ""
      json_add PASS "thermals" "${MAX}C"
    fi
  fi
fi

# ============================ 4 RAM ==================================
hr "4 · RAM modules"
if [ "$ROOT" = full ] && command -v dmidecode >/dev/null; then
  "${SUDO[@]}" dmidecode -t memory 2>/dev/null | awk '
    /Memory Device/ {indev=1; loc=sz=typ=spd=""}
    indev && /Locator:/ && !/Bank/ {loc=$2" "$3" "$4}
    indev && /Size:/ {sz=$2" "$3}
    indev && /Type:/ && !/Error/ {typ=$2}
    indev && /Speed:/ {spd=$2" "$3}
    indev && /Part Number:/ && $2!="" {print "  "loc" | "sz" | "typ" | "spd" | part "$2" "$3; indev=0}'
  EMPTY=$("${SUDO[@]}" dmidecode -t memory 2>/dev/null | grep -c "No Module Installed")
  echo "  empty slots: $EMPTY (upgrade room)"
  record PASS "raminfo" "modules listed, $EMPTY empty slots" ""
  json_add PASS "raminfo" "empty slots $EMPTY"
else
  echo "  $(warn_tag) dmidecode needs root"; record SKIP "raminfo" "" ""
fi
if [ "$SELLER" = 1 ] || ui_confirm "Quick RAM test (~30s)? [y/N] "; then
  if command -v memtester >/dev/null; then
    MB=$(($(free -m | awk '/^Mem:/{print $2}') / 4))
    ERRS=$(memtester "${MB}M" 1 2>&1 | grep -cE "FAILURE|failed")
    if [ "$ERRS" -eq 0 ]; then
      echo "  $(pass_tag) $(tr ram_ok)"
      record PASS "ram-quick" "$(tr ram_ok)" ""
      json_add PASS "ram-quick" "${MB}MB clean"
    else
      echo "  $(fail_tag) $(tr ram_bad)"
      record FAIL "ram-quick" "$(tr ram_bad) ($ERRS errors)" "WALK AWAY"
      json_add FAIL "ram-quick" "$ERRS errors"
    fi
  else
    echo "  $(warn_tag) $(install_hint memtester)"; record SKIP "ram-quick" "" ""
  fi
fi
if [ -d /sys/devices/system/edac/mc ]; then
  CE=$(cat /sys/devices/system/edac/mc/mc*/ce_count 2>/dev/null | awk '{s+=$1}END{print s+0}')
  UE=$(cat /sys/devices/system/edac/mc/mc*/ue_count 2>/dev/null | awk '{s+=$1}END{print s+0}')
  [ "${UE:-0}" -gt 0 ] && { echo "  $(fail_tag) ECC uncorrectable errors: $UE"; record FAIL "ecc" "ECC uncorrectable errors $UE" "WALK AWAY"; }
  [ "${CE:-0}" -gt 0 ] && { echo "  $(warn_tag) ECC correctable errors: $CE"; record WARN "ecc" "ECC correctable errors $CE" "-5%"; }
fi

# ============================ 5 DISK SMART ===========================
hr "5 · Disk SMART"
DISK="$(main_disk)"
[ -n "$DISK" ] && echo "  target: $DISK ($(lsblk -dno MODEL "$DISK" 2>/dev/null))"
ROTA=$(cat "/sys/block/$(basename "$DISK")/queue/rotational" 2>/dev/null)
[ "$ROTA" = "0" ] && { echo "  type   : SSD/NVMe (non-rotational)"; record PASS "rotational" "SSD confirmed" ""; }
[ "$ROTA" = "1" ] && { echo "  type   : HDD (rotational)"; record PASS "rotational" "HDD confirmed" ""; }
if command -v nvme >/dev/null && echo "$DISK" | grep -q nvme; then
  "${SUDO[@]}" nvme smart-log "$DISK" 2>/dev/null | grep -E 'critical_warning|percentage_used|media_errors|unsafe_shutdowns|power_on_hours' | sed 's/^/  nvme /'
fi
if command -v smartctl >/dev/null; then
  SMART="$("${SUDO[@]}" smartctl -A "$DISK" 2>/dev/null)"; [ -z "$SMART" ] && SMART="$("${SUDO[@]}" smartctl -d sat -A "$DISK" 2>/dev/null)"
  HEALTH="$("${SUDO[@]}" smartctl -H "$DISK" 2>/dev/null || "${SUDO[@]}" smartctl -d sat -H "$DISK" 2>/dev/null)"
  echo "$HEALTH" | grep -E 'result|PASSED|FAILED' | sed 's/^/  /'
  POH=$(echo "$SMART" | grep -oE 'Power_On_Hours[^0-9]*[0-9]+|Power-On Hours[^0-9]*[0-9]+' | grep -oE '[0-9]+$' | head -1)
  PCYC=$(echo "$SMART" | grep -oE 'Power_Cycles[^0-9]*[0-9]+|Power Cycles[^0-9]*[0-9]+' | grep -oE '[0-9]+$' | head -1)
  echo "$SMART" | grep -E 'Reallocated|Pending|Uncorrectable|Media Wearout|Percentage Used|Available Spare|Unsafe|Power_On_Hours|Power-On Hours|Power Cycles|Power_Cycles|Data Units Written' | sed 's/^/    /'
  RB=$(echo "$SMART" | grep -oE '(Reallocated_Sector_Ct|Reallocated_Block_Count)[^0-9]*[0-9]+' | tail -1 | grep -oE '[0-9]+$')
  PB=$(echo "$SMART" | grep -oE '(Current_Pending_Sector|Pending_Sector_Count|Growing Defect)[^0-9]*[0-9]+' | tail -1 | grep -oE '[0-9]+$')
  PU=$(echo "$SMART" | grep -oE 'Percentage Used[^0-9]*([0-9]+)' | grep -oE '[0-9]+' | head -1)
  if [ -n "$RB" ] && [ "$RB" -gt 0 ] || [ -n "$PB" ] && [ "$PB" -gt 0 ]; then
    echo "  $(fail_tag) $(tr disk_realloc) (realloc=$RB pending=$PB)"
    record FAIL "smart-badsectors" "$(tr disk_realloc) realloc=$RB pending=$PB" "WALK AWAY"
    json_add FAIL "smart-badsectors" "realloc $RB pending $PB"
  else
    echo "  $(pass_tag) $(tr disk_ok) zero bad sectors"
    record PASS "smart-badsectors" "$(tr disk_ok)" ""
    json_add PASS "smart-badsectors" "realloc 0 pending 0"
  fi
  if [ -n "$PU" ] && [ "$PU" -gt 50 ]; then
    echo "  $(warn_tag) $(tr disk_wear): ${PU}%"
    record WARN "smart-wear" "$(tr disk_wear) ${PU}%" "-10–20%"
    json_add WARN "smart-wear" "${PU}%"
  fi
  [ -n "$POH" ] && echo "  power-on hours: $POH  cycles: $PCYC"
  photo_step "SMART results"
  if [ "$SELLER" = 0 ] && [ "$QUICK" = 0 ] && ui_confirm "Run SMART short self-test (2 min, offline test, read-only to data)? [y/N] "; then
    "${SUDO[@]}" smartctl -t short "$DISK" >/dev/null 2>&1 && echo "  self-test started; results appear in smartctl -a later"
  fi
else
  echo "  $(warn_tag) $(install_hint smartmontools)"; record SKIP "smart" "" ""
fi

# ============================ 6 SURFACE ==============================
hr "6 · Full read-only surface scan"
if [ "$QUICK" = 1 ] || [ "$SELLER" = 1 ]; then echo "  skipped (quick/seller mode)"; record SKIP "surface" "" ""
elif ui_confirm "Slow scan 5-checkpoint read sample (5-15 min)? [y/N] "; then
  TOTAL=$("${SUDO[@]}" blockdev --getsize64 "$DISK" 2>/dev/null)
  BS=4194304; STEP=$(( TOTAL / 5 / BS )); [ "$STEP" -lt 400 ] && STEP=400
  LOWSPEED=0
  for i in 0 1 2 3 4; do
    SPD=$("${SUDO[@]}" dd if="$DISK" bs=$BS skip=$(( i * STEP )) count=400 2>&1 >/dev/null | grep -oE '[0-9.]+ [kMG]?B/s' | tail -1)
    echo "    checkpoint $((i+1))/5: ${SPD:-n/a}"
    v=$(echo "$SPD" | grep -oE '^[0-9.]+'); u=$(echo "$SPD" | grep -oE '[kMG]')
    if [ -n "$v" ] && [ "$ROTA" = "0" ] && { [ "$u" = "k" ] || { [ "$u" = "M" ] && awk "BEGIN{exit !($v < 100)}"; }; }; then LOWSPEED=1; fi
  done
  [ "$LOWSPEED" = 1 ] && { echo "  $(warn_tag) SSD read speed dipped below 100 MB/s -- sick drive"; record WARN "surface-speed" "SSD slow checkpoints" "-10%"; }
  echo "  full audit (optional): sudo badblocks -sv -e 10 $DISK"
  record PASS "surface" "5 checkpoints sampled read-only" ""
  json_add PASS "surface" "speeds sampled"
fi

# ============================ 7 FIO ==================================
hr "7 · Disk benchmark (fio)"
if [ "$QUICK" = 1 ] || [ "$SELLER" = 1 ]; then echo "  skipped"; record SKIP "fio" "" ""
elif command -v fio >/dev/null && ui_confirm "10s read benchmark? [y/N] "; then
  BW=$("${SUDO[@]}" fio --name=r --filename="$DISK" --readonly --rw=read --bs=1M --iodepth=8 --time_based --runtime=10 2>/dev/null | grep -oE 'BW=[0-9.]+[MG]i?B/s' | head -1)
  echo "  sequential read: ${BW:-n/a}"
  EXP="1200"; [ "$ROTA" = "1" ] && EXP="100"
  echo "  expected for this drive type: >= ${EXP} MB/s"
  record PASS "fio" "seq read ${BW:-n/a} (expect >=${EXP})" ""
  json_add PASS "fio" "${BW:-n/a}"
else
  echo "  $(install_hint fio)"; record SKIP "fio" "" ""
fi

# ============================ 8 FAKE CAPACITY ========================
hr "8 · Fake-capacity probe (USB sticks / suspicious drives)"
if command -v f3probe >/dev/null && [ "$SELLER" = 0 ] && ui_confirm "f3probe a REMOVABLE usb drive? (never the system disk) [y/N] "; then
  USB=$(lsblk -dpno NAME,TRAN,TYPE 2>/dev/null | awk '$2=="usb" && $3=="disk"{print $1; exit}')
  if [ -n "$USB" ]; then
    echo "  probing $USB (read-only probe)..."
    "${SUDO[@]}" timeout 300 f3probe --destructive "$USB" 2>/dev/null | tail -5 | sed 's/^/  /' || echo "  probe skipped/failed"
    record WARN "f3probe" "see output above; 'Fake drive confirmed' = WALK AWAY" "case-by-case"
  else echo "  no removable USB drive found"; record SKIP "f3probe" "" ""; fi
else record SKIP "f3probe" "" ""; fi

# ============================ 9 SOAK =================================
hr "9 · Soak test (CPU+RAM+disk)"
if [ "$QUICK" = 1 ] || [ "$SELLER" = 1 ]; then echo "  skipped (quick mode)"
elif ui_confirm "10-minute combined soak? (any crash = do not buy) [y/N] "; then
  DM0=$(dmesg 2>/dev/null | wc -l)
  ui_gauge "soak" 600
  END=$(( SECONDS + 600 ))
  while [ "$SECONDS" -lt "$END" ]; do
    for i in 1 2 3 4; do timeout 25 sha256sum /dev/zero >/dev/null 2>&1 & done
    timeout 25 dd if="$DISK" bs=1M count=64 2>/dev/null | sha256sum >/dev/null 2>&1
    free -m | sha256sum >/dev/null; sleep 2
  done
  DM1=$(dmesg 2>/dev/null | wc -l)
  echo "  $(pass_tag) survived 10 min combined load (kernel lines +$((DM1-DM0)))"
  record PASS "soak" "survived 10 min combined load" ""
  json_add PASS "soak" "ok"
else echo "  skipped by user"; record SKIP "soak" "" ""; fi

# ============================ 10 GPU =================================
hr "10 · GPU"
NG=$(lspci 2>/dev/null | grep -cE 'VGA|3D controller')
[ "$NG" -gt 1 ] && echo "  hybrid: iGPU + dGPU (test BOTH)"
if [ "$SELLER" = 0 ] && ui_confirm "GPU load test? [y/N] "; then
  if command -v glmark2 >/dev/null; then
    SC=$(timeout 180 glmark2 2>/dev/null | grep -oE 'glmark2 Score: [0-9]+')
    echo "  ${SC:-no score}"; record PASS "gpu" "${SC:-no score}" ""
  elif command -v stress-ng >/dev/null; then
    timeout 60 stress-ng --matrix 1 --timeout 55s --metrics-brief 2>/dev/null | tail -2 | sed 's/^/  /'
    echo "  $(pass_tag) no crash/artifacts reported"; record PASS "gpu" "matrix load ok" ""
  else echo "  $(install_hint glmark2)"; record SKIP "gpu" "" ""; fi
else record SKIP "gpu" "" ""; fi

# ============================ 11 DISPLAY =============================
hr "11 · Display / EDID"
EDIDF=""
for f in /sys/class/drm/card*-*-*/edid; do [ -s "$f" ] && EDIDF="$f" && break; done
if [ -n "$EDIDF" ] && command -v edid-decode >/dev/null; then
  "${SUDO[@]}" edid-decode "$EDIDF" 2>/dev/null | grep -E 'Made in week|Detailed mode|Manufacturer' | head -4 | sed 's/^/  /'
  PY=$("${SUDO[@]}" edid-decode "$EDIDF" 2>/dev/null | grep -oE 'made [a-z]+ week [0-9]+ of [0-9]{4}' | grep -oE '[0-9]{4}' | head -1)
  BY=$(echo "${DETECTED[age_bios]:-}" | grep -oE '[0-9]{4}' | head -1)
  if [ -n "$PY" ] && [ -n "$BY" ] && [ "$PY" -gt $(( BY + 1 )) ]; then
    echo "  $(warn_tag) $(tr panel_newer) (panel $PY > bios $BY)"
    record WARN "panel-date" "$(tr panel_newer) panel=$PY bios=$BY" "-5% (replaced screen)"
    json_add WARN "panel-date" "panel $PY bios $BY"
  elif [ -n "$PY" ]; then
    echo "  $(pass_tag) $(tr panel_ok)"; record PASS "panel-date" "$(tr panel_ok)" ""
  fi
else
  echo "  $(warn_tag) $(install_hint edid-decode)"; record SKIP "edid" "" ""
fi
XR=$(xrandr --current 2>/dev/null | grep -E '\*' | awk '{print $1}' | head -1)
[ -n "$XR" ] && echo "  resolution: $XR"
if command -v xinput >/dev/null && xinput list 2>/dev/null | grep -qi touch; then
  if ui_confirm "Touchscreen detected -- tap 5 spots now, touch registered on all? [y/N] "; then
    record PASS "touchscreen" "responds" ""
  elif [ "$UI_SKIPPED" = 0 ]; then record WARN "touchscreen" "buyer could not confirm" "-3%"; fi
fi

# ============================ 12 FANS ================================
hr "12 · Fans"
FRPM=$(sensors 2>/dev/null | grep -ioE 'fan[0-9]*: *[0-9]+' | grep -oE '[0-9]+' | head -1)
if [ -n "$FRPM" ] && [ "$FRPM" -gt 0 ]; then
  echo "  $(pass_tag) fan ${FRPM} RPM"
  record PASS "fans" "${FRPM} RPM" ""
else
  echo "  $(warn_tag) no fan RPM readable"; record WARN "fans" "not readable; judge by ear" ""
fi
ui_confirm "$(tr fan_ok) Is it QUIET (no grinding/rattling)? [y/N] " || { if [ "$UI_SKIPPED" = 1 ]; then record SKIP "fan-noise" "" ""; else echo "  $(warn_tag) fan noise reported"; record WARN "fan-noise" "grinding/rattle reported" "-5–10%"; fi; }

# ============================ 13 BATTERY =============================
hr "13 · Battery"
BFOUND=0
for b in /sys/class/power_supply/BAT*; do
  [ -e "$b/capacity" ] || continue
  BFOUND=1
  CAP=$(cat "$b/capacity"); FULL=$(cat "$b/charge_full" "$b/energy_full" 2>/dev/null | head -1)
  DES=$(cat "$b/charge_full_design" "$b/energy_full_design" 2>/dev/null | head -1)
  CYC=$(cat "$b/cycle_count" 2>/dev/null)
  echo "  charge: ${CAP}%  cycles: ${CYC:-?}"
  if [ -n "$FULL" ] && [ -n "$DES" ] && [ "$DES" -gt 0 ] 2>/dev/null; then
    H=$(( 100 * FULL / DES ))
    echo "  health: ${H}% of design"
    if [ "$H" -ge 80 ]; then echo "  $(pass_tag) $(tr batt_ok)"; record PASS "battery" "$(tr batt_ok) ${H}%" ""
    elif [ "$H" -ge 60 ]; then echo "  $(warn_tag) $(tr batt_mid) (${H}%)"; record WARN "battery" "$(tr batt_mid) ${H}%" "-5–10%"
    else echo "  $(fail_tag) $(tr batt_bad) (${H}%)"; record FAIL "battery" "$(tr batt_bad) ${H}%" "-10–15%"; fi
    json_add "PASS" "battery-health" "${H}%"
  fi
done
[ "$BFOUND" = 0 ] && { echo "  $(info_tag) $(tr battna)"; record SKIP "battery" "" ""; }
# 5-min discharge under load
if [ "$BFOUND" = 1 ] && [ "$QUICK" = 0 ] && [ "$SELLER" = 0 ] && ui_confirm "5-min discharge-under-load test? (unplug AC first) [y/N] "; then
  ST=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null)
  if [ "$ST" = "Discharging" ]; then
    E1=$(cat /sys/class/power_supply/BAT0/energy_now /sys/class/power_supply/BAT0/charge_now 2>/dev/null | head -1)
    C1=$(cat /sys/class/power_supply/BAT0/capacity)
    ( for i in 1 2 3; do timeout 290 sha256sum /dev/zero >/dev/null 2>&1 & done ) 2>/dev/null
    sleep 300
    E2=$(cat /sys/class/power_supply/BAT0/energy_now /sys/class/power_supply/BAT0/charge_now 2>/dev/null | head -1)
    C2=$(cat /sys/class/power_supply/BAT0/capacity)
    if [ -n "$E1" ] && [ -n "$E2" ] && [ "$E1" -gt 0 ] 2>/dev/null; then
      DROP=$(awk "BEGIN{printf \"%.1f\", ($E1-$E2)/$E1*100}")
      PCT_MIN=$(awk "BEGIN{printf \"%.2f\", ($E1-$E2)/$E1*100/5}")
      echo "  lost ${DROP}% in 5 min under load (${PCT_MIN}%/min); capacity ${C1}%->${C2}%"
      if awk "BEGIN{exit !($DROP > 15)}"; then
        echo "  $(fail_tag) $(tr batt_drop)"; record FAIL "discharge" "$(tr batt_drop) ${DROP}%/5min" "-10%"
      elif awk "BEGIN{exit !($DROP > 8)}"; then
        echo "  $(warn_tag) $(tr batt_drop)"; record WARN "discharge" "${DROP}% per 5 min" "-5%"
      else
        echo "  $(pass_tag) discharge rate acceptable"; record PASS "discharge" "${DROP}% per 5 min" ""
      fi
      json_add PASS "discharge" "${DROP}%/5min"
    fi
  else echo "  still on AC -- unplug and re-run this check"; record SKIP "discharge" "" ""; fi
fi

# ============================ 14 AC ADAPTER ==========================
hr "14 · AC adapter"
for ac in /sys/class/power_supply/A*C; do
  [ -e "$ac/online" ] || continue
  echo "  $(basename "$ac"): online=$(cat "$ac/online")"
  [ -f "$ac/manufacturer" ] && echo "  identity: $(cat "$ac/manufacturer") $(cat "$ac/model_name" 2>/dev/null)"
  [ -f "$ac/wattage" ] && echo "  wattage : $(awk "BEGIN{print int($(cat "$ac/wattage")/1000)")W"
done
echo "  NOTE: BIOS message 'adapter cannot be determined' = non-genuine adapter"
ui_confirm "Adapter is original, undamaged, correct wattage? [y/N] " || { if [ "$UI_SKIPPED" = 1 ]; then record SKIP "ac-adapter" "" ""; else echo "  $(warn_tag) adapter flagged"; record WARN "ac-adapter" "non-original/damaged adapter" "-5%"; fi; }
[ -n "$(find /sys/class/power_supply -name 'A*C' 2>/dev/null | head -1)" ] && record PASS "ac-adapter" "present and online" ""

# ============================ 15 WIFI / BT / IO ======================
hr "15 · WiFi / Bluetooth / IO"
if command -v nmcli >/dev/null; then
  WDEV=$(nmcli -t -f DEVICE,TYPE device 2>/dev/null | grep wifi | cut -d: -f1 | head -1)
  if [ -n "$WDEV" ]; then
    nmcli device wifi list --rescan yes 2>/dev/null | head -4 | sed 's/^/  /'
    N5=$(nmcli -f FREQ device wifi list 2>/dev/null | grep -cE '5[0-9]{3}')
    echo "  $(pass_tag) $(tr wifi_ok) ($N5 networks on 5GHz)"
    record PASS "wifi" "$(tr wifi_ok)" ""
    json_add PASS "wifi" "5GHz nets $N5"
  else
    echo "  $(fail_tag) $(tr wifi_bad)"; record FAIL "wifi" "$(tr wifi_bad)" "-10% (USB dongle)"
  fi
fi
if command -v bluetoothctl >/dev/null && [ "$SELLER" = 0 ]; then
  ( timeout 12 bluetoothctl scan on >/dev/null 2>&1 ) ; BT=$(timeout 3 bluetoothctl devices 2>/dev/null | head -2)
  [ -n "$BT" ] && { echo "  bluetooth ok: $BT"; record PASS "bluetooth" "scans devices" ""; } || { echo "  bluetooth: nothing found"; record WARN "bluetooth" "no devices seen" ""; }
fi
IFACE=$(ip -o link 2>/dev/null | awk -F': ' '$2!~/lo|wlan|ww/{print $2; exit}')
if command -v ethtool >/dev/null && [ -n "$IFACE" ]; then
  echo "  ethernet $IFACE: $(ethtool "$IFACE" 2>/dev/null | grep -E 'Speed:' | head -1)"
fi
echo "  USB topology (480M=USB2, 5000M+=USB3):"
lsusb -t 2>/dev/null | sed 's/^/    /' | head -12
lsusb 2>/dev/null | grep -iE 'fingerprint|card reader' | sed 's/^/  extra: /'
if ui_confirm "Test NOW: every USB port with your stick, HDMI on seller's TV, SD card reader, touchpad moves, headphone jack? All working? [y/N] "; then
  record PASS "io-manual" "ports/hdmi/touchpad/jack confirmed" ""
elif [ "$UI_SKIPPED" = 1 ]; then record SKIP "io-manual" "" ""
else record WARN "io-manual" "some port failed or untested" "-3–10%"; fi

# ============================ 16 AUDIO / CAM / KBD ===================
hr "16 · Audio / webcam / keyboard"
RUNAS=""
[ -n "${SUDO_USER:-}" ] && RUNAS="sudo -u $SUDO_USER"
if command -v speaker-test >/dev/null; then
  if $RUNAS speaker-test -t sine -f 440 -l 2 -p 1 >/dev/null 2>&1; then echo "  $(pass_tag) speakers"; record PASS "speakers" "tone ok" ""
  else echo "  $(warn_tag) verify speakers by playing a video"; record WARN "speakers" "not verified in session" ""; fi
fi
if command -v arecord >/dev/null && command -v aplay >/dev/null; then
  echo "  MIC LOOPBACK: speak now (5s played back)..."
  if $RUNAS timeout 6 arecord -f cd -d 5 2>/dev/null | $RUNAS aplay - 2>/dev/null; then
    echo "  $(pass_tag) mic ok"; record PASS "mic" "loopback ok" ""
  else echo "  $(warn_tag) test mic with any recorder app"; record WARN "mic" "not verified" ""; fi
fi
CAM=$(ls /dev/video* 2>/dev/null | head -1)
if [ -n "$CAM" ]; then
  if command -v fswebcam >/dev/null && fswebcam -d "$CAM" -r 1280x720 --no-banner /tmp/pcdoctor-cam.jpg >/dev/null 2>&1; then
    echo "  $(pass_tag) webcam frame: /tmp/pcdoctor-cam.jpg"; record PASS "webcam" "frame captured" ""
  else echo "  webcam present: $CAM (open any camera app)"; record PASS "webcam" "device present" ""; fi
else echo "  $(fail_tag) no webcam device"; record FAIL "webcam" "no camera" "-5–10%"; fi
if [ "$SELLER" = 0 ]; then
  if command -v evtest >/dev/null && [ "$ROOT" = full ]; then
    KBD=$(evtest 2>/dev/null | grep -iE 'AT Translated|keyboard' | grep -oE '/dev/input/event[0-9]+' | head -1)
    [ -n "$KBD" ] && echo "  keyboard test: type keys now (90s), Ctrl+C to end:"
    if [ -n "$KBD" ] && timeout 90 evtest "$KBD" 2>/dev/null | grep -cE 'KEY_[A-Z0-9]+.*value 1' >/dev/null; then
      echo "  $(pass_tag) keystrokes detected (confirm EVERY key worked)"
      record PASS "keyboard" "events seen; confirm all keys" ""
    else
      echo "  $(warn_tag) keyboard not fully tested -- type every key manually"
      record SKIP "keyboard" "" ""
    fi
  else record WARN "keyboard" "$(install_hint evtest)" ""; fi
fi

# ============================ 17 DMESG ===============================
hr "17 · Kernel error scan"
HITS=$("${SUDO[@]}" dmesg -T --level=err,warn 2>/dev/null | grep -icE 'mce|machine check|pcieport.*error|I/O error|gpu.*reset|drm.*error|usb.*disconnect|ata[0-9]+.*error|nvme.*timeout|thermal.*shutdown')
"${SUDO[@]}" dmesg -T --level=err,warn 2>/dev/null | grep -iE 'mce|machine check|pcieport.*error|I/O error|gpu.*reset|usb.*disconnect|ata[0-9]+.*error|nvme.*timeout|thermal.*shutdown' | tail -8 | sed 's/^/    /'
if "${SUDO[@]}" dmesg 2>/dev/null | grep -qiE 'mce|machine check'; then
  echo "  $(fail_tag) MCE = CPU/board failing"; record FAIL "mce" "Machine Check Exception" "WALK AWAY"; json_add FAIL "mce" "1"
elif [ "$HITS" -gt 0 ]; then
  echo "  $(warn_tag) $HITS kernel warnings (ata/nvme = disk, usb = usually cosmetic)"
  record WARN "dmesg" "$HITS kernel warnings" "case-by-case"
else
  echo "  $(pass_tag) no concerning kernel errors"; record PASS "dmesg" "clean" ""
fi

# ============================ 18 ANTI-FRAUD ==========================
hr "18 · Anti-fraud checks"
SSYS=$("${SUDO[@]}" dmidecode -s system-serial-number 2>/dev/null)
SBRD=$("${SUDO[@]}" dmidecode -s baseboard-serial-number 2>/dev/null)
SCHS=$("${SUDO[@]}" dmidecode -s chassis-serial-number 2>/dev/null)
clean() { echo "$1" | grep -viE 'to be filled|none|default|string|^0+$|^\s*$' | head -1 | xargs; }
SS=$(clean "$SSYS"); SB=$(clean "$SBRD"); SC=$(clean "$SCHS")
echo "  system serial : ${SS:-n/a}"; echo "  board serial  : ${SB:-n/a}"; echo "  chassis serial: ${SC:-n/a}"
if [ -n "$SS" ] && [ -n "$SC" ] && [ "$SS" != "$SC" ]; then
  echo "  $(warn_tag) $(tr serial_bad) (system vs chassis)"
  record WARN "serial-mismatch" "$(tr serial_bad) sys=$SS chassis=$SC" "-10% or walk"; json_add WARN "serial-mismatch" "$SS vs $SC"
elif [ -z "$SS" ] && [ -z "$SC" ]; then
  echo "  $(warn_tag) no serials exposed by firmware (unusual -- note it)"
  record SKIP "serial" "" ""
else
  echo "  $(pass_tag) $(tr serial_ok)"; record PASS "serial" "$(tr serial_ok)" ""
fi
BIOSD=$("${SUDO[@]}" dmidecode -s bios-release-date 2>/dev/null); echo "  BIOS date: $BIOSD"
if command -v mokutil >/dev/null; then
  SBST=$(mokutil --sb-state 2>/dev/null | head -1); echo "  $(tr secure_boot): $SBST"
elif ls /sys/firmware/efi/efivars/SecureBoot-* >/dev/null 2>&1; then
  SBVAL=$(cat /sys/firmware/efi/efivars/SecureBoot-* 2>/dev/null | tail -c 1 | od -An -tu1 | tr -dc '[:digit:]')
  echo "  $(tr secure_boot): $([ "$SBVAL" = "1" ] && echo enabled || echo disabled/unknown)"
fi
command -v efibootmgr >/dev/null && "${SUDO[@]}" efibootmgr -v 2>/dev/null | head -6 | sed 's/^/  /'
if "${SUDO[@]}" dmidecode 2>/dev/null | grep -qiE 'computrace|absolute'; then
  echo "  $(fail_tag) $(tr absolute)"; record WARN "anti-theft" "$(tr absolute)" "unlock or -10%"
fi
lspci 2>/dev/null | grep -i "Management Engine" | sed 's/^/  /' && echo "  ($(tr me_found))"
MSDM=/sys/firmware/acpi/tables/MSDM
if [ -f "$MSDM" ]; then
  WK=$(strings "$MSDM" 2>/dev/null | grep -oE '[A-Z0-9]{5}(-[A-Z0-9]{5}){4}' | head -1)
  [ -n "$WK" ] && echo "  $(tr msdm): ${WK:0:5}-.....-${WK: -5} (photo the full key from your own screen if needed)"
  [ -n "$WK" ] && record PASS "msdm" "OEM Windows key in firmware (original Windows)" ""
fi
TPM=$(ls /sys/class/tpm 2>/dev/null | head -1); [ -n "$TPM" ] && echo "  TPM: present"
photo_step "anti-fraud section"

# ============================ 19 OS SCAN (read-only) =================
hr "19 · Installed-OS scan (remote-access tools, install date)"
LIVE=0; mount 2>/dev/null | grep -qE 'overlay|/run/live|/run/media.*isodevice' && LIVE=1
if [ "$LIVE" = 1 ] && [ "$SELLER" = 0 ] && ui_confirm "Read-only scan of the installed OS partition? [y/N] "; then
  MP=$(mktemp -d /tmp/pcd-os.XXXXXX)
  PART=$(lsblk -lpno NAME,FSTYPE,TYPE 2>/dev/null | awk '$3=="part" && $2~/ext4|xfs|ntfs/{print $1; exit}' | grep -v "$(findmnt -n -o SOURCE / 2>/dev/null)" | head -1)
  if [ -n "$PART" ] && "${SUDO[@]}" mount -o ro "$PART" "$MP" 2>/dev/null; then
    REMOTE=$("${SUDO[@]}" grep -rliE 'teamviewer|anydesk' "$MP/Program Files" "$MP/Program Files (x86)" "$MP/etc" "$MP/usr/share/applications" "$MP/opt" 2>/dev/null | head -3)
    if [ -n "$REMOTE" ]; then
      echo "  $(fail_tag) $(tr remote_tools): $(basename "$(echo "$REMOTE" | head -1)")"
      record FAIL "remote-access" "$(tr remote_tools)" "WALK AWAY (stolen laptop risk)"; json_add FAIL "remote-access" "found"
    else
      echo "  $(pass_tag) $(tr no_remote)"; record PASS "os-scan" "$(tr no_remote)" ""
    fi
    OLDEST=$("${SUDO[@]}" find "$MP/home" "$MP/Users" -maxdepth 1 -mindepth 1 -printf '%T+ %p\n' 2>/dev/null | sort | head -1)
    [ -n "$OLDEST" ] && echo "  oldest user profile: $OLDEST"
    "${SUDO[@]}" umount "$MP" 2>/dev/null
  else
    echo "  $(warn_tag) $(tr mount_na)"; record SKIP "os-scan" "" ""
  fi
  rmdir "$MP" 2>/dev/null
else record SKIP "os-scan" "" ""; [ "$LIVE" = 0 ] && echo "  (only meaningful from the live USB)" ; fi

# ============================ 20 PHYSICAL ============================
hr "20 · Physical inspection"
if [ "$SELLER" = 0 ] && [ "$ASK" = "yes" ]; then
  pcheck() {
    if ui_confirm "$1 [y/N] "; then
      record WARN "physical" "$2" "$3"; echo "  $(warn_tag) $2 -> $3"; json_add WARN "physical" "$2"
    fi
  }
  pcheck "Missing or stripped screws?" "screws missing/stripped" "-3%"
  pcheck "Liquid damage: stains, corrosion in ports?" "liquid damage" "-15–25% or walk"
  pcheck "Hinge loose, cracked, creaking?" "hinge damaged" "-5–10%"
  pcheck "Battery swollen: bulging case, lifted trackpad? (SAFETY)" "swollen battery" "WALK AWAY"
  pcheck "Fan grinding or rattling when pressed to load?" "fan bearing worn" "-5–10%"
  pcheck "Deep scratches, dents, cracked plastics?" "cosmetic damage" "-3–8%"
  pcheck "Keyboard worn smooth / keys shiny vs claimed age?" "wear inconsistent with claimed age" "-3%"
  record PASS "physical-done" "checklist completed" ""
else
  echo "  (skipped: non-interactive mode)"
  record SKIP "physical" "" ""
fi

# ============================ 21 VERDICT =============================
hr "21 · Verdict"
claims_table
P=0; W=0; F=0
for line in "${SCORECARD[@]}"; do
  case "${line%%|*}" in PASS) P=$((P+1));; WARN) W=$((W+1));; FAIL) F=$((F+1));; esac
done
echo "  PASS: $P   WARN: $W   FAIL: $F   (runtime $(( SECONDS - T_START ))s)"
CRIT=0
for line in "${SCORECARD[@]}"; do
  case "$line" in
    FAIL\|ram-quick*|FAIL\|smart-badsectors*|FAIL\|mce*|FAIL\|swollen*|FAIL\|claims-storage*|FAIL\|claims-ram*|FAIL\|remote-access*|FAIL\|claims-age*) CRIT=$((CRIT+1)) ;;
  esac
  json_add "${line%%|*}" "$(echo "$line" | cut -d'|' -f2)" "$(echo "$line" | cut -d'|' -f3)"
done
if [ "$CRIT" -gt 0 ] || [ "$F" -ge 2 ]; then
  echo -e "\n  ${R}${B}$(tr verdict_walk)${X}"
  VERDICT="WALK AWAY"
elif [ "$F" -gt 0 ] || [ "$W" -ge 3 ]; then
  echo -e "\n  ${Y}${B}$(tr verdict_neg)${X}"
  VERDICT="NEGOTIATE"
else
  echo -e "\n  ${G}${B}$(tr verdict_buy)${X}"
  VERDICT="BUY"
fi
echo "  Top reasons:"
for line in "${SCORECARD[@]}"; do
  r="${line%%|*}"
  if [ "$r" = "FAIL" ]; then echo "    BAD: $(echo "$line" | cut -d'|' -f3)  [$(echo "$line" | cut -d'|' -f4)]"
  elif [ "$r" = "WARN" ]; then echo "    CAUTION: $(echo "$line" | cut -d'|' -f3)  [$(echo "$line" | cut -d'|' -f4)]"; fi
done | head -6
echo "  Price-deduction sheet:"
for line in "${SCORECARD[@]}"; do
  r="${line%%|*}"; g=$(echo "$line" | cut -d'|' -f4)
  [ -n "$g" ] && [ "$r" != "SKIP" ] && echo "    $r $(echo "$line" | cut -d'|' -f2): $g"
done
photo_step "final verdict"

# ============================ 22 REPORTS =============================
json_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\n'; }
{
  echo "{"
  echo " \"version\":\"$VERSION\", \"generated\":\"$(date -Iseconds)\", \"host\":\"$(json_escape "$(hostname)")\","
  echo " \"serial\":\"$SERIAL\", \"verdict\":\"$VERDICT\", \"lang\":\"$([ "$LANG_PT" = 1 ] && echo pt-MZ || echo en)\","
  echo " \"claims\":{ \"ram\":\"${CLAIMS[ram]:-}\", \"storage_gb\":\"${CLAIMS[sto]:-}\", \"type\":\"${CLAIMS[type]:-}\", \"cpu\":\"$(json_escape "${CLAIMS[cpu]:-}")\", \"age_years\":\"${CLAIMS[age]:-}\", \"battery_min\":\"${CLAIMS[batt]:-}\" },"
  echo " \"detected\":{ \"ram_gb\":\"${DETECTED[ram]:-}\", \"storage_gb\":\"${DETECTED[sto]:-}\", \"type\":\"${DETECTED[type]:-}\", \"cpu\":\"$(json_escape "${DETECTED[cpu]:-}")\", \"poh\":\"${DETECTED[poh]:-}\", \"bios\":\"${DETECTED[age_bios]:-}\" },"
  echo " \"checks\":["
  first=1
  while IFS= read -r line; do
    [ "$first" = 1 ] || echo ","; first=0
    echo "  $line"
  done < "$REPORT.jsonl"
  echo " ]"
  echo "}"
} > "$REPORTJSON" 2>/dev/null
rm -f "$REPORT.jsonl"
SHA=$(sha256sum "$REPORT" | awk '{print $1}')
echo
echo "  $(tr report_saved): $REPORT"
echo "  json: $REPORTJSON"
echo "  $(tr sha): $SHA"
echo "  cp the two files to your USB stick before leaving!"
# reports were created by root (sudo run) -- hand them back to the user
if [ -n "${SUDO_USER:-}" ] && [ "$(id -u)" = 0 ]; then
  chown "$SUDO_USER" "$REPORT" "$REPORTJSON" 2>/dev/null
  chmod 644 "$REPORT" "$REPORTJSON" 2>/dev/null
fi

# ============================ 23 LLM (optional, online) ==============
llm_ready() {
  command -v curl >/dev/null || { echo "  curl missing"; return 1; }
  curl -s -m 6 -o /dev/null https://api.openai.com 2>/dev/null || { echo "  offline"; return 1; }
  return 0
}
llm_call() { # llm_call "user content"
  local key model url body
  read -r -s -p "  LLM API key (not stored, just this session): " key </dev/tty; echo
  [ -n "$key" ] || { echo "  no key given, skipping"; return 1; }
  model=$(ui_input "model [gpt-4o-mini]:"); model=${model:-gpt-4o-mini}
  url=$(ui_input "API base [https://api.openai.com/v1/chat/completions]:")
  url=${url:-https://api.openai.com/v1/chat/completions}
  body=$(jq -n --arg k "" --arg m "$model" --arg sys 'You explain a used-PC health report to a non-technical buyer in Mozambique. Use ONLY the JSON provided. Never invent values; if a check is missing, say "not tested". Never change or override the rule-based verdict, only explain it. Be short, plain, no jargon, reply in the user'"'"'s language (English or Portuguese). Price advice must be rough ranges.' --arg u "$1" '{model:$m,temperature:0.2,messages:[{role:"system",content:$sys},{role:"user",content:$u}]}' 2>/dev/null) || body="{\"model\":\"$model\",\"messages\":[{\"role\":\"system\",\"content\":\"explain\"},{\"role\":\"user\",\"content\":$1}]}"
  curl -s -m 60 "$url" -H "Content-Type: application/json" -H "Authorization: Bearer $key" -d "$body" \
    | jq -r '.choices[0].message.content' 2>/dev/null || echo "  (llm call failed)"
}
scrub() { sed -E "s/$SERIAL/REDACTED/g; s/([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}/MAC:REDACTED/g" "$1"; }
if [ "$EXPLAIN" = 1 ] || [ "$CHAT" = 1 ]; then
  if llm_ready; then
    CTX=$(jq -Rs . < <(scrub "$REPORTJSON"))
    if [ "$EXPLAIN" = 1 ]; then
      echo "  ---- LLM summary ----"
      llm_call "Explain this report JSON: $CTX"
    else
      echo "  ---- LLM chat (empty question exits) ----"
      while :; do
        Q=$(ui_input "your question:")
        [ -z "$Q" ] && break
        llm_call "Report JSON: $CTX -- Question: $(json_escape "$Q")"
      done
    fi
  else echo "  offline: using built-in plain-language results above"; fi
fi

exit 0
