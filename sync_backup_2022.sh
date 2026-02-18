#!/data/data/com.termux/files/usr/bin/bash

########################################
# SUKRULLAH PRO SYNC v3.5 - FINAL
########################################

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

########################################
# CONFIG
########################################

TG_TOKEN="7860150214:AAFSJVE8MigIaQB3-jbTme0IAQZT2U60thg"
TG_CHAT_ID="6403536553"

ALLOWED_WIFI1="Encore 2_5GHz"
ALLOWED_WIFI2="Encore2"
ONEDRIVE_LIMIT=48

LOCAL1="$HOME/storage/shared/Cloud-Sync-File"
REMOTE1="onedrive:Cloud-Sync-File"
LOCAL2="$HOME/storage/shared/HiRes_Songs"
REMOTE2="onedrive:HiRes_Songs"

MODE=${1:-auto}

LOG_DIR="$HOME/sync_logs"
MASTER_LOG="$LOG_DIR/master_sync.log"
mkdir -p "$LOG_DIR"

########################################
# CRONTAB AUTO-SETUP
# Pehli baar chalane pe crontab set ho jayega
########################################

setup_cron() {
    # Check karo crontab already set hai ya nahi
    CRON_CHECK=$(crontab -l 2>/dev/null | grep "sync.sh auto" | wc -l)
    if [ "$CRON_CHECK" -lt 4 ]; then
        # Purana crontab saaf karo aur naya set karo
        (
            crontab -l 2>/dev/null | grep -v "sync.sh"
            echo "0 2  * * * bash ~/sync.sh auto >> ~/sync_logs/cron.log 2>&1"
            echo "0 11 * * * bash ~/sync.sh auto >> ~/sync_logs/cron.log 2>&1"
            echo "0 17 * * * bash ~/sync.sh auto >> ~/sync_logs/cron.log 2>&1"
            echo "0 21 * * * bash ~/sync.sh auto >> ~/sync_logs/cron.log 2>&1"
        ) | crontab -
        echo -e "${G}✅ Crontab set ho gaya! (02:00, 11:00, 17:00, 21:00)${N}"
        log_msg "Crontab auto-configured"
    fi
}

########################################
# WIFI WATCHER MODE
########################################

if [ "$MODE" = "watch" ]; then
    echo -e "${C}╔══════════════════════════════════════════╗${N}"
    echo -e "${C}║${N}  ${B}${PK}★ WIFI WATCHER STARTED${N}              ${C}║${N}"
    echo -e "${C}║${N}  ${D}Watching: ${ALLOWED_WIFI1} / ${ALLOWED_WIFI2}${N}"
    echo -e "${C}║${N}  ${D}Check interval: every 2 hours${N}"
    echo -e "${C}║${N}  ${D}Ctrl+C to stop${N}"
    echo -e "${C}╚══════════════════════════════════════════╝${N}"
    LAST_SYNC_WIFI=""
    while true; do
        WIFI_NOW=$(termux-wifi-connectioninfo 2>/dev/null | grep '"ssid"' | cut -d'"' -f4)
        [ "$WIFI_NOW" = "<unknown ssid>" ] && WIFI_NOW=""
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

########################################
# STORAGE PERMISSION
########################################

if [ ! -d "$HOME/storage/shared" ]; then
    termux-setup-storage
fi

########################################
# HELPER FUNCTIONS
########################################

dtop() { echo -e "${C}╔════════════════════════════════════════════╗${N}"; }
dmid() { echo -e "${C}╠════════════════════════════════════════════╣${N}"; }
dbot() { echo -e "${C}╚════════════════════════════════════════════╝${N}"; }

log_msg() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$MASTER_LOG"; }

# Progress bar
pbar() {
    local val=$1 width=20
    local filled=$(( val * width / 100 ))
    [ $filled -gt $width ] && filled=$width
    local empty=$(( width - filled )) bar="" col i=0
    if   [ "$val" -le 15 ]; then col=$R
    elif [ "$val" -le 30 ]; then col=$Y
    else col=$G; fi
    while [ $i -lt $filled ]; do bar="${bar}█"; i=$(( i+1 )); done
    i=0
    while [ $i -lt $empty  ]; do bar="${bar}░"; i=$(( i+1 )); done
    echo -e "${col}[${bar}]${N} ${B}${val}%${N}"
}

