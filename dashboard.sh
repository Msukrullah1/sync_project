#!/data/data/com.termux/files/usr/bin/bash
########################################
# SUKRULLAH DASHBOARD v4.3 (Fixed)
# Sirf Termux display — Poco X3 Pro
# NOTE: Width same रखा गया (BOXW=46 / BARW=34)
# Features removed: NONE (only fixed + improved conversions)
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
  for((i=1;i<=empty;i++)); do bar+=$(cc 242)"░"; done
  printf "▕%s%s %s%3d%%%s" "$bar" "$(rc)" "$(cc 250)" "$val" "$(rc)"
}
bat_icon(){
  local p=$1 s=$2
  case "$s" in CHARGING|Charging) echo "🔌"; return;; esac
  [[ "$p" -le 10 ]] && echo "🪫" || echo "🔋"
}

# ───────────────── GB Conversion (FIXED) ─────────────────
# Disk values (Internal/SD): auto-detect bytes/KB/MB/GB
# Cloud values (Zoho/OneDrive): plain numbers => GB
fmt_gb() {
  # prints number as "xx.xG"
  awk -v x="$1" 'BEGIN{ if(x<10) printf "%.2fG", x; else printf "%.1fG", x }'
}

to_gb_disk() {
  # Accepts: "123G", "1.5T", "120M", "224567224"(likely KB), "1234567890"(bytes), etc.
  local v="${1:-0}"
  v="${v// /}"
  [[ -z "$v" ]] && v="0"

  # Already with unit
  if [[ "$v" =~ ^[0-9]+([.][0-9]+)?[Gg]([Bb])?$ ]]; then
    awk -v x="${v%[Gg]*}" 'BEGIN{printf "%.1fG", x+0}'; return
  fi
  if [[ "$v" =~ ^[0-9]+([.][0-9]+)?[Tt]([Bb])?$ ]]; then
    awk -v x="${v%[Tt]*}" 'BEGIN{printf "%.1fG", (x+0)*1024}'; return
  fi
  if [[ "$v" =~ ^[0-9]+([.][0-9]+)?[Mm]([Bb])?$ ]]; then
    awk -v x="${v%[Mm]*}" 'BEGIN{printf "%.2fG", (x+0)/1024}'; return
  fi
  if [[ "$v" =~ ^[0-9]+([.][0-9]+)?[Kk]([Bb])?$ ]]; then
    awk -v x="${v%[Kk]*}" 'BEGIN{printf "%.2fG", (x+0)/1024/1024}'; return
  fi

  # Pure numeric -> auto guess
  if [[ "$v" =~ ^[0-9]+$ ]]; then
    local n="$v"
    # If it looks like df -k values (hundreds of millions) => KB
    if [[ "$n" -ge 10000000 && "$n" -lt 10000000000 ]]; then
      awk -v k="$n" 'BEGIN{printf "%.1fG", (k/1024/1024)}'; return
    fi
    # Very big => bytes
    awk -v b="$n" 'BEGIN{printf "%.1fG", (b/1024/1024/1024)}'; return
  fi

  echo "${v}"
}

