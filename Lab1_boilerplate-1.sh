#!/usr/bin/env bash
#
# ============================================================================
#  BOILERPLATE : Linux Security Assessment Tool  (IS2083 Lab 1)
# ============================================================================
#  This is a boilerplate you can use to create your own script. Copy it,
#  rename it, and fill in each TODO section by section, following the handout.
#  Do not skip ahead: build and test one section at a time.
#
#  Target: a Debian based Linux VM (Ubuntu or Kali). Run from a terminal.
#  On a Red Hat based system, replace the Debian commands with equivalents
#  (apt -> dnf, ufw -> firewalld, /var/log/auth.log -> /var/log/secure).
# ============================================================================

set -u   # catch unset variables. We avoid 'set -e' so one failed check
         # does not stop the whole assessment.

# --- Section 2: Name the tool ------------------------------------------------
TOOL_NAME="Linux Security Assesment Tool"

# --- Section 3: Startup dialog -----------------------------------------------
# TODO: show a zenity info box that says "<TOOL_NAME> has started".
#       Fall back to echo if zenity is missing.
# TODO: cache sudo once with:  sudo -v
if command -v zenity >/dev/null 2>&1; then
zenity --info --text="$TOOL_NAME has started"
else
echo "$TOOL_NAME has started"
fi
sudo -v


# --- Section 4: Report creation (file manipulation) --------------------------
# TODO: make WORKDIR under $HOME, build a timestamped REPORT path, touch it,
#       and write log() and section() helpers that echo AND append with tee -a.
WORKDIR="$HOME/linux_security_reports"
mkdir -p "$WORKDIR"

REPORT="$WORKDIR/report_$(date +%Y%m%d_%H%M%S).txt"
touch "$REPORT"

log() {
   echo "1" | tee -a "$REPORT"
}

section() {
   echo "" |tee -a "$REPORT"
   echo "===== $1=====" | tee -a "$REPORT"
}
# --- Section 5: System administration ----------------------------------------
# TODO: report OS, uptime, disk usage, UID 0 accounts, sudo group members,
#       and the count of upgradable packages. Save the count in UPGRADES.
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
# TODO: report process count, top 5 by CPU and by memory, listening services,
#       then start a background 'sleep' job, capture its PID with $!, and kill it.
section "Process Control"

log "Process Count:"
ps -e --no-headers | wc-l | ee -a "$REPORT"

log "Top 5 Process by CPU:"
ps aux --sort=%cpu | head -n 6 | tee -a "$REPORT"

log "TOP 5 Processes by Memory:"
ps aux --sort=-%mem |head -n 6 | tee -a "$REPORT"

log "Listening Services:"
ss-tuln | tee -a "$REPORT"

sleep 60 &
SLEEP_PID=$!
log "Background sleep PID: $SLEEP_PID"
kill "SLEEP_PID" 
# --- Section 7: File security audit ------------------------------------------
# TODO: count and list world writable files under /home (save in WORLD_WRITABLE),
#       list SUID programs, and show permissions of /etc/passwd and /etc/shadow.
section "File Security Audit"

log "World-Writable Files Under /home:"
WORLD_WRITABLE=$(find /home -type f -perm -0002 2>?dev/null | wc -l)
find /home -type f -peerm -0002 2>/dev/null | tee -a "$REPORT"
log "World-Writable File Count: $WORLD_WRITABLE"

log "SUID Programs:"
find / -type f -perm -4000 2>/dev/null | tee -a "$REPORT"

log "Permissions for /etc/passwd and /etc/shadow:"
ls -l /etc/passwd /etc/shadow  | tee -a "$REPORT" 
# --- Section 8: Security hardening --------------------------------------------
# TODO: enable ufw (default deny incoming) and set FW_ENABLED to 1 or 0;
#       count failed SSH logins into FAILED; count empty password accounts into EMPTY.
section "Security Hardening"

log "Firewall Status:"
sudo ufw default deny incoming
sudo ufw --force enable
ufw status | tee -a "$REPORT"

if ufw status |grep -q "Status: active"; then
   FW_ENABLED=1
else
   FW_ENABLED=0
fi

log "Failed SSH Logins:"
FAILED=$(grep-i "Failed password" /var/log/auth.log 2>/dev/null | wc -l)
log "Failed SSH Login Count: $FAILED"

log "Accounts With Empty Passwords:"
EMPTY=$(sudo awk -F: '$2 =="" {print $1}' /etc/shadow | wc -l)
log "Empty Password Account COunt: $EMPTY"
# --- Section 9: Security score -----------------------------------------------
# TODO: start SCORE at 100 and subtract points for each finding
#       (UPGRADES, WORLD_WRITABLE, FAILED, EMPTY, FW_ENABLED). Clamp at 0.
#       Set RATING to STRONG / MODERATE / NEEDS WORK, and log the score.
section "Security Score "

SCORE=100

(( UPGRADES > 0 )) && (( SCORE-=10 ))
(( WORLD_WRITABLE > 0 )) && (( SCORE-=20 ))
(( FAILED > 0 )) && (( SCORE -=10 ))
(( EMPTY > 0 )) && (( SCORE-=30 ))
(( FW_ENABLED ==0 )) && (( SCORE-=30 ))

(( SCORE <0 )) && SCORE=0

if (( SCORE >= 90 )); then
     RATING="STRONG"
elif (( SCORE>= 70 )); then
     RATING="MODERATE"
else
     RATING="NEEDS WORK"
fi

log "Security Score: $SCORE/100"
log "Security Rating: $RATING"
# --- Section 10: Completion dialog -------------------------------------------
# TODO: chmod 600 the report, then show a zenity box that says
#       "<TOOL_NAME> has completed", the security score, and the report path.
chmod 600 "$REPORT"

if command -v zenity >/dev/null 2>&1; then
     zenity --info --text="$TOOL_NAME has completed. \nSecurity Score: $SCORE/100\nReport: $REPORT"
else
   echo "$TOOL_NAME has completed."
   echo "Security Score: $SCORE/100"
   echo "Report: $REPORT"
fi 
# --- Section 11: GitHub (do this in the terminal, not in the script) ---------
#   git init
#   git add .
#   git commit -m "Version 1.0 of my Linux Security Assessment Tool"
#   git branch -M main
#   git remote add origin <your repo URL>
#   git push -u origin main
