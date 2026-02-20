#!/data/data/com.termux/files/usr/bin/bash
##############################################
# SUKRULLAH PRO SYNC v3.7 — Mobile-Optimized
# Termux + rclone + Telegram (OD toggle + UI fix)
##############################################

# ───── Colors ─────
R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; C='\033[0;36m'
M='\033[0;35m'; O='\033[38;5;214m'; LM='\033[38;5;154m'; SB='\033[38;5;39m'
PK='\033[38;5;213m'; B='\033[1m'; D='\033[2m'; N='\033[0m'

# 256‑color helpers
cc()     { printf "\033[38;5;%sm" "$1"; }
resetc() { printf "\033[0m"; }

# ───── Config (edit as you like) ─────
# Prefer ENV for secrets: export TG_TOKEN=... ; export TG_CHAT_ID=...
TG_TOKEN="${TG_TOKEN:-}"
TG_CHAT_ID="${TG_CHAT_ID:-}"

ALLOWED_WIFI1="Encore 2_5GHz"
ALLOWED_WIFI2="Encore2"

# OneDrive soft limit (GB)
ONEDRIVE_LIMIT=48

# Paths (LOCAL -> REMOTE). NOTE: Both go to OneDrive remote.
LOCAL1="$HOME/storage/shared/Cloud-Sync-File"
REMOTE1="onedrive:Cloud-Sync-File"

LOCAL2="$HOME/storage/shared/HiRes_Songs"
REMOTE2="onedrive:HiRes_Songs"

# Default mode + feature toggles
MODE="auto"           # auto | manual | force | watch | preview
SYNC_OD=1             # 1 = allow syncing to OneDrive, 0 = skip rclone sync
                      # You can override at runtime: --no-od (sets SYNC_OD=0)
# Optional: SKIP_OD=1 in ENV will also disable OD sync
[ -n "$SKIP_OD" ] && SYNC_OD=0

# Logs
LOG_DIR="$HOME/sync_logs"
MASTER_LOG="$LOG_DIR/master_sync.log"
mkdir -p "$LOG_DIR"

# ───── Parse CLI args ─────
# Examples:
#   bash sync.sh               -> auto (Wi‑Fi gated)
#   bash sync.sh manual        -> run on current network
#   bash sync.sh force         -> allow mobile data
#   bash sync.sh auto --no-od  -> UI + checks + NO rclone sync
#   bash sync.sh preview       -> UI only (no sync)
if [ -n "$1" ]; then MODE="$1"; fi
for arg in "$@"; do
  case "$arg" in
    --no-od|--no-onedrive|nood) SYNC_OD=0 ;;
  esac
done

# ───── Mobile-friendly UI width (fits 20:9 1080×2400) ─────
# Use terminal columns; keep boxes compact so they don't wrap.
COLS=$(tput cols 2>/dev/null || echo 80)
# Inner content width (without borders). Keep between 46..72 for most phones.
if   [ "$COLS" -ge 90 ]; then BOXW=72
elif [ "$COLS" -ge 70 ]; then BOXW=60
else BOXW=50
fi
# Progress bar width derives from box width
# Keep a little margin so percent text never wraps.
if   [ "$BOXW" -ge 70 ]; then BARW=42
elif [ "$BOXW" -ge 60 ]; then BARW=36
else BARW=28
fi

# ───── Box helpers (rounded + dynamic width) ─────
line() { # $1=char  $2=repeat
  local c="$1" n="$2"; printf "%*s" "$n" "" | tr ' ' "$c"
}
dtop() { echo -e "${C}╭$(line ─ "$BOXW")╮${N}"; }
dmid() { echo -e "${C}├$(line ─ "$BOXW")┤${N}"; }
dbot() { echo -e "${C}╰$(line ─ "$BOXW")╯${N}"; }
row()  { # prints with left/right borders; DOES NOT hard-truncate color codes
  # Ensure your content string stays within ~$BOXW chars to avoid wraps.
  echo -e "${C}│${N} $1"
}

log_msg() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$MASTER_LOG"; }

# ───── Gradient progress bar (fits BARW) ─────
color_scale() {
  local v=$1
  if   [ "$v" -le 25 ]; then echo 46
  elif [ "$v" -le 50 ]; then echo 190
  elif [ "$v" -le 75 ]; then echo 214
  else echo 196
  fi
}
fpbar() { # fpbar <percent> [width]
  local val=$1 width=${2:-$BARW}
  [ "$val" -lt 0 ] && val=0
  [ "$val" -gt 100 ] && val=100
  local filled=$(( val * width / 100 ))
  [ $filled -gt $width ] && filled=$width
  local empty=$(( width - filled ))
  local bar="" i c
  for (( i=1; i<=filled; i++ )); do
    local p=$(( i * 100 / width ))
    c=$(color_scale "$p"); bar+=$(cc "$c")"█"
  done
  for (( i=1; i<=empty; i++ )); do bar+=$(cc 242)"░"; done
  printf "▕%s%s %s%3d%%%s" "$bar" "$(resetc)" "$(cc 250)" "$val" "$(resetc)"
}

