#!/data/data/com.termux/files/usr/bin/bash
########################################
# SUKRULLAH PRO SYNC v3.6 — Enhanced UI
# Termux + rclone + Telegram report
########################################

# ───── Colors (ANSI & 256-color helpers) ─────
R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
C='\033[0;36m'
M='\033[0;35m'
O='\033[38;5;214m'
LM='\033[38;5;154m'
SB='\033[38;5;39m'
PK='\033[38;5;213m'
B='\033[1m'
D='\033[2m'
N='\033[0m'

cc()      { printf "\033[38;5;%sm" "$1"; }   # 256-color set
resetc()  { printf "\033[0m"; }

# ───── Config ─────
# Prefer ENV vars (export TG_TOKEN / TG_CHAT_ID in ~/.bashrc); fallback empty
TG_TOKEN="${TG_TOKEN:-}"
TG_CHAT_ID="${TG_CHAT_ID:-}"

ALLOWED_WIFI1="Encore 2_5GHz"
ALLOWED_WIFI2="Encore2"

ONEDRIVE_LIMIT=48   # in GB (soft block before sync)

LOCAL1="$HOME/storage/shared/Cloud-Sync-File"
REMOTE1="onedrive:Cloud-Sync-File"

LOCAL2="$HOME/storage/shared/HiRes_Songs"
REMOTE2="onedrive:HiRes_Songs"

MODE=${1:-auto}
LOG_DIR="$HOME/sync_logs"
MASTER_LOG="$LOG_DIR/master_sync.log"

mkdir -p "$LOG_DIR"

# ───── Box drawing helpers (rounded) ─────
dtop() { echo -e "${C}╭────────────────────────────────────────────╮${N}"; }
dmid() { echo -e "${C}├────────────────────────────────────────────┤${N}"; }
dbot() { echo -e "${C}╰────────────────────────────────────────────╯${N}"; }
log_msg() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$MASTER_LOG"; }

# ───── Fancy gradient progress bar ─────
# value -> color (green→yellow→orange→red)
color_scale() {
  local val=$1
  if   [ "$val" -le 25 ]; then echo 46
  elif [ "$val" -le 50 ]; then echo 190
  elif [ "$val" -le 75 ]; then echo 214
  else echo 196
  fi
}

# fpbar <percent> <width>
fpbar() {
  local val=$1 width=${2:-24}
  [ "$val" -lt 0 ] && val=0
  [ "$val" -gt 100 ] && val=100

  local filled=$(( val * width / 100 ))
  [ $filled -gt $width ] && filled=$width
  local empty=$(( width - filled ))

  local left_cap="▕" right_cap="▏"
  local bar="" i c

  for (( i=1; i<=filled; i++ )); do
    local p=$(( i * 100 / width ))
    c=$(color_scale "$p")
    bar+=$(cc "$c")"█"
  done
  for (( i=1; i<=empty; i++ )); do
    bar+=$(cc 242)"░"
  done
  printf "%s%s%s %s%3d%%%s" "$left_cap" "$bar" "$(resetc)" "$(cc 250)" "$val" "$(resetc)"
}

battery_icon() {
  local pct=$1 status="$2" icon="🔋"
  case "$status" in
    CHARGING|Charging) icon="🔌" ;;
    *) if [ "$pct" -le 10 ]; then icon="🪫"; fi ;;
  esac
  printf "%s" "$icon"
}

# Telegram-friendly bar (monochrome sparkline)
tbar() {
  local val=$1 width=${2:-24}
  [ "$val" -lt 0 ] && val=0
  [ "$val" -gt 100 ] && val=100
  local filled=$(( val * width / 100 ))
  local out="" i
  for (( i=1; i<=width; i++ )); do
    if [ $i -le $filled ]; then out+="█"; else out+="·"; fi
  done
  printf "%s %3d%%" "$out" "$val"
}

