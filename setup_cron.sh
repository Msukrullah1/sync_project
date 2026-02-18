#!/data/data/com.termux/files/usr/bin/bash

clear
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "        ⚙️   SYNC SETUP"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 1. sync.sh check
if [ ! -f "$HOME/sync.sh" ]; then
    echo "  ❌ sync.sh not found in ~/"
    echo "  Pehle sync.sh copy karo:"
    echo "  cp ~/storage/shared/Download/sync.sh ~/sync.sh"
    exit 1
fi

# 2. Permissions
chmod +x "$HOME/sync.sh"
echo "  ✅ sync.sh permission set"

# 3. Reports folder
mkdir -p "$HOME/sync_reports"
echo "  ✅ sync_reports folder ready"

# 4. cronie install
pkg install cronie -y > /dev/null 2>&1
echo "  ✅ cronie installed"

# 5. Cron jobs
CRON_JOB_1="0 11 * * * bash $HOME/sync.sh >> $HOME/sync.log 2>&1"
CRON_JOB_2="0 17 * * * bash $HOME/sync.sh >> $HOME/sync.log 2>&1"
CRON_JOB_3="0 2  * * * bash $HOME/sync.sh >> $HOME/sync.log 2>&1"

(crontab -l 2>/dev/null | grep -v "sync.sh"; \
 echo "$CRON_JOB_1"; \
 echo "$CRON_JOB_2"; \
 echo "$CRON_JOB_3") | crontab -

echo "  ✅ Cron jobs set:"
echo "     🕙 11:00 AM daily"
echo "     🕔  5:00 PM daily"
echo "     🕑  2:00 AM daily"

# 6. Cron start
crond 2>/dev/null
echo "  ✅ Cron service started"

# 7. Termux:Boot
BOOT_DIR="$HOME/.termux/boot"
mkdir -p "$BOOT_DIR"
cat > "$BOOT_DIR/start-cron.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
crond
EOF
chmod +x "$BOOT_DIR/start-cron.sh"
echo "  ✅ Termux:Boot configured"

# 8. Aliases — clean + fresh
sed -i '/# Sync alias/d' "$HOME/.bashrc" 2>/dev/null
sed -i '/alias sync-now/d' "$HOME/.bashrc" 2>/dev/null
sed -i '/alias sync-log/d' "$HOME/.bashrc" 2>/dev/null
sed -i '/alias sync-status/d' "$HOME/.bashrc" 2>/dev/null
sed -i '/alias sync-reports/d' "$HOME/.bashrc" 2>/dev/null

cat >> "$HOME/.bashrc" << 'EOF'

# Sync alias
alias sync-now='bash $HOME/sync.sh'
alias sync-log='tail -50 $HOME/sync.log'
alias sync-status='crontab -l'
alias sync-reports='ls -lt $HOME/sync_reports/'
EOF

source "$HOME/.bashrc" 2>/dev/null

echo "  ✅ Aliases added:"
echo "     sync-now     → manual sync"
echo "     sync-log     → last 50 log lines"
echo "     sync-status  → cron schedule"
echo "     sync-reports → sabhi report files"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "        ✅  SETUP COMPLETE!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  📋 Active schedule:"
crontab -l | grep sync.sh
echo ""
echo "  💡 Commands:"
echo "     sync-now     → abhi sync karo"
echo "     sync-log     → logs dekho"
echo "     sync-status  → schedule dekho"
echo "     sync-reports → report files dekho"
echo ""
echo "  ⚠️  Termux:Boot install karo F-Droid se"
echo "     (phone restart ke baad cron auto-start)"
echo ""
echo "  Aliases activate karne ke liye:"
echo "  source ~/.bashrc"
echo ""
