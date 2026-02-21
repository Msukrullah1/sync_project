#!/data/data/com.termux/files/usr/bin/bash
########################################
# SUKRULLAH PRO SYNC v4.1
# Main controller — calls dashboard & telegram
########################################
source "$HOME/sync_project/.env"

# ───── Config ─────
ALLOWED_WIFI1="Encore 2_5GHz"
ALLOWED_WIFI2="Encore2"
ZOHO_REMOTE="zoho:"
ZOHO_TOTAL_GB=55
ZOHO_SYNC=1
ZOHO_LIMIT_PCT=95
LOCAL1="$HOME/storage/shared/Cloud-Sync-File"
REMOTE1="zoho:Cloud-Sync-File"
LOCAL2="/storage/emulated/0/HiRes_Songs"
REMOTE2="zoho:HIRES_SONGS"
OD_INFO_ON=1
MODE="auto"
[ -n "$1" ] && MODE="$1"
for arg in "$@"; do
  case "$arg" in --no-od) OD_INFO_ON=0 ;; esac
done

export ALLOWED_WIFI1 ALLOWED_WIFI2 ZOHO_REMOTE ZOHO_TOTAL_GB
export ZOHO_SYNC ZOHO_LIMIT_PCT LOCAL1 REMOTE1 LOCAL2 REMOTE2
export OD_INFO_ON MODE

# ───── Paths ─────
LOG_DIR="$HOME/sync_logs"
MASTER_LOG="$LOG_DIR/master_sync.log"
mkdir -p "$LOG_DIR"
export LOG_DIR MASTER_LOG

log_msg() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$MASTER_LOG"; }

# ───── Storage permission ─────
[ -d "$HOME/storage/shared" ] || termux-setup-storage

# ───── WATCH MODE ─────
if [ "$MODE" = "watch" ]; then
  bash "$HOME/sync_project/dashboard.sh" watch
  exit 0
fi

# ───── Gather info ─────
BAT=$(termux-battery-status 2>/dev/null | grep -o '"percentage":[[:space:]]*[0-9]\+' | grep -o '[0-9]\+'); BAT=${BAT:-0}
BAT_STATUS=$(termux-battery-status 2>/dev/null | grep -o '"status":[[:space:]]*"[^"]*"' | cut -d'"' -f4); BAT_STATUS=${BAT_STATUS:-Unknown}
CURRENT_WIFI=$(termux-wifi-connectioninfo 2>/dev/null | grep '"ssid"' | tail -1 | cut -d'"' -f4)
[ "$CURRENT_WIFI" = "<unknown ssid>" ] && CURRENT_WIFI=""

INT_RAW=$(df -h /storage/emulated/0 2>/dev/null | awk 'NR==2')
[ -z "$INT_RAW" ] && INT_RAW=$(df -h "$HOME/storage/shared" 2>/dev/null | awk 'NR==2')INT_TOTAL=$(echo "$INT_RAW" | awk '{print $2}')
INT_USED=$(echo "$INT_RAW"  | awk '{print $3}')
INT_FREE=$(echo "$INT_RAW"  | awk '{print $4}')
INT_PCT=$(echo "$INT_RAW"   | awk '{print $5}' | tr -d '%'); INT_PCT=${INT_PCT:-0}

SD_RAW=$(df -h 2>/dev/null | grep '/storage/' | grep -v 'emulated' | head -n1)
SD_TOTAL=$(echo "$SD_RAW" | awk '{print $2}')
SD_USED=$(echo "$SD_RAW"  | awk '{print $3}')
SD_FREE=$(echo "$SD_RAW"  | awk '{print $4}')
SD_PCT=$(echo "$SD_RAW"   | awk '{print $5}' | tr -d '%'); SD_PCT=${SD_PCT:-0}

ZOHO_RAW=$(rclone about "$ZOHO_REMOTE" 2>/dev/null)
ZOHO_USED=$(echo "$ZOHO_RAW" | grep -i '^Used' | awk '{print $2}'); ZOHO_USED=${ZOHO_USED%.*}; ZOHO_USED=${ZOHO_USED:-0}
ZOHO_FREE=$(( ZOHO_TOTAL_GB - ZOHO_USED ))
[ "$ZOHO_FREE" -lt 0 ] && ZOHO_FREE=0
ZOHO_PCT=$(( ZOHO_USED * 100 / ZOHO_TOTAL_GB ))

OD_TOTAL=""; OD_USED_G=""; OD_FREE_G=""; OD_PCT=0
if [ "$OD_INFO_ON" -eq 1 ]; then
  OD_RAW=$(rclone about onedrive: 2>/dev/null)
  OD_TOTAL=$(echo "$OD_RAW" | grep -E '^Total:' | awk '{print $2}' | sed 's/G.*//')
  OD_USED_G=$(echo "$OD_RAW" | grep -E '^Used:'  | awk '{print $2}' | sed 's/G.*//')
  OD_FREE_G=$(echo "$OD_RAW" | grep -E '^Free:'  | awk '{print $2}' | sed 's/G.*//')
  if [ -n "$OD_TOTAL" ] && [ -n "$OD_USED_G" ]; then
    OD_U=${OD_USED_G%.*}; OD_T=${OD_TOTAL%.*}
    OD_U=${OD_U:-0}; OD_T=${OD_T:-1}
    [ "$OD_T" -gt 0 ] && OD_PCT=$(( OD_U * 100 / OD_T ))
  fi
fi

export BAT BAT_STATUS CURRENT_WIFI
export INT_TOTAL INT_USED INT_FREE INT_PCT
export SD_RAW SD_TOTAL SD_USED SD_FREE SD_PCT
export ZOHO_RAW ZOHO_USED ZOHO_FREE ZOHO_PCT
export OD_TOTAL OD_USED_G OD_FREE_G OD_PCT