battery_icon() {
  local pct=$1 status="$2" icon="🔋"
  case "$status" in
    CHARGING|Charging) icon="🔌" ;;
    *) if [ "$pct" -le 10 ]; then icon="🪫"; fi ;;
  esac
  printf "%s" "$icon"
}

# Telegram-friendly bar (monochrome)
tbar() {
  local val=$1 width=${2:-$((BARW-4))}
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
  [ -z "$TG_TOKEN" ] || [ -z "$TG_CHAT_ID" ] && return 0
  local msg="$1" f resp
  f=$(mktemp); printf '%s' "$msg" > "$f"
  resp=$(curl -s -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
            -d "chat_id=${TG_CHAT_ID}" \
            -d "parse_mode=HTML" \
            --data-urlencode "text=$(cat "$f")")
  rm -f "$f"
  echo "$resp" | grep -q '"ok":true' || { echo -e "${Y}ℹ Telegram send skipped/failed.${N}"; }
}

# ───── CRONTAB AUTO-SETUP ─────
setup_cron() {
  local count
  count=$(crontab -l 2>/dev/null | grep -F "sync.sh auto" | wc -l)
  if [ "${count:-0}" -lt 4 ]; then
    (
      crontab -l 2>/dev/null | grep -v "sync.sh" || true
      echo "0 2  * * * bash ~/sync.sh auto >> ~/sync_logs/cron.log 2>&1"
      echo "0 11 * * * bash ~/sync.sh auto >> ~/sync_logs/cron.log 2>&1"
      echo "0 17 * * * bash ~/sync.sh auto >> ~/sync_logs/cron.log 2>&1"
      echo "0 21 * * * bash ~/sync.sh auto >> ~/sync_logs/cron.log 2>&1"
    ) | crontab -
    row "${G}✅ Crontab set: 02:00, 11:00, 17:00, 21:00${N}"
    log_msg "Crontab auto-configured"
  fi
}

# ───── WIFI WATCHER ─────
if [ "$MODE" = "watch" ]; then
  row "${PK}${B}★ WIFI WATCHER STARTED${N}"
  row "${D}Watching: ${ALLOWED_WIFI1} / ${ALLOWED_WIFI2}${N}"
  row "${D}Interval: every 2 hours — Ctrl+C to stop${N}"
  LAST_SYNC_WIFI=""
  while true; do
    WIFI_NOW=$(termux-wifi-connectioninfo 2>/dev/null | grep '"ssid"' | cut -d'"' -f4)
    [ "$WIFI_NOW" = "\<unknown ssid\>" ] && WIFI_NOW=""
    TS=$(date '+%H:%M:%S')
    if [ "$WIFI_NOW" = "$ALLOWED_WIFI1" ] || [ "$WIFI_NOW" = "$ALLOWED_WIFI2" ]; then
      if [ "$LAST_SYNC_WIFI" != "$WIFI_NOW" ]; then
        echo -e "${G}[$TS]${N} WiFi matched: ${B}${WIFI_NOW}${N} — Syncing!"
        LAST_SYNC_WIFI="$WIFI_NOW"
        bash "$0" manual "$([ $SYNC_OD -eq 0 ] && echo --no-od)"
      else
        echo -e "${D}[$TS] Already synced on '${WIFI_NOW}'. Next: 2h.${N}"
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

# ───── Termux storage permission ─────
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

# Only query OneDrive 'about' if OD sync is enabled; keeps things faster/safer
OD_INFO=""; OD_TOTAL=""; OD_USED=""; OD_FREE=""; OD_PCT=0
if [ "$SYNC_OD" -eq 1 ]; then
  OD_INFO=$(rclone about onedrive: 2>/dev/null)
  OD_TOTAL=$(echo "$OD_INFO" | grep -E '^Total:' | awk '{print $2}' | sed 's/G.*//')
  OD_USED=$(echo "$OD_INFO"  | grep -E '^Used:'  | awk '{print $2}' | sed 's/G.*//')
  OD_FREE=$(echo "$OD_INFO"  | grep -E '^Free:'  | awk '{print $2}' | sed 's/G.*//')
  if [ -n "$OD_TOTAL" ] && [ -n "$OD_USED" ]; then
    OD_INT=${OD_USED%.*}; OD_TOT_INT=${OD_TOTAL%.*}
    OD_INT=${OD_INT:-0};   OD_TOT_INT=${OD_TOT_INT:-1}
    [ "$OD_TOT_INT" -gt 0 ] && OD_PCT=$(( OD_INT * 100 / OD_TOT_INT ))
  fi
