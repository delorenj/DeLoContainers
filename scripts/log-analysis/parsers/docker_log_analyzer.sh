#!/bin/bash

# Docker Container Log Analyzer
# Analyzes Docker container logs for memory-related issues

set -euo pipefail

LOG_DIR="/home/delorenj/docker/trunk-main/scripts/log-analysis/reports"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
REPORT_FILE="$LOG_DIR/docker_analysis_$TIMESTAMP.txt"

mkdir -p "$LOG_DIR"

echo "Docker Container Log Analysis - $(date)" > "$REPORT_FILE"
echo "=================================================" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Function to analyze container logs
analyze_container_logs() {
    local container_name="$1"
    echo "Analyzing logs for container: $container_name" >> "$REPORT_FILE"
    echo "----------------------------------------" >> "$REPORT_FILE"
    
    # Get container info
    {
        echo "Container Info:"
        docker inspect "$container_name" --format "Image: {{.Config.Image}}" 2>/dev/null || echo "Container not found"
        docker inspect "$container_name" --format "Status: {{.State.Status}}" 2>/dev/null || echo "Status: Unknown"
        docker inspect "$container_name" --format "RestartCount: {{.RestartCount}}" 2>/dev/null || echo "RestartCount: Unknown"
        echo ""
    } >> "$REPORT_FILE"
    
    # Check for memory-related errors in container logs
    {
        echo "Memory-related errors in logs:"
        docker logs "$container_name" --since 24h 2>&1 | grep -i -E "(memory|oom|killed|out of memory|allocation|heap)" | tail -20 || echo "No memory-related errors found"
        echo ""
    } >> "$REPORT_FILE" 2>&1
    
    # Check for error patterns
    {
        echo "General error patterns:"
        docker logs "$container_name" --since 24h 2>&1 | grep -i -E "(error|failed|exception|crash)" | tail -10 || echo "No general errors found"
        echo ""
    } >> "$REPORT_FILE" 2>&1
    
    # Check restart patterns
    {
        echo "Recent restart information:"
        docker logs "$container_name" --since 2h 2>&1 | head -5 || echo "No recent logs available"
        echo ""
        echo "----------------------------------------"
        echo ""
    } >> "$REPORT_FILE" 2>&1
}

# Get list of all containers
echo "Getting list of all containers..." >> "$REPORT_FILE"
{
    echo "Current container status:"
    docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Size}}"
    echo ""
} >> "$REPORT_FILE"

# Focus on problematic containers (restarting or unhealthy)
echo "Analyzing problematic containers..." >> "$REPORT_FILE"
echo "=================================================" >> "$REPORT_FILE"

PROBLEMATIC_CONTAINERS=$(docker ps -a --format "{{.Names}}\t{{.Status}}" | grep -E "(Restarting|unhealthy|Exited)" | cut -f1 || true)

if [ -n "$PROBLEMATIC_CONTAINERS" ]; then
    echo "Found problematic containers:" >> "$REPORT_FILE"
    echo "$PROBLEMATIC_CONTAINERS" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    while IFS= read -r container; do
        if [ -n "$container" ]; then
            analyze_container_logs "$container"
        fi
    done <<< "$PROBLEMATIC_CONTAINERS"
else
    echo "No problematic containers found currently." >> "$REPORT_FILE"
fi

# Analyze Docker daemon logs
echo "" >> "$REPORT_FILE"
echo "Docker Daemon Log Analysis" >> "$REPORT_FILE"
echo "=================================================" >> "$REPORT_FILE"

{
    echo "Recent Docker daemon errors:"
    journalctl -u docker --no-pager --since "2 hours ago" | grep -i -E "(error|failed|memory|oom)" | tail -20 || echo "No recent Docker daemon errors"
    echo ""
    
    echo "Container lifecycle events:"
    journalctl -u docker --no-pager --since "2 hours ago" | grep -i -E "(started|stopped|died|restart)" | tail -15 || echo "No recent container lifecycle events"
} >> "$REPORT_FILE" 2>&1

# Check Docker system resource usage
echo "" >> "$REPORT_FILE"
echo "Docker System Resource Usage" >> "$REPORT_FILE"
echo "=================================================" >> "$REPORT_FILE"

{
    echo "Docker system info:"
    docker system df 2>/dev/null || echo "Docker system df not available"
    echo ""
    
    echo "Current container resource usage:"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}" 2>/dev/null || echo "Docker stats not available"
} >> "$REPORT_FILE" 2>&1

echo "" >> "$REPORT_FILE"
echo "Analysis complete at $(date)" >> "$REPORT_FILE"

echo "Docker log analysis complete. Report saved to: $REPORT_FILE"

# Output summary
echo ""
echo "Summary:"
echo "- Problematic containers: $(echo "$PROBLEMATIC_CONTAINERS" | wc -l 2>/dev/null || echo "0")"
echo "- Report location: $REPORT_FILE"