#!/usr/bin/env bash
o

set -u   # catch unset variables. We avoid 'set -e' so one failed check
         # does not stop the whole assessment.

# --- Section 2: Name the tool ------------------------------------------------
TOOL_NAME="FalconGuard"

# --- Section 3: Startup dialog -----------------------------------------------
# zenity --info --width=360 --title="$TOOL_NAME" \
     --text="$TOOL_NAME has started." \
     2>/dev/null || echo "[$TOOL_NAME] started"
sudo -v


# --- Section 4: Report creation (file manipulation) --------------------------

WORKDIR="$HOME/${TOOL_NAME}_reports"
mkdir -p "$WORKDIR"
REPORT="$WORKDIR/report_$(date +%Y%m%d_%H%M%S).txt"
touch "$REPORT"
log() { echo "$*" | tee -a "$REPORT"; }
section() { log "===== $* ====="; }
log "$TOOL_NAME security report"
log "Generated : $(date)"
log "Host : $(hostname)"
log "Run by : $(whoami)"
# --- Section 5: System administration ----------------------------------------

section "System Administration"

log "Operating System:"
cat /etc/os-release | tee -a "$REPORT"

log "Uptime:"
uptime |tee -a  "$REPORT"

log "Disk Usage:"
df -h | tee -a "$REPORT"

log "UID 0 Accounts:"
awk -F: '$3 ==0 {print $1}' /etc/passwd |tee -a "$REPORT"

log "Sudo Group Members:"
getent group sudo | tee -a "$REPORT"

UPGRADES=$(apt list --upgradable 2>/dev/null | tail -n +2 | wc -1)
log "Upgradable Packages: $UPGRADES"

# --- Section 6: Process control ----------------------------------------------
section "Process Control"

log "Process Count:"
ps -e --no-headers |wc -l | ee -a "$REPORT"

log "Top 5 Process by CPU:"
ps aux --sort=%cpu | head -n 6 | tee -a "$REPORT"

log "TOP 5 Processes by Memory:"
ps aux --sort=-%mem |head -n 6 | tee -a "$REPORT"

log "Listening Services:"
ss -tuln | tee -a "$REPORT"

sleep 120 &
WATCHER_PID=$!
log " watcher started as PID $WATCHER_PID"
kill "$WATCHER_PID" 2>/dev/null && log " watcher (PID $WATCHER_PID) stopped"
# --- Section 7: File security audit ------------------------------------------
section "File and permission audit"

log "World_Writable Files Under /home:"
WORLD_WRITABLE=$(find /home -xdev -type f -perm -0002 2>?dev/null | wc -l)
find /home -type f -perm -0002 2>/dev/null | tee -a "$REPORT"
log "World-Writable File Count: $WORLD_WRITABLE"

log "SUID Programs:"
find /usr/bin /usr/sbin -xdev -type f -perm -4000 2>/dev/null | sed 's/^/ /' | tee -a "$REPORT"

log "Permissions for /etc/passwd and /etc/shadow:"
ls -l /etc/passwd /etc/shadow  | tee -a "$REPORT" 
# --- Section 8: Security hardening --------------------------------------------

section "Security Hardening"

if command -v ufw >/dev?null; then
sudo ufw --force enable
sudo ufw default deny incoming >/dev/null
sudo ufw default allow outgoing >/dev/null
FW_ENABLED=1
log "Firewall (ufw) enabled with default deny incoming."
sudo ufw status verbose | tee -a "$REPORT"
else
 FW_ENABLED=0
 log "ufw is not installed. Install: sudo apt install ufw"
fi

FAILED=$(sudo grep "Failed password" /var/log/auth.log 2>/dev/null | wc-l)
log "Failed SSH login attempts on record: $FAILED"

EMPTY=$(sudo awk -F: '($2==){print $1}' /etc/shadow 2>/dev/null | wc  -l)
log "Accounts with an EMPTY password: $EMPTY (should be 0)"
# --- Section 9: Security score -----------------------------------------------
section "Security Score "

SCORE=100

[ "$UPGRADES" -gt 0 ] && SCORE=$((SCORE - 10))
[ "$WORLD_WRITABLE" -gt 0 ] && SCORE=$((SCORE - 15))
[ "$FAILED"-gt 20 ] && SCORE=$((SCORE - 10))
[ "$EMPTY" -gt 0 ] && SCORE=$((SCORE - 30))
[ "$FW_ENABLED" -eq 0 ] && SCORE=$((SCORE - 20))

[ "$SCORE" -lt 0 ] && SCORE=0

if ["$SCORE" -ge 90 ]; then
  RATING="STRONG"
  elif [ "$SCORE" -ge 70 ]; then
  RATING="MODERATE"
else
  RATING="NEEDS WORK"
fi

log "Security score: $SCORE / 100 ($RATING)"
# --- Section 10: Completion dialog -------------------------------------------
 section "Finishing up"

chmod 600 "$REPORT"
log "Report locked to owner only (chmod 600)."
log "Report saved to: $REPORT"

zenity --info --width=420 --title="$TOOL_NAME" \
  --text="$TOOL_NAME has completed."$'\n'"Security score: $SCORE / 100 ($RATING)" \
  2>/dev/null || echo "[$TOOL_NAME] completed. Score: $SCORE/100"
# --- Section 11: GitHub (do this in the terminal, not in the script) ---------
#   git init
#   git add .
#   git commit -m "Version 1.0 of my Linux Security Assessment Tool"
#   git branch -M main
#   git remote add origin <your repo URL>
#   git push -u origin main
