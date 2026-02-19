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

# Add & commit local changes
git add . 2>/dev/null

if ! git diff-index --quiet HEAD --; then
    git commit -m "Auto Sync: $(date '+%Y-%m-%d %H:%M:%S')"
    git push origin main
    echo "[$(date)] Push Successful ✅" >> "$LOG_FILE"
    send_notification "✅ Auto Push Successful at $(date)"
fi

# Pull latest safely
git pull origin main --rebase

if [ $? -ne 0 ]; then
    echo "[$(date)] Merge conflict detected ❌" >> "$LOG_FILE"
    send_notification "❌ Merge Conflict Detected at $(date)"
    exit 1
fi