to_gb_cloud() {
  # Cloud values: if "29" => 29G (GB), if "2.400" => 2.400G, if already has unit keep it
  local v="${1:-0}"
  v="${v// /}"
  [[ -z "$v" ]] && v="0"

  if [[ "$v" =~ ^[0-9]+([.][0-9]+)?[Gg]([Bb])?$ ]]; then
    awk -v x="${v%[Gg]*}" 'BEGIN{printf "%.3fG", x+0}'; return
  fi
  if [[ "$v" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    awk -v x="$v" 'BEGIN{printf "%.3fG", x+0}'; return
  fi

  # if M/T etc then convert
  if [[ "$v" =~ ^[0-9]+([.][0-9]+)?[Tt] ]]; then
    awk -v x="${v%[Tt]*}" 'BEGIN{printf "%.3fG", (x+0)*1024}'; return
  fi
  if [[ "$v" =~ ^[0-9]+([.][0-9]+)?[Mm] ]]; then
    awk -v x="${v%[Mm]*}" 'BEGIN{printf "%.3fG", (x+0)/1024}'; return
  fi
  echo "$v"
}

# ───────────────── Fallback storage using df (only when vars missing) ─────────────────
df_kb_stats() { df -k "$1" 2>/dev/null | awk 'NR==2{print $3,$2,$4}'; } # used total avail (KB)
detect_internal_path() {
  [[ -d "$HOME/storage/shared" ]] && { echo "$HOME/storage/shared"; return; }
  [[ -d "/storage/emulated/0" ]] && { echo "/storage/emulated/0"; return; }
  [[ -d "/sdcard" ]] && { echo "/sdcard"; return; }
  echo "$PREFIX"
}
detect_sd_path() {
  [[ -d "/storage" ]] || { echo ""; return; }
  local p
  for p in /storage/*; do
    [[ -d "$p" ]] || continue
    [[ "$p" =~ /storage/(emulated|self)$ ]] && continue
    echo "$p"; return
  done
  echo ""
}

# ───────────────── WATCH MODE (same as your original) ─────────────────
if [[ "${MODE:-}" = "watch" ]] || [[ "${1:-}" = "watch" ]]; then
  clear; dtop
  row " ${PK}${B}◈ WIFI WATCHER ACTIVE${N}"
  row " ${D}Networks: ${ALLOWED_WIFI1} / ${ALLOWED_WIFI2}${N}"
  row " ${D}Interval: 2h  Stop: Ctrl+C${N}"
  dbot

  LAST_WIFI=""
  while true; do
    WIFI_NOW="$(termux-wifi-connectioninfo 2>/dev/null | awk -F\" '/"ssid"/{print $4; exit}')"
    [[ "$WIFI_NOW" = "<unknown ssid>" ]] && WIFI_NOW=""
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

# ───────────────── Battery/Network fallback ─────────────────
if [[ -z "${BAT:-}" ]] && command -v termux-battery-status >/dev/null 2>&1; then
  BAT="$(termux-battery-status 2>/dev/null | awk -F'[:,}]' '/percentage/{gsub(/[^0-9]/,"",$2); print $2; exit}')"
fi
BAT="${BAT:-0}"
BAT_STATUS="${BAT_STATUS:-Unknown}"

if [[ -z "${CURRENT_WIFI:-}" ]] && command -v termux-wifi-connectioninfo >/dev/null 2>&1; then
  CURRENT_WIFI="$(termux-wifi-connectioninfo 2>/dev/null | awk -F\" '/"ssid"/{print $4; exit}')"
  [[ "$CURRENT_WIFI" = "<unknown ssid>" ]] && CURRENT_WIFI=""
fi

# ───────────────── BLOCKED screen (same behavior) ─────────────────
if [[ "${MODE:-auto}" = "auto" ]]; then
  if [[ "${CURRENT_WIFI:-}" != "${ALLOWED_WIFI1:-}" ]] && [[ "${CURRENT_WIFI:-}" != "${ALLOWED_WIFI2:-}" ]]; then
    clear
    echo ""
    echo -e " ${GD}${B}★ SUKRULLAH PRO SYNC v4.3 ★${N}"
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
echo -e " ${GD}${B}★ SUKRULLAH PRO SYNC v4.3 ★${N}"
echo -e " ${D}${DAY}${N}"
echo ""

# ───────────────── Resolve storage values (prefer existing vars from sync.sh) ─────────────────
# Internal
if [[ -z "${INT_USED:-}" || -z "${INT_FREE:-}" || -z "${INT_TOTAL:-}" ]]; then
  IPATH="$(detect_internal_path)"
  read -r iu it ia <<<"$(df_kb_stats "$IPATH")"
  INT_USED="$iu"; INT_TOTAL="$it"; INT_FREE="$ia"
  INT_PCT="${INT_PCT:-0}"
fi

INT_USED_G="$(to_gb_disk "$INT_USED")"
INT_FREE_G="$(to_gb_disk "$INT_FREE")"
INT_TOTAL_G="$(to_gb_disk "$INT_TOTAL")"

# SD
if [[ -n "${SD_RAW:-}" ]]; then
  : # use provided SD_* values
else
  SDPATH="$(detect_sd_path)"
  if [[ -n "$SDPATH" ]]; then
    read -r su st sa <<<"$(df_kb_stats "$SDPATH")"
    SD_RAW="1"
    SD_USED="$su"; SD_TOTAL="$st"; SD_FREE="$sa"
    SD_PCT="${SD_PCT:-0}"
  fi
fi

if [[ -n "${SD_RAW:-}" ]]; then
  SD_USED_G="$(to_gb_disk "$SD_USED")"
  SD_FREE_G="$(to_gb_disk "$SD_FREE")"
  SD_TOTAL_G="$(to_gb_disk "$SD_TOTAL")"
fi

# Zoho (cloud -> numeric = GB)
ZOHO_USED_G="$(to_gb_cloud "${ZOHO_USED:-0}")"
ZOHO_FREE_G="$(to_gb_cloud "${ZOHO_FREE:-0}")"
ZOHO_TOTAL_GB="${ZOHO_TOTAL_GB:-55}"

# OneDrive (cloud -> numeric = GB)
OD_USED_GB="$(to_gb_cloud "${OD_USED_G:-N/A}")"
OD_FREE_GB="$(to_gb_cloud "${OD_FREE_G:-N/A}")"
OD_TOTAL_GB="$(to_gb_cloud "${OD_TOTAL:-N/A}")"

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
row " ${B}Used : ${INT_USED_G}${N}"
row " ${B}Free : ${INT_FREE_G}${N} / ${INT_TOTAL_G}"
row " $(fpbar "${INT_PCT:-0}")"
dempty

row " ${SB}${B}💳 Micro SD Card${N}"
if [[ -n "${SD_RAW:-}" ]]; then
  row " ${B}Used : ${SD_USED_G}${N}"
  row " ${B}Free : ${SD_FREE_G}${N} / ${SD_TOTAL_G}"
  row " $(fpbar "${SD_PCT:-0}")"
else
  row " ${D}Not detected${N}"
fi
dempty

row " ${PK}${B}☁️ Zoho WorkDrive ${LIME}[Sync ON]${N}"
if [[ -n "${ZOHO_RAW:-}" || -n "${ZOHO_USED:-}" ]]; then
  row " ${B}Used : ${ZOHO_USED_G}${N}"
  row " ${B}Free : ${ZOHO_FREE_G}${N} / ${ZOHO_TOTAL_GB}G"
