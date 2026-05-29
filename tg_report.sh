#!/data/data/com.termux/files/usr/bin/bash
########################################
# SUKRULLAH TELEGRAM REPORT v5.0
########################################
source "$HOME/sync_project/.env"

TG_TOKEN="${TG_TOKEN:-}"
TG_CHAT_ID="${TG_CHAT_ID:-}"
[ -z "$TG_TOKEN" ] || [ -z "$TG_CHAT_ID" ] && exit 0

# ── Monospace block bar (20 wide) ──
make_bar(){
  local v=$1 w=20
  [ "$v" -lt 0 ] && v=0; [ "$v" -gt 100 ] && v=100
  local f=$(( v * w / 100 ))
  [ "$f" -eq 0 ] && [ "$v" -gt 0 ] && f=1
  local bar="" i
  for((i=1;i<=w;i++)); do
    [ $i -le $f ] && bar+="█" || bar+="░"
  done
  printf "%s %3d%%" "$bar" "$v"
}

# ── Color dot by fill percentage ──
status_dot(){
  local v=$1
  [ "$v" -ge 90 ] && echo "🔴" && return
  [ "$v" -ge 75 ] && echo "🟡" && return
  echo "🟢"
}

# ── Battery icon ──
bat_icon(){
  local p=$1 s="${2:-}"
  case "$s" in CHARGING|Charging|charging|FULL|Full) echo "🔌"; return;; esac
  [ "$p" -le 15 ] && echo "🪫" || echo "🔋"
}

# ── Duration formatter ──
fmt_dur(){
  local s=${1:-0}
  local h=$(( s/3600 )) m=$(( (s%3600)/60 )) sec=$(( s%60 ))
  [ "$h" -gt 0 ] && echo "${h}h ${m}m ${sec}s" && return
  [ "$m" -gt 0 ] && echo "${m}m ${sec}s" && return
  echo "${sec}s"
}

# ── GB formatter ──
fmt_gb(){
  local val="$1" num
  num="${val%G}"
  [[ "$num" =~ ^[0-9]+(\.[0-9]+)?$ ]] && printf "%.1fGB" "$num" || echo "${val:-N/A}"
}

# ── Escape HTML special chars ──
esc(){ printf '%s' "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'; }

SEP="━━━━━━━━━━━━━━━━━━━━━━━━━━"
NET=$([ -n "${CURRENT_WIFI:-}" ] && esc "${CURRENT_WIFI}" || echo "Mobile Data")
BAT_ICO=$(bat_icon "${BAT:-0}" "${BAT_STATUS:-Unknown}")
DUR=$(fmt_dur "${SYNC_DURATION:-0}")
MODE_UP=$(echo "${MODE:-auto}" | tr '[:lower:]' '[:upper:]')

# ── Progress bars ──
BAT_BAR=$(make_bar "${BAT:-0}")
INT_BAR=$(make_bar "${INT_PCT:-0}")
SD_BAR=$(make_bar  "${SD_PCT:-0}")
ZH_BAR=$(make_bar  "${ZOHO_PCT:-0}")

# ── Status dots ──
INT_DOT=$(status_dot "${INT_PCT:-0}")
ZH_DOT=$(status_dot  "${ZOHO_PCT:-0}")

# ── MicroSD section ──
_sd_num="${SD_TOTAL:-}"; _sd_num="${_sd_num%G}"
if [ -n "${SD_TOTAL:-}" ] && [ "${_sd_num:-0}" != "0" ] && [ -n "${_sd_num:-}" ]; then
  SD_DOT=$(status_dot "${SD_PCT:-0}")
  SD_SECTION="${SD_DOT} <b>MicroSD Card</b>
   $(fmt_gb "${SD_USED:-0}") / $(fmt_gb "${SD_TOTAL:-0}")  •  Free: <b>$(fmt_gb "${SD_FREE:-0}")</b>
<code>   ${SD_BAR}</code>"
else
  SD_SECTION="💳 <b>MicroSD Card</b>
   <i>Not Detected</i>"
fi

# ── Zoho alert ──
ZH_ALERT=""
[ "${ZOHO_PCT:-0}" -ge 90 ] && ZH_ALERT="
🚨 <b>CRITICAL — Zoho almost full!</b>"
[ "${ZOHO_PCT:-0}" -ge 80 ] && [ "${ZOHO_PCT:-0}" -lt 90 ] && ZH_ALERT="
⚠️ <i>Zoho storage nearing limit</i>"

# ── Sync result status ──
if [ "${TOTAL_UPLOADED:-0}" -gt 0 ] || [ "${TOTAL_DELETED:-0}" -gt 0 ]; then
  SYNC_ICON="✅"; SYNC_LABEL="SUCCESS"
else
  SYNC_ICON="☑️"; SYNC_LABEL="UP TO DATE"
fi

DAY=$(date '+%A, %d %b %Y')
TIME=$(date '+%H:%M:%S')

REPORT="🚀 <b>SUKRULLAH PRO SYNC</b>  <code>v4.3</code>
📅 <i>${DAY}  •  ${TIME}</i>

<b>${SEP}</b>
<b>   ⚡ SYSTEM STATUS</b>
<b>${SEP}</b>
${BAT_ICO} <b>Battery</b>    <b>${BAT:-0}%</b>  <i>(${BAT_STATUS:-Unknown})</i>
<code>   ${BAT_BAR}</code>

📶 <b>Network</b>    <b>${NET}</b>
⚙️ <b>Mode</b>       <b>${MODE_UP}</b>

<b>${SEP}</b>
<b>   💾 STORAGE</b>
<b>${SEP}</b>
${INT_DOT} <b>Internal Storage</b>
   $(fmt_gb "${INT_USED:-0}") / $(fmt_gb "${INT_TOTAL:-0}")  •  Free: <b>$(fmt_gb "${INT_FREE:-0}")</b>
<code>   ${INT_BAR}</code>

${SD_SECTION}

${ZH_DOT} <b>Zoho WorkDrive</b>
   $(fmt_gb "${ZOHO_USED:-0}") / $(fmt_gb "${ZOHO_TOTAL_GB:-55}")  •  Free: <b>$(fmt_gb "${ZOHO_FREE:-0}")</b>
<code>   ${ZH_BAR}</code>${ZH_ALERT}

<b>${SEP}</b>
<b>   📁 SYNC RESULTS</b>
<b>${SEP}</b>
${SYNC_ICON} <b>Status</b>     <b>${SYNC_LABEL}</b>
⬆️ <b>Uploaded</b>   <b>${TOTAL_UPLOADED:-0}</b> files
🗑️ <b>Deleted</b>    <b>${TOTAL_DELETED:-0}</b> files
⏱️ <b>Duration</b>   <b>${DUR}</b>

<b>${SEP}</b>"

Y='\033[1;33m'; N='\033[0m'; SB='\033[38;5;39m'
echo -e "${SB}📡 Sending Telegram report...${N}"

TMP=$(mktemp)
printf '%s' "$REPORT" > "$TMP"
resp=$(curl -s --max-time 30 \
  -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
  --data-urlencode "text@${TMP}" \
  -d "chat_id=${TG_CHAT_ID}" \
  -d "parse_mode=HTML")
rm -f "$TMP"

echo "$resp" | grep -q '"ok":true' \
  && echo -e "\033[38;5;118m✅ Telegram report sent!\033[0m" \
  || echo -e "${Y}⚠ TG send failed${N}"