# Telegram plain bar
tbar() {
    local val=$1 width=20
    local filled=$(( val * width / 100 ))
    [ $filled -gt $width ] && filled=$width
    local empty=$(( width - filled )) bar="" i=0
    while [ $i -lt $filled ]; do bar="${bar}█"; i=$(( i+1 )); done
    i=0
    while [ $i -lt $empty  ]; do bar="${bar}░"; i=$(( i+1 )); done
    echo "[${bar}] ${val}%"
}

########################################
# GATHER SYSTEM INFO
########################################

BAT=$(termux-battery-status 2>/dev/null | grep percentage | grep -o '[0-9]*')
BAT=${BAT:-0}
BAT_STATUS=$(termux-battery-status 2>/dev/null | grep '"status"' | cut -d'"' -f4)
BAT_STATUS=${BAT_STATUS:-Unknown}

CURRENT_WIFI=$(termux-wifi-connectioninfo 2>/dev/null | grep '"ssid"' | cut -d'"' -f4)
[ "$CURRENT_WIFI" = "<unknown ssid>" ] && CURRENT_WIFI=""

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
OD_TOTAL=$(echo "$OD_INFO" | grep 'Total' | awk '{print $2}' | sed 's/G.*//')
OD_USED=$(echo "$OD_INFO"  | grep 'Used'  | awk '{print $2}' | sed 's/G.*//')
OD_FREE=$(echo "$OD_INFO"  | grep 'Free'  | awk '{print $2}' | sed 's/G.*//')
OD_PCT=0
if [ -n "$OD_TOTAL" ] && [ -n "$OD_USED" ]; then
    OD_INT=${OD_USED%.*}; OD_TOT_INT=${OD_TOTAL%.*}
    OD_INT=${OD_INT:-0}; OD_TOT_INT=${OD_TOT_INT:-1}
    [ "$OD_TOT_INT" -gt 0 ] && OD_PCT=$(( OD_INT * 100 / OD_TOT_INT ))
fi

NOW=$(date '+%Y-%m-%d %H:%M:%S')
DAY=$(date '+%A')

########################################
# WIFI CHECK — auto mode only
########################################

if [ "$MODE" = "auto" ]; then
    if [ "$CURRENT_WIFI" != "$ALLOWED_WIFI1" ] && \
       [ "$CURRENT_WIFI" != "$ALLOWED_WIFI2" ]; then
        clear
        WSHOW="${CURRENT_WIFI:-Mobile Data}"
        dtop
        echo -e "${C}║${N}  ${R}${B}⛔ SYNC BLOCKED - WRONG NETWORK${N}     ${C}║${N}"
        dmid
        echo -e "${C}║${N}  ${Y}Connected :${N} ${WSHOW}"
        echo -e "${C}║${N}  ${G}Allowed   :${N} Encore 2_5GHz / Encore2  ${C}║${N}"
        dmid
        echo -e "${C}║${N}  ${D}sync.sh manual = any WiFi${N}           ${C}║${N}"
        echo -e "${C}║${N}  ${D}sync.sh force  = Mobile Data${N}         ${C}║${N}"
        echo -e "${C}║${N}  ${D}sync.sh watch  = auto WiFi watcher${N}   ${C}║${N}"
        dbot
        log_msg "BLOCKED - Wrong WiFi: ${CURRENT_WIFI:-Mobile Data}"
        exit 0
    fi
fi

########################################
# ASCII HEADER
########################################

clear
echo ""
echo -e "${M}${B}"
echo " ███████╗██╗   ██╗██╗  ██╗██████╗ ██╗   ██╗██╗     ██╗      █████╗ ██╗  ██╗"
echo " ██╔════╝██║   ██║██║ ██╔╝██╔══██╗██║   ██║██║     ██║     ██╔══██╗██║  ██║"
echo " ███████╗██║   ██║█████╔╝ ██████╔╝██║   ██║██║     ██║     ███████║███████║"
echo " ╚════██║██║   ██║██╔═██╗ ██╔══██╗██║   ██║██║     ██║     ██╔══██║██╔══██║"
echo " ███████║╚██████╔╝██║  ██╗██║  ██║╚██████╔╝███████╗███████╗██║  ██║██║  ██║"
echo " ╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝"
echo -e "${N}"
echo -e " ${SB}${B}PRO SYNC SYSTEM v3.5${N}  ${D}|${N}  ${O}${DAY}, ${NOW}${N}"
echo ""