send_telegram() {
  # $1: HTML text
  if [ -z "$TG_TOKEN" ] || [ -z "$TG_CHAT_ID" ]; then
    echo -e "${Y}ℹ Telegram not configured (set TG_TOKEN & TG_CHAT_ID). Skipping.${N}"
    return 0
  fi
  local txt_file
  txt_file=$(mktemp)
  printf '%s' "$1" > "$txt_file"
  local resp
  resp=$(curl -s -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
            -d "chat_id=${TG_CHAT_ID}" \
            -d "parse_mode=HTML" \
            --data-urlencode "text=$(cat "$txt_file")")
  rm -f "$txt_file"
  if echo "$resp" | grep -q '"ok":true'; then
    echo -e "${G}${B}✅ Telegram report sent successfully!${N}"
  else
    echo -e "${R}⚠ Telegram send failed${N}"
    echo "$resp" | head -3
  fi
}

# ───── CRONTAB AUTO-SETUP ─────
setup_cron() {
  # ensure 4 entries (02:00, 11:00, 17:00, 21:00)
  local CRON_CHECK
  CRON_CHECK=$(crontab -l 2>/dev/null | grep -F "sync.sh auto" | wc -l)
  if [ "${CRON_CHECK:-0}" -lt 4 ]; then
    (
      crontab -l 2>/dev/null | grep -v "sync.sh" || true
      echo "0 2  * * * bash ~/sync.sh auto >> ~/sync_logs/cron.log 2>&1"
      echo "0 11 * * * bash ~/sync.sh auto >> ~/sync_logs/cron.log 2>&1"
      echo "0 17 * * * bash ~/sync.sh auto >> ~/sync_logs/cron.log 2>&1"
      echo "0 21 * * * bash ~/sync.sh auto >> ~/sync_logs/cron.log 2>&1"
    ) | crontab -
    echo -e "${G}✅ Crontab set ho gaya! (02:00, 11:00, 17:00, 21:00)${N}"
    log_msg "Crontab auto-configured"
  fi
}

# ───── WIFI WATCHER MODE ─────
if [ "$MODE" = "watch" ]; then
  echo -e "${C}╔══════════════════════════════════════════╗${N}"
  echo -e "${C}║${N} ${B}${PK}★ WIFI WATCHER STARTED${N} ${C}║${N}"
  echo -e "${C}║${N} ${D}Watching: ${ALLOWED_WIFI1} / ${ALLOWED_WIFI2}${N}"
  echo -e "${C}║${N} ${D}Check interval: every 2 hours${N}"
  echo -e "${C}║${N} ${D}Ctrl+C to stop${N}"
  echo -e "${C}╚══════════════════════════════════════════╝${N}"
  LAST_SYNC_WIFI=""
  while true; do
    WIFI_NOW=$(termux-wifi-connectioninfo 2>/dev/null | grep '"ssid"' | cut -d'"' -f4)
    [ "$WIFI_NOW" = "\<unknown ssid\>" ] && WIFI_NOW=""
    TS=$(date '+%H:%M:%S')
    if [ "$WIFI_NOW" = "$ALLOWED_WIFI1" ] || [ "$WIFI_NOW" = "$ALLOWED_WIFI2" ]; then
      if [ "$LAST_SYNC_WIFI" != "$WIFI_NOW" ]; then
        echo -e "${G}[$TS]${N} WiFi matched: ${B}${WIFI_NOW}${N} — Syncing!"
        LAST_SYNC_WIFI="$WIFI_NOW"
        bash "$0" manual
        echo -e "${D}Next check in 2 hours...${N}"
      else
        echo -e "${D}[$TS] Already synced on '${WIFI_NOW}'. Next check in 2 hours.${N}"
      fi
    else
      SHOW="${WIFI_NOW:-Mobile Data / No WiFi}"
      echo -e "${Y}[$TS]${N} Waiting... Connected: ${B}${SHOW}${N}"
      LAST_SYNC_WIFI=""
    fi
    sleep 7200
  done
  exit 0
fi

# ───── Storage permission (Termux) ─────
if [ ! -d "$HOME/storage/shared" ]; then
  termux-setup-storage
fi

# ───── SYSTEM INFO ─────
BAT=$(termux-battery-status 2>/dev/null | grep -o '"percentage":[[:space:]]*[0-9]\+' | grep -o '[0-9]\+')
BAT=${BAT:-0}
BAT_STATUS=$(termux-battery-status 2>/dev/null | grep -o '"status":[[:space:]]*"[^"]*"' | cut -d'"' -f4)
BAT_STATUS=${BAT_STATUS:-Unknown}

