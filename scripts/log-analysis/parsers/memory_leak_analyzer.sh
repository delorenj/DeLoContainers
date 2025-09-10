#!/bin/bash

# Memory Leak Log Analysis Script
# Analyzes system logs for memory-related issues and patterns

set -euo pipefail

LOG_DIR="/home/delorenj/docker/trunk-main/scripts/log-analysis/reports"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
REPORT_FILE="$LOG_DIR/memory_leak_analysis_$TIMESTAMP.txt"

mkdir -p "$LOG_DIR"

echo "Memory Leak Analysis Report - $(date)" > "$REPORT_FILE"
echo "=================================================" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Function to log with timestamp
log_section() {
    echo "" >> "$REPORT_FILE"
    echo "[$1] - $(date '+%Y-%m-%d %H:%M:%S')" >> "$REPORT_FILE"
    echo "----------------------------------------" >> "$REPORT_FILE"
}

# Check for Out of Memory events in system logs
log_section "OOM KILLER EVENTS"
{
    echo "Checking for OOM killer events in system logs..."
    if journalctl --no-pager --since "1 week ago" | grep -i "killed process\|out of memory\|oom-killer"; then
        echo "OOM events found above"
    else
        echo "No OOM killer events found in the last week"
    fi
} >> "$REPORT_FILE" 2>&1

# Check memory allocation failures
log_section "MEMORY ALLOCATION FAILURES"
{
    echo "Checking for memory allocation failures..."
    if journalctl --no-pager --since "1 week ago" | grep -i "cannot allocate memory\|memory allocation failed"; then
        echo "Memory allocation failures found above"
    else
        echo "No memory allocation failures found"
    fi
} >> "$REPORT_FILE" 2>&1

# Docker daemon memory issues
log_section "DOCKER DAEMON MEMORY ISSUES"
{
    echo "Analyzing Docker daemon logs for memory issues..."
    if journalctl --no-pager -u docker --since "1 day ago" | grep -i "memory\|oom\|killed"; then
        echo "Docker memory issues found above"
    else
        echo "No Docker memory issues found in last 24 hours"
    fi
} >> "$REPORT_FILE" 2>&1

# Container restarts (potential memory issues)
log_section "CONTAINER RESTART PATTERNS"
{
    echo "Analyzing container restart patterns..."
    echo "Recent container restarts:"
    docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" | grep -i restart || echo "No restarting containers currently"
    
    echo ""
    echo "Docker daemon container restart logs:"
    journalctl --no-pager -u docker --since "2 hours ago" | grep -i "restart\|exit\|died" | tail -20 || echo "No recent container restart logs"
} >> "$REPORT_FILE" 2>&1

# System memory pressure indicators
log_section "SYSTEM MEMORY PRESSURE"
{
    echo "Current memory usage:"
    free -h
    
    echo ""
    echo "Memory usage trends (if available):"
    # Check if sar is available for historical data
    if command -v sar &> /dev/null; then
        echo "Memory utilization over last 24 hours:"
        sar -r 1 1 2>/dev/null || echo "SAR memory data not available"
    else
        echo "SAR utility not installed - install sysstat for historical memory data"
    fi
} >> "$REPORT_FILE" 2>&1

# Check for memory leaks in specific processes
log_section "PROCESS MEMORY ANALYSIS"
{
    echo "Top memory consuming processes:"
    ps aux --sort=-%mem | head -15
    
    echo ""
    echo "Docker containers memory usage:"
    docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}\t{{.MemPerc}}" 2>/dev/null || echo "Unable to get Docker stats"
} >> "$REPORT_FILE" 2>&1

# Check systemd service failures related to memory
log_section "SYSTEMD SERVICE MEMORY FAILURES"
{
    echo "Failed services (may indicate memory issues):"
    systemctl list-units --failed --no-pager
    
    echo ""
    echo "Services with memory-related failures:"
    journalctl --no-pager --since "1 day ago" -p err | grep -i memory || echo "No memory-related service failures"
} >> "$REPORT_FILE" 2>&1

# Check for swap usage patterns
log_section "SWAP USAGE ANALYSIS"
{
    echo "Current swap usage:"
    swapon --show || echo "No swap configured"
    
    echo ""
    echo "Swap usage from free command:"
    free -h | grep -i swap
} >> "$REPORT_FILE" 2>&1

echo ""
echo "Analysis complete. Report saved to: $REPORT_FILE"
echo "Key findings:"
echo "1. Found $(journalctl --no-pager --since "1 week ago" | grep -c "killed process\|out of memory\|oom-killer" || echo "0") OOM events in the last week"
echo "2. Found $(docker ps | grep -c "Restarting" || echo "0") currently restarting containers"
echo "3. Report contains detailed analysis of system memory patterns"

# Output current memory status
echo ""
echo "Current system memory status:"
free -h