########################################
# SYSTEM STATUS BOX
########################################

dtop
echo -e "${C}║${N}  ${B}${PK}★ SYSTEM STATUS${N}                        ${C}║${N}"
dmid

BAT_BAR=$(pbar "$BAT")
echo -e "${C}║${N}  🔋 ${B}Battery${N}   ${Y}${BAT}% (${BAT_STATUS})${N}"
echo -e "${C}║${N}     ${BAT_BAR}"

if [ "$MODE" = "force" ]; then
    echo -e "${C}║${N}  📡 ${B}Network${N}   ${R}Mobile Data (Force Mode)${N}  ${C}║${N}"
elif [ -n "$CURRENT_WIFI" ]; then
    echo -e "${C}║${N}  📡 ${B}Network${N}   ${G}${CURRENT_WIFI}${N}"
else
    echo -e "${C}║${N}  📡 ${B}Network${N}   ${Y}Mobile Data${N}               ${C}║${N}"
fi

if   [ "$MODE" = "force"  ]; then echo -e "${C}║${N}  ⚙  ${B}Mode${N}      ${R}${B}FORCE MODE${N}                ${C}║${N}"
elif [ "$MODE" = "manual" ]; then echo -e "${C}║${N}  ⚙  ${B}Mode${N}      ${Y}${B}MANUAL MODE${N}               ${C}║${N}"
else                               echo -e "${C}║${N}  ⚙  ${B}Mode${N}      ${G}${B}AUTO MODE${N}                 ${C}║${N}"; fi

########################################
# STORAGE BOX
########################################

dmid
echo -e "${C}║${N}  ${B}${PK}★ STORAGE OVERVIEW${N}                     ${C}║${N}"
dmid

echo -e "${C}║${N}  ${O}${B}📱 Internal Storage${N}                    ${C}║${N}"
echo -e "${C}║${N}     ${B}${INT_USED}${N} / ${INT_TOTAL}   Free: ${LM}${INT_FREE}${N}"
echo -e "${C}║${N}     $(pbar "$INT_PCT")"

echo -e "${C}║${N}  ${SB}${B}💾 SD Card${N}                             ${C}║${N}"
if [ -n "$SD_RAW" ]; then
    echo -e "${C}║${N}     ${B}${SD_USED}${N} / ${SD_TOTAL}   Free: ${LM}${SD_FREE}${N}"
    echo -e "${C}║${N}     $(pbar "$SD_PCT")"
else
    echo -e "${C}║${N}     ${D}Not Found${N}                             ${C}║${N}"
fi

echo -e "${C}║${N}  ${M}${B}☁  OneDrive${N}                            ${C}║${N}"
if [ -n "$OD_TOTAL" ]; then
    echo -e "${C}║${N}     ${B}${OD_USED}G${N} / ${OD_TOTAL}G   Free: ${LM}${OD_FREE}G${N}   Limit: ${R}${ONEDRIVE_LIMIT}G${N}"
    echo -e "${C}║${N}     $(pbar "$OD_PCT")"
else
    echo -e "${C}║${N}     ${R}Cannot reach OneDrive${N}                ${C}║${N}"
fi

########################################
# SCHEDULERS BOX
########################################

dmid
echo -e "${C}║${N}  ${B}${PK}★ SCHEDULERS${N}                           ${C}║${N}"
dmid
echo -e "${C}║${N}  🕑 ${B}02:00${N}  🕚 ${B}11:00${N}  🕔 ${B}17:00${N}  🕘 ${B}21:00${N}      ${C}║${N}"
echo -e "${C}║${N}  ${D}cron: 0 2,11,17,21 * * * sync.sh auto${N}  ${C}║${N}"
echo -e "${C}║${N}  ${LM}WiFi Watcher: bash ~/sync.sh watch${N}      ${C}║${N}"
dbot
echo ""

########################################
# CRONTAB AUTO SETUP
########################################

setup_cron

########################################
# ONEDRIVE LIMIT CHECK
########################################

