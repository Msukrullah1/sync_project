#!/data/data/com.termux/files/usr/bin/bash
########################################
# SUKRULLAH DASHBOARD v4.5 FINAL
# Termux display — Poco X3 Pro (width fixed)
# Features removed: NONE
########################################

# ───── Colors ─────
R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; C='\033[0;36m'
M='\033[0;35m'; O='\033[38;5;214m'; LM='\033[38;5;154m'; SB='\033[38;5;39m'
PK='\033[38;5;213m'; B='\033[1m'; D='\033[2m'; N='\033[0m'
LIME='\033[38;5;118m'; ROSE='\033[38;5;204m'; GD='\033[38;5;220m'

# ───── Fixed width (DO NOT CHANGE) ─────
BOXW=46
BARW=34

line() { printf "%*s" "$1" "" | tr ' ' "$2"; }
dtop() { echo -e "${C}╭$(line $BOXW ─)╮${N}"; }
dmid() { echo -e "${C}├$(line $BOXW ─)┤${N}"; }
dbot() { echo -e "${C}╰$(line $BOXW ─)╯${N}"; }
row()  { echo -e "${C}│${N} $1"; }
dempty(){ echo -e "${C}│${N}"; }

# ───── Safe numeric percent ─────
pct_safe() {
  local v="${1:-0}"
  v="$(echo "$v" | tr -cd '0-9')"
  [[ -z "$v" ]] && v=0
  (( v<0 )) && v=0
  (( v>100 )) && v=100
  echo "$v"
}

# ───── df helpers (GB always) ─────
to_gb_bytes(){ awk -v b="${1:-0}" 'BEGIN{printf "%.1fG", (b/1024/1024/1024)}'; }

df_stats() {
  # used total free pct
  local p="$1"
  local u t f pct
  read -r u t f < <(df -B1 "$p" 2>/dev/null | awk 'NR==2{print $3,$2,$4}')
  [[ -z "$t" || "$t" -le 0 ]] && echo "0 0 0 0" && return
  pct="$(awk -v u="$u" -v t="$t" 'BEGIN{printf "%d", (u*100/t)}')"
  echo "$u $t $f $pct"
}

detect_internal_path(){
  [[ -d "$HOME/storage/shared" ]] && { echo "$HOME/storage/shared"; return; }
  [[ -d "/storage/emulated/0" ]] && { echo "/storage/emulated/0"; return; }
  [[ -d "/sdcard" ]] && { echo "/sdcard"; return; }
  echo "$PREFIX"
}

