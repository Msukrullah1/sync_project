#!/data/data/com.termux/files/usr/bin/bash
##############################################
# SUKRULLAH PRO SYNC v3.8 — OD View-Only Mode
# Termux UI optimized for 6.67" 1080x2400 (20:9)
# OneDrive: connection + storage show ONLY (no sync)
##############################################

# ───── Colors ─────
R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; C='\033[0;36m'
M='\033[0;35m'; O='\033[38;5;214m'; LM='\033[38;5;154m'; SB='\033[38;5;39m'
PK='\033[38;5;213m'; B='\033[1m'; D='\033[2m'; N='\033[0m'

cc()     { printf "\033[38;5;%sm" "$1"; }
resetc() { printf "\033[0m"; }

# ───── Config ─────
# Secrets via ENV recommended:
#   export TG_TOKEN=... ; export TG_CHAT_ID=...
TG_TOKEN="${TG_TOKEN:-}"
TG_CHAT_ID="${TG_CHAT_ID:-}"

ALLOWED_WIFI1="Encore 2_5GHz"
ALLOWED_WIFI2="Encore2"

# Soft info limit (GB) for warning only
ONEDRIVE_LIMIT=48

# Data roots (still referenced for UI; no sync by default)
LOCAL1="$HOME/storage/shared/Cloud-Sync-File"
REMOTE1="onedrive:Cloud-Sync-File"

LOCAL2="$HOME/storage/shared/HiRes_Songs"
REMOTE2="onedrive:HiRes_Songs"

# Default behaviors
MODE="auto"        # auto | manual | force | watch | preview
OD_INFO_ON=1       # 1=show OneDrive quota; 0=skip even about
OD_SYNC_ON=0       # 🔒 DEFAULT OFF — no rclone sync to OneDrive

# CLI parse
if [ -n "$1" ]; then MODE="$1"; fi
for arg in "$@"; do
  case "$arg" in
    --no-od|--no-onedrive) OD_INFO_ON=0 ;;
    --od-sync)             OD_SYNC_ON=1 ;;   # explicit opt-in for future
  esac
done

# ───── Mobile-friendly width (prevents wrapping) ─────
COLS=$(tput cols 2>/dev/null || echo 80)
if   [ "$COLS" -ge 90 ]; then BOXW=72
elif [ "$COLS" -ge 70 ]; then BOXW=60
else BOXW=50
fi
if   [ "$BOXW" -ge 70 ]; then BARW=42
elif [ "$BOXW" -ge 60 ]; then BARW=36
else BARW=28
fi

line() { local c="$1" n="$2"; printf "%*s" "$n" "" | tr ' ' "$c"; }
dtop() { echo -e "${C}╭$(line ─ "$BOXW")╮${N}"; }
dmid() { echo -e "${C}├$(line ─ "$BOXW")┤${N}"; }
dbot() { echo -e "${C}╰$(line ─ "$BOXW")╯${N}"; }
row()  { echo -e "${C}│${N} $1"; }

LOG_DIR="$HOME/sync_logs"
MASTER_LOG="$LOG_DIR/master_sync.log"
mkdir -p "$LOG_DIR"
log_msg() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$MASTER_LOG"; }