CURRENT_WIFI=$(termux-wifi-connectioninfo 2>/dev/null | grep '"ssid"' | cut -d'"' -f4)
[ "$CURRENT_WIFI" = "\<unknown ssid\>" ] && CURRENT_WIFI=""

INT_RAW=$(df -h "$HOME/storage/shared" 2>/dev/null | awk 'NR==2')
INT_TOTAL=$(echo "$INT_RAW" | awk '{print $2}')
INT_USED=$(echo "$INT_RAW"  | awk '{print $3}')
INT_FREE=$(echo "$INT_RAW"  | awk '{print $4}')
INT_PCT=$(echo "$INT_RAW"   | awk '{print $5}' | tr -d '%')
INT_PCT=${INT_PCT:-0}

SD_RAW=$(df -h 2>/dev/null | grep '/storage/' | grep -v 'emulated' | head -n1)
SD_TOTAL=$(echo "$SD_RAW" | awk '{print $2}')
SD_USED=$(echo "$SD_RAW"  | awk '{print $3}')
SD_FREE=$(echo "$SD_RAW"  | awk '{print $4}')
SD_PCT=$(echo "$SD_RAW"   | awk '{print $5}' | tr -d '%')
SD_PCT=${SD_PCT:-0}

OD_INFO=$(rclone about onedrive: 2>/dev/null)
OD_TOTAL=$(echo "$OD_INFO" | grep -E '^Total:' | awk '{print $2}' | sed 's/G.*//')
OD_USED=$(echo "$OD_INFO"  | grep -E '^Used:'  | awk '{print $2}' | sed 's/G.*//')
OD_FREE=$(echo "$OD_INFO"  | grep -E '^Free:'  | awk '{print $2}' | sed 's/G.*//')

OD_PCT=0
if [ -n "$OD_TOTAL" ] && [ -n "$OD_USED" ]; then
  OD_INT=${OD_USED%.*}; OD_TOT_INT=${OD_TOTAL%.*}
  OD_INT=${OD_INT:-0};   OD_TOT_INT=${OD_TOT_INT:-1}
  [ "$OD_TOT_INT" -gt 0 ] && OD_PCT=$(( OD_INT * 100 / OD_TOT_INT ))
fi

NOW=$(date '+%Y-%m-%d %H:%M:%S')
DAY=$(date '+%A')

# ───── WIFI CHECK — auto mode only ─────
if [ "$MODE" = "auto" ]; then
  if [ "$CURRENT_WIFI" != "$ALLOWED_WIFI1" ] && [ "$CURRENT_WIFI" != "$ALLOWED_WIFI2" ]; then
    clear
    WSHOW="${CURRENT_WIFI:-Mobile Data}"
    dtop
    echo -e "${C}│${N} ${R}${B}⛔ SYNC BLOCKED - WRONG NETWORK${N} ${C}│${N}"
    dmid
    echo -e "${C}│${N} ${Y}Connected :${N} ${WSHOW}"
    echo -e "${C}│${N} ${G}Allowed   :${N} ${ALLOWED_WIFI1} / ${ALLOWED_WIFI2} ${C}│${N}"
    dmid
    echo -e "${C}│${N} ${D}sync.sh manual = any WiFi${N} ${C}│${N}"
    echo -e "${C}│${N} ${D}sync.sh force  = Mobile Data${N} ${C}│${N}"
    echo -e "${C}│${N} ${D}sync.sh watch  = auto WiFi watcher${N} ${C}│${N}"
    dbot
    log_msg "BLOCKED - Wrong WiFi: ${CURRENT_WIFI:-Mobile Data}"
    exit 0
  fi
fi

