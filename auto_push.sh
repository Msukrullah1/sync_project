#!/bin/bash

PROJECT_DIR="$HOME/sync_project"
LOG_FILE="$PROJECT_DIR/cron.log"

cd "$PROJECT_DIR" || exit 1

# Stage ALL changes (including deletions)
git add -A 2>/dev/null

# Commit only if there are staged changes
if ! git diff --cached --quiet 2>/dev/null; then
    git commit -m "Auto Sync: $(date '+%Y-%m-%d %H:%M:%S')" 2>/dev/null
fi

# Pull using merge (not rebase) — avoids "unstaged changes" error
if ! git pull --no-rebase origin main 2>/dev/null; then
    source "$PROJECT_DIR/.env" 2>/dev/null
    bash "$PROJECT_DIR/notify.sh" "Git Pull Failed at $(date)"
    exit 1
fi

# Push changes
if ! git push origin main 2>/dev/null; then
    source "$PROJECT_DIR/.env" 2>/dev/null
    bash "$PROJECT_DIR/notify.sh" "Git Push Failed at $(date)"
    exit 1
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Auto Push Completed" >> "$LOG_FILE"
