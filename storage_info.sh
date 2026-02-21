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
OD_TOTAL=""; OD_USED_G=""; OD_FREE_G=""; OD_PCT=0
if [ "${OD_INFO_ON:-1}" -eq 1 ]; then
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
export INT_RAW INT_TOTAL INT_USED INT_FREE INT_PCT
export SD_RAW SD_TOTAL SD_USED SD_FREE SD_PCT
export ZOHO_RAW ZOHO_USED ZOHO_FREE ZOHO_PCT ZOHO_TOTAL_GB
export OD_TOTAL OD_USED_G OD_FREE_G OD_PCT
