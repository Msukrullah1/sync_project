#!/bin/bash

PROJECT_DIR="$HOME/sync_project"
LOG_FILE="$PROJECT_DIR/cron.log"

cd "$PROJECT_DIR" || exit 1

# Pull latest safely
git pull origin main --rebase

# Only track .sh files
git add *.sh 2>/dev/null

# Check for changes
if ! git diff-index --quiet HEAD --; then
    git commit -m "Smart Sync (.sh only): $(date '+%Y-%m-%d %H:%M:%S')"
    git push origin main
    echo "[$(date)] Smart Push Successful ✅" >> "$LOG_FILE"
else
    echo "[$(date)] No .sh changes ✔" >> "$LOG_FILE"
fi
