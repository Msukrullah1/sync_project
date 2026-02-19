#!/bin/bash

cd "$HOME/sync_project" || exit 1

git checkout backup-main
git merge main
git push origin backup-main
git checkout main

echo "[$(date)] Weekly Backup Updated 🚀" >> "$HOME/sync_project/backup.log"
