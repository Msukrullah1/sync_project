#!/bin/bash

PROJECT_DIR="$HOME/sync_project"
LOG_FILE="$PROJECT_DIR/cron.log"

cd "$PROJECT_DIR" || exit 1

# Pull latest changes safely
git pull origin main --rebase

# Add all changes except ignored files
git add .

# Check if there are changes
if ! git diff-index --quiet HEAD --; then
    git commit -m "Auto Sync: $(date '+%Y-%m-%d %H:%M:%S')"
    git push origin main
    echo "[$(date)] Auto Push Successful ✅" >> "$LOG_FILE"
else
    echo "[$(date)] No changes to push ✔" >> "$LOG_FILE"
fi
