#!/bin/bash

# Cron and Scheduled Task Analysis Script
# Analyzes cron jobs and systemd timers that might cause memory issues

set -euo pipefail

LOG_DIR="/home/delorenj/docker/trunk-main/scripts/log-analysis/reports"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
REPORT_FILE="$LOG_DIR/cron_task_analysis_$TIMESTAMP.txt"

mkdir -p "$LOG_DIR"

echo "Cron and Scheduled Task Analysis - $(date)" > "$REPORT_FILE"
echo "=================================================" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Function to log with timestamp
log_section() {
    echo "" >> "$REPORT_FILE"
    echo "[$1] - $(date '+%Y-%m-%d %H:%M:%S')" >> "$REPORT_FILE"
    echo "----------------------------------------" >> "$REPORT_FILE"
}

# Analyze system cron jobs
log_section "SYSTEM CRON JOBS"
{
    echo "System-wide cron jobs (/etc/crontab):"
    if [ -f /etc/crontab ]; then
        cat /etc/crontab | grep -v "^#" | grep -v "^$" || echo "No active entries in /etc/crontab"
    else
        echo "/etc/crontab not found"
    fi
    
    echo ""
    echo "System cron directories:"
    for dir in /etc/cron.d /etc/cron.daily /etc/cron.hourly /etc/cron.monthly /etc/cron.weekly; do
        if [ -d "$dir" ]; then
            echo "Contents of $dir:"
            ls -la "$dir" 2>/dev/null || echo "Cannot access $dir"
            echo ""
        fi
    done
} >> "$REPORT_FILE" 2>&1

# Analyze user cron jobs
log_section "USER CRON JOBS"
{
    echo "Current user cron jobs:"
    crontab -l 2>/dev/null || echo "No cron jobs for current user"
    
    echo ""
    echo "Root user cron jobs:"
    sudo crontab -l 2>/dev/null || echo "No cron jobs for root user (or no sudo access)"
    
    echo ""
    echo "Cron jobs for other users:"
    for user in $(cut -d: -f1 /etc/passwd); do
        if sudo crontab -u "$user" -l 2>/dev/null; then
            echo "Cron jobs for user $user:"
            sudo crontab -u "$user" -l 2>/dev/null
            echo ""
        fi
    done 2>/dev/null || echo "Unable to check other user cron jobs (sudo required)"
} >> "$REPORT_FILE" 2>&1

# Analyze systemd timers
log_section "SYSTEMD TIMERS"
{
    echo "Active systemd timers:"
    systemctl list-timers --no-pager || echo "Cannot list systemd timers"
    
    echo ""
    echo "All systemd timer units:"
    systemctl list-unit-files --no-pager --type=timer | grep -v "^$" || echo "No timer units found"
} >> "$REPORT_FILE" 2>&1

# Check for recent cron executions
log_section "RECENT CRON EXECUTIONS"
{
    echo "Recent cron job executions from syslog:"
    journalctl --no-pager -u cron --since "24 hours ago" | tail -20 || echo "No recent cron job logs found"
    
    echo ""
    echo "Cron-related entries in auth log:"
    grep -i cron /var/log/auth.log 2>/dev/null | tail -10 || echo "No cron entries in auth log"
} >> "$REPORT_FILE" 2>&1

# Check for memory-intensive scheduled tasks
log_section "MEMORY-INTENSIVE TASK ANALYSIS"
{
    echo "Searching for potentially memory-intensive scheduled tasks:"
    echo ""
    
    # Check for backup scripts
    echo "Backup-related scheduled tasks:"
    {
        crontab -l 2>/dev/null | grep -i -E "(backup|rsync|tar|dump)" || echo "No backup tasks in user cron"
        sudo crontab -l 2>/dev/null | grep -i -E "(backup|rsync|tar|dump)" || echo "No backup tasks in root cron"
    } 2>/dev/null
    
    echo ""
    echo "Log rotation and cleanup tasks:"
    {
        find /etc/cron.* -type f -exec grep -l -i -E "(logrotate|cleanup|compress|archive)" {} \; 2>/dev/null | while read file; do
            echo "File: $file"
            cat "$file" 2>/dev/null | grep -v "^#" | grep -v "^$"
            echo ""
        done
    } || echo "No log rotation tasks found in cron directories"
    
    echo ""
    echo "Docker-related scheduled tasks:"
    {
        crontab -l 2>/dev/null | grep -i docker || echo "No Docker tasks in user cron"
        sudo crontab -l 2>/dev/null | grep -i docker || echo "No Docker tasks in root cron"
    } 2>/dev/null
} >> "$REPORT_FILE" 2>&1

# Check for at jobs
log_section "AT JOBS (ONE-TIME SCHEDULED TASKS)"
{
    echo "Pending at jobs:"
    atq 2>/dev/null || echo "at command not available or no pending jobs"
    
    echo ""
    echo "Recent at job executions:"
    journalctl --no-pager -u atd --since "24 hours ago" 2>/dev/null | tail -10 || echo "No recent at job logs"
} >> "$REPORT_FILE" 2>&1

# Check Docker container scheduled tasks
log_section "DOCKER CONTAINER SCHEDULED TASKS"
{
    echo "Checking for cron jobs inside running containers:"
    docker ps --format "{{.Names}}" | while read container; do
        echo "Checking container: $container"
        if docker exec "$container" which crontab >/dev/null 2>&1; then
            echo "Cron jobs in $container:"
            docker exec "$container" crontab -l 2>/dev/null || echo "No cron jobs in $container"
        else
            echo "No crontab in $container"
        fi
        echo ""
    done 2>/dev/null || echo "Unable to check Docker container cron jobs"
} >> "$REPORT_FILE" 2>&1

# Memory correlation analysis
log_section "MEMORY CORRELATION ANALYSIS"
{
    echo "Analyzing correlation between scheduled tasks and memory usage:"
    echo ""
    
    echo "Current time: $(date)"
    echo "Current memory usage: $(free -h | grep Mem | awk '{print $3 "/" $2}')"
    
    echo ""
    echo "Checking if we're near scheduled task execution times:"
    current_hour=$(date +%H)
    current_minute=$(date +%M)
    
    echo "Current time: ${current_hour}:${current_minute}"
    echo ""
    
    # Check if any cron jobs are scheduled to run soon
    echo "Upcoming scheduled tasks (next 2 hours):"
    {
        # This is a simplified check - a full implementation would parse cron expressions
        crontab -l 2>/dev/null | grep -v "^#" | while read line; do
            if [[ $line =~ ^[0-9*] ]]; then
                echo "Task: $line"
            fi
        done
    } 2>/dev/null || echo "No user cron jobs to analyze"
} >> "$REPORT_FILE" 2>&1

echo ""
echo "Cron and scheduled task analysis complete. Report saved to: $REPORT_FILE"

# Summary output
echo ""
echo "Summary:"
echo "1. System cron jobs: $(find /etc/cron.* -type f 2>/dev/null | wc -l || echo "0") files"
echo "2. Active systemd timers: $(systemctl list-timers --no-pager --quiet | wc -l || echo "0")"
echo "3. Report contains detailed analysis of all scheduled tasks"
echo "4. Check report for memory-intensive tasks that might correlate with memory growth"