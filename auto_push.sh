#!/bin/bash

cd ~/sync_project || exit

# Pull latest changes first
git pull origin main

# Add all changes
git add .

# Check if there is anything to commit
if ! git diff-index --quiet HEAD --; then
    git commit -m "Auto Sync: $(date '+%Y-%m-%d %H:%M:%S')"
    git push origin main
    echo "Auto Push Successful ✅"
else
    echo "No changes to push ✔"
fi