# ───── ASCII HEADER ─────
clear
echo ""
echo -e "${M}${B}"
echo " ███████╗██╗  ██╗██╗  ██╗██████╗  ██╗  ██╗██╗  ██╗ █████╗ ██╗  ██╗"
echo " ██╔════╝██║  ██║██║  ██╔╝██╔══██╗██║  ██║██║  ██║ ██╔══██╗██║  ██║"
echo " ███████╗██║  ██║█████╔╝ ██████╔╝██║  ██║██║  ██║ ███████║███████║"
echo " ╚════██║██║  ██║██╔═██╗ ██╔══██╗██║  ██║██║  ██║ ██╔══██║██╔══██║"
echo " ███████║╚██████╔╝██║  ██╗██║  ██║╚██████╔╝███████╗███████╗██║  ██║██║  ██║"
echo " ╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝"
echo -e "${N}"
echo -e "  ${SB}${B}PRO SYNC SYSTEM v3.6${N}  ${D}• ${O}${DAY}, ${NOW}${N}"
echo ""

# ───── SYSTEM STATUS BOX ─────
dtop
echo -e "${C}│${N} ${B}${PK}★ SYSTEM STATUS${N} ${C}│${N}"
dmid
echo -e "${C}│${N} $(battery_icon "$BAT" "$BAT_STATUS") ${B}Battery${N} ${Y}${BAT}% (${BAT_STATUS})${N}"
echo -e "${C}│${N} $(fpbar "$BAT" 28)"
if [ "$MODE" = "force" ]; then
  echo -e "${C}│${N} 📡 ${B}Network${N} ${R}Mobile Data (Force Mode)${N} ${C}│${N}"
elif [ -n "$CURRENT_WIFI" ]; then
  echo -e "${C}│${N} 📡 ${B}Network${N} ${G}${CURRENT_WIFI}${N}"
else
  echo -e "${C}│${N} 📡 ${B}Network${N} ${Y}Mobile Data${N} ${C}│${N}"
fi
case "$MODE" in
  force)  echo -e "${C}│${N} ⚙ ${B}Mode${N} ${R}${B}[ FORCE ]${N} ${C}│${N}";;
  manual) echo -e "${C}│${N} ⚙ ${B}Mode${N} ${Y}${B}[ MANUAL ]${N} ${C}│${N}";;
  *)      echo -e "${C}│${N} ⚙ ${B}Mode${N} ${G}${B}[ AUTO ]${N} ${C}│${N}";;
esac

# ───── STORAGE BOX ─────
dmid
echo -e "${C}│${N} ${B}${PK}★ STORAGE OVERVIEW${N} ${C}│${N}"
dmid

echo -e "${C}│${N} ${O}${B}📱 Internal Storage${N}"
echo -e "${C}│${N} ${B}${INT_USED}${N} / ${INT_TOTAL}  Free: ${LM}${INT_FREE}${N}"
echo -e "${C}│${N} $(fpbar "$INT_PCT" 30)"

echo -e "${C}│${N} ${SB}${B}💾 SD Card${N}"
if [ -n "$SD_RAW" ]; then
  echo -e "${C}│${N} ${B}${SD_USED}${N} / ${SD_TOTAL}  Free: ${LM}${SD_FREE}${N}"
  echo -e "${C}│${N} $(fpbar "$SD_PCT" 30)"
else
  echo -e "${C}│${N} ${D}Not Found${N}"
fi

echo -e "${C}│${N} ${M}${B}☁ OneDrive${N}"
if [ -n "$OD_TOTAL" ]; then
  echo -e "${C}│${N} ${B}${OD_USED}G${N} / ${OD_TOTAL}G  Free: ${LM}${OD_FREE}G${N}  Limit: ${R}${ONEDRIVE_LIMIT}G${N}"
  echo -e "${C}│${N} $(fpbar "$OD_PCT" 30)"
else
  echo -e "${C}│${N} ${R}Cannot reach OneDrive${N}"
fi

# ───── SCHEDULERS BOX ─────
dmid
echo -e "${C}│${N} ${B}${PK}★ SCHEDULERS${N} ${C}│${N}"
dmid
echo -e "${C}│${N} 🕑 ${B}02:00${N}  🕚 ${B}11:00${N}  🕔 ${B}17:00${N}  🕘 ${B}21:00${N} ${C}│${N}"
echo -e "${C}│${N} ${D}cron: 0 2,11,17,21 * * * sync.sh auto${N} ${C}│${N}"
echo -e "${C}│${N} ${LM}WiFi Watcher: bash ~/sync.sh watch${N} ${C}│${N}"
dbot
echo ""