fi

NOW=$(date '+%Y-%m-%d %H:%M:%S'); DAY=$(date '+%A')

# ───── WIFI gate — auto only ─────
if [ "$MODE" = "auto" ]; then
  if [ "$CURRENT_WIFI" != "$ALLOWED_WIFI1" ] && [ "$CURRENT_WIFI" != "$ALLOWED_WIFI2" ]; then
    clear; dtop
    row "${R}${B}⛔ SYNC BLOCKED - WRONG NETWORK${N}"
    dmid
    row "${Y}Connected :${N} ${CURRENT_WIFI:-Mobile Data}"
    row "${G}Allowed   :${N} ${ALLOWED_WIFI1} / ${ALLOWED_WIFI2}"
    dmid
    row "${D}sync.sh manual  → any WiFi${N}"
    row "${D}sync.sh force   → allow Mobile Data${N}"
    row "${D}sync.sh preview → UI only (no sync)${N}"
    dbot
    log_msg "BLOCKED - Wrong WiFi: ${CURRENT_WIFI:-Mobile}"
    exit 0
  fi
fi

# ───── HEADER (compact on small terminals) ─────
clear
if [ "$COLS" -ge 84 ]; then
  echo -e "${M}${B}"
  echo " ███████╗██╗  ██╗██╗  ██╗██████╗  ██╗  ██╗██╗  ██╗ █████╗ ██╗  ██╗"
  echo " ██╔════╝██║  ██║██║  ██╔╝██╔══██╗██║  ██║██║  ██║ ██╔══██╗██║  ██║"
  echo " ███████╗██║  ██║█████╔╝ ██████╔╝██║  ██║██║  ██║ ███████║███████║"
  echo " ╚════██║██║  ██║██╔═██╗ ██╔══██╗██║  ██║██║  ██║ ██╔══██║██╔══██║"
  echo " ███████║╚██████╔╝██║  ██╗██║  ██║╚██████╔╝███████╗███████╗██║  ██║██║  ██║"
  echo " ╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝"
  echo -e "${N}"
fi
echo -e "  ${SB}${B}PRO SYNC SYSTEM v3.7${N}  ${D}• ${O}${DAY}, ${NOW}${N}"
echo ""

# ───── SYSTEM STATUS BOX ─────
dtop
row "${PK}${B}★ SYSTEM STATUS${N}"
dmid
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
dmid
row "${PK}${B}★ STORAGE OVERVIEW${N}"
dmid
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
if [ "$SYNC_OD" -eq 0 ]; then
  row "${Y}OneDrive sync is disabled (--no-od).${N}"
else
  if [ -n "$OD_TOTAL" ]; then
    row "${B}${OD_USED}G${N} / ${OD_TOTAL}G   Free: ${LM}${OD_FREE}G${N}   Limit: ${R}${ONEDRIVE_LIMIT}G${N}"
    row "$(fpbar "$OD_PCT" "$BARW")"
  else
    row "${R}Cannot reach OneDrive (about).${N}"
  fi
fi

# ───── SCHEDULERS BOX ─────
dmid
row "${PK}${B}★ SCHEDULERS${N}"
dmid
row "🕑 ${B}02:00${N}  🕚 ${B}11:00${N}  🕔 ${B}17:00${N}  🕘 ${B}21:00${N}"
row "${D}cron: 0 2,11,17,21 * * * sync.sh auto${N}"
row "${LM}WiFi Watcher: bash ~/sync.sh watch${N}"
dbot
echo ""

# ───── CRONTAB AUTO SETUP ─────
setup_cron

# ───── OD LIMIT GUARD ─────
if [ "$SYNC_OD" -eq 1 ]; then
  OD_USED_INT=${OD_USED%.*}; OD_USED_INT=${OD_USED_INT:-0}
  if [ -n "$OD_USED_INT" ] && [ "$OD_USED_INT" -ge "$ONEDRIVE_LIMIT" ] 2>/dev/null; then
    dtop
    row "${R}${B}⛔ ONEDRIVE LIMIT REACHED — STOPPED${N}"
    row "Used: ${OD_USED}G / Limit: ${ONEDRIVE_LIMIT}G"
    dbot
    log_msg "ABORTED - OneDrive limit: ${OD_USED}G / ${ONEDRIVE_LIMIT}G"
    send_telegram "⛔ <b>SYNC ABORTED</b> — OneDrive limit
Used: ${OD_USED}G / Limit: ${ONEDRIVE_LIMIT}G"
    exit 0
  fi
fi

# ───── PREVIEW MODE: stop before syncing ─────
if [ "$MODE" = "preview" ]; then
  row "${Y}Preview mode: No syncing performed.${N}"
  exit 0
fi

