# 🚀 SUKRULLAH PRO SYNC v4.3
> Mobile DevOps Automation System — Android (Termux)

---

## 📌 Overview

Yeh system ek Android device (Termux) ko automated sync server mein convert karta hai jo:

- Zoho WorkDrive se files sync karta hai
- GitHub pe code push karta hai
- Telegram pe detailed report bhejta hai
- Daily/Weekly backup karta hai
- Cron se scheduled tasks chalata hai

---

## 📂 File Structure

```
sync_project/
├── sync.sh              # Main controller
├── dashboard.sh         # Termux display dashboard
├── tg_report.sh         # Telegram report sender
├── storage_info.sh      # Storage detection (alag file)
├── auto_push.sh         # Auto git push har 30 min
├── daily_zip_backup.sh  # Daily ZIP backup
├── weekly_backup.sh     # Weekly backup branch
├── notify.sh            # Notification helper
├── .env                 # Tokens (git ignored)
└── .gitignore
```

---

## ⚙️ Sync Configuration

| Name | Local Path | Remote |
|------|-----------|--------|
| Cloud-Sync-File | `~/storage/shared/Cloud-Sync-File` | `zoho:Cloud-Sync-File` |
| HiRes_Songs | `/storage/emulated/0/HiRes_Songs` | `zoho:HIRES_SONGS` |

---

## 🕐 Cron Schedule

| Time | Task |
|------|------|
| 02:00, 11:00, 17:00, 21:00 | Auto Sync |
| Every 30 min | Auto Git Push |
| Daily 3:00 AM | ZIP Backup |
| Sunday 4:00 AM | Weekly Backup Branch |

---

## 🔧 Run Commands

```bash
bash ~/sync_project/sync.sh           # Auto mode
bash ~/sync_project/sync.sh manual    # Manual (no WiFi check)
bash ~/sync_project/sync.sh preview   # Dashboard only
bash ~/sync_project/sync.sh force     # Mobile data pe bhi sync
bash ~/sync_project/sync.sh watch     # WiFi watcher mode
```

---

## 📊 Dashboard Features

- Battery % — colored progress bar (Red → Yellow → Orange → Green)
- Network, Mode display
- Internal Storage, MicroSD (auto detect), Zoho WorkDrive
- Cron schedule

---

## 📩 Telegram Report Features

- Battery bar with color indicator
- All storage in GB (e.g. 72.0GB / 107.0GB)
- Progress bars for all drives
- Upload & Delete count
- Timestamp

---

## 📁 .env File

```bash
TG_TOKEN=your_telegram_bot_token
TG_CHAT_ID=your_chat_id
ZOHO_TOTAL=55
```

---

## 🔐 Security

- SSH key authentication (ed25519)
- `.env` git ignored
- Telegram token sirf local stored
- Cron logs git ignored

---

## 🛠 Technologies

- Termux (Linux on Android)
- Bash scripting
- Git & GitHub
- rclone (Zoho WorkDrive)
- Telegram Bot API
- Cron scheduler
- SSH (ed25519)

---

## 📱 New Device Setup

```bash
# 1. SSH key banao
ssh-keygen -t ed25519

# 2. Public key GitHub pe add karo

# 3. Repo clone karo
git clone git@github.com:Msukrullah1/sync_project.git

# 4. .env file banao
nano ~/sync_project/.env

# 5. rclone configure karo
rclone config

# 6. Run karo
bash ~/sync_project/sync.sh
```

---

## 🚨 Troubleshooting

| Problem | Solution |
|---------|----------|
| Storage N/A | `sync.sh preview` se chalao, directly nahi |
| MicroSD not detected | SD card check karo, auto detect hoga |
| Telegram fail | `.env` mein TG_TOKEN check karo |
| Git conflict | `git fetch origin && git reset --hard origin/main` |
| Cron not running | `ps aux \| grep crond` |

---

## ✅ Features Status

| Feature | Status |
|---------|--------|
| Auto Sync (Zoho) | ✅ |
| Auto Git Push | ✅ |
| Telegram Reports | ✅ |
| Daily ZIP Backup | ✅ |
| Weekly Backup | ✅ |
| Termux Dashboard | ✅ |
| MicroSD Detection | ✅ |
| Battery Bar Colors | ✅ |
| Storage in GB | ✅ |
