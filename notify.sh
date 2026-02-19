#!/bin/bash

# ==============================
#  Sync Monitor Bot - Error Only
# ==============================

BOT_TOKEN="YAHAN_APNA_PURANA_WORKING_BOT_TOKEN_DALO"
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
