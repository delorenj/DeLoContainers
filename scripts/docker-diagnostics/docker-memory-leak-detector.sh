#!/bin/bash

# Docker Memory Leak Detector
# Comprehensive script to identify Docker-related memory consumption issues

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT_FILE="${SCRIPT_DIR}/memory-leak-report-$(date +%Y%m%d-%H%M%S).txt"
LOG_FILE="${SCRIPT_DIR}/memory-monitoring.log"

echo "🔍 Docker Memory Leak Detection Report" | tee "$REPORT_FILE"
echo "Generated: $(date)" | tee -a "$REPORT_FILE"
echo "=======================================" | tee -a "$REPORT_FILE"

# Function to log with timestamp
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE" "$REPORT_FILE"
}

# Function to convert bytes to human readable
convert_bytes() {
    local bytes=$1
    if [ "$bytes" -ge 1073741824 ]; then
        echo "$(( bytes / 1073741824 ))GB"
    elif [ "$bytes" -ge 1048576 ]; then
        echo "$(( bytes / 1048576 ))MB"
    elif [ "$bytes" -ge 1024 ]; then
        echo "$(( bytes / 1024 ))KB"
    else
        echo "${bytes}B"
    fi
}

log_message "🚨 CRITICAL MEMORY CONSUMERS DETECTED"

# 1. Top Memory Consuming Containers
log_message "\n📊 CONTAINER MEMORY USAGE (Current)"
{
    echo "CONTAINER_NAME|IMAGE|MEMORY_USAGE|MEMORY_LIMIT|MEMORY_PERCENT|STATUS"
    docker stats --no-stream --format "table {{.Container}}|{{.Image}}|{{.MemUsage}}|{{.MemPerc}}|{{.Status}}" | grep -v "CONTAINER" | while IFS='|' read -r container image memusage mempercent status; do
        # Extract numeric memory usage for sorting
        memory_mb=$(echo "$memusage" | grep -o '^[0-9.]*' | head -1)
        if [ -n "$memory_mb" ]; then
            printf "%s|%s|%s|N/A|%s|%s\n" "$container" "$image" "$memusage" "$mempercent" "$status"
        fi
    done | sort -t'|' -k3 -nr
} | column -t -s'|' | tee -a "$REPORT_FILE"

# 2. Problematic Containers Analysis
log_message "\n🚨 HIGH MEMORY CONSUMERS (>1GB)"
docker stats --no-stream | awk 'NR>1 {
    gsub(/GiB/, "*1024", $4)
    gsub(/MiB/, "", $4)
    if ($4+0 > 1024) print $1, $4, $2
}' | while read container memory image; do
    log_message "🔴 CRITICAL: $container ($image) using ${memory}MB"
    
    # Get detailed container info
    log_message "  Container Details:"
    docker inspect "$container" --format '  Image: {{.Config.Image}}' | tee -a "$REPORT_FILE"
    docker inspect "$container" --format '  Created: {{.Created}}' | tee -a "$REPORT_FILE"
    docker inspect "$container" --format '  Status: {{.State.Status}}' | tee -a "$REPORT_FILE"
    docker inspect "$container" --format '  Restart Count: {{.RestartCount}}' | tee -a "$REPORT_FILE"
    
    # Check for memory limits
    memory_limit=$(docker inspect "$container" --format '{{.HostConfig.Memory}}')
    if [ "$memory_limit" = "0" ]; then
        log_message "  ⚠️  NO MEMORY LIMIT SET - This container can consume unlimited memory!"
    else
        log_message "  Memory Limit: $(convert_bytes $memory_limit)"
    fi
    
    # Check for memory leaks in logs
    log_message "  Checking logs for memory-related errors:"
    if docker logs --tail 50 "$container" 2>&1 | grep -i "memory\|oom\|killed\|out of memory\|leak" | head -5; then
        log_message "  🔥 MEMORY ISSUES FOUND IN LOGS!"
    else
        log_message "  No obvious memory errors in recent logs"
    fi
    
    echo "" | tee -a "$REPORT_FILE"
done

# 3. Docker System Resource Usage
log_message "\n💾 DOCKER SYSTEM RESOURCE USAGE"
{
    docker system df -v | head -20
} | tee -a "$REPORT_FILE"

# 4. Volume Analysis for Memory-Mapped Files
log_message "\n🗂️  LARGE VOLUME ANALYSIS"
docker system df -v | grep -A 100 "Local Volumes space usage:" | grep -E "GB|[0-9]{3,}" | head -10 | while read line; do
    if [[ "$line" =~ ([0-9]+\.?[0-9]*)(GB|MB) ]]; then
        size="${BASH_REMATCH[1]}"
        unit="${BASH_REMATCH[2]}"
        volume_name=$(echo "$line" | awk '{print $1}')
        
        if [[ "$unit" == "GB" && $(echo "$size > 1.0" | bc -l 2>/dev/null || echo 0) == 1 ]]; then
            log_message "🔴 LARGE VOLUME: $volume_name - ${size}${unit}"
            
            # Find containers using this volume
            if docker ps -a --format "table {{.Names}}\t{{.Mounts}}" | grep -q "$volume_name"; then
                log_message "  Used by containers:"
                docker ps -a --format "table {{.Names}}\t{{.Mounts}}" | grep "$volume_name" | awk '{print "    " $1}' | tee -a "$REPORT_FILE"
            fi
        fi
    fi