OD_USED_INT=${OD_USED%.*}; OD_USED_INT=${OD_USED_INT:-0}
if [ -n "$OD_USED_INT" ] && [ "$OD_USED_INT" -ge "$ONEDRIVE_LIMIT" ] 2>/dev/null; then
    dtop
    echo -e "${C}║${N}  ${R}${B}⛔ ONEDRIVE LIMIT REACHED — STOPPED${N}  ${C}║${N}"
    echo -e "${C}║${N}  Used: ${OD_USED}G / Limit: ${ONEDRIVE_LIMIT}G"
    dbot
    log_msg "ABORTED - OneDrive limit: ${OD_USED}G / ${ONEDRIVE_LIMIT}G"
    curl -s -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
        -F chat_id="${TG_CHAT_ID}" \
        -F text="⛔ SYNC ABORTED - OneDrive limit: ${OD_USED}G / ${ONEDRIVE_LIMIT}G" > /dev/null
    exit 0
fi

########################################
# SYNC FUNCTION
########################################

SUMMARY=""
TOTAL_UPLOADED=0
TOTAL_DELETED=0

run_sync() {
    local NAME="$1" SRC="$2" DST="$3"
    local LOG="$LOG_DIR/sync_${NAME}_$(date +%Y%m%d_%H%M%S).log"

    echo ""
    dtop
    echo -e "${C}║${N}  ${SB}${B}🔄 SYNCING: ${NAME}${N}"
    echo -e "${C}║${N}  ${D}SRC: ${SRC}${N}"
    echo -e "${C}║${N}  ${D}DST: ${DST}${N}"
    dmid

    rclone sync "$SRC" "$DST" \
        --delete-during \
        --log-file="$LOG" \
        --log-level INFO \
        --progress 2>&1 | while IFS= read -r line; do
            echo -e "  ${D}${line}${N}"
        done

    local UP_LIST="" DEL_LIST=""
    local UP_COUNT=0 DEL_COUNT=0

    if [ -f "$LOG" ]; then
        UP_LIST=$(grep ": Copied (new)" "$LOG" 2>/dev/null \
            | awk '{print $5}' | sed 's/:$//' | grep -v '^$' || true)
        DEL_LIST=$(grep ": Deleted" "$LOG" 2>/dev/null \
            | grep -v "stats\|Checks\|Transferred" \
            | awk '{print $5}' | sed 's/:$//' | grep -v '^$' || true)
    fi

    [ -n "$UP_LIST"  ] && UP_COUNT=$(printf '%s\n' "$UP_LIST"  | wc -l | tr -d ' ')
    [ -n "$DEL_LIST" ] && DEL_COUNT=$(printf '%s\n' "$DEL_LIST" | wc -l | tr -d ' ')
    UP_COUNT=$(( UP_COUNT + 0 ))
    DEL_COUNT=$(( DEL_COUNT + 0 ))

    TOTAL_UPLOADED=$(( TOTAL_UPLOADED + UP_COUNT ))
    TOTAL_DELETED=$(( TOTAL_DELETED + DEL_COUNT ))

    echo -e "${C}║${N}  ${G}${B}✅ Done!${N}   Uploaded: ${LM}${B}${UP_COUNT}${N}   │   Deleted: ${R}${B}${DEL_COUNT}${N}"

    if [ "$UP_COUNT" -gt 0 ] && [ -n "$UP_LIST" ]; then
        dmid
        echo -e "${C}║${N}  ${LM}${B}📤 UPLOADED FILES (${UP_COUNT})${N}"
        printf '%s\n' "$UP_LIST" | head -20 | while IFS= read -r f; do
            [ -z "$f" ] && continue
            echo -e "${C}║${N}  ${G}+${N} ${f}"
        done
        [ "$UP_COUNT" -gt 20 ] && echo -e "${C}║${N}  ${D}... and $(( UP_COUNT - 20 )) more${N}"
    fi

    if [ "$DEL_COUNT" -gt 0 ] && [ -n "$DEL_LIST" ]; then
        dmid
        echo -e "${C}║${N}  ${R}${B}🗑  DELETED FILES (${DEL_COUNT})${N}"
        printf '%s\n' "$DEL_LIST" | head -20 | while IFS= read -r f; do
            [ -z "$f" ] && continue
            echo -e "${C}║${N}  ${R}-${N} ${f}"
        done
        [ "$DEL_COUNT" -gt 20 ] && echo -e "${C}║${N}  ${D}... and $(( DEL_COUNT - 20 )) more${N}"
    fi

    dbot

    SUMMARY="${SUMMARY}
📂 ${NAME}
📤 Uploaded (${UP_COUNT}):
${UP_LIST:-  None}
🗑 Deleted (${DEL_COUNT}):
${DEL_LIST:-  None}
────────────────────────────"

    log_msg "SYNC ${NAME} Uploaded:${UP_COUNT} Deleted:${DEL_COUNT}"
}

