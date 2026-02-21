#!/data/data/com.termux/files/usr/bin/bash
########################################
# SUKRULLAH TELEGRAM REPORT v4.6 FINAL (SD FIX)
# - Emoji bars (always visible on Telegram)
# - Internal/SD in GB via df
# - Safe send (data-urlencode)
########################################

ENV_FILE="$HOME/sync_project/.env"
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"

TG_TOKEN="${TG_TOKEN:-}"
TG_CHAT_ID="${TG_CHAT_ID:-}"

# Exit if missing
[[ -z "$TG_TOKEN" || -z "$TG_CHAT_ID" ]] && exit 0

# ───── Helpers ─────
html_escape() { echo -n "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'; }

pct_safe() {
  local v="${1:-0}"
  v="$(echo "$v" | tr -cd '0-9')"
  [[ -z "$v" ]] && v=0
  (( v<0 )) && v=0
  (( v>100 )) && v=100
  echo "$v"
}

to_gb_bytes(){ awk -v b="${1:-0}" 'BEGIN{printf "%.1fG", (b/1024/1024/1024)}'; }

df_stats() {
  local p="$1"
  local u t f pct
  read -r u t f < <(df -B1 "$p" 2>/dev/null | awk 'NR==2{print $3,$2,$4}')
  [[ -z "$t" || "$t" -le 0 ]] && echo "0 0 0 0" && return
  pct="$(awk -v u="$u" -v t="$t" 'BEGIN{printf "%d", (u*100/t)}')"
  echo "$u $t $f $pct"
}

detect_internal_path(){
  [[ -d "$HOME/storage/shared" ]] && { echo "$HOME/storage/shared"; return; }
  [[ -d "/storage/emulated/0" ]] && { echo "/storage/emulated/0"; return; }
  [[ -d "/sdcard" ]] && { echo "/sdcard"; return; }
  echo "$PREFIX"
}

# ✅ SD ROOT DETECTOR (external-1 -> /storage/F453-D575)
detect_sd_path() {
  local p rp root

  for p in "$HOME/storage/external-1" "$HOME/storage/external-2"; do
    if [[ -e "$p" ]]; then
      rp="$(readlink -f "$p" 2>/dev/null)"
      if [[ -n "$rp" ]]; then
        if [[ "$rp" == */Android/data/com.termux/files* ]]; then
          root="${rp%/Android/data/com.termux/files*}"
          [[ -d "$root" ]] && { echo "$root"; return; }
        fi
        [[ -d "$rp" ]] && { echo "$rp"; return; }
      fi
    fi
  done

  if [[ -d "/storage" ]]; then
    for p in /storage/*; do
      [[ -d "$p" ]] || continue
      [[ "$p" =~ /storage/(emulated|self)$ ]] && continue
      if echo "$p" | grep -Eq '/storage/[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}$'; then
        echo "$p"; return
      fi
    done
  fi

  if [[ -d "/mnt/media_rw" ]]; then
    for p in /mnt/media_rw/*; do
      [[ -d "$p" ]] || continue
      if echo "$p" | grep -Eq '/mnt/media_rw/[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}$'; then
        echo "$p"; return
      fi
    done
  fi

  echo ""
}

# Emoji bar for Telegram
ebar() {
  local pct="$(pct_safe "$1")"
  local fill="${2:-🟩}"
  local empty="${3:-⬛}"
  local len="${4:-16}"
  local filled=$(( pct * len / 100 ))
  local i out=""
  for ((i=1;i<=len;i++)); do
    if (( i<=filled )); then out+="$fill"; else out+="$empty"; fi
  done
  printf "%s %3d%%" "$out" "$pct"
}

# ───── Battery + WiFi fallback ─────
if command -v termux-battery-status >/dev/null 2>&1; then
  BJSON="$(termux-battery-status 2>/dev/null)"
  [[ -z "${BAT:-}" ]] && BAT="$(echo "$BJSON" | awk -F'[:,}]' '/percentage/{gsub(/[^0-9]/,"",$2); print $2; exit}')"
  [[ -z "${BAT_STATUS:-}" ]] && BAT_STATUS="$(echo "$BJSON" | awk -F\" '/"status"/{print $4; exit}')"
fi
BAT="$(pct_safe "${BAT:-0}")"
BAT_STATUS="${BAT_STATUS:-Unknown}"

if [[ -z "${CURRENT_WIFI:-}" ]] && command -v termux-wifi-connectioninfo >/dev/null 2>&1; then
  CURRENT_WIFI="$(termux-wifi-connectioninfo 2>/dev/null | awk -F\" '/"ssid"/{print $4; exit}')"
  [[ "$CURRENT_WIFI" = "<unknown ssid>" ]] && CURRENT_WIFI=""
fi
NET="$( [[ -n "${CURRENT_WIFI:-}" ]] && echo "${CURRENT_WIFI}" || echo "Mobile Data" )"

# ───── Internal/SD storage (GB) ─────
INT_PATH="$(detect_internal_path)"
read -r IU IT IF IP < <(df_stats "$INT_PATH")
INT_USED="$(to_gb_bytes "$IU")"
INT_TOTAL="$(to_gb_bytes "$IT")"
INT_FREE="$(to_gb_bytes "$IF")"
INT_PCT="$(pct_safe "$IP")"

SD_PATH="$(detect_sd_path)"
SD_OK=0
SD_PCT=0
if [[ -n "$SD_PATH" ]]; then
  read -r SU ST SF SP < <(df_stats "$SD_PATH")
  if [[ "$ST" -gt 0 ]]; then
    SD_OK=1
    SD_USED="$(to_gb_bytes "$SU")"
    SD_TOTAL="$(to_gb_bytes "$ST")"
    SD_FREE="$(to_gb_bytes "$SF")"
    SD_PCT="$(pct_safe "$SP")"
  fi
fi

# Zoho / OneDrive (use existing sync vars)
ZOHO_TOTAL_GB="${ZOHO_TOTAL_GB:-55}"
ZOHO_USED="${ZOHO_USED:-0}G"
ZOHO_FREE="${ZOHO_FREE:-0}G"
ZOHO_PCT="$(pct_safe "${ZOHO_PCT:-0}")"

OD_USED_G="${OD_USED_G:-N/A}"
OD_TOTAL="${OD_TOTAL:-N/A}"
OD_FREE_G="${OD_FREE_G:-N/A}"
OD_PCT="$(pct_safe "${OD_PCT:-0}")"

# ───── Bars (unique colors) ─────
BAT_BAR="$(ebar "$BAT" "🟩" "⬛" 16)"
INT_BAR="$(ebar "$INT_PCT" "🟦" "⬜" 16)"
SD_BAR="$(ebar "$SD_PCT" "🟫" "⬜" 16)"
ZH_BAR="$(ebar "$ZOHO_PCT" "🟪" "⬜" 16)"
OD_BAR="$(ebar "$OD_PCT" "🟦" "⬜" 16)"

BICON="🔋"
case "$BAT_STATUS" in
  CHARGING|Charging) BICON="⚡🔋" ;;
  FULL|Full)         BICON="✅🔋" ;;
esac

NOW="$(date '+%d %b %Y, %H:%M:%S')"
MODE="${MODE:-auto}"

NET_ESC="$(html_escape "$NET")"
MODE_ESC="$(html_escape "$MODE")"
LOG_ESC="$(html_escape "${MASTER_LOG:-sync_logs/master_sync.log}")"

REPORT="🛰️ <b>SUKRULLAH PRO SYNC</b> <i>v4.6</i>

<b>🧩 SYSTEM</b>
${BICON} Battery: <b>${BAT}%</b> (${BAT_STATUS})
<code>${BAT_BAR}</code>
📶 Network: <b>${NET_ESC}</b>
🛠️ Mode: <b>${MODE_ESC}</b>
🕒 Time: <i>${NOW}</i>

<b>💾 STORAGE (GB)</b>
📱 Internal: <b>${INT_USED}</b> / <b>${INT_TOTAL}</b> • Free: <b>${INT_FREE}</b>
<code>${INT_BAR}</code>"

if [[ "$SD_OK" -eq 1 ]]; then
  REPORT="${REPORT}

💳 SD Card: <b>${SD_USED}</b> / <b>${SD_TOTAL}</b> • Free: <b>${SD_FREE}</b>
<code>${SD_BAR}</code>"
else
  REPORT="${REPORT}

💳 SD Card: <b>Not detected</b>
<code>${SD_BAR}</code>"
fi

REPORT="${REPORT}

☁️ Zoho WorkDrive: <b>${ZOHO_USED}</b> / <b>${ZOHO_TOTAL_GB}G</b> • Free: <b>${ZOHO_FREE}</b>
<code>${ZH_BAR}</code>

🔵 OneDrive: <b>${OD_USED_G}</b> / <b>${OD_TOTAL}</b> • Free: <b>${OD_FREE_G}</b> <i>(Display Only)</i>
<code>${OD_BAR}</code>

<b>📦 SYNC RESULTS</b>
⬆️ Uploaded: <b>${TOTAL_UPLOADED:-0}</b> files
🗑️ Deleted: <b>${TOTAL_DELETED:-0}</b> files
📝 Log: <code>${LOG_ESC}</code>"

echo "📡 Sending Telegram report..."
resp="$(curl -s -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
  -d "chat_id=${TG_CHAT_ID}" \
  -d "parse_mode=HTML" \
  -d "disable_web_page_preview=true" \
  --data-urlencode "text=${REPORT}")"

if echo "$resp" | grep -q '"ok":true'; then
  echo "✅ Telegram report sent!"
else
  echo "⚠️ TG send failed"
  echo "$resp"
fi
