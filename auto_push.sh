#!/bin/bash

PROJECT_DIR="$HOME/sync_project"
LOG_FILE="$PROJECT_DIR/cron.log"

cd "$PROJECT_DIR" || exit 1

# Stage changes
git add . 2>/dev/null
git commit -m "Auto Sync: $(date '+%Y-%m-%d %H:%M:%S')" 2>/dev/null

# Pull latest
git pull origin main --rebase
if [ $? -ne 0 ]; then
    ./notify.sh "Git Pull Failed at $(date)"
    exit 1
fi

# Push changes
git push origin main
if [ $? -ne 0 ]; then
    ./notify.sh "Git Push Failed at $(date)"
    exit 1
fi

echo "[$(date)] Sync Completed" >> "$LOG_FILE"
