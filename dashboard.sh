#!/data/data/com.termux/files/usr/bin/bash
########################################
# SUKRULLAH DASHBOARD v4.2 (Advanced)
# Termux display — Poco X3 Pro (width fixed)
# Features removed: NONE (only improved + added fallbacks)
########################################

# ───────────────── Colors ─────────────────
R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; C='\033[0;36m'
M='\033[0;35m'; O='\033[38;5;214m'; LM='\033[38;5;154m'; SB='\033[38;5;39m'
PK='\033[38;5;213m'; B='\033[1m'; D='\033[2m'; N='\033[0m'
LIME='\033[38;5;118m'; ROSE='\033[38;5;204m'; GD='\033[38;5;220m'

# ───────────────── Fixed width — Poco X3 Pro (DO NOT CHANGE) ─────────────────
BOXW=46
BARW=34

line() { printf "%*s" "$1" "" | tr ' ' "$2"; }
dtop() { echo -e "${C}╭$(line $BOXW ─)╮${N}"; }
dmid() { echo -e "${C}├$(line $BOXW ─)┤${N}"; }
dbot() { echo -e "${C}╰$(line $BOXW ─)╯${N}"; }
row()  { echo -e "${C}│${N} $1"; }
dempty(){ echo -e "${C}│${N}"; }

# ───────────────── Helpers (GB normalize + percent safe) ─────────────────
# Convert strings like: 120M, 1.5G, 1024K, 2T, 1234567890 (bytes) => "x.xG"
to_gb() {
  local v="${1:-0}"
  v="${v// /}"
  [[ -z "$v" ]] && v="0"

  # If already ends with G/GB
  if [[ "$v" =~ ^[0-9]+([.][0-9]+)?([Gg])([Bb])?$ ]]; then
    awk -v x="${v%[Gg]*}" 'BEGIN{printf "%.1fG", x+0}'
    return
  fi

  # T / TB
  if [[ "$v" =~ ^[0-9]+([.][0-9]+)?([Tt])([Bb])?$ ]]; then
    awk -v x="${v%[Tt]*}" 'BEGIN{printf "%.1fG", (x+0)*1024}'
    return
  fi

  # M / MB
  if [[ "$v" =~ ^[0-9]+([.][0-9]+)?([Mm])([Bb])?$ ]]; then
    awk -v x="${v%[Mm]*}" 'BEGIN{printf "%.1fG", (x+0)/1024}'
    return
  fi

  # K / KB
  if [[ "$v" =~ ^[0-9]+([.][0-9]+)?([Kk])([Bb])?$ ]]; then
    awk -v x="${v%[Kk]*}" 'BEGIN{printf "%.3fG", (x+0)/1024/1024}'
    return
  fi

  # Bytes numeric
  if [[ "$v" =~ ^[0-9]+$ ]]; then
    awk -v b="$v" 'BEGIN{printf "%.1fG", (b/1024/1024/1024)}'
    return
  fi

  # Unknown, return as-is
  echo "${v}"
}

# Get df stats in bytes for a path -> "used total avail pct"
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

# Auto detect shared storage mount
detect_internal_path() {
  # Prefer Termux shared storage if available
  if [[ -d "$HOME/storage/shared" ]]; then
    echo "$HOME/storage/shared"
    return
  fi
  # Try common Android paths
  if [[ -d "/storage/emulated/0" ]]; then
    echo "/storage/emulated/0"
    return
  fi
  if [[ -d "/sdcard" ]]; then
    echo "/sdcard"
    return
  fi
  # Fallback to Termux prefix
  echo "$PREFIX"
}

