#!/bin/bash

# ==========================================
# Server Monitoring Script
# ==========================================

# ---------- Colors ----------
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
NC="\033[0m"

# ---------- Thresholds ----------
CPU_THRESHOLD=80
MEM_THRESHOLD=80
DISK_THRESHOLD=80
INODE_THRESHOLD=80

# ---------- Email ----------
EMAIL="chinipillii@gmail.com"

# ---------- Log File ----------
LOG_DIR="/home/ec2-user/server-monitor/logs"
LOGFILE="$LOG_DIR/server-monitor.log"

mkdir -p "$LOG_DIR"

# ---------- Server Details ----------
HOST=$(hostname)
DATE=$(date)

# ---------- Start Log ----------
echo "==========================================" >> "$LOGFILE"
echo "Date      : $DATE" >> "$LOGFILE"
echo "Hostname  : $HOST" >> "$LOGFILE"

# ==========================================
# CPU Usage
# ==========================================
CPU=$(top -bn1 | awk '/Cpu\(s\)/ {print int($2+$4)}')

# ==========================================
# Memory Usage
# ==========================================
MEM=$(free | awk '/Mem:/ {print int($3/$2*100)}')

# ==========================================
# Disk Usage
# ==========================================
DISK=$(df -h / | awk 'NR==2 {gsub("%",""); print $5}')

# ==========================================
# Display Server Usage
# ==========================================

echo "========================================="
echo "        SERVER RESOURCE USAGE"
echo "========================================="

echo -e "${GREEN}CPU Usage      : ${CPU}%${NC}"
echo -e "${YELLOW}Memory Usage   : ${MEM}%${NC}"
echo -e "${GREEN}Disk Usage     : ${DISK}%${NC}"

echo "CPU Usage      : ${CPU}%" >> "$LOGFILE"
echo "Memory Usage   : ${MEM}%" >> "$LOGFILE"
echo "Disk Usage     : ${DISK}%" >> "$LOGFILE"

# ==========================================
# Service Monitoring
# ==========================================

echo ""
echo "========================================="
echo "         SERVICE STATUS"
echo "========================================="

echo "" >> "$LOGFILE"
echo "========== SERVICE STATUS ==========" >> "$LOGFILE"

SERVICES=("nginx" "httpd" "jenkins" "docker")

for SERVICE in "${SERVICES[@]}"
do
    if systemctl is-active --quiet "$SERVICE"
    then
        STATUS="Running"
        COLOR=$GREEN
    else
        STATUS="Stopped"
        COLOR=$RED
    fi

    echo -e "${COLOR}${SERVICE} : ${STATUS}${NC}"
    echo "${SERVICE} : ${STATUS}" >> "$LOGFILE"
done

# ==========================================
# Disk Inode Monitoring
# ==========================================

echo ""
echo "========================================="
echo "       DISK INODE USAGE"
echo "========================================="

echo "" >> "$LOGFILE"
echo "========== DISK INODE ==========" >> "$LOGFILE"

INODE=$(df -i / | awk 'NR==2 {print $5}')
INODE_VALUE=$(echo "$INODE" | tr -d '%')

echo -e "${YELLOW}Disk Inode Usage : ${INODE}${NC}"
echo "Disk Inode Usage : ${INODE}" >> "$LOGFILE"

# ==========================================
# Network Connectivity Check
# ==========================================

echo ""
echo "========================================="
echo "     NETWORK CONNECTIVITY CHECK"
echo "========================================="

echo "" >> "$LOGFILE"
echo "========== NETWORK CONNECTIVITY ==========" >> "$LOGFILE"

PING_HOST="8.8.8.8"

if ping -c 2 "$PING_HOST" > /dev/null 2>&1
then
    echo -e "${GREEN}Internet Status : Connected${NC}"
    echo "Internet Status : Connected" >> "$LOGFILE"
else
    echo -e "${RED}Internet Status : Disconnected${NC}"
    echo "Internet Status : Disconnected" >> "$LOGFILE"

    ALERTS+="Internet Connectivity Failed\n"
fi

# ==========================================
# Website Reachability Check
# ==========================================

echo ""
echo "========================================="
echo "     WEBSITE REACHABILITY CHECK"
echo "========================================="

echo "" >> "$LOGFILE"
echo "========== WEBSITE REACHABILITY ==========" >> "$LOGFILE"

# Website to monitor
URL="https://www.google.com"

HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}" "$URL")

if [ "$HTTP_STATUS" = "200" ]; then
    echo -e "${GREEN}$URL is Reachable (HTTP $HTTP_STATUS)${NC}"
    echo "$URL : Reachable (HTTP $HTTP_STATUS)" >> "$LOGFILE"
else
    echo -e "${RED}$URL is NOT Reachable (HTTP $HTTP_STATUS)${NC}"
    echo "$URL : NOT Reachable (HTTP $HTTP_STATUS)" >> "$LOGFILE"

    ALERTS+="Website Unreachable: $URL (HTTP $HTTP_STATUS)\n"
fi

