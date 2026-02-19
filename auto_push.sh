#!/bin/bash

PROJECT_DIR="$HOME/sync_project"
LOG_FILE="$PROJECT_DIR/cron.log"

BOT_TOKEN="PASTE_YOUR_REAL_BOT_TOKEN_HERE"
CHAT_ID="PASTE_YOUR_REAL_CHAT_ID_HERE"

send_notification() {
curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
-d chat_id="$CHAT_ID" \
-d text="$1" > /dev/null
}

cd "$PROJECT_DIR" || exit 1

# FIRST: add & commit any local changes
git add . 2>/dev/null

if ! git diff-index --quiet HEAD --; then
    git commit -m "Pre-sync commit: $(date '+%Y-%m-%d %H:%M:%S')"
fi

# THEN: pull safely
git pull origin main --rebase

if [ $? -ne 0 ]; then
    echo "[$(date)] Merge conflict detected ❌" >> "$LOG_FILE"
    send_notification "❌ Merge Conflict Detected at $(date)"
    exit 1
fi

# NOW: only track .sh files
git add *.sh 2>/dev/null

if ! git diff-index --quiet HEAD --; then
    git commit -m "Smart Sync (.sh only): $(date '+%Y-%m-%d %H:%M:%S')"
    git push origin main
    echo "[$(date)] Smart Push Successful ✅" >> "$LOG_FILE"
    send_notification "✅ Auto Push Successful at $(date)"
else
    echo "[$(date)] No .sh changes ✔" >> "$LOG_FILE"
fi
