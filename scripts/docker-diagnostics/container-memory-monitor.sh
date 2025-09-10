#!/bin/bash

# Container Memory Monitor - Real-time monitoring for memory leaks
# This script monitors Docker containers continuously and alerts on memory growth

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/container-memory-monitor.log"
ALERT_THRESHOLD_MB=1000  # Alert if container uses more than 1GB
GROWTH_THRESHOLD=20      # Alert if memory grows by 20% in 5 minutes

echo "🔍 Docker Container Memory Monitor Started"
echo "Monitoring containers for memory growth and leaks..."
echo "Alert threshold: ${ALERT_THRESHOLD_MB}MB"
echo "Growth threshold: ${GROWTH_THRESHOLD}%"
echo "Log file: $LOG_FILE"
echo "Press Ctrl+C to stop monitoring"

# Function to log with timestamp
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to send alert (can be extended to email, slack, etc.)
send_alert() {
    local message="$1"
    log_message "🚨 ALERT: $message"
    # Add notification methods here (email, slack webhook, etc.)
}

# Function to extract memory usage in MB
extract_memory_mb() {
    local mem_usage="$1"
    if [[ "$mem_usage" =~ ([0-9.]+)GiB ]]; then
        echo "$(echo "${BASH_REMATCH[1]} * 1024" | bc -l | cut -d. -f1)"
    elif [[ "$mem_usage" =~ ([0-9.]+)MiB ]]; then
        echo "${BASH_REMATCH[1]}" | cut -d. -f1
    else
        echo "0"
    fi
}

# Initialize previous memory readings
declare -A prev_memory
declare -A alert_counts

log_message "🚀 Memory monitor initialized"

# Main monitoring loop
while true; do
    current_time=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Get current container stats
    while read -r container cpu mem_usage mem_percent net_io block_io; do
        # Skip header line
        if [[ "$container" == "CONTAINER" ]]; then
            continue
        fi
        
        # Extract memory in MB
        current_mb=$(extract_memory_mb "$mem_usage")
        
        # Check if memory exceeds threshold
        if [ "$current_mb" -gt "$ALERT_THRESHOLD_MB" ]; then
            alert_counts["$container"]=$((${alert_counts["$container"]:-0} + 1))
            
            # Only alert every 10 cycles to avoid spam
            if [ $((${alert_counts["$container"]} % 10)) -eq 1 ]; then
                send_alert "Container $container using ${current_mb}MB (>${ALERT_THRESHOLD_MB}MB threshold)"
                
                # Get additional details for high memory containers
                log_message "📊 High memory container details for $container:"
                docker inspect "$container" --format '  Image: {{.Config.Image}}' | tee -a "$LOG_FILE"
                docker inspect "$container" --format '  Uptime: {{.State.StartedAt}}' | tee -a "$LOG_FILE"
                docker inspect "$container" --format '  Restart Count: {{.RestartCount}}' | tee -a "$LOG_FILE"
                
                # Check for memory limit
                memory_limit=$(docker inspect "$container" --format '{{.HostConfig.Memory}}')
                if [ "$memory_limit" = "0" ]; then
                    log_message "  ⚠️  NO MEMORY LIMIT - Unlimited memory consumption possible!"
                else
                    limit_mb=$((memory_limit / 1024 / 1024))
                    log_message "  Memory Limit: ${limit_mb}MB"
                fi
            fi
        fi
        
        # Check for memory growth
        if [ -n "${prev_memory[$container]}" ]; then
            prev_mb=${prev_memory[$container]}
            if [ "$prev_mb" -gt 0 ]; then
                growth_percent=$(echo "scale=2; ($current_mb - $prev_mb) * 100 / $prev_mb" | bc -l)
                
                if [ "$(echo "$growth_percent > $GROWTH_THRESHOLD" | bc -l)" = "1" ]; then
                    send_alert "Container $container memory grew ${growth_percent}% (${prev_mb}MB → ${current_mb}MB)"
                fi
            fi
        fi
        
        # Store current memory for next iteration
        prev_memory["$container"]=$current_mb
        
        # Log current stats
        if [ "$current_mb" -gt 100 ]; then  # Only log containers using >100MB
            log_message "📈 $container: ${current_mb}MB (CPU: $cpu, Mem%: $mem_percent)"
        fi
        
    done < <(docker stats --no-stream --format "table {{.Container}} {{.CPUPerc}} {{.MemUsage}} {{.MemPerc}} {{.NetIO}} {{.BlockIO}}")
    
    # Sleep for 5 minutes before next check
    sleep 300
    
done