# ───── SYNC FUNCTION ─────
SUMMARY=""; TOTAL_UPLOADED=0; TOTAL_DELETED=0

run_sync() {
  local NAME="$1" SRC="$2" DST="$3"
  local LOG="$LOG_DIR/sync_${NAME}_$(date +%Y%m%d_%H%M%S).log"

  echo ""; dtop
  row "${SB}${B}🔄 SYNCING: ${NAME}${N}"
  row "${D}SRC: ${SRC}${N}"
  row "${D}DST: ${DST}${N}"
  dmid

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
  UP_COUNT=$(( UP_COUNT + 0 )); DEL_COUNT=$(( DEL_COUNT + 0 ))
  TOTAL_UPLOADED=$(( TOTAL_UPLOADED + UP_COUNT ))
  TOTAL_DELETED=$(( TOTAL_DELETED + DEL_COUNT ))

  row "${G}${B}✅ Done!${N} Uploaded: ${LM}${B}${UP_COUNT}${N} │ Deleted: ${R}${B}${DEL_COUNT}${N}"

  if [ "$UP_COUNT" -gt 0 ] && [ -n "$UP_LIST" ]; then
    dmid; row "${LM}${B}📤 UPLOADED FILES (${UP_COUNT})${N}"
    printf '%s\n' "$UP_LIST" | head -20 | while IFS= read -r f; do
      [ -z "$f" ] && continue; row "${G}+${N} ${f}"
    done
    [ "$UP_COUNT" -gt 20 ] && row "${D}... and $(( UP_COUNT - 20 )) more${N}"
  fi

  if [ "$DEL_COUNT" -gt 0 ] && [ -n "$DEL_LIST" ]; then
    dmid; row "${R}${B}🗑 DELETED FILES (${DEL_COUNT})${N}"
    printf '%s\n' "$DEL_LIST" | head -20 | while IFS= read -r f; do
      [ -z "$f" ] && continue; row "${R}-${N} ${f}"
    done
    [ "$DEL_COUNT" -gt 20 ] && row "${D}... and $(( DEL_COUNT - 20 )) more${N}"
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

# ───── RUN SYNCS (respect OD toggle) ─────
log_msg "START Mode:${MODE} WiFi:${CURRENT_WIFI:-Mobile} Battery:${BAT}%"

if [ "$SYNC_OD" -eq 1 ]; then
  run_sync "Cloud-Sync-File" "$LOCAL1" "$REMOTE1"
  run_sync "HiRes_Songs"     "$LOCAL2" "$REMOTE2"
else
  # When OD sync disabled, still show a gentle message
  dtop
  row "${Y}OneDrive sync skipped (--no-od).${N}"
  row "You can enable it by removing --no-od flag or setting SYNC_OD=1."
  dbot
fi

# ───── FINAL SUMMARY BOX ─────
echo ""; dtop
row "${G}${B}✅ ALL TASKS COMPLETED${N}"
dmid
row "${B}Total Uploaded :${N} ${LM}${B}${TOTAL_UPLOADED}${N} files"
row "${B}Total Deleted  :${N} ${R}${B}${TOTAL_DELETED}${N} files"
row "${B}Battery        :${N} ${BAT}% (${BAT_STATUS})"
if [ "$SYNC_OD" -eq 1 ]; then
  row "${B}OneDrive       :${N} ${OD_USED:-N/A}G / ${OD_TOTAL:-N/A}G used"
else
  row "${B}OneDrive       :${N} Sync disabled"
fi
row "${B}Log            :${N} ${D}${MASTER_LOG}${N}"
row "${B}Finished At    :${N} ${O}$(date '+%H:%M:%S')${N}"
dbot
echo ""

# ───── TELEGRAM REPORT ─────
BAT_TB=$(tbar "$BAT" $((BARW)))
INT_TB=$(tbar "$INT_PCT" $((BARW)))
SD_TB=$(tbar "$SD_PCT" $((BARW)))
OD_TB=$(tbar "$OD_PCT" $((BARW)))

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
☁️ OneDrive : $([ "$SYNC_OD" -eq 1 ] && echo "${OD_USED:-N/A}G / ${OD_TOTAL:-N/A}G (Free: ${OD_FREE:-N/A}G)" || echo "Sync disabled")
<code>$([ "$SYNC_OD" -eq 1 ] && echo "${OD_TB}" || echo "──────────────")</code>

📁 <b>RESULTS</b>
📤 Uploaded : ${TOTAL_UPLOADED} files
🗑 Deleted  : ${TOTAL_DELETED} files

📋 <b>DETAILS</b>
${SUMMARY}

📝 Log: ${MASTER_LOG}"

send_telegram "$REPORT"
log_msg "END Uploaded:${TOTAL_UPLOADED} Deleted:${TOTAL_DELETED}"
