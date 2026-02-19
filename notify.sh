#!/bin/bash

# ==============================
#  Sync Monitor Bot (Error Mode)
# ==============================

BOT_TOKEN="PASTE_YOUR_OLD_WORKING_BOT_TOKEN_HERE"
CHAT_ID="6403536553"

send_error() {
    curl -s -X POST \
    "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d chat_id="${CHAT_ID}" \
    -d text="❌ ERROR: $1" > /dev/null
}

send_file() {
    curl -s -F chat_id="${CHAT_ID}" \
    -F document=@"$1" \
    "https://api.telegram.org/bot${BOT_TOKEN}/sendDocument" > /dev/null
}
