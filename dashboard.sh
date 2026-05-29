#!/data/data/com.termux/files/usr/bin/bash
########################################
# SUKRULLAH DASHBOARD v4.2
# Sirf Termux display — Poco X3 Pro
# Edit karo bina sync.sh chhue!
########################################

# ───── Colors ─────
R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; C='\033[0;36m'
M='\033[0;35m'; O='\033[38;5;214m'; LM='\033[38;5;154m'; SB='\033[38;5;39m'
PK='\033[38;5;213m'; B='\033[1m'; D='\033[2m'; N='\033[0m'
LIME='\033[38;5;118m'; ROSE='\033[38;5;204m'; GD='\033[38;5;220m'

# ───── Fixed width — Poco X3 Pro ─────
BOXW=46
BARW=34

line() { printf "%*s" "$1" "" | tr ' ' "$2"; }
dtop() { echo -e "${C}╭$(line $BOXW ─)╮${N}"; }
dmid() { echo -e "${C}├$(line $BOXW ─)┤${N}"; }
dbot() { echo -e "${C}╰$(line $BOXW ─)╯${N}"; }
row()  { echo -e "${C}│${N} $1"; }
dempty(){ echo -e "${C}│${N}"; }

# ───── GB formatter (e.g., 2.5GB) ─────
fmt_gb(){
  local val="$1"
  local num="${val%G}"
  if [[ "$num" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    printf "%.1fGB" "$num"
  else
    echo "${val:-N/A}"
  fi
}

# ───── Progress bar ─────
cc() { printf "\033[38;5;%sm" "$1"; }
rc() { printf "\033[0m"; }
color_scale(){
  local v=$1
  [ "$v" -le 25 ] && echo 46 && return
  [ "$v" -le 50 ] && echo 190 && return
  [ "$v" -le 75 ] && echo 214 && return
  echo 196
}
bat_scale(){
  local v=$1
  [ "$v" -le 20 ] && echo 196 && return
  [ "$v" -le 40 ] && echo 214 && return
  [ "$v" -le 60 ] && echo 220 && return
  [ "$v" -le 80 ] && echo 118 && return
  echo 34
}
batbar(){
  local val=$1
  [ "$val" -lt 0 ] && val=0
  [ "$val" -gt 100 ] && val=100
  local filled=$(( val * BARW / 100 ))
  local empty=$(( BARW - filled ))
  local bar="" i c p
  for((i=1;i<=filled;i++)); do
    p=$(( i*100/BARW ))
    c=$(bat_scale "$p")
    bar+=$(cc "$c")"█"
  done
  for((i=1;i<=empty;i++)); do bar+=$(cc 242)"░"; done
  printf "▕%s%s %s%3d%%%s" "$bar" "$(rc)" "$(cc 250)" "$val" "$(rc)"
}
fpbar(){
  local val=$1
  [ "$val" -lt 0 ] && val=0
  [ "$val" -gt 100 ] && val=100
  local filled=$(( val * BARW / 100 ))
  local empty=$(( BARW - filled ))
  local bar="" i c p
  for((i=1;i<=filled;i++)); do
    p=$(( i*100/BARW ))
    c=$(color_scale "$p")
    bar+=$(cc "$c")"█"
  done
  for((i=1;i<=empty;i++)); do bar+=$(cc 242)"░"; done
  printf "▕%s%s %s%3d%%%s" "$bar" "$(rc)" "$(cc 250)" "$val" "$(rc)"
}

bat_icon(){
  local p=$1 s=$2
  case "$s" in CHARGING|Charging) echo "🔌"; return;; esac
  [ "$p" -le 10 ] && echo "🪫" || echo "🔋"
}

# ───── WATCH MODE ─────
if [ "${MODE:-}" = "watch" ] || [ "${1:-}" = "watch" ]; then
  clear; dtop
  row "  ${PK}${B}◈ WIFI WATCHER ACTIVE${N}"
  row "  ${D}Networks: ${ALLOWED_WIFI1} / ${ALLOWED_WIFI2}${N}"
  row "  ${D}Interval: 2h  |  Stop: Ctrl+C${N}"
  dbot
  LAST_WIFI=""
  while true; do
    WIFI_NOW=$(termux-wifi-connectioninfo 2>/dev/null | grep '"ssid"' | tail -1 | cut -d'"' -f4)
    [ "$WIFI_NOW" = "<unknown ssid>" ] && WIFI_NOW=""
    TS=$(date '+%H:%M:%S')
    if [ "$WIFI_NOW" = "${ALLOWED_WIFI1}" ] || [ "$WIFI_NOW" = "${ALLOWED_WIFI2}" ]; then
      if [ "$LAST_WIFI" != "$WIFI_NOW" ]; then
        echo -e "${LIME}[$TS]${N} WiFi: ${B}${WIFI_NOW}${N} — Syncing!"
        LAST_WIFI="$WIFI_NOW"
        bash "$HOME/sync_project/sync.sh" manual
      else
        echo -e "${D}[$TS] Already synced. Next in 2h.${N}"
      fi
    else
      echo -e "${Y}[$TS]${N} Waiting... ${B}${WIFI_NOW:-Mobile Data}${N}"; LAST_WIFI=""
    fi
    sleep 7200
  done
  exit 0
fi

DAY=$(date '+%A, %d %b %Y')

# ───── BLOCKED screen (auto mode wrong wifi) ─────
if [ "${MODE:-auto}" = "auto" ]; then
  if [ "${CURRENT_WIFI:-}" != "${ALLOWED_WIFI1}" ] && [ "${CURRENT_WIFI:-}" != "${ALLOWED_WIFI2}" ]; then
    clear
    echo ""
    echo -e "  ${GD}${B}★ SUKRULLAH PRO SYNC v4.2 ★${N}"
    echo -e "  ${D}${DAY}${N}"
    echo ""
    dtop
    row "  ${ROSE}${B}⛔  SYNC BLOCKED — WRONG NETWORK${N}"
    dmid
    row "  ${Y}Connected :${N} ${CURRENT_WIFI:-Mobile Data}"
    row "  ${LIME}Allowed   :${N} ${ALLOWED_WIFI1}"
    row "  ${LIME}          ${N} ${ALLOWED_WIFI2}"
    dmid
    row "  ${D}manual = any WiFi${N}"
    row "  ${D}force  = mobile data${N}"
    row "  ${D}watch  = auto watcher${N}"
    dbot
    echo ""
    exit 0
  fi
fi

# ───── Header ─────
clear
echo ""
echo -e "  ${GD}${B}★ SUKRULLAH PRO SYNC v4.2 ★${N}"
echo -e "  ${D}${DAY}${N}"
echo ""

# ───── SYSTEM STATUS ─────
dtop
row "  ${PK}${B}⚡ SYSTEM STATUS${N}"
dmid
row "  $(bat_icon "${BAT:-0}" "${BAT_STATUS:-Unknown}") ${B}Battery${N}   ${Y}${B}${BAT:-0}%${N} ${D}(${BAT_STATUS:-Unknown})${N}"
row "  $(batbar "${BAT:-0}")"
dempty
if [ "${MODE:-auto}" = "force" ]; then
  row "  📡 ${B}Network${N}   ${ROSE}Mobile Data (Force)${N}"
elif [ -n "${CURRENT_WIFI:-}" ]; then
  row "  📡 ${B}Network${N}   ${LIME}${CURRENT_WIFI}${N}"
else
  row "  📡 ${B}Network${N}   ${Y}Mobile Data${N}"
fi
case "${MODE:-auto}" in
  force)   row "  ⚙  ${B}Mode${N}      ${ROSE}${B}[ FORCE ]${N}" ;;
  manual)  row "  ⚙  ${B}Mode${N}      ${Y}${B}[ MANUAL ]${N}" ;;
  preview) row "  ⚙  ${B}Mode${N}      ${M}${B}[ PREVIEW ]${N}" ;;
  *)       row "  ⚙  ${B}Mode${N}      ${LIME}${B}[ AUTO ]${N}" ;;