# ───── CRONTAB AUTO SETUP ─────
setup_cron

# ───── ONEDRIVE LIMIT CHECK ─────
OD_USED_INT=${OD_USED%.*}; OD_USED_INT=${OD_USED_INT:-0}
if [ -n "$OD_USED_INT" ] && [ "$OD_USED_INT" -ge "$ONEDRIVE_LIMIT" ] 2>/dev/null; then
  dtop
  echo -e "${C}│${N} ${R}${B}⛔ ONEDRIVE LIMIT REACHED — STOPPED${N} ${C}│${N}"
  echo -e "${C}│${N} Used: ${OD_USED}G / Limit: ${ONEDRIVE_LIMIT}G"
  dbot
  log_msg "ABORTED - OneDrive limit: ${OD_USED}G / ${ONEDRIVE_LIMIT}G"
  send_telegram "⛔ <b>SYNC ABORTED</b> — OneDrive limit reached
Used: ${OD_USED}G / Limit: ${ONEDRIVE_LIMIT}G"
  exit 0
fi

# ───── SYNC FUNCTION ─────
SUMMARY=""
TOTAL_UPLOADED=0
TOTAL_DELETED=0

run_sync() {
  local NAME="$1" SRC="$2" DST="$3"
  local LOG="$LOG_DIR/sync_${NAME}_$(date +%Y%m%d_%H%M%S).log"

  echo ""
  dtop
  echo -e "${C}│${N} ${SB}${B}🔄 SYNCING: ${NAME}${N}"
  echo -e "${C}│${N} ${D}SRC: ${SRC}${N}"
  echo -e "${C}│${N} ${D}DST: ${DST}${N}"
  dmid

  # Run rclone with progress; mirror logs to console (dim)
  rclone sync "$SRC" "$DST" \
    --delete-during \
    --log-file="$LOG" \
    --log-level INFO \
    --progress 2>&1 | while IFS= read -r line; do
      echo -e " ${D}${line}${N}"
    done

  local UP_LIST="" DEL_LIST="" UP_COUNT=0 DEL_COUNT=0
  if [ -f "$LOG" ]; then
    UP_LIST=$(grep ": Copied (new)" "$LOG" 2>/dev/null | awk '{print $5}' | sed 's/:$//' | grep -v '^$' || true)
    DEL_LIST=$(grep ": Deleted" "$LOG" 2>/dev/null | grep -v -E "stats|Checks|Transferred" | awk '{print $5}' | sed 's/:$//' | grep -v '^$' || true)
  fi

  [ -n "$UP_LIST" ]  && UP_COUNT=$(printf '%s\n' "$UP_LIST" | wc -l | tr -d ' ')
  [ -n "$DEL_LIST" ] && DEL_COUNT=$(printf '%s\n' "$DEL_LIST" | wc -l | tr -d ' ')
  UP_COUNT=$(( UP_COUNT + 0 ))
  DEL_COUNT=$(( DEL_COUNT + 0 ))
  TOTAL_UPLOADED=$(( TOTAL_UPLOADED + UP_COUNT ))
  TOTAL_DELETED=$(( TOTAL_DELETED + DEL_COUNT ))

  echo -e "${C}│${N} ${G}${B}✅ Done!${N} Uploaded: ${LM}${B}${UP_COUNT}${N} │ Deleted: ${R}${B}${DEL_COUNT}${N}"

  if [ "$UP_COUNT" -gt 0 ] && [ -n "$UP_LIST" ]; then
    dmid
    echo -e "${C}│${N} ${LM}${B}📤 UPLOADED FILES (${UP_COUNT})${N}"
    printf '%s\n' "$UP_LIST" | head -20 | while IFS= read -r f; do
      [ -z "$f" ] && continue
      echo -e "${C}│${N} ${G}+${N} ${f}"
    done
    [ "$UP_COUNT" -gt 20 ] && echo -e "${C}│${N} ${D}... and $(( UP_COUNT - 20 )) more${N}"
  fi

  if [ "$DEL_COUNT" -gt 0 ] && [ -n "$DEL_LIST" ]; then
    dmid
    echo -e "${C}│${N} ${R}${B}🗑 DELETED FILES (${DEL_COUNT})${N}"
    printf '%s\n' "$DEL_LIST" | head -20 | while IFS= read -r f; do
      [ -z "$f" ] && continue
      echo -e "${C}│${N} ${R}-${N} ${f}"
    done
    [ "$DEL_COUNT" -gt 20 ] && echo -e "${C}│${N} ${D}... and $(( DEL_COUNT - 20 )) more${N}"
  fi

  dbot

  SUMMARY="${SUMMARY}
📂 ${NAME}
📤 Uploaded (${UP_COUNT}):
${UP_LIST:- None}
🗑 Deleted (${DEL_COUNT}):
${DEL_LIST:- None}
────────────────────────────"
  log_msg "SYNC ${NAME} Uploaded:${UP_COUNT} Deleted:${DEL_COUNT}"
}