# ───── Gradient progress bar ─────
color_scale(){ local v=$1; if [ "$v" -le 25 ]; then echo 46; elif [ "$v" -le 50 ]; then echo 190; elif [ "$v" -le 75 ]; then echo 214; else echo 196; fi; }
fpbar(){
  local val=$1 width=${2:-$BARW}
  [ "$val" -lt 0 ] && val=0; [ "$val" -gt 100 ] && val=100
  local filled=$(( val * width / 100 )); [ $filled -gt $width ] && filled=$width
  local empty=$(( width - filled )); local bar="" i c
  for((i=1;i<=filled;i++));do local p=$(( i*100/width )); c=$(color_scale "$p"); bar+=$(cc "$c")"█"; done
  for((i=1;i<=empty;i++));do bar+=$(cc 242)"░"; done
  printf "▕%s%s %s%3d%%%s" "$bar" "$(resetc)" "$(cc 250)" "$val" "$(resetc)"
}
battery_icon(){ local pct=$1 s="$2" i="🔋"; case "$s" in CHARGING|Charging) i="🔌";; *) [ "$pct" -le 10 ] && i="🪫";; esac; printf "%s" "$i"; }
tbar(){ local v=$1 w=${2:-$((BARW-4))}; [ "$v" -lt 0 ]&&v=0; [ "$v" -gt 100 ]&&v=100; local f=$(( v*w/100 )) out=""; for((i=1;i<=w;i++));do [ $i -le $f ]&&out+="█"||out+="·"; done; printf "%s %3d%%" "$out" "$v"; }

send_telegram(){
  [ -z "$TG_TOKEN" ] || [ -z "$TG_CHAT_ID" ] && return 0
  local msg="$1" f resp; f=$(mktemp); printf '%s' "$msg" > "$f"
  resp=$(curl -s -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
            -d "chat_id=${TG_CHAT_ID}" -d "parse_mode=HTML" \
            --data-urlencode "text=$(cat "$f")")
  rm -f "$f"; echo "$resp" | grep -q '"ok":true' || echo -e "${Y}ℹ TG send failed/skipped${N}"
}

# ───── CRON AUTOSYNC (as per system design) ─────
setup_cron(){
  local n; n=$(crontab -l 2>/dev/null | grep -F "sync.sh auto" | wc -l)
  if [ "${n:-0}" -lt 4 ]; then
    ( crontab -l 2>/dev/null | grep -v "sync.sh" || true
      echo "0 2  * * * bash ~/sync.sh auto >> ~/sync_logs/cron.log 2>&1"
      echo "0 11 * * * bash ~/sync.sh auto >> ~/sync_logs/cron.log 2>&1"
      echo "0 17 * * * bash ~/sync.sh auto >> ~/sync_logs/cron.log 2>&1"
      echo "0 21 * * * bash ~/sync.sh auto >> ~/sync_logs/cron.log 2>&1"
    ) | crontab -
    row "${G}✅ Crontab set: 02:00, 11:00, 17:00, 21:00${N}"
    log_msg "Crontab auto-configured"
  fi
}

# ───── WATCH MODE ─────
if [ "$MODE" = "watch" ]; then
  dtop; row "${PK}${B}★ WIFI WATCHER STARTED${N}"; row "${D}Watching: ${ALLOWED_WIFI1} / ${ALLOWED_WIFI2}${N}"
  row "${D}Every 2 hours — Ctrl+C to stop${N}"; dbot
  LAST_WIFI=""
  while true; do
    WIFI_NOW=$(termux-wifi-connectioninfo 2>/dev/null | grep '"ssid"' | cut -d'"' -f4)
    [ "$WIFI_NOW" = "\<unknown ssid\>" ] && WIFI_NOW=""
    TS=$(date '+%H:%M:%S')
    if [ "$WIFI_NOW" = "$ALLOWED_WIFI1" ] || [ "$WIFI_NOW" = "$ALLOWED_WIFI2" ]; then
      if [ "$LAST_WIFI" != "$WIFI_NOW" ]; then
        echo -e "${G}[$TS]${N} WiFi matched: ${B}${WIFI_NOW}${N} — preview run"
        LAST_WIFI="$WIFI_NOW"; bash "$0" manual
      else
        echo -e "${D}[$TS] Already ran on '${WIFI_NOW}'. Next: 2h.${N}"
      fi
    else
      echo -e "${Y}[$TS]${N} Waiting... Connected: ${B}${WIFI_NOW:-Mobile/No WiFi}${N}"; LAST_WIFI=""
    fi
    sleep 7200
  done
  exit 0
fi

# ───── Storage permission ─────
[ -d "$HOME/storage/shared" ] || termux-setup-storage