# Auto detect SD card (typical: /storage/XXXX-XXXX)
detect_sd_path() {
  if [[ -d "/storage" ]]; then
    local p
    # pick first mount-like folder, exclude emulated/self
    for p in /storage/*; do
      [[ -d "$p" ]] || continue
      [[ "$p" =~ /storage/(emulated|self)$ ]] && continue
      # many SD cards look like /storage/XXXX-XXXX
      echo "$p"
      return
    done
  fi
  echo ""
}

# ───────────────── Progress bar ─────────────────
cc() { printf "\033[38;5;%sm" "$1"; }
rc() { printf "\033[0m"; }

color_scale(){
  local v=$1
  [[ "$v" -le 25 ]] && echo 46  && return
  [[ "$v" -le 50 ]] && echo 190 && return
  [[ "$v" -le 75 ]] && echo 214 && return
  echo 196
}

fpbar(){
  local val=$1
  [[ "$val" -lt 0 ]] && val=0
  [[ "$val" -gt 100 ]] && val=100
  local filled=$(( val * BARW / 100 ))
  local empty=$(( BARW - filled ))
  local bar="" i c p
  for((i=1;i<=filled;i++)); do
    p=$(( i*100/BARW ))
    c=$(color_scale "$p")
    bar+=$(cc "$c")"█"
  done
  for((i=1;i<=empty;i++)); do
    bar+=$(cc 242)"░"
  done
  printf "▕%s%s %s%3d%%%s" "$bar" "$(rc)" "$(cc 250)" "$val" "$(rc)"
}

bat_icon(){
  local p=$1 s=$2
  case "$s" in
    CHARGING|Charging) echo "🔌"; return;;
  esac
  [[ "$p" -le 10 ]] && echo "🪫" || echo "🔋"
}

# ───────────────── WATCH MODE (kept intact, only hardened) ─────────────────
if [[ "${MODE:-}" = "watch" ]] || [[ "${1:-}" = "watch" ]]; then
  clear; dtop
  row " ${PK}${B}◈ WIFI WATCHER ACTIVE${N}"
  row " ${D}Networks: ${ALLOWED_WIFI1} / ${ALLOWED_WIFI2}${N}"
  row " ${D}Interval: 2h  Stop: Ctrl+C${N}"
  dbot

  LAST_WIFI=""
  while true; do
    WIFI_NOW=""
    if command -v termux-wifi-connectioninfo >/dev/null 2>&1; then
      WIFI_NOW="$(termux-wifi-connectioninfo 2>/dev/null | awk -F\" '/"ssid"/{print $4; exit}')"
      [[ "$WIFI_NOW" = "<unknown ssid>" ]] && WIFI_NOW=""
    fi

    TS="$(date '+%H:%M:%S')"
    if [[ "$WIFI_NOW" = "${ALLOWED_WIFI1:-}" ]] || [[ "$WIFI_NOW" = "${ALLOWED_WIFI2:-}" ]]; then
      if [[ "$LAST_WIFI" != "$WIFI_NOW" ]]; then
        echo -e "${LIME}[$TS]${N} WiFi: ${B}${WIFI_NOW}${N} — Syncing!"
        LAST_WIFI="$WIFI_NOW"
        bash "$HOME/sync_project/sync.sh" manual
      else
        echo -e "${D}[$TS] Already synced. Next in 2h.${N}"
      fi
    else
      echo -e "${Y}[$TS]${N} Waiting... ${B}${WIFI_NOW:-Mobile Data}${N}"
      LAST_WIFI=""
    fi
    sleep 7200
  done
  exit 0
fi

DAY="$(date '+%A, %d %b %Y')"

# ───────────────── Fill missing values (fallbacks) ─────────────────
# WIFI
if [[ -z "${CURRENT_WIFI:-}" ]] && command -v termux-wifi-connectioninfo >/dev/null 2>&1; then
  CURRENT_WIFI="$(termux-wifi-connectioninfo 2>/dev/null | awk -F\" '/"ssid"/{print $4; exit}')"
  [[ "$CURRENT_WIFI" = "<unknown ssid>" ]] && CURRENT_WIFI=""
fi

# Battery (fallback)
if [[ -z "${BAT:-}" ]] && command -v termux-battery-status >/dev/null 2>&1; then
  BAT="$(termux-battery-status 2>/dev/null | awk -F'[:,}]' '/percentage/{gsub(/[^0-9]/,"",$2); print $2; exit}')"
fi
[[ -z "${BAT:-}" ]] && BAT=0
[[ -z "${BAT_STATUS:-}" ]] && BAT_STATUS="Unknown"

# Internal storage fallback compute (bytes -> display GB)
INTERNAL_PATH="$(detect_internal_path)"
if [[ -z "${INT_TOTAL:-}" || -z "${INT_USED:-}" || -z "${INT_FREE:-}" || -z "${INT_PCT:-}" ]]; then
  read -r _u _t _a _p <<<"$(df_stats "$INTERNAL_PATH")"
  INT_USED="$(to_gb "$_u")"
  INT_TOTAL="$(to_gb "$_t")"
  INT_FREE="$(to_gb "$_a")"
  INT_PCT="${_p}"
else
  # normalize to GB anyway
  INT_USED="$(to_gb "${INT_USED}")"
  INT_TOTAL="$(to_gb "${INT_TOTAL}")"
  INT_FREE="$(to_gb "${INT_FREE}")"
fi

# SD card fallback compute
SD_PATH="$(detect_sd_path)"
if [[ -n "$SD_PATH" ]]; then
  read -r su st sa sp <<<"$(df_stats "$SD_PATH")"
  SD_RAW="1"
  SD_USED="$(to_gb "$su")"
  SD_TOTAL="$(to_gb "$st")"
  SD_FREE="$(to_gb "$sa")"
  SD_PCT="$sp"
else
  SD_RAW=""
fi

# Zoho normalize (if provided)
if [[ -n "${ZOHO_RAW:-}" || -n "${ZOHO_USED:-}" || -n "${ZOHO_FREE:-}" ]]; then
  ZOHO_USED="$(to_gb "${ZOHO_USED:-0G}")"
  ZOHO_FREE="$(to_gb "${ZOHO_FREE:-0G}")"
  # total is config in GB
  ZOHO_TOTAL_GB="${ZOHO_TOTAL_GB:-55}"
fi

# OneDrive normalize (display only)
if [[ -n "${OD_TOTAL:-}" || -n "${OD_USED_G:-}" || -n "${OD_FREE_G:-}" ]]; then
  OD_USED_G="$(to_gb "${OD_USED_G:-0G}")"
  OD_TOTAL="$(to_gb "${OD_TOTAL:-0G}")"
  OD_FREE_G="$(to_gb "${OD_FREE_G:-0G}")"
fi

# ───────────────── BLOCKED screen (auto mode wrong wifi) ─────────────────
if [[ "${MODE:-auto}" = "auto" ]]; then
  if [[ "${CURRENT_WIFI:-}" != "${ALLOWED_WIFI1:-}" ]] && [[ "${CURRENT_WIFI:-}" != "${ALLOWED_WIFI2:-}" ]]; then
    clear
    echo ""
    echo -e " ${GD}${B}★ SUKRULLAH PRO SYNC v4.2 ★${N}"
    echo -e " ${D}${DAY}${N}"
    echo ""
    dtop
    row " ${ROSE}${B}⛔ SYNC BLOCKED — WRONG NETWORK${N}"
    dmid
    row " ${Y}Connected :${N} ${CURRENT_WIFI:-Mobile Data}"
    row " ${LIME}Allowed :${N} ${ALLOWED_WIFI1:-N/A}"
    row " ${LIME} ${N} ${ALLOWED_WIFI2:-N/A}"
    dmid
    row " ${D}manual = any WiFi${N}"
    row " ${D}force  = mobile data${N}"
    row " ${D}watch  = auto watcher${N}"
    dbot
    echo ""
    exit 0
  fi
fi

# ───────────────── Header ─────────────────
clear
echo ""
echo -e " ${GD}${B}★ SUKRULLAH PRO SYNC v4.2 ★${N}"
echo -e " ${D}${DAY}${N}"
echo ""

# ───────────────── SYSTEM STATUS ─────────────────
dtop
row " ${PK}${B}⚡ SYSTEM STATUS${N}"
dmid
row " $(bat_icon "${BAT:-0}" "${BAT_STATUS:-Unknown}") ${B}Battery${N} ${Y}${B}${BAT:-0}%${N} ${D}(${BAT_STATUS:-Unknown})${N}"
row " $(fpbar "${BAT:-0}")"
dempty

if [[ "${MODE:-auto}" = "force" ]]; then
  row " 📡 ${B}Network${N} ${ROSE}Mobile Data (Force)${N}"
elif [[ -n "${CURRENT_WIFI:-}" ]]; then
  row " 📡 ${B}Network${N} ${LIME}${CURRENT_WIFI}${N}"
else
  row " 📡 ${B}Network${N} ${Y}Mobile Data${N}"
fi

case "${MODE:-auto}" in
  force)   row " ⚙ ${B}Mode${N} ${ROSE}${B}[ FORCE ]${N}" ;;
  manual)  row " ⚙ ${B}Mode${N} ${Y}${B}[ MANUAL ]${N}" ;;
  preview) row " ⚙ ${B}Mode${N} ${M}${B}[ PREVIEW ]${N}" ;;
  *)       row " ⚙ ${B}Mode${N} ${LIME}${B}[ AUTO ]${N}" ;;
esac

# ───────────────── STORAGE ─────────────────
dmid
row " ${PK}${B}💾 STORAGE DASHBOARD${N}"
dmid

row " ${O}${B}📱 Internal Storage${N}"
row " ${B}${INT_USED:-N/A}${N} / ${INT_TOTAL:-N/A}  Free: ${LIME}${B}${INT_FREE:-N/A}${N}"
row " $(fpbar "${INT_PCT:-0}")"
dempty

row " ${SB}${B}💳 Micro SD Card${N}"
if [[ -n "${SD_RAW:-}" ]]; then
  row " ${B}${SD_USED}${N} / ${SD_TOTAL}  Free: ${LIME}${B}${SD_FREE}${N}"
  row " $(fpbar "${SD_PCT:-0}")"
else
  row " ${D}Not detected${N}"
fi
dempty

row " ${PK}${B}☁️ Zoho WorkDrive ${LIME}[Sync ON]${N}"
if [[ -n "${ZOHO_RAW:-}" || -n "${ZOHO_USED:-}" ]]; then
  row " ${B}${ZOHO_USED:-0G}${N} / ${ZOHO_TOTAL_GB:-55}G  Free: ${LIME}${B}${ZOHO_FREE:-0G}${N}"
  row " $(fpbar "${ZOHO_PCT:-0}")"
else
  row " ${ROSE}Cannot reach Zoho${N}"
fi
dempty

row " ${C}${B}🔵 OneDrive ${Y}[Display Only]${N}"
if [[ "${OD_INFO_ON:-1}" -eq 1 ]] && [[ -n "${OD_TOTAL:-}" ]]; then
  row " ${B}${OD_USED_G:-N/A}${N} / ${OD_TOTAL:-N/A}  Free: ${LIME}${B}${OD_FREE_G:-N/A}${N}"
  row " $(fpbar "${OD_PCT:-0}")"
else
  row " ${D}Cannot reach OneDrive${N}"
fi

# ───────────────── SCHEDULE (kept) ─────────────────
dmid
row " ${GD}${B}🕐 SCHEDULE${N}"
dmid
row " 🕑 ${B}02:00${N} 🕚 ${B}11:00${N} 🕔 ${B}17:00${N} 🕘 ${B}21:00${N}"
row " ${D}auto_push : every 30 min${N}"
row " ${LIME}watch: bash sync.sh watch${N}"
dbot
echo ""