# ───── RUN SYNCS ─────
log_msg "START Mode:${MODE} WiFi:${CURRENT_WIFI:-Mobile} Battery:${BAT}%"
run_sync "Cloud-Sync-File" "$LOCAL1" "$REMOTE1"
run_sync "HiRes_Songs"     "$LOCAL2" "$REMOTE2"

# ───── FINAL SUMMARY BOX ─────
echo ""
dtop
echo -e "${C}│${N} ${G}${B}✅ ALL SYNCS COMPLETED SUCCESSFULLY!${N} ${C}│${N}"
dmid
echo -e "${C}│${N} ${B}Total Uploaded :${N} ${LM}${B}${TOTAL_UPLOADED}${N} files"
echo -e "${C}│${N} ${B}Total Deleted  :${N} ${R}${B}${TOTAL_DELETED}${N} files"
echo -e "${C}│${N} ${B}Battery        :${N} ${BAT}% (${BAT_STATUS})"
echo -e "${C}│${N} ${B}OneDrive       :${N} ${OD_USED:-N/A}G / ${OD_TOTAL:-N/A}G used"
echo -e "${C}│${N} ${B}Log            :${N} ${D}${MASTER_LOG}${N}"
echo -e "${C}│${N} ${B}Finished At    :${N} ${O}$(date '+%H:%M:%S')${N}"
dbot
echo ""

# ───── TELEGRAM REPORT ─────
BAT_TB=$(tbar "$BAT" 24)
INT_TB=$(tbar "$INT_PCT" 24)
SD_TB=$(tbar "$SD_PCT" 24)
OD_TB=$(tbar "$OD_PCT" 24)

REPORT="🚀 <b>SUKRULLAH PRO SYNC COMPLETED</b>
📊 <b>SYSTEM</b>
$(battery_icon "$BAT" "$BAT_STATUS") Battery : ${BAT}% (${BAT_STATUS})
<code>${BAT_TB}</code>
📶 Network : ${CURRENT_WIFI:-Mobile Data}
⚙️ Mode    : ${MODE}
🕒 Time    : $(date '+%d %b %Y, %H:%M:%S')

💾 <b>STORAGE</b>
📱 Internal : ${INT_USED} / ${INT_TOTAL} (Free: ${INT_FREE})
<code>${INT_TB}</code>
💾 SD Card  : ${SD_USED:-N/A} / ${SD_TOTAL:-N/A} (Free: ${SD_FREE:-N/A})
<code>${SD_TB}</code>
☁️ OneDrive : ${OD_USED:-N/A}G / ${OD_TOTAL:-N/A}G (Free: ${OD_FREE:-N/A}G)
<code>${OD_TB}</code>

📁 <b>RESULTS</b>
📤 Uploaded : ${TOTAL_UPLOADED} files
🗑 Deleted  : ${TOTAL_DELETED} files

📋 <b>DETAILS</b>
${SUMMARY}

📝 Log: ${MASTER_LOG}"

echo -e "${SB}📡 Sending Telegram report...${N}"
send_telegram "$REPORT"
log_msg "END Uploaded:${TOTAL_UPLOADED} Deleted:${TOTAL_DELETED}"