# ───── SYSTEM INFO ─────
BAT=$(termux-battery-status 2>/dev/null | grep -o '"percentage":[[:space:]]*[0-9]\+' | grep -o '[0-9]\+'); BAT=${BAT:-0}
BAT_STATUS=$(termux-battery-status 2>/dev/null | grep -o '"status":[[:space:]]*"[^"]*"' | cut -d'"' -f4); BAT_STATUS=${BAT_STATUS:-Unknown}
CURRENT_WIFI=$(termux-wifi-connectioninfo 2>/dev/null | grep '"ssid"' | cut -d'"' -f4); [ "$CURRENT_WIFI" = "\<unknown ssid\>" ] && CURRENT_WIFI=""

INT_RAW=$(df -h "$HOME/storage/shared" 2>/dev/null | awk 'NR==2')
INT_TOTAL=$(echo "$INT_RAW" | awk '{print $2}')
INT_USED=$(echo "$INT_RAW"  | awk '{print $3}')
INT_FREE=$(echo "$INT_RAW"  | awk '{print $4}')
INT_PCT=$(echo "$INT_RAW"   | awk '{print $5}' | tr -d '%'); INT_PCT=${INT_PCT:-0}

SD_RAW=$(df -h 2>/dev/null | grep '/storage/' | grep -v 'emulated' | head -n1)
SD_TOTAL=$(echo "$SD_RAW" | awk '{print $2}')
SD_USED=$(echo "$SD_RAW"  | awk '{print $3}')
SD_FREE=$(echo "$SD_RAW"  | awk '{print $4}')
SD_PCT=$(echo "$SD_RAW"   | awk '{print $5}' | tr -d '%'); SD_PCT=${SD_PCT:-0}

OD_INFO=""; OD_TOTAL=""; OD_USED=""; OD_FREE=""; OD_PCT=0
if [ "$OD_INFO_ON" -eq 1 ]; then
  OD_INFO=$(rclone about onedrive: 2>/dev/null)
  OD_TOTAL=$(echo "$OD_INFO" | grep -E '^Total:' | awk '{print $2}' | sed 's/G.*//')
  OD_USED=$(echo "$OD_INFO"  | grep -E '^Used:'  | awk '{print $2}' | sed 's/G.*//')
  OD_FREE=$(echo "$OD_INFO"  | grep -E '^Free:'  | awk '{print $2}' | sed 's/G.*//')
  if [ -n "$OD_TOTAL" ] && [ -n "$OD_USED" ]; then
    OD_INT=${OD_USED%.*}; OD_TOT_INT=${OD_TOTAL%.*}; OD_INT=${OD_INT:-0}; OD_TOT_INT=${OD_TOT_INT:-1}
    [ "$OD_TOT_INT" -gt 0 ] && OD_PCT=$(( OD_INT * 100 / OD_TOT_INT ))
  fi
fi

NOW=$(date '+%Y-%m-%d %H:%M:%S'); DAY=$(date '+%A')

# ───── Wi‑Fi gate (auto) ─────
if [ "$MODE" = "auto" ]; then
  if [ "$CURRENT_WIFI" != "$ALLOWED_WIFI1" ] && [ "$CURRENT_WIFI" != "$ALLOWED_WIFI2" ]; then
    clear; dtop
    row "${R}${B}⛔ BLOCKED - WRONG NETWORK${N}"
    dmid
    row "${Y}Connected :${N} ${CURRENT_WIFI:-Mobile Data}"
    row "${G}Allowed   :${N} ${ALLOWED_WIFI1} / ${ALLOWED_WIFI2}"
    dmid
    row "${D}sync.sh manual  → any WiFi${N}"
    row "${D}sync.sh force   → allow Mobile Data${N}"
    row "${D}sync.sh preview → UI only${N}"
    dbot; log_msg "BLOCKED - Wrong WiFi: ${CURRENT_WIFI:-Mobile}"; exit 0
  fi