done

# 5. Orphaned Resources
log_message "\n🧹 ORPHANED RESOURCES"
log_message "Dangling Images:"
dangling_count=$(docker images -f "dangling=true" -q | wc -l)
if [ "$dangling_count" -gt 0 ]; then
    log_message "  🔴 Found $dangling_count dangling images"
    docker images -f "dangling=true" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}" | head -10 | tee -a "$REPORT_FILE"
else
    log_message "  ✅ No dangling images"
fi

log_message "\nUnused Volumes:"
unused_volumes=$(docker volume ls -f "dangling=true" -q | wc -l)
if [ "$unused_volumes" -gt 0 ]; then
    log_message "  🔴 Found $unused_volumes unused volumes"
    docker volume ls -f "dangling=true" | tee -a "$REPORT_FILE"
else
    log_message "  ✅ No unused volumes"
fi

# 6. Container Restart Analysis (indicates potential memory issues)
log_message "\n🔄 CONTAINER RESTART ANALYSIS"
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" | grep -E "Restarting|Exited" | while read name status image; do
    restart_count=$(docker inspect "$name" --format '{{.RestartCount}}' 2>/dev/null || echo "0")
    if [ "$restart_count" -gt 0 ]; then
        log_message "🔴 $name: $restart_count restarts - Status: $status"
    fi
done

# 7. Docker Daemon Memory Usage
log_message "\n🐳 DOCKER DAEMON MEMORY USAGE"
docker_pid=$(pgrep -f dockerd | head -1)
if [ -n "$docker_pid" ]; then
    daemon_memory=$(ps -p "$docker_pid" -o rss= | awk '{print $1*1024}')
    log_message "Docker Daemon Memory: $(convert_bytes $daemon_memory)"
    
    if [ "$daemon_memory" -gt 1073741824 ]; then # > 1GB
        log_message "🔴 CRITICAL: Docker daemon using excessive memory!"
    fi
else
    log_message "Could not determine Docker daemon memory usage"
fi

# 8. Memory-Mapped Files Check
log_message "\n🗂️  MEMORY-MAPPED FILES IN CONTAINERS"
for container in $(docker ps -q); do
    container_name=$(docker ps --filter id="$container" --format "{{.Names}}")
    log_message "Checking $container_name for memory-mapped files:"
    
    # Check for large files in common memory-heavy locations
    docker exec "$container" sh -c '
        find /tmp /var/tmp /var/log /app /data -type f -size +100M 2>/dev/null | head -5
    ' 2>/dev/null | while read file; do
        if [ -n "$file" ]; then
            log_message "  🔍 Large file found: $file"
        fi
    done || log_message "  Could not check filesystem (container may not support shell)"
done

# 9. Generate Recommendations
log_message "\n💡 RECOMMENDATIONS"

# Check metamcp specifically
if docker ps --format "{{.Names}}" | grep -q "metamcp"; then
    metamcp_memory=$(docker stats --no-stream --format "{{.MemUsage}}" metamcp | grep -o '^[0-9.]*')
    if [ -n "$metamcp_memory" ] && [ "$(echo "$metamcp_memory > 10" | bc -l 2>/dev/null || echo 0)" = "1" ]; then
        log_message "🚨 METAMCP CRITICAL ISSUE:"
        log_message "  - Container consuming ${metamcp_memory}GB+ memory"
        log_message "  - No memory limit set - can consume unlimited host memory"
        log_message "  - Consider adding memory limit: deploy.resources.limits.memory: 4G"
        log_message "  - Check for memory leaks in claude-flow or MCP processes"
        log_message "  - Consider restarting: docker restart metamcp"
    fi
fi

# Check Windows VM
if docker ps --format "{{.Names}}" | grep -q "windows"; then
    log_message "🚨 WINDOWS VM ISSUE:"
    log_message "  - VM configured for 32GB RAM allocation"
    log_message "  - Volume windows-data: ~69GB disk usage"
    log_message "  - Consider reducing RAM_SIZE if not actively used"
    log_message "  - Monitor VM's actual memory usage vs allocation"
fi

# Check Qdrant
if docker ps --format "{{.Names}}" | grep -q "qdrant"; then
    qdrant_volumes=$(docker system df -v | grep -E "qdrant.*GB" | wc -l)
    if [ "$qdrant_volumes" -gt 0 ]; then
        log_message "🚨 QDRANT STORAGE ISSUE:"
        log_message "  - Multiple Qdrant volumes consuming significant space"
        log_message "  - Consider cleaning up unused collections"
        log_message "  - Review data retention policies"
    fi
fi

log_message "\n🔧 IMMEDIATE ACTIONS:"
log_message "1. Add memory limits to containers without limits"
log_message "2. Clean up dangling images and unused volumes"
log_message "3. Consider stopping Windows VM if not in use"
log_message "4. Restart metamcp to clear potential memory leaks"
log_message "5. Review and optimize Qdrant data storage"

log_message "\n📊 Run this script regularly to monitor memory trends"
log_message "Report saved to: $REPORT_FILE"
log_message "Monitoring log: $LOG_FILE"

# Set executable permissions for the script
chmod +x "$0"