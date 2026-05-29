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
MODE="auto"
[ -n "$1" ] && MODE="$1"

export ALLOWED_WIFI1 ALLOWED_WIFI2 ZOHO_REMOTE ZOHO_TOTAL_GB
export ZOHO_SYNC ZOHO_LIMIT_PCT LOCAL1 REMOTE1 LOCAL2 REMOTE2
export MODE

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
export BAT BAT_STATUS CURRENT_WIFI
CURRENT_WIFI=$(termux-wifi-connectioninfo 2>/dev/null | grep '"ssid"' | tail -1 | cut -d'"' -f4)
[ "$CURRENT_WIFI" = "<unknown ssid>" ] && CURRENT_WIFI=""

source "$HOME/sync_project/storage_info.sh"

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

# ───── Log rotation ─────
rotate_log(){
  local f="$1" max="${2:-500}"
  [ -f "$f" ] || return
  local lines; lines=$(wc -l < "$f")
  if [ "$lines" -gt "$max" ]; then
    tail -n "$max" "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"
  fi
}
rotate_log "$MASTER_LOG" 500
rotate_log "$LOG_DIR/cron.log" 500
find "$LOG_DIR" -name "sync_*.log" -mtime +7 -delete 2>/dev/null

# ───── Cron setup ─────
setup_cron(){
  local existing; existing=$(crontab -l 2>/dev/null | grep -cF "sync.sh auto" || echo 0)
  [ "${existing}" -eq 4 ] && return
  (
    crontab -l 2>/dev/null | grep -v "sync.sh" || true
    echo "0 2  * * * bash $HOME/sync_project/sync.sh auto >> $LOG_DIR/cron.log 2>&1"
    echo "0 11 * * * bash $HOME/sync_project/sync.sh auto >> $LOG_DIR/cron.log 2>&1"
    echo "0 17 * * * bash $HOME/sync_project/sync.sh auto >> $LOG_DIR/cron.log 2>&1"
    echo "0 21 * * * bash $HOME/sync_project/sync.sh auto >> $LOG_DIR/cron.log 2>&1"
  ) | crontab -
  log_msg "Crontab auto-configured"
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
    --timeout 60s \
    --contimeout 30s \
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