# ───── Show dashboard ─────
bash "$HOME/sync_project/dashboard.sh"

# ───── WiFi gate ─────
if [ "$MODE" = "auto" ]; then
  if [ "$CURRENT_WIFI" != "$ALLOWED_WIFI1" ] && [ "$CURRENT_WIFI" != "$ALLOWED_WIFI2" ]; then
    log_msg "BLOCKED - Wrong WiFi: ${CURRENT_WIFI:-Mobile}"
    exit 0
  fi
fi

# ───── Preview mode ─────
if [ "$MODE" = "preview" ]; then exit 0; fi

# ───── Zoho limit check ─────
if [ "$ZOHO_PCT" -ge "$ZOHO_LIMIT_PCT" ]; then
  log_msg "ABORTED - Zoho full ${ZOHO_USED}G/${ZOHO_TOTAL_GB}G"
  exit 0
fi

# ───── Cron setup ─────
setup_cron(){
  local n; n=$(crontab -l 2>/dev/null | grep -F "sync.sh auto" | wc -l)
  if [ "${n:-0}" -lt 4 ]; then
    (
      crontab -l 2>/dev/null | grep -v "sync.sh" || true
      echo "0 2  * * * bash $HOME/sync_project/sync.sh auto >> $LOG_DIR/cron.log 2>&1"
      echo "0 11 * * * bash $HOME/sync_project/sync.sh auto >> $LOG_DIR/cron.log 2>&1"
      echo "0 17 * * * bash $HOME/sync_project/sync.sh auto >> $LOG_DIR/cron.log 2>&1"
      echo "0 21 * * * bash $HOME/sync_project/sync.sh auto >> $LOG_DIR/cron.log 2>&1"
    ) | crontab -
    log_msg "Crontab auto-configured"
  fi
}
setup_cron

# ───── Sync ─────
TOTAL_UPLOADED=0
TOTAL_DELETED=0

# Colors for sync output
C='\033[0;36m'; N='\033[0m'; D='\033[2m'
LM='\033[38;5;154m'; LIME='\033[38;5;118m'; ROSE='\033[38;5;204m'; B='\033[1m'
BOXW=46
line() { printf "%*s" "$1" "" | tr ' ' "$2"; }
dtop() { echo -e "${C}╭$(line $BOXW ─)╮${N}"; }
dmid() { echo -e "${C}├$(line $BOXW ─)┤${N}"; }
dbot() { echo -e "${C}╰$(line $BOXW ─)╯${N}"; }
row()  { echo -e "${C}│${N} $1"; }

run_sync(){
  local NAME="$1" SRC="$2" DST="$3"
  local LOG="$LOG_DIR/sync_${NAME}_$(date +%Y%m%d_%H%M%S).log"
  echo ""
  dtop
  row "  ${C}${B}🔄 SYNCING: ${NAME}${N}"
  row "  ${D}▸ FROM: ${SRC}${N}"
  row "  ${D}▸ TO  : ${DST}${N}"
  dmid
  rclone sync "$SRC" "$DST" \
    --delete-during \
    --log-file="$LOG" \
    --log-level INFO \
    --progress 2>&1 | while IFS= read -r l; do
      echo -e "  ${D}${l}${N}"
    done
  local UP=0 DEL=0
  if [ -f "$LOG" ]; then
    UP=$(grep ": Copied (new)" "$LOG" 2>/dev/null | wc -l | tr -d ' ')
    DEL=$(grep ": Deleted" "$LOG" 2>/dev/null | grep -v "stats\|Checks\|Transferred" | wc -l | tr -d ' ')
  fi
  UP=$(( UP + 0 )); DEL=$(( DEL + 0 ))
  TOTAL_UPLOADED=$(( TOTAL_UPLOADED + UP ))
  TOTAL_DELETED=$(( TOTAL_DELETED + DEL ))
  row "  ${LIME}${B}✔ Done!${N}   ⬆ ${LM}${B}${UP}${N} uploaded   🗑 ${ROSE}${B}${DEL}${N} deleted"
  dbot
  log_msg "SYNC ${NAME} ⬆${UP} 🗑${DEL}"
}

log_msg "START Mode:${MODE} WiFi:${CURRENT_WIFI:-Mobile} Bat:${BAT}%"

run_sync "Cloud-Sync-File" "$LOCAL1" "$REMOTE1"
run_sync "HiRes_Songs"     "$LOCAL2" "$REMOTE2"

# ───── Final summary ─────
O='\033[38;5;214m'; GD='\033[38;5;220m'
echo ""
dtop
row "  ${LIME}${B}✅ ALL SYNCS COMPLETED!${N}"
dmid
row "  ${B}⬆ Uploaded  :${N}  ${LM}${B}${TOTAL_UPLOADED}${N} files"
row "  ${B}🗑 Deleted   :${N}  ${ROSE}${B}${TOTAL_DELETED}${N} files"
row "  ${B}🔋 Battery   :${N}  ${BAT}% (${BAT_STATUS})"
row "  ${B}☁️  Zoho      :${N}  ${ZOHO_USED}G / ${ZOHO_TOTAL_GB}G (${ZOHO_PCT}%)"
row "  ${B}🕒 Finished  :${N}  ${O}$(date '+%H:%M:%S')${N}"
dbot
echo ""

# ───── Telegram report ─────
export TOTAL_UPLOADED TOTAL_DELETED
bash "$HOME/sync_project/tg_report.sh"

log_msg "END ⬆${TOTAL_UPLOADED} 🗑${TOTAL_DELETED}"
