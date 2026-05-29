#!/data/data/com.termux/files/usr/bin/bash
########################################
# SUKRULLAH TELEGRAM REPORT v4.3
# Sirf Telegram report — alag se edit karo!
########################################
source "$HOME/sync_project/.env"

TG_TOKEN="${TG_TOKEN:-}"
TG_CHAT_ID="${TG_CHAT_ID:-}"

[ -z "$TG_TOKEN" ] && [ -z "$TG_CHAT_ID" ] && exit 0

# ───── GB formatter ─────
fmt_gb(){
  local val="$1"
  local num="${val%G}"
  if [[ "$num" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    printf "%.1fGB" "$num"
  else
    echo "${val:-N/A}"
  fi
}

# ───── Battery Emoji Bar ─────
# <=20% = 🟥 red, >20% = 🟩 green, empty = ⬛
bat_ebar(){
  local v=$1 w=20
  [ "$v" -lt 0 ] && v=0
  [ "$v" -gt 100 ] && v=100
  local f=$(( v * w / 100 ))
  local bar="" i filled_em
  [ "$v" -le 20 ] && filled_em="🟥" || filled_em="🟩"
  for((i=1;i<=w;i++)); do
  [ $i -le $f ] && bar+="$filled_em" || bar+="◻"
  done
  printf "%s  %d%%" "$bar" "$v"
}

# ───── Storage Emoji Bar ─────
# filled = 🟦, empty = ⬛
storage_ebar(){
  local v=$1 w=20
  [ "$v" -lt 0 ] && v=0
  [ "$v" -gt 100 ] && v=100
  local f=$(( v * w / 100 ))
  [ "$f" -eq 0 ] && [ "$v" -gt 0 ] && f=1
  local bar="" i
  for((i=1;i<=w;i++)); do
  [ $i -le $f ] && bar+="◼" || bar+="◻"
  done
  printf "%s  %d%%" "$bar" "$v"
}

NET=$([ -n "${CURRENT_WIFI:-}" ] && echo "${CURRENT_WIFI}" || echo "Mobile Data")

BAT_BAR=$(bat_ebar "${BAT:-0}")
INT_BAR=$(storage_ebar "${INT_PCT:-0}")
SD_BAR=$(storage_ebar "${SD_PCT:-0}")
ZH_BAR=$(storage_ebar "${ZOHO_PCT:-0}")

# ───── MicroSD section ─────
_sd_num="${SD_TOTAL:-}"
_sd_num="${_sd_num%G}"
if [ -n "${SD_TOTAL:-}" ] && [ "${_sd_num:-0}" != "0" ] && [ -n "${_sd_num:-}" ]; then
  SD_SECTION="MicroSD
$(fmt_gb "${SD_USED:-0}") / $(fmt_gb "${SD_TOTAL:-0}")  •  Free: $(fmt_gb "${SD_FREE:-0}")
${SD_BAR}"
else
  SD_SECTION="MicroSD
❌ Not Detected"
fi

REPORT="🚀 <b>SUKRULLAH PRO SYNC v4.3</b>

⚙️ <b>SYSTEM</b>
🔋 Battery : <b>${BAT:-0}%</b>  (${BAT_STATUS:-Unknown})
${BAT_BAR}
📶 Network : ${NET}
⚙️ Mode    : ${MODE:-auto}
🕒 Time    : $(date '+%d %b %Y, %H:%M:%S')

💾 <b>STORAGE</b>

Internal
$(fmt_gb "${INT_USED:-0}") / $(fmt_gb "${INT_TOTAL:-0}")  •  Free: $(fmt_gb "${INT_FREE:-0}")
${INT_BAR}

${SD_SECTION}

Zoho WorkDrive
$(fmt_gb "${ZOHO_USED:-0}") / $(fmt_gb "${ZOHO_TOTAL_GB:-55}")  •  Free: $(fmt_gb "${ZOHO_FREE:-0}")
${ZH_BAR}

📁 <b>SYNC RESULTS</b>
⬆ Uploaded : <b>${TOTAL_UPLOADED:-0}</b> files
🗑 Deleted  : <b>${TOTAL_DELETED:-0}</b> files

📝 Log: ${MASTER_LOG:-sync_logs/master_sync.log}"

Y='\033[1;33m'; N='\033[0m'; SB='\033[38;5;39m'
echo -e "${SB}📡 Sending Telegram report...${N}"

resp=$(curl -s --max-time 30 -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
          -F "chat_id=${TG_CHAT_ID}" \
          -F "parse_mode=HTML" \
          -F "text=${REPORT}")

echo "$resp" | grep -q '"ok":true' \
  && echo -e "\033[38;5;118m✅ Telegram report sent!\033[0m" \
  || echo -e "${Y}⚠ TG send failed${N}"
