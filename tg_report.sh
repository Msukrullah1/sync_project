#!/data/data/com.termux/files/usr/bin/bash
########################################
# SUKRULLAH TELEGRAM REPORT v4.1
# Sirf Telegram report — alag se edit karo!
########################################
source "$HOME/sync_project/.env"

TG_TOKEN="${TG_TOKEN:-}"
TG_CHAT_ID="${TG_CHAT_ID:-}"

[ -z "$TG_TOKEN" ] && [ -z "$TG_CHAT_ID" ] && exit 0

# ───── Telegram bar ─────
tbar(){
  local v=$1 w=28
  [ "$v" -lt 0 ] && v=0
  [ "$v" -gt 100 ] && v=100
  local f=$(( v*w/100 )) out="" i
  for((i=1;i<=w;i++)); do
    [ $i -le $f ] && out+="█" || out+="░"
  done
  printf "%s %3d%%" "$out" "$v"
}

BAT_TB=$(tbar "${BAT:-0}")
ZH_TB=$(tbar "${ZOHO_PCT:-0}")
OD_TB=$(tbar "${OD_PCT:-0}")

NET=$([ -n "${CURRENT_WIFI:-}" ] && echo "${CURRENT_WIFI}" || echo "Mobile Data")

REPORT="🚀 <b>SUKRULLAH PRO SYNC v4.1</b>

⚙️ <b>SYSTEM</b>
🔋 Battery : <b>${BAT:-0}%</b> (${BAT_STATUS:-Unknown})
<code>${BAT_TB}</code>
📶 Network : ${NET}
⚙️ Mode    : ${MODE:-auto}
🕒 Time    : $(date '+%d %b %Y, %H:%M:%S')

💾 <b>STORAGE</b>
📱 Internal : ${INT_USED:-N/A} / ${INT_TOTAL:-N/A}  •  Free: ${INT_FREE:-N/A}
☁️ Zoho     : ${ZOHO_USED:-0}G / ${ZOHO_TOTAL_GB:-55}G  •  Free: ${ZOHO_FREE:-0}G
<code>${ZH_TB}</code>
🔵 OneDrive : ${OD_USED_G:-N/A}G / ${OD_TOTAL:-N/A}G (Display Only)
<code>${OD_TB}</code>

📁 <b>SYNC RESULTS</b>
⬆ Uploaded : <b>${TOTAL_UPLOADED:-0}</b> files
🗑 Deleted  : <b>${TOTAL_DELETED:-0}</b> files

📝 Log: ${MASTER_LOG:-sync_logs/master_sync.log}"

Y='\033[1;33m'; N='\033[0m'; SB='\033[38;5;39m'
echo -e "${SB}📡 Sending Telegram report...${N}"

resp=$(curl -s -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
          -F "chat_id=${TG_CHAT_ID}" \
          -F "parse_mode=HTML" \
          -F "text=${REPORT}")

echo "$resp" | grep -q '"ok":true' \
  && echo -e "\033[38;5;118m✅ Telegram report sent!\033[0m" \
  || echo -e "${Y}⚠ TG send failed${N}"
