#!/data/data/com.termux/files/usr/bin/bash
########################################
# SUKRULLAH TELEGRAM REPORT v4.3 (Improved)
# - Bars corrected (emoji color bars)
# - Battery color different, storage colors different
# - Storage always in GB
# - Safe HTML escaping for Telegram
########################################

set +e

# ---------- Load env ----------
ENV_FILE="$HOME/sync_project/.env"
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"

TG_TOKEN="${TG_TOKEN:-}"
TG_CHAT_ID="${TG_CHAT_ID:-}"

# silently exit if not configured
[[ -z "$TG_TOKEN" || -z "$TG_CHAT_ID" ]] && exit 0

# ---------- Helpers ----------
html_escape() {
  # Escape for Telegram HTML parse_mode
  # &, <, >
  echo -n "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

# Convert: 120M / 1.5G / 2T / bytes => "x.xG"
to_gb() {
  local v="${1:-0}"
  v="${v// /}"
  [[ -z "$v" ]] && v="0"

  # already G/GB
  if [[ "$v" =~ ^[0-9]+([.][0-9]+)?([Gg])([Bb])?$ ]]; then
    awk -v x="${v%[Gg]*}" 'BEGIN{printf "%.1fG", x+0}'; return
  fi
  # T/TB
  if [[ "$v" =~ ^[0-9]+([.][0-9]+)?([Tt])([Bb])?$ ]]; then
    awk -v x="${v%[Tt]*}" 'BEGIN{printf "%.1fG", (x+0)*1024}'; return
  fi
  # M/MB
  if [[ "$v" =~ ^[0-9]+([.][0-9]+)?([Mm])([Bb])?$ ]]; then
    awk -v x="${v%[Mm]*}" 'BEGIN{printf "%.1fG", (x+0)/1024}'; return
  fi
  # K/KB
  if [[ "$v" =~ ^[0-9]+([.][0-9]+)?([Kk])([Bb])?$ ]]; then
    awk -v x="${v%[Kk]*}" 'BEGIN{printf "%.3fG", (x+0)/1024/1024}'; return
  fi
  # bytes numeric
  if [[ "$v" =~ ^[0-9]+$ ]]; then
    awk -v b="$v" 'BEGIN{printf "%.1fG", (b/1024/1024/1024)}'; return
  fi

  echo "$v"
}

# df stats -> used total avail pct  (bytes)
df_stats() {
  local path="$1"
  local out used total avail pct
  out="$(df -B1 "$path" 2>/dev/null | awk 'NR==2{print $3,$2,$4}')"
  if [[ -z "$out" ]]; then
    echo "0 0 0 0"
    return
  fi
  read -r used total avail <<<"$out"
  pct="$(awk -v u="$used" -v t="$total" 'BEGIN{ if(t>0) printf "%d", (u*100/t); else print 0 }')"
  echo "$used $total $avail $pct"
}

detect_internal_path() {
  [[ -d "$HOME/storage/shared" ]] && { echo "$HOME/storage/shared"; return; }
  [[ -d "/storage/emulated/0" ]] && { echo "/storage/emulated/0"; return; }
  [[ -d "/sdcard" ]] && { echo "/sdcard"; return; }
  echo "$PREFIX"
}

detect_sd_path() {
  if [[ -d "/storage" ]]; then
    local p
    for p in /storage/*; do
      [[ -d "$p" ]] || continue
      [[ "$p" =~ /storage/(emulated|self)$ ]] && continue
      echo "$p"
      return
    done
  fi
  echo ""
}

# Correct emoji progress bar (Telegram-friendly)
# usage: ebar PCT FILLED_EMOJI EMPTY_EMOJI LEN
ebar() {
  local pct="${1:-0}"
  local fill="${2:-🟦}"
  local empty="${3:-⬜}"
  local len="${4:-18}"

  [[ "$pct" -lt 0 ]] && pct=0
  [[ "$pct" -gt 100 ]] && pct=100

  local filled=$(( pct * len / 100 ))
  local i out=""
  for ((i=1; i<=len; i++)); do
    if (( i <= filled )); then out+="$fill"; else out+="$empty"; fi
  done
  printf "%s %3d%%" "$out" "$pct"
}

# ---------- Collect runtime values (fallbacks) ----------
# Battery + Temp
if command -v termux-battery-status >/dev/null 2>&1; then
  BJSON="$(termux-battery-status 2>/dev/null)"
  [[ -z "${BAT:-}" ]] && BAT="$(echo "$BJSON" | awk -F'[:,}]' '/percentage/{gsub(/[^0-9]/,"",$2); print $2; exit}')"
  [[ -z "${BAT_STATUS:-}" ]] && BAT_STATUS="$(echo "$BJSON" | awk -F\" '/"status"/{print $4; exit}')"
  [[ -z "${TEMP_C:-}" ]] && TEMP_C="$(echo "$BJSON" | awk -F'[:,}]' '/temperature/{gsub(/[^0-9.]/,"",$2); if($2!="") print $2; exit}')"
fi
BAT="${BAT:-0}"
BAT_STATUS="${BAT_STATUS:-Unknown}"
TEMP_C="${TEMP_C:-N/A}"

# Network SSID
if [[ -z "${CURRENT_WIFI:-}" ]] && command -v termux-wifi-connectioninfo >/dev/null 2>&1; then
  CURRENT_WIFI="$(termux-wifi-connectioninfo 2>/dev/null | awk -F\" '/"ssid"/{print $4; exit}')"
  [[ "$CURRENT_WIFI" = "<unknown ssid>" ]] && CURRENT_WIFI=""
fi
NET="$( [[ -n "${CURRENT_WIFI:-}" ]] && echo "${CURRENT_WIFI}" || echo "Mobile Data" )"
MODE="${MODE:-auto}"

# Internal storage (force GB)
INTERNAL_PATH="$(detect_internal_path)"
if [[ -z "${INT_TOTAL:-}" || -z "${INT_USED:-}" || -z "${INT_FREE:-}" || -z "${INT_PCT:-}" ]]; then
  read -r iu it ia ip <<<"$(df_stats "$INTERNAL_PATH")"
  INT_USED="$(to_gb "$iu")"
  INT_TOTAL="$(to_gb "$it")"
  INT_FREE="$(to_gb "$ia")"
  INT_PCT="$ip"
else
  INT_USED="$(to_gb "${INT_USED}")"
  INT_TOTAL="$(to_gb "${INT_TOTAL}")"
  INT_FREE="$(to_gb "${INT_FREE}")"
fi

# SD card (optional)
SD_PATH="$(detect_sd_path)"
SD_DETECTED=0
if [[ -n "$SD_PATH" ]]; then
  read -r su st sa sp <<<"$(df_stats "$SD_PATH")"
  # If total is 0 then treat as not detected
  if [[ "$st" -gt 0 ]]; then
    SD_DETECTED=1
    SD_USED="$(to_gb "$su")"
    SD_TOTAL="$(to_gb "$st")"
    SD_FREE="$(to_gb "$sa")"
    SD_PCT="$sp"
  fi
fi
[[ -z "${SD_PCT:-}" ]] && SD_PCT=0

# Zoho (display in GB)
ZOHO_TOTAL_GB="${ZOHO_TOTAL_GB:-55}"
ZOHO_USED="$(to_gb "${ZOHO_USED:-0G}")"
ZOHO_FREE="$(to_gb "${ZOHO_FREE:-0G}")"
ZOHO_PCT="${ZOHO_PCT:-0}"

# OneDrive (display only)
OD_USED_G="$(to_gb "${OD_USED_G:-N/A}")"
OD_TOTAL="$(to_gb "${OD_TOTAL:-N/A}")"
OD_FREE_G="$(to_gb "${OD_FREE_G:-N/A}")"
OD_PCT="${OD_PCT:-0}"

# ---------- Bars (different colors) ----------
# Battery: green blocks + black empties
BAT_BAR="$(ebar "$BAT" "🟩" "⬛" 18)"

# Storage: internal blue, SD brown, Zoho purple, OD blue-circle theme
INT_BAR="$(ebar "${INT_PCT:-0}" "🟦" "⬜" 18)"
SD_BAR="$(ebar "${SD_PCT:-0}" "🟫" "⬜" 18)"
ZOHO_BAR="$(ebar "${ZOHO_PCT:-0}" "🟪" "⬜" 18)"
OD_BAR="$(ebar "${OD_PCT:-0}" "🟦" "⬜" 18)"

# Icons by battery status
BICON="🔋"
case "$BAT_STATUS" in
  CHARGING|Charging) BICON="⚡🔋" ;;
  FULL|Full)         BICON="✅🔋" ;;
esac

NOW_TS="$(date '+%d %b %Y, %H:%M:%S')"

# ---------- Build message (HTML) ----------
NET_ESC="$(html_escape "$NET")"
MODE_ESC="$(html_escape "$MODE")"
LOG_ESC="$(html_escape "${MASTER_LOG:-sync_logs/master_sync.log}")"

REPORT="🛰️ <b>SUKRULLAH PRO SYNC</b> <i>v4.3</i>

<b>🧩 SYSTEM</b>
${BICON} Battery: <b>${BAT}%</b> (${BAT_STATUS})  🌡️ <b>${TEMP_C}°C</b>
<code>${BAT_BAR}</code>
📶 Network: <b>${NET_ESC}</b>
🛠️ Mode: <b>${MODE_ESC}</b>
🕒 Time: <i>${NOW_TS}</i>

<b>💾 STORAGE (GB)</b>
📱 Internal: <b>${INT_USED}</b> / <b>${INT_TOTAL}</b>  • Free: <b>${INT_FREE}</b>
<code>${INT_BAR}</code>"

if [[ "$SD_DETECTED" -eq 1 ]]; then
  REPORT="${REPORT}

💳 SD Card: <b>${SD_USED}</b> / <b>${SD_TOTAL}</b>  • Free: <b>${SD_FREE}</b>
<code>${SD_BAR}</code>"
else
  REPORT="${REPORT}

💳 SD Card: <b>Not detected</b>
<code>${SD_BAR}</code>"
fi

REPORT="${REPORT}

☁️ Zoho WorkDrive: <b>${ZOHO_USED}</b> / <b>${ZOHO_TOTAL_GB}G</b>  • Free: <b>${ZOHO_FREE}</b>
<code>${ZOHO_BAR}</code>

🔵 OneDrive: <b>${OD_USED_G}</b> / <b>${OD_TOTAL}</b>  • Free: <b>${OD_FREE_G}</b> <i>(Display Only)</i>
<code>${OD_BAR}</code>

<b>📦 SYNC RESULTS</b>
⬆️ Uploaded: <b>${TOTAL_UPLOADED:-0}</b> files
🗑️ Deleted: <b>${TOTAL_DELETED:-0}</b> files
📝 Log: <code>${LOG_ESC}</code>"

# ---------- Send Telegram ----------
echo "📡 Sending Telegram report..."
resp="$(curl -s -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
  -F "chat_id=${TG_CHAT_ID}" \
  -F "parse_mode=HTML" \
  -F "disable_web_page_preview=true" \
  -F "text=${REPORT}")"

echo "$resp" | grep -q '"ok":true'
if [[ $? -eq 0 ]]; then
  echo "✅ Telegram report sent!"
else
  echo "⚠️ TG send failed"
  echo "$resp"
fi
