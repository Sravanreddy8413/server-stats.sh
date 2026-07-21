#!/bin/bash

echo "===================================="
echo "      SERVER PERFORMANCE REPORT"
echo "===================================="

echo "Date      : $(date)"
echo "Hostname  : $(hostname)"
echo

# CPU Usage
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}')
echo "CPU Usage : ${CPU_USAGE}%"
echo

# Disk Usage
echo "Disk Usage"
df -h /

echo

# Memory Usage
echo "Memory Usage"
free -h

echo

echo "Top 5 CPU Processes"
ps -eo pid,user,%cpu,%mem,comm --sort=-%cpu | head -6

echo

echo "Top 5 Memory Processes"
ps -eo pid,user,%cpu,%mem,comm --sort=-%mem | head -6