########################################
# RUN SYNCS
########################################

log_msg "START Mode:${MODE} WiFi:${CURRENT_WIFI:-Mobile} Battery:${BAT}%"

run_sync "Cloud-Sync-File" "$LOCAL1" "$REMOTE1"
run_sync "HiRes_Songs"     "$LOCAL2" "$REMOTE2"

########################################
# FINAL SUMMARY BOX
########################################

echo ""
dtop
echo -e "${C}║${N}  ${G}${B}✅  ALL SYNCS COMPLETED SUCCESSFULLY!${N}  ${C}║${N}"
dmid
echo -e "${C}║${N}  ${B}Total Uploaded :${N}  ${LM}${B}${TOTAL_UPLOADED}${N} files"
echo -e "${C}║${N}  ${B}Total Deleted  :${N}  ${R}${B}${TOTAL_DELETED}${N} files"
echo -e "${C}║${N}  ${B}Battery        :${N}  ${BAT}% (${BAT_STATUS})"
echo -e "${C}║${N}  ${B}OneDrive       :${N}  ${OD_USED:-N/A}G / ${OD_TOTAL:-N/A}G used"
echo -e "${C}║${N}  ${B}Log            :${N}  ${D}${MASTER_LOG}${N}"
echo -e "${C}║${N}  ${B}Finished At    :${N}  ${O}$(date '+%H:%M:%S')${N}"
dbot
echo ""

########################################
# TELEGRAM REPORT
########################################

BAT_TB=$(tbar "$BAT")
INT_TB=$(tbar "$INT_PCT")
SD_TB=$(tbar "$SD_PCT")
OD_TB=$(tbar "$OD_PCT")

REPORT="🚀 <b>SUKRULLAH PRO SYNC COMPLETED</b>

📊 <b>SYSTEM</b>
🔋 Battery  : ${BAT}% (${BAT_STATUS})
<code>${BAT_TB}</code>
📶 Network  : ${CURRENT_WIFI:-Mobile Data}
⚙️ Mode     : ${MODE}
🕒 Time     : $(date '+%d %b %Y, %H:%M:%S')

💾 <b>STORAGE</b>
📱 Internal : ${INT_USED} / ${INT_TOTAL}  (Free: ${INT_FREE})
<code>${INT_TB}</code>
💾 SD Card  : ${SD_USED:-N/A} / ${SD_TOTAL:-N/A}  (Free: ${SD_FREE:-N/A})
<code>${SD_TB}</code>
☁️ OneDrive : ${OD_USED:-N/A}G / ${OD_TOTAL:-N/A}G  (Free: ${OD_FREE:-N/A}G)
<code>${OD_TB}</code>

📁 <b>RESULTS</b>
📤 Uploaded : ${TOTAL_UPLOADED} files
🗑 Deleted  : ${TOTAL_DELETED} files

📋 <b>DETAILS</b>
${SUMMARY}

📝 Log: ${MASTER_LOG}"

echo -e "${SB}📡 Sending Telegram report...${N}"

TG_TMP=$(mktemp)
printf '%s' "$REPORT" > "$TG_TMP"

TG_RESPONSE=$(curl -s \
    -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
    -F "chat_id=${TG_CHAT_ID}" \
    -F "parse_mode=HTML" \
    -F "text=<${TG_TMP}")

rm -f "$TG_TMP"

if echo "$TG_RESPONSE" | grep -q '"ok":true'; then
    echo -e "${G}${B}✅ Telegram report sent successfully!${N}"
else
    echo -e "${R}⚠ Telegram send failed${N}"
    echo "$TG_RESPONSE" | head -3
fi

log_msg "END Uploaded:${TOTAL_UPLOADED} Deleted:${TOTAL_DELETED}"
