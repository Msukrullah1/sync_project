#!/bin/bash

BOT_TOKEN="8389555301:AAGZRmlnggV0KmYJmp76T3isoWvHVJfogXE"
CHAT_ID="6403536553"
MESSAGE="$1"

curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
-d chat_id="$CHAT_ID" \
-d text="$MESSAGE"
