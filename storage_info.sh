#!/data/data/com.termux/files/usr/bin/bash
INT_RAW=$(df -h /storage/emulated/0 2>/dev/null | awk 'NR==2')
[ -z "$INT_RAW" ] && INT_RAW=$(df -h "$HOME/storage/shared" 2>/dev/null | awk 'NR==2')
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
ZOHO_RAW=$(rclone about "${ZOHO_REMOTE:-zoho:}" 2>/dev/null)
ZOHO_USED=$(echo "$ZOHO_RAW" | grep -i '^Used' | awk '{print $2}')
ZOHO_USED=${ZOHO_USED%.*}; ZOHO_USED=${ZOHO_USED:-0}
ZOHO_TOTAL_GB=${ZOHO_TOTAL_GB:-55}
ZOHO_FREE=$(( ZOHO_TOTAL_GB - ZOHO_USED ))
[ "$ZOHO_FREE" -lt 0 ] && ZOHO_FREE=0
ZOHO_PCT=$(( ZOHO_USED * 100 / ZOHO_TOTAL_GB ))
export INT_RAW INT_TOTAL INT_USED INT_FREE INT_PCT
export SD_RAW SD_TOTAL SD_USED SD_FREE SD_PCT
export ZOHO_RAW ZOHO_USED ZOHO_FREE ZOHO_PCT ZOHO_TOTAL_GB