# ==========================================
# Generate Daily Report
# ==========================================

REPORT_DIR="/home/ec2-user/server-monitor/reports"
mkdir -p "$REPORT_DIR"

REPORT_FILE="$REPORT_DIR/server-report-$(date +%F).txt"

{
echo "========================================="
echo "        DAILY SERVER REPORT"
echo "========================================="
echo ""
echo "Hostname        : $HOST"
echo "Date            : $DATE"
echo ""
echo "CPU Usage       : ${CPU}%"
echo "Memory Usage    : ${MEM}%"
echo "Disk Usage      : ${DISK}%"
echo "Disk Inode      : ${INODE}"
echo ""
echo "========== SERVICE STATUS =========="

for SERVICE in "${SERVICES[@]}"
do
    if systemctl is-active --quiet "$SERVICE"
    then
        STATUS="Running"
    else
        STATUS="Stopped"
    fi

    echo "$SERVICE : $STATUS"
done

echo ""
echo "========== NETWORK =========="

if ping -c 2 8.8.8.8 >/dev/null 2>&1
then
    echo "Internet : Connected"
else
    echo "Internet : Disconnected"
fi

echo ""
echo "========== WEBSITE =========="

echo "Website : $URL"
echo "HTTP Status : $HTTP_STATUS"

} > "$REPORT_FILE"

echo ""
echo -e "${GREEN}Daily Report Generated Successfully${NC}"
echo -e "${GREEN}Location : ${REPORT_FILE}${NC}"

echo "Daily Report Generated : $REPORT_FILE" >> "$LOGFILE"

# ==========================================
# Build Alert Message
# ==========================================

ALERTS=""

[ "$CPU" -ge "$CPU_THRESHOLD" ] && ALERTS+="CPU Usage is High : ${CPU}%\n"
[ "$MEM" -ge "$MEM_THRESHOLD" ] && ALERTS+="Memory Usage is High : ${MEM}%\n"
[ "$DISK" -ge "$DISK_THRESHOLD" ] && ALERTS+="Disk Usage is High : ${DISK}%\n"
[ "$INODE_VALUE" -ge "$INODE_THRESHOLD" ] && ALERTS+="Disk Inode Usage is High : ${INODE}\n"

for SERVICE in "${SERVICES[@]}"
do
    if ! systemctl is-active --quiet "$SERVICE"
    then
        ALERTS+="Service Down : $SERVICE\n"
    fi
done

if ! ping -c 2 8.8.8.8 >/dev/null 2>&1
then
    ALERTS+="Internet Connectivity Failed\n"
fi

if [ "$HTTP_STATUS" != "200" ]
then
    ALERTS+="Website Unreachable : $URL (HTTP $HTTP_STATUS)\n"
fi

# ==========================================
# Send Email Report
# ==========================================

EMAIL_BODY="/tmp/server_monitor_email.txt"

{
echo "Server Monitoring Report"
echo "========================================="
echo "Hostname        : $HOST"
echo "Date            : $DATE"
echo ""

echo "CPU Usage       : ${CPU}%"
echo "Memory Usage    : ${MEM}%"
echo "Disk Usage      : ${DISK}%"
echo "Disk Inode      : ${INODE}"
echo ""

echo "========== SERVICES =========="

for SERVICE in "${SERVICES[@]}"
do
    if systemctl is-active --quiet "$SERVICE"
    then
        echo "$SERVICE : Running"
    else
        echo "$SERVICE : Stopped"
    fi
done

echo ""
echo "========== NETWORK =========="

if ping -c 2 8.8.8.8 >/dev/null 2>&1
then
    echo "Internet : Connected"
else
    echo "Internet : Disconnected"
fi

echo ""
echo "========== WEBSITE =========="
echo "Website : $URL"
echo "HTTP Status : $HTTP_STATUS"

echo ""
echo "========== ALERTS =========="

if [ -z "$ALERTS" ]
then
    echo "No Alerts. Server is Healthy."
else
    echo -e "$ALERTS"
fi

} > "$EMAIL_BODY"

mail -s "Daily Server Monitoring Report - $HOST" "$EMAIL" < "$EMAIL_BODY"

echo "Email sent successfully."


ALERTS=""

if [ "$CPU" -ge "$CPU_THRESHOLD" ]; then
    ALERTS+="CPU Usage is High (${CPU}%)\n"
fi

if [ "$MEM" -ge "$MEM_THRESHOLD" ]; then
    ALERTS+="Memory Usage is High (${MEM}%)\n"
fi

if [ "$DISK" -ge "$DISK_THRESHOLD" ]; then
    ALERTS+="Disk Usage is High (${DISK}%)\n"
fi

if [ "$INODE_VALUE" -ge "$INODE_THRESHOLD" ]; then
    echo -e "${RED}WARNING : High Disk Inode Usage (${INODE})${NC}"
    echo "WARNING : High Disk Inode Usage (${INODE})" >> "$LOGFILE"
    ALERTS+="Disk Inode Usage is High (${INODE})\n"
fi

