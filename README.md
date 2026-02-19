# 🚀 Sync Project – Mobile DevOps Automation System

## 👤 Owner
**Sukrullah**

## 🔗 Repository
git@github.com:Msukrullah1/sync_project.git  
https://github.com/Msukrullah1/sync_project.git

---

# 📌 Project Overview

This project converts an Android device (Termux) into a mini DevOps automation server.

It automatically:

- Pulls latest changes
- Commits local changes
- Pushes to GitHub
- Sends Telegram notifications
- Creates daily ZIP backups
- Maintains weekly backup branch
- Runs scheduled tasks via Cron
- Uses SSH for secure authentication

---

# 🛠 Technologies Used

- Termux (Linux environment on Android)
- Git
- GitHub
- SSH (ed25519 authentication)
- Cron (cronie)
- Zip
- Telegram Bot API

---

# 📂 Project Structure
sync_project/ │ ├── auto_push.sh ├── weekly_backup.sh ├── daily_zip_backup.sh ├── setup_cron.sh ├── README.md ├── .gitignore └── other .sh files
---

# ⚙ Automation System

## 🔄 Auto Sync (Every 30 Minutes)

Cron Entry:*/30 * * * * /data/data/com.termux/files/home/sync_project/auto_push.sh
Process:
1. Pull latest changes
2. Add local changes
3. Commit
4. Push
5. Send Telegram notification

---

## 📦 Daily ZIP Backup (3 AM)

Creates:sync_backups/backup_YYYY-MM-DD.zip
Excludes:
- .git folder
- log files

---

## 🔁 Weekly Backup Branch (Sunday 4 AM)

Branch:
backup-main
Merges `main` into `backup-main`.

Used as disaster recovery layer.

---

# 🔐 Security Model

- SSH authentication enabled
- No password login
- Telegram token stored locally
- Logs ignored via .gitignore
- Cron logs not committed

---

# 📱 Multi-Device Setup Guide

To add a new device:

### 1️⃣ Install Git & SSH

### 2️⃣ Generate SSH Key

ssh-keygen -t ed25519
### 3️⃣ Add Public Key to GitHub

### 4️⃣ Clone Repository

git clone git@github.com:Msukrullah1/sync_project.git
### 5️⃣ Setup Cron
crontab -e
---

# 🚨 Troubleshooting

## Git Conflict
git pull
Resolve manually.

## Cron Not Running
ps aux | grep crond crontab -l
## Telegram Not Working
Check:
- BOT_TOKEN
- CHAT_ID
- Internet connection

---

# 🎯 System Status

✔ SSH Secured  
✔ Auto Commit  
✔ Auto Push  
✔ Telegram Alerts  
✔ Daily Backup  
✔ Weekly Backup  
✔ Multi-Device Ready  

---

# 🧠 Summary

This system transforms a mobile device into a secure, automated Git synchronization and backup server.

Minimal manual work.  
Fully automated.  
Secure and scalable.