fi

# ───── Header ─────
clear
[ "$COLS" -ge 84 ] && {
  echo -e "${M}${B}"
  echo " ███████╗██╗  ██╗██╗  ██╗██████╗  ██╗  ██╗██╗  ██╗ █████╗ ██╗  ██╗"
  echo " ██╔════╝██║  ██║██║  ██╔╝██╔══██╗██║  ██║██║  ██║ ██╔══██╗██║  ██║"
  echo " ███████╗██║  ██║█████╔╝ ██████╔╝██║  ██║██║  ██║ ███████║███████║"
  echo " ╚════██║██║  ██║██╔═██╗ ██╔══██╗██║  ██║██║  ██║ ██╔══██║██╔══██║"
  echo " ███████║╚██████╔╝██║  ██╗██║  ██║╚██████╔╝███████╗███████╗██║  ██║██║  ██║"
  echo " ╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝"
  echo -e "${N}"
}
echo -e "  ${SB}${B}PRO SYNC SYSTEM v3.8${N}  ${D}• ${O}${DAY}, ${NOW}${N}"
echo ""

# ───── STATUS BOX ─────
dtop; row "${PK}${B}★ SYSTEM STATUS${N}"; dmid
row "$(battery_icon "$BAT" "$BAT_STATUS") ${B}Battery${N}  ${Y}${BAT}% (${BAT_STATUS})${N}"
row "$(fpbar "$BAT" "$BARW")"
if [ "$MODE" = "force" ]; then
  row "📡 ${B}Network${N}  ${R}Mobile Data (Force)${N}"
elif [ -n "$CURRENT_WIFI" ]; then
  row "📡 ${B}Network${N}  ${G}${CURRENT_WIFI}${N}"
else
  row "📡 ${B}Network${N}  ${Y}Mobile Data${N}"
fi
case "$MODE" in
  force)  row "⚙ ${B}Mode${N}     ${R}${B}[ FORCE ]${N}" ;;
  manual) row "⚙ ${B}Mode${N}     ${Y}${B}[ MANUAL ]${N}" ;;
  preview)row "⚙ ${B}Mode${N}     ${M}${B}[ PREVIEW ]${N}" ;;
  *)      row "⚙ ${B}Mode${N}     ${G}${B}[ AUTO ]${N}" ;;
esac

# ───── STORAGE BOX ─────
dmid; row "${PK}${B}★ STORAGE OVERVIEW${N}"; dmid
row "${O}${B}📱 Internal Storage${N}"
row "${B}${INT_USED}${N} / ${INT_TOTAL}   Free: ${LM}${INT_FREE}${N}"
row "$(fpbar "$INT_PCT" "$BARW")"

row "${SB}${B}💾 SD Card${N}"
if [ -n "$SD_RAW" ]; then
  row "${B}${SD_USED}${N} / ${SD_TOTAL}   Free: ${LM}${SD_FREE}${N}"
  row "$(fpbar "$SD_PCT" "$BARW")"
else
  row "${D}Not Found${N}"
fi

row "${M}${B}☁ OneDrive${N}"
if [ "$OD_INFO_ON" -eq 0 ]; then
  row "${Y}OD info disabled (--no-od).${N}"
else
  if [ -n "$OD_TOTAL" ]; then
    row "${B}${OD_USED}G${N} / ${OD_TOTAL}G   Free: ${LM}${OD_FREE}G${N}   Limit: ${R}${ONEDRIVE_LIMIT}G${N}"
    row "$(fpbar "$OD_PCT" "$BARW")"
  else
    row "${R}Cannot reach OneDrive (about).${N}"
  fi
fi

# ───── SCHEDULERS BOX ─────
dmid; row "${PK}${B}★ SCHEDULERS${N}"; dmid
row "🕑 ${B}02:00${N}  🕚 ${B}11:00${N}  🕔 ${B}17:00${N}  🕘 ${B}21:00${N}"
row "${D}cron: 0 2,11,17,21 * * * sync.sh auto${N}"
row "${LM}WiFi Watcher: bash ~/sync.sh watch${N}"
dbot; echo ""

