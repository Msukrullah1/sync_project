#!/bin/bash

PROJECT_DIR="$HOME/sync_project"
BACKUP_DIR="$HOME/sync_backups"

mkdir -p "$BACKUP_DIR"

zip -r "$BACKUP_DIR/backup_$(date '+%Y-%m-%d').zip" "$PROJECT_DIR" -x "*.git*" "*.log"

echo "[$(date)] ZIP Backup Created 📦" >> "$PROJECT_DIR/backup.log"
