#!/bin/bash

# Continuous Memory Monitoring Script
# Monitors system and container memory usage in real-time

set -euo pipefail

LOG_DIR="/home/delorenj/docker/trunk-main/scripts/log-analysis/reports"
MONITOR_LOG="$LOG_DIR/memory_monitor.log"
ALERT_THRESHOLD=80  # Alert when memory usage exceeds 80%
INTERVAL=30  # Check every 30 seconds

mkdir -p "$LOG_DIR"

# Function to log with timestamp
log_with_timestamp() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$MONITOR_LOG"
}

# Function to get memory percentage
get_memory_percentage() {
    free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}'
}

# Function to check for memory alerts
check_memory_alert() {
    local mem_percent=$(get_memory_percentage)
    local mem_int=${mem_percent%.*}  # Remove decimal part
    
    if [ "$mem_int" -gt "$ALERT_THRESHOLD" ]; then
        log_with_timestamp "MEMORY ALERT: Usage at ${mem_percent}% (threshold: ${ALERT_THRESHOLD}%)"
        
        # Log top memory processes
        log_with_timestamp "Top memory consuming processes:"
        ps aux --sort=-%mem | head -10 >> "$MONITOR_LOG"
        
        # Log container memory usage
        log_with_timestamp "Container memory usage:"
        docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}\t{{.MemPerc}}" >> "$MONITOR_LOG" 2>/dev/null || echo "Docker stats unavailable" >> "$MONITOR_LOG"
        
        return 0
    else
        log_with_timestamp "Memory usage: ${mem_percent}% (OK)"
        return 1
    fi
}

# Function to monitor container restarts
monitor_container_restarts() {
    local restart_count=$(docker ps --format "table {{.Names}}\t{{.Status}}" | grep -c "Restarting" || echo "0")
    if [ "$restart_count" -gt 0 ]; then
        log_with_timestamp "WARNING: $restart_count containers are restarting"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" | grep "Restarting" >> "$MONITOR_LOG" || true
    fi
}

# Function to log memory statistics
log_memory_stats() {
    log_with_timestamp "Memory Statistics:"
    free -h >> "$MONITOR_LOG"
    echo "" >> "$MONITOR_LOG"
    
    # Log container memory usage periodically
    log_with_timestamp "Container Memory Usage:"
    docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}\t{{.MemPerc}}" >> "$MONITOR_LOG" 2>/dev/null || echo "Docker stats unavailable" >> "$MONITOR_LOG"
    echo "" >> "$MONITOR_LOG"
}

echo "Starting continuous memory monitoring..."
echo "Log file: $MONITOR_LOG"
echo "Alert threshold: ${ALERT_THRESHOLD}%"
echo "Check interval: ${INTERVAL} seconds"
echo "Press Ctrl+C to stop"

log_with_timestamp "Memory monitoring started (PID: $$)"
log_with_timestamp "Alert threshold: ${ALERT_THRESHOLD}%"
log_with_timestamp "Check interval: ${INTERVAL} seconds"

# Main monitoring loop
while true; do
    # Check for memory alerts
    if check_memory_alert; then
        # High memory usage detected, log detailed stats
        log_memory_stats
        monitor_container_restarts
        
        # Check for new OOM events
        if journalctl --no-pager --since "1 minute ago" | grep -q "killed process\|out of memory\|oom-killer"; then
            log_with_timestamp "NEW OOM EVENT DETECTED!"
            journalctl --no-pager --since "1 minute ago" | grep "killed process\|out of memory\|oom-killer" >> "$MONITOR_LOG"
        fi
    else
        # Normal memory usage, just monitor container restarts
        monitor_container_restarts
    fi
    
    # Log detailed stats every 10 minutes (20 cycles * 30 seconds)
    if [ $(($(date +%s) % 600)) -lt 30 ]; then
        log_memory_stats
    fi
    
    sleep "$INTERVAL"
done