# ───── CRON SETUP ─────
setup_cron

# ───── PREVIEW/VIEW-ONLY BEHAVIOR ─────
if [ "$MODE" = "preview" ]; then
  row "${Y}Preview mode: No syncing performed.${N}"; exit 0
fi

# ───── NO-SYNC DEFAULT ─────
if [ "$OD_SYNC_ON" -ne 1 ]; then
  dtop; row "${Y}OneDrive sync is OFF (view-only).${N}"
  row "Enable later with: ${B}bash sync.sh manual --od-sync${N}"
  dbot
  log_msg "VIEW-ONLY run. No sync executed."
else
  # If you explicitly enabled --od-sync, warn & still ask user to confirm once.
  dtop; row "${R}${B}⚠ OD SYNC ENABLED VIA FLAG (--od-sync)${N}"
  row "Proceeding will mirror local→OneDrive (delete-during)."
  row "Press ${B}Ctrl+C${N} to abort within 5 seconds..."
  dbot; sleep 5

  # --- Real sync steps (only if allowed explicitly) ---
  run_sync(){
    local NAME="$1" SRC="$2" DST="$3"
    local LOG="$LOG_DIR/sync_${NAME}_$(date +%Y%m%d_%H%M%S).log"
    echo ""; dtop; row "${SB}${B}🔄 SYNCING: ${NAME}${N}"
    row "${D}SRC: ${SRC}${N}"; row "${D}DST: ${DST}${N}"; dmid
    rclone sync "$SRC" "$DST" --delete-during --log-file="$LOG" --log-level INFO --progress 2>&1 | while IFS= read -r l; do echo -e " ${D}${l}${N}"; done
    dbot; log_msg "SYNC ${NAME} (explicit)"
  }
  run_sync "Cloud-Sync-File" "$LOCAL1" "$REMOTE1"
  run_sync "HiRes_Songs"     "$LOCAL2" "$REMOTE2"
fi

# ───── FINAL SUMMARY + TELEGRAM ─────
echo ""; dtop
row "${G}${B}✅ TASK COMPLETED${N}"
dmid
row "${B}Battery     :${N} ${BAT}% (${BAT_STATUS})"
if [ "$OD_INFO_ON" -eq 1 ]; then
  row "${B}OneDrive    :${N} ${OD_USED:-N/A}G / ${OD_TOTAL:-N/A}G used"
else
  row "${B}OneDrive    :${N} Info disabled"
fi
row "${B}Log         :${N} ${D}${MASTER_LOG}${N}"
row "${B}Finished At :${N} ${O}$(date '+%H:%M:%S')${N}"
dbot; echo ""

BAT_TB=$(tbar "$BAT" $((BARW)))
OD_TB=$(tbar "$OD_PCT" $((BARW)))
REPORT="📣 <b>SYNC VIEW REPORT</b>
🔋 Battery : ${BAT}% (${BAT_STATUS})
📶 Network : ${CURRENT_WIFI:-Mobile Data}
⚙️ Mode    : ${MODE}
☁️ OneDrive: $([ "$OD_INFO_ON" -eq 1 ] && echo "${OD_USED:-N/A}G / ${OD_TOTAL:-N/A}G (Free: ${OD_FREE:-N/A}G)" || echo "Info disabled")
<b>Status</b> : $([ "$OD_SYNC_ON" -eq 1 ] && echo "SYNC RUN (explicit)" || echo "VIEW-ONLY (no sync)")
<code>${BAT_TB}</code>
<code>$([ "$OD_INFO_ON" -eq 1 ] && echo "${OD_TB}" || echo "────────────")</code>
📝 Log: ${MASTER_LOG}"
send_telegram "$REPORT"
log_msg "END (view-only=$((OD_SYNC_ON!=1)))"