esac

# ───── STORAGE ─────
dmid
row "  ${PK}${B}💾 STORAGE DASHBOARD${N}"
dmid

# ── Internal Storage ──
row "  ${O}${B}📱 Internal Storage${N}"
row "  ${B}$(fmt_gb "${INT_USED:-N/A}")${N} / $(fmt_gb "${INT_TOTAL:-N/A}")   Free: ${LIME}${B}$(fmt_gb "${INT_FREE:-N/A}")${N}"
row "  $(fpbar "${INT_PCT:-0}")"
dempty

# ── MicroSD Card ──
row "  ${SB}${B}💳 Micro SD Card${N}"
# SD_RAW check: detect karo ki SD mount hai ya nahi
# sync.sh se SD_TOTAL, SD_USED, SD_FREE, SD_PCT aate hain
# Agar SD_TOTAL empty ya "0" ya "0G" hai to "Not detected"
_sd_total_num="${SD_TOTAL:-}"
_sd_total_num="${_sd_total_num%G}"
_sd_total_num="${_sd_total_num%M}"
if [ -n "${SD_TOTAL:-}" ] && [ "${_sd_total_num:-0}" != "0" ] && [ "${_sd_total_num:-0}" != "" ]; then
  row "  ${B}$(fmt_gb "${SD_USED:-0}")${N} / $(fmt_gb "${SD_TOTAL:-0}")   Free: ${LIME}${B}$(fmt_gb "${SD_FREE:-0}")${N}"
  row "  $(fpbar "${SD_PCT:-0}")"
elif [ -n "${SD_RAW:-}" ]; then
  # Fallback: SD_RAW hai to raw display
  row "  ${B}${SD_USED:-?}${N} / ${SD_TOTAL:-?}   Free: ${LIME}${B}${SD_FREE:-?}${N}"
  row "  $(fpbar "${SD_PCT:-0}")"
else
  row "  ${D}⚠ Not detected — Check mount${N}"
fi
dempty

# ── Zoho WorkDrive ──
row "  ${PK}${B}☁️  Zoho WorkDrive ${LIME}[Sync ON]${N}"
if [ -n "${ZOHO_RAW:-}" ] || [ -n "${ZOHO_USED:-}" ]; then
  row "  ${B}$(fmt_gb "${ZOHO_USED:-0}")${N} / $(fmt_gb "${ZOHO_TOTAL_GB:-55}")   Free: ${LIME}${B}$(fmt_gb "${ZOHO_FREE:-0}")${N}"
  row "  $(fpbar "${ZOHO_PCT:-0}")"
else
  row "  ${ROSE}Cannot reach Zoho${N}"
fi
dempty

# ───── SCHEDULE ─────
dmid
row "  ${GD}${B}🕐 SCHEDULE${N}"
dmid
row "  🕑 ${B}02:00${N}  🕚 ${B}11:00${N}  🕔 ${B}17:00${N}  🕘 ${B}21:00${N}"
row "  ${D}auto_push : every 30 min${N}"
row "  ${LIME}watch: bash sync.sh watch${N}"
dbot
echo ""
