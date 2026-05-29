#!/bin/bash

# ==============================
#  Sync Monitor Bot - Error Only
# ==============================

PROJECT_DIR="$HOME/sync_project"
[ -f "$PROJECT_DIR/.env" ] && source "$PROJECT_DIR/.env"

BOT_TOKEN="${TG_TOKEN:-}"
CHAT_ID="${TG_CHAT_ID:-}"

[ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ] && exit 0

send_error() {
    curl -s --max-time 30 -X POST \
    "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d chat_id="${CHAT_ID}" \
    -d text="❌ ERROR: $1" > /dev/null
}

send_file() {
    curl -s --max-time 60 -F chat_id="${CHAT_ID}" \
    -F document=@"$1" \
    "https://api.telegram.org/bot${BOT_TOKEN}/sendDocument" > /dev/null
}

[ -n "$1" ] && send_error "$1"
