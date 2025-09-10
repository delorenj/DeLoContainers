#!/bin/bash

# Host-based MetaMCP Monitoring and Control
# Monitors from host system to avoid BusyBox limitations

CONTAINER_NAME="metamcp"
MAX_PROCESSES=15
MAX_MEMORY_MB=4096
CHECK_INTERVAL=30
LOG_FILE="/tmp/metamcp-host-monitor.log"
ALERT_FILE="/tmp/metamcp-alerts.log"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    local level="$1"
    shift
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $*" | tee -a "$LOG_FILE"
}

alert() {
    local message="$1"
    log "ALERT" "$message"
    echo "$(date '+%Y-%m-%d %H:%M:%S') $message" >> "$ALERT_FILE"
    # Could integrate with notification system here
}

get_container_stats() {
    if ! docker ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        return 1
    fi
    
    docker stats --no-stream --format "json" "$CONTAINER_NAME" 2>/dev/null
}

get_process_count() {
    if ! docker exec "$CONTAINER_NAME" ps aux 2>/dev/null | grep -E "(npm|node)" | grep -v grep | wc -l; then
        echo "0"
    fi
}

get_memory_usage_mb() {
    local stats=$(get_container_stats)
    if [ -n "$stats" ]; then
        echo "$stats" | jq -r '.MemUsage' | sed 's/[^0-9.]//g' | head -1
    else
        echo "0"
    fi
}

get_cpu_usage() {
    local stats=$(get_container_stats)
    if [ -n "$stats" ]; then
        echo "$stats" | jq -r '.CPUPerc' | sed 's/%//'
    else
        echo "0"
    fi
}

check_container_health() {
    if ! docker ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        log "ERROR" "Container $CONTAINER_NAME is not running"
        return 1
    fi
    
    # Check if container is healthy
    local health=$(docker inspect "$CONTAINER_NAME" --format='{{.State.Health.Status}}' 2>/dev/null)
    if [ "$health" != "healthy" ]; then
        log "WARN" "Container health status: $health"
    fi
    
    return 0
}

emergency_process_cleanup() {
    log "WARN" "Starting emergency process cleanup"
    
    # Use the BusyBox-compatible emergency script
    /home/delorenj/docker/trunk-main/scripts/emergency-metamcp-busybox-killer.sh false
    
    return $?
}

emergency_container_restart() {
    log "CRITICAL" "Performing emergency container restart"
    alert "EMERGENCY: Restarting MetaMCP container due to resource crisis"
    
    # Graceful restart with health check
    docker restart "$CONTAINER_NAME"
    
    # Wait for container to be healthy
    local attempts=0
    local max_attempts=12 # 2 minutes
    
    while [ $attempts -lt $max_attempts ]; do
        sleep 10
        attempts=$((attempts + 1))
        
        if check_container_health; then
            local health=$(docker inspect "$CONTAINER_NAME" --format='{{.State.Health.Status}}' 2>/dev/null)
            if [ "$health" = "healthy" ]; then
                log "INFO" "Container restart successful and healthy"
                return 0
            fi
        fi
        
        log "INFO" "Waiting for container health... ($attempts/$max_attempts)"
    done
    
    log "ERROR" "Container restart failed or unhealthy after 2 minutes"
    return 1
}

analyze_process_explosion() {
    log "INFO" "Analyzing process explosion patterns"
    
    # Get detailed process information
    docker exec "$CONTAINER_NAME" sh -c '
        echo "=== Process Analysis ==="
        echo "Total processes:"
        ps aux | wc -l
        echo ""
        echo "npm/node processes:"
        ps aux | grep -E "(npm|node)" | grep -v grep | wc -l
        echo ""
        echo "Process command frequency:"
        ps aux | grep -E "(npm|node)" | grep -v grep | awk "{print \$11, \$12}" | sort | uniq -c | sort -nr | head -10
        echo ""
        echo "Memory usage by process:"
        ps aux | grep -E "(npm|node)" | grep -v grep | sort -k4 -nr | head -10
    ' >> "$LOG_FILE"
}

monitor_loop() {
    log "INFO" "Starting MetaMCP host monitor (PID: $$)"
    log "INFO" "Max processes: $MAX_PROCESSES, Max memory: ${MAX_MEMORY_MB}MB"
    log "INFO" "Check interval: ${CHECK_INTERVAL}s"
    
    while true; do
        if ! check_container_health; then
            sleep "$CHECK_INTERVAL"
            continue
        fi
        
        local process_count=$(get_process_count)
        local memory_usage=$(get_memory_usage_mb)
        local cpu_usage=$(get_cpu_usage)
        
        # Process count check
        if [ "$process_count" -gt "$MAX_PROCESSES" ]; then
            alert "Process explosion detected: $process_count processes (max: $MAX_PROCESSES)"
            analyze_process_explosion
            
            if [ "$process_count" -gt $((MAX_PROCESSES * 3)) ]; then
                # Severe explosion - emergency restart
                log "CRITICAL" "Severe process explosion: $process_count processes"
                emergency_container_restart
            else
                # Moderate explosion - cleanup
                emergency_process_cleanup
            fi
        fi
        
        # Memory check (if we can parse it)
        if [ -n "$memory_usage" ] && [ "$memory_usage" != "0" ]; then
            local memory_mb=${memory_usage%.*} # Remove decimals
            if [ "$memory_mb" -gt "$MAX_MEMORY_MB" ]; then
                alert "Memory limit exceeded: ${memory_mb}MB (max: ${MAX_MEMORY_MB}MB)"
                emergency_process_cleanup
            fi
        fi
        
        # Log status every 10 minutes
        if [ $(($(date +%M) % 10)) -eq 0 ]; then
            log "INFO" "Status: ${process_count} processes, ${memory_usage}MB memory, ${cpu_usage}% CPU"
        fi
        
        sleep "$CHECK_INTERVAL"
    done
}

# Handle signals gracefully
trap 'log "INFO" "Monitor stopping..."; exit 0' SIGTERM SIGINT

# Main execution
case "${1:-monitor}" in
    monitor)
        monitor_loop
        ;;
    check)
        process_count=$(get_process_count)
        memory_usage=$(get_memory_usage_mb)
        echo "Process count: $process_count"
        echo "Memory usage: ${memory_usage}MB"
        echo "Status: $([ "$process_count" -le "$MAX_PROCESSES" ] && echo "OK" || echo "CRITICAL")"
        ;;
    cleanup)
        emergency_process_cleanup
        ;;
    restart)
        emergency_container_restart
        ;;
    analyze)
        analyze_process_explosion
        ;;
    *)
        echo "Usage: $0 [monitor|check|cleanup|restart|analyze]"
        echo "  monitor  - Start continuous monitoring (default)"
        echo "  check    - Single status check"
        echo "  cleanup  - Emergency process cleanup"
        echo "  restart  - Emergency container restart"
        echo "  analyze  - Analyze process explosion"
        exit 1
        ;;
esac