detect_sd_path(){
  if [[ -d "/storage" ]]; then
    local p
    for p in /storage/*; do
      [[ -d "$p" ]] || continue
      [[ "$p" =~ /storage/(emulated|self)$ ]] && continue
      echo "$p"; return
    done
  fi
  echo ""
}

# ───── Progress bars (TERMUX SAFE) ─────
cc() { printf "\033[38;5;%sm" "$1"; }
rc() { printf "\033[0m"; }

# bar style: "bat" greenish, "stor" bluish
fpbar(){
  local val="$(pct_safe "$1")"
  local type="${2:-stor}"
  local filled=$(( val * BARW / 100 ))
  local empty=$(( BARW - filled ))
  local bar="" i c p

  for((i=1;i<=filled;i++)); do
    p=$(( i*100/BARW ))
    if [[ "$type" = "bat" ]]; then
      # green -> yellow -> red
      if   (( p<=25 )); then c=46
      elif (( p<=50 )); then c=190
      elif (( p<=75 )); then c=214
      else c=196
      fi
    else
      # storage = blue shades
      if   (( p<=50 )); then c=39
      elif (( p<=80 )); then c=33
      else c=27
      fi
    fi
    bar+=$(cc "$c")"#"
  done
  for((i=1;i<=empty;i++)); do bar+=$(cc 242)"."; done

  printf "▕%s%s %s%3d%%%s" "$bar" "$(rc)" "$(cc 250)" "$val" "$(rc)"
}

bat_icon(){
  local p="$(pct_safe "$1")" s="$2"
  case "$s" in CHARGING|Charging) echo "🔌"; return;; esac
  (( p<=10 )) && echo "🪫" || echo "🔋"
}

# ───── WATCH MODE (kept) ─────
if [[ "${MODE:-}" = "watch" ]] || [[ "${1:-}" = "watch" ]]; then
  clear; dtop
  row " ${PK}${B}◈ WIFI WATCHER ACTIVE${N}"
  row " ${D}Networks: ${ALLOWED_WIFI1} / ${ALLOWED_WIFI2}${N}"
  row " ${D}Interval: 2h  Stop: Ctrl+C${N}"
  dbot

  LAST_WIFI=""
  while true; do
    WIFI_NOW=""
    if command -v termux-wifi-connectioninfo >/dev/null 2>&1; then
      WIFI_NOW="$(termux-wifi-connectioninfo 2>/dev/null | awk -F\" '/"ssid"/{print $4; exit}')"
      [[ "$WIFI_NOW" = "<unknown ssid>" ]] && WIFI_NOW=""
    fi

    TS="$(date '+%H:%M:%S')"
    if [[ "$WIFI_NOW" = "${ALLOWED_WIFI1:-}" ]] || [[ "$WIFI_NOW" = "${ALLOWED_WIFI2:-}" ]]; then
      if [[ "$LAST_WIFI" != "$WIFI_NOW" ]]; then
        echo -e "${LIME}[$TS]${N} WiFi: ${B}${WIFI_NOW}${N} — Syncing!"
        LAST_WIFI="$WIFI_NOW"
        bash "$HOME/sync_project/sync.sh" manual
      else
        echo -e "${D}[$TS] Already synced. Next in 2h.${N}"
      fi
    else
      echo -e "${Y}[$TS]${N} Waiting... ${B}${WIFI_NOW:-Mobile Data}${N}"
      LAST_WIFI=""
    fi
    sleep 7200
  done
  exit 0
fi

DAY="$(date '+%A, %d %b %Y')"

# ───── WIFI fallback ─────
if [[ -z "${CURRENT_WIFI:-}" ]] && command -v termux-wifi-connectioninfo >/dev/null 2>&1; then
  CURRENT_WIFI="$(termux-wifi-connectioninfo 2>/dev/null | awk -F\" '/"ssid"/{print $4; exit}')"
  [[ "$CURRENT_WIFI" = "<unknown ssid>" ]] && CURRENT_WIFI=""
fi

# ───── Battery fallback ─────
if [[ -z "${BAT:-}" ]] && command -v termux-battery-status >/dev/null 2>&1; then
  BAT="$(termux-battery-status 2>/dev/null | awk -F'[:,}]' '/percentage/{gsub(/[^0-9]/,"",$2); print $2; exit}')"
fi
BAT="$(pct_safe "${BAT:-0}")"
BAT_STATUS="${BAT_STATUS:-Unknown}"

# ───── REAL STORAGE from df (GB always) ─────
INT_PATH="$(detect_internal_path)"
read -r IU IT IF IP < <(df_stats "$INT_PATH")
INT_USED="$(to_gb_bytes "$IU")"
INT_TOTAL="$(to_gb_bytes "$IT")"
INT_FREE="$(to_gb_bytes "$IF")"
INT_PCT="$(pct_safe "$IP")"

SD_PATH="$(detect_sd_path)"
SD_RAW=""
SD_PCT=0
if [[ -n "$SD_PATH" ]]; then
  read -r SU ST SF SP < <(df_stats "$SD_PATH")
  if [[ "$ST" -gt 0 ]]; then
    SD_RAW="1"
    SD_USED="$(to_gb_bytes "$SU")"
    SD_TOTAL="$(to_gb_bytes "$ST")"
    SD_FREE="$(to_gb_bytes "$SF")"
    SD_PCT="$(pct_safe "$SP")"
  fi
fi

# ───── BLOCKED screen (kept) ─────
if [[ "${MODE:-auto}" = "auto" ]]; then
  if [[ "${CURRENT_WIFI:-}" != "${ALLOWED_WIFI1:-}" ]] && [[ "${CURRENT_WIFI:-}" != "${ALLOWED_WIFI2:-}" ]]; then
    clear
    echo ""
    echo -e " ${GD}${B}★ SUKRULLAH PRO SYNC v4.5 ★${N}"
    echo -e " ${D}${DAY}${N}"
    echo ""
    dtop
    row " ${ROSE}${B}⛔ SYNC BLOCKED — WRONG NETWORK${N}"
    dmid
    row " ${Y}Connected :${N} ${CURRENT_WIFI:-Mobile Data}"
    row " ${LIME}Allowed :${N} ${ALLOWED_WIFI1:-N/A}"
    row " ${LIME} ${N} ${ALLOWED_WIFI2:-N/A}"
    dmid
    row " ${D}manual = any WiFi${N}"
    row " ${D}force  = mobile data${N}"
    row " ${D}watch  = auto watcher${N}"
    dbot
    echo ""
    exit 0
  fi
fi

# ───── Header ─────
clear
echo ""
echo -e " ${GD}${B}★ SUKRULLAH PRO SYNC v4.5 ★${N}"
echo -e " ${D}${DAY}${N}"
echo ""

# ───── SYSTEM STATUS ─────
dtop
row " ${PK}${B}⚡ SYSTEM STATUS${N}"
dmid
row " $(bat_icon "$BAT" "$BAT_STATUS") ${B}Battery${N} ${Y}${B}${BAT}%${N} ${D}(${BAT_STATUS})${N}"
row " $(fpbar "$BAT" bat)"
dempty

if [[ "${MODE:-auto}" = "force" ]]; then
  row " 📡 ${B}Network${N} ${ROSE}Mobile Data (Force)${N}"
elif [[ -n "${CURRENT_WIFI:-}" ]]; then
  row " 📡 ${B}Network${N} ${LIME}${CURRENT_WIFI}${N}"
else
  row " 📡 ${B}Network${N} ${Y}Mobile Data${N}"
fi

case "${MODE:-auto}" in
  force)   row " ⚙ ${B}Mode${N} ${ROSE}${B}[ FORCE ]${N}" ;;
  manual)  row " ⚙ ${B}Mode${N} ${Y}${B}[ MANUAL ]${N}" ;;
  preview) row " ⚙ ${B}Mode${N} ${M}${B}[ PREVIEW ]${N}" ;;
  *)       row " ⚙ ${B}Mode${N} ${LIME}${B}[ AUTO ]${N}" ;;
esac

# ───── STORAGE ─────
dmid
row " ${PK}${B}💾 STORAGE DASHBOARD (GB)${N}"
dmid

row " ${O}${B}📱 Internal Storage${N}"
row " ${B}${INT_USED}${N} / ${INT_TOTAL}  Free: ${LIME}${B}${INT_FREE}${N}"
row " $(fpbar "$INT_PCT" stor)"
dempty

row " ${SB}${B}💳 Micro SD Card${N}"
if [[ -n "$SD_RAW" ]]; then
  row " ${B}${SD_USED}${N} / ${SD_TOTAL}  Free: ${LIME}${B}${SD_FREE}${N}"
  row " $(fpbar "$SD_PCT" stor)"
else
  row " ${D}Not detected${N}"
fi
dempty

row " ${PK}${B}☁️ Zoho WorkDrive ${LIME}[Sync ON]${N}"
if [[ -n "${ZOHO_RAW:-}" ]]; then
  row " ${B}${ZOHO_USED:-0}G${N} / ${ZOHO_TOTAL_GB:-55}G  Free: ${LIME}${B}${ZOHO_FREE:-0}G${N}"
  row " $(fpbar "$(pct_safe "${ZOHO_PCT:-0}")" stor)"
else
  row " ${ROSE}Cannot reach Zoho${N}"
fi
dempty

row " ${C}${B}🔵 OneDrive ${Y}[Display Only]${N}"
if [[ "${OD_INFO_ON:-1}" -eq 1 ]] && [[ -n "${OD_TOTAL:-}" ]]; then
  row " ${B}${OD_USED_G:-N/A}G${N} / ${OD_TOTAL:-N/A}G  Free: ${LIME}${B}${OD_FREE_G:-N/A}G${N}"
  row " $(fpbar "$(pct_safe "${OD_PCT:-0}")" stor)"
else
  row " ${D}Cannot reach OneDrive${N}"
fi

# ───── SCHEDULE ─────
dmid
row " ${GD}${B}🕐 SCHEDULE${N}"
dmid
row " 🕑 ${B}02:00${N} 🕚 ${B}11:00${N} 🕔 ${B}17:00${N} 🕘 ${B}21:00${N}"
row " ${D}auto_push : every 30 min${N}"
row " ${LIME}watch: bash sync.sh watch${N}"
dbot
echo ""
``
