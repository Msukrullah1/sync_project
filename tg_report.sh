#!/data/data/com.termux/files/usr/bin/bash
########################################
# SUKRULLAH TELEGRAM REPORT v4.2 (Advanced)
# Only Telegram report — safe + clean + GB everywhere
########################################

# Load env safely
ENV_FILE="$HOME/sync_project/.env"
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"

TG_TOKEN="${TG_TOKEN:-}"
TG_CHAT_ID="${TG_CHAT_ID:-}"

# If not configured, silently exit (as your original logic)
if [[ -z "$TG_TOKEN" || -z "$TG_CHAT_ID" ]]; then
  exit 0
fi

# ───────────────── Helpers ─────────────────
# Convert strings like 120M/1.5G/2T/bytes => "x.xG"
to_gb() {
  local v="${1:-0}"
  v="${v// /}"
  [[ -z "$v" ]] && v="0"

  if [[ "$v" =~ ^[0-9]+([.][0-9]+)?([Gg])([Bb])?$ ]]; then
    awk -v x="${v%[Gg]*}" 'BEGIN{printf "%.1fG", x+0}'; return
  fi
  if [[ "$v" =~ ^[0-9]+([.][0-9]+)?([Tt])([Bb])?$ ]]; then
    awk -v x="${v%[Tt]*}" 'BEGIN{printf "%.1fG", (x+0)*1024}'; return
  fi
  if [[ "$v" =~ ^[0-9]+([.][0-9]+)?([Mm])([Bb])?$ ]]; then
    awk -v x="${v%[Mm]*}" 'BEGIN{printf "%.1fG", (x+0)/1024}'; return
  fi
  if [[ "$v" =~ ^[0-9]+([.][0-9]+)?([Kk])([Bb])?$ ]]; then
    awk -v x="${v%[Kk]*}" 'BEGIN{printf "%.3fG", (x+0)/1024/1024}'; return
  fi
  if [[ "$v" =~ ^[0-9]+$ ]]; then
    awk -v b="$v" 'BEGIN{printf "%.1fG", (b/1024/1024/1024)}'; return
  fi
  echo "$v"
}

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

# Telegram bar
tbar() {
  local v="${1:-0}" w=28
  [[ "$v" -lt 0 ]] && v=0
  [[ "$v" -gt 100 ]] && v=100
  local f=$(( v*w/100 )) out="" i
  for ((i=1;i<=w;i++)); do
    if [[ $i -le $f ]]; then out+="█"; else out+="░"; fi
  done
  printf "%s %3d%%" "$out" "$v"
}

# ───────────────── Collect runtime values (fallbacks) ─────────────────
# Battery
if [[ -z "${BAT:-}" ]] && command -v termux-battery-status >/dev/null 2>&1; then
  BAT="$(termux-battery-status 2>/dev/null | awk -F'[:,}]' '/percentage/{gsub(/[^0-9]/,"",$2); print $2; exit}')"
fi
BAT="${BAT:-0}"
BAT_STATUS="${BAT_STATUS:-Unknown}"

# Network
if [[ -z "${CURRENT_WIFI:-}" ]] && command -v termux-wifi-connectioninfo >/dev/null 2>&1; then
  CURRENT_WIFI="$(termux-wifi-connectioninfo 2>/dev/null | awk -F\" '/"ssid"/{print $4; exit}')"
  [[ "$CURRENT_WIFI" = "<unknown ssid>" ]] && CURRENT_WIFI=""
fi
NET="$( [[ -n "${CURRENT_WIFI:-}" ]] && echo "${CURRENT_WIFI}" || echo "Mobile Data" )"

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
if [[ -n "$SD_PATH" ]]; then
  read -r su st sa sp <<<"$(df_stats "$SD_PATH")"
  SD_USED="$(to_gb "$su")"
  SD_TOTAL="$(to_gb "$st")"
  SD_FREE="$(to_gb "$sa")"
  SD_PCT="$sp"
else
  SD_USED="N/A"; SD_TOTAL="N/A"; SD_FREE="N/A"; SD_PCT="0"
fi

# Zoho (already usually in G, normalize)
ZOHO_USED="$(to_gb "${ZOHO_USED:-0G}")"
ZOHO_FREE="$(to_gb "${ZOHO_FREE:-0G}")"
ZOHO_TOTAL_GB="${ZOHO_TOTAL_GB:-55}"
ZOHO_PCT="${ZOHO_PCT:-0}"

# OneDrive (display only)
OD_USED_G="$(to_gb "${OD_USED_G:-N/A}")"
OD_TOTAL="$(to_gb "${OD_TOTAL:-N/A}")"
OD_FREE_G="$(to_gb "${OD_FREE_G:-N/A}")"
OD_PCT="${OD_PCT:-0}"

# Bars
BAT_TB="$(tbar "$BAT")"
INT_TB="$(tbar "${INT_PCT:-0}")"
SD_TB="$(tbar "${SD_PCT:-0}")"
ZH_TB="$(tbar "$ZOHO_PCT")"
OD_TB="$(tbar "$OD_PCT")"

MODE="${MODE:-auto}"
NOW_TS="$(date '+%d %b %Y, %H:%M:%S')"

# ───────────────── Telegram message ─────────────────
REPORT="🚀 <b>SUKRULLAH PRO SYNC v4.2</b>
⚙️ <b>SYSTEM</b>
🔋 Battery : <b>${BAT}%</b> (${BAT_STATUS})
<code>${BAT_TB}</code>
📡 Network : ${NET}
⚙️ Mode : ${MODE}
🕒 Time : ${NOW_TS}

💾 <b>STORAGE (GB)</b>
📱 Internal : ${INT_USED} / ${INT_TOTAL} • Free: ${INT_FREE}
<code>${INT_TB}</code>
💳 SD Card : ${SD_USED} / ${SD_TOTAL} • Free: ${SD_FREE}
<code>${SD_TB}</code>
☁️ Zoho : ${ZOHO_USED} / ${ZOHO_TOTAL_GB}G • Free: ${ZOHO_FREE}
<code>${ZH_TB}</code>
🔵 OneDrive : ${OD_USED_G} / ${OD_TOTAL} • Free: ${OD_FREE_G} (Display Only)
<code>${OD_TB}</code>

📁 <b>SYNC RESULTS</b>
⬆️ Uploaded : <b>${TOTAL_UPLOADED:-0}</b> files
🗑️ Deleted : <b>${TOTAL_DELETED:-0}</b> files
📝 Log: ${MASTER_LOG:-sync_logs/master_sync.log}"

# ───────────────── Send Telegram ─────────────────
SB='\033[38;5;39m'; Y='\033[1;33m'; N='\033[0m'
echo -e "${SB}📡 Sending Telegram report...${N}"

if ! command -v curl >/dev/null 2>&1; then
  echo -e "${Y}⚠ curl not found. Install: pkg install curl${N}"
  exit 1
fi

resp="$(curl -s -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
  -F "chat_id=${TG_CHAT_ID}" \
  -F "parse_mode=HTML" \
  -F "text=${REPORT}")"

if echo "$resp" | grep -q '"ok":true'; then
  echo -e "\033[38;5;118m✅ Telegram report sent!\033[0m"
else
  echo -e "${Y}⚠ TG send failed${N}"
  echo "$resp"
fi
