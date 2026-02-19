#!/bin/bash

PROJECT_DIR="$HOME/sync_project"
LOG_FILE="$PROJECT_DIR/cron.log"

# 🔔 Telegram Config
BOT_TOKEN="8389555301:AAGZRmlnggV0KmYJmp76T3isoWvHVJfogXE"
CHAT_ID="6403536553"

send_notification() {
curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
-d chat_id="$CHAT_ID" \
-d text="$1" > /dev/null
}

cd "$PROJECT_DIR" || exit 1

# Pull latest changes safely
git pull origin main --rebase

# Conflict check
if [ $? -ne 0 ]; then
    echo "[$(date)] Merge conflict detected ❌" >> "$LOG_FILE"
    send_notification "❌ Merge Conflict Detected at $(date)"
    exit 1
fi

# Track only .sh files
git add *.sh 2>/dev/null

# Check for changes
if ! git diff-index --quiet HEAD --; then
    git commit -m "Smart Sync (.sh only): $(date '+%Y-%m-%d %H:%M:%S')"
    git push origin main
    echo "[$(date)] Smart Push Successful ✅" >> "$LOG_FILE"
    send_notification "✅ Auto Push Successful at $(date)"
else
    echo "[$(date)] No .sh changes ✔" >> "$LOG_FILE"
fi
