#!/bin/bash
# Continuous health monitoring script for qBittorrent
# Usage: ./health-check.sh [--continuous] [--interval=seconds] [--alert-webhook=url]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_DIR="/home/delorenj/docker/trunk-main/stacks/media"
MONITORING_DIR="$SCRIPT_DIR/logs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Default configuration
CONTINUOUS_MODE=false
CHECK_INTERVAL=300  # 5 minutes
ALERT_WEBHOOK=""
MAX_LOG_FILES=100
LOG_FILE="$MONITORING_DIR/health_check_$TIMESTAMP.log"
STATUS_FILE="$MONITORING_DIR/current_status.json"
METRICS_FILE="$MONITORING_DIR/metrics.json"

mkdir -p "$MONITORING_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --continuous)
            CONTINUOUS_MODE=true
            shift
            ;;
        --interval=*)
            CHECK_INTERVAL="${1#*=}"
            shift
            ;;
        --alert-webhook=*)
            ALERT_WEBHOOK="${1#*=}"
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --continuous        Run continuously"
            echo "  --interval=SECONDS  Check interval in seconds (default: 300)"
            echo "  --alert-webhook=URL Webhook URL for alerts"
            echo "  --help             Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Logging function
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date -Iseconds)
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Alert function
send_alert() {
    local severity="$1"
    local message="$2"
    local details="$3"
    
    log_message "ALERT" "$severity: $message"
    
    if [ -n "$ALERT_WEBHOOK" ]; then
        local payload=$(jq -n \
            --arg severity "$severity" \
            --arg message "$message" \
            --arg details "$details" \
            --arg timestamp "$(date -Iseconds)" \
            '{
                "severity": $severity,
                "service": "qbittorrent",
                "message": $message,
                "details": $details,
                "timestamp": $timestamp
            }')
        
        curl -s -X POST -H "Content-Type: application/json" \
             -d "$payload" "$ALERT_WEBHOOK" >/dev/null 2>&1 || \
             log_message "ERROR" "Failed to send alert to webhook"
    fi
}

# Health check function
perform_health_check() {
    local check_timestamp=$(date -Iseconds)
    local check_results=()
    local overall_status="HEALTHY"
    local warnings=0
    local errors=0
    
    log_message "INFO" "Starting health check"
    
    cd "$STACK_DIR"
    
    # Check 1: Container Status
    if docker-compose ps qbittorrent | grep -q "Up"; then
        check_results+=('{"check": "container_status", "status": "PASS", "message": "Container is running"}')
        log_message "INFO" "✓ Container is running"
    else
        check_results+=('{"check": "container_status", "status": "FAIL", "message": "Container is not running"}')
        log_message "ERROR" "✗ Container is not running"
        overall_status="CRITICAL"
        ((errors++))
        send_alert "CRITICAL" "qBittorrent container is down" "Container health check failed"
    fi
    
    # Check 2: Web UI Accessibility
    local web_response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8091 || echo "000")
    if [ "$web_response" = "200" ] || [ "$web_response" = "401" ] || [ "$web_response" = "403" ]; then
        check_results+=('{"check": "web_ui", "status": "PASS", "message": "Web UI accessible", "details": "HTTP '${web_response}'"}')
        log_message "INFO" "✓ Web UI accessible (HTTP $web_response)"
    else
        check_results+=('{"check": "web_ui", "status": "FAIL", "message": "Web UI not accessible", "details": "HTTP '${web_response}'"}')
        log_message "ERROR" "✗ Web UI not accessible (HTTP $web_response)"
        overall_status="CRITICAL"
        ((errors++))
        send_alert "HIGH" "qBittorrent Web UI not accessible" "HTTP response: $web_response"
    fi
    
    # Check 3: VPN Connection
    local vpn_ip=$(docker exec gluetun curl -s --connect-timeout 10 ipinfo.io/ip 2>/dev/null || echo "ERROR")
    if [[ "$vpn_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        check_results+=('{"check": "vpn_connection", "status": "PASS", "message": "VPN connected", "details": "IP: '${vpn_ip}'"}')
        log_message "INFO" "✓ VPN connected (IP: $vpn_ip)"
    else
        check_results+=('{"check": "vpn_connection", "status": "FAIL", "message": "VPN connection issue", "details": "'${vpn_ip}'"}')
        log_message "ERROR" "✗ VPN connection issue"
        overall_status="CRITICAL"
        ((errors++))
        send_alert "CRITICAL" "VPN connection lost" "External IP check failed: $vpn_ip"
    fi
    
    # Check 4: DNS Resolution
    if docker exec qbittorrent nslookup google.com >/dev/null 2>&1; then
        check_results+=('{"check": "dns_resolution", "status": "PASS", "message": "DNS resolution working"}')
        log_message "INFO" "✓ DNS resolution working"
    else
        check_results+=('{"check": "dns_resolution", "status": "FAIL", "message": "DNS resolution failed"}')
        log_message "ERROR" "✗ DNS resolution failed"
        overall_status="CRITICAL"
        ((errors++))
        send_alert "HIGH" "DNS resolution failed" "Cannot resolve external domains"
    fi
    
    # Check 5: Torrent Port Listening
    if docker exec qbittorrent netstat -ln | grep -q ":49152"; then
        check_results+=('{"check": "torrent_port", "status": "PASS", "message": "Torrent port listening"}')
        log_message "INFO" "✓ Torrent port listening"
    else
        check_results+=('{"check": "torrent_port", "status": "WARN", "message": "Torrent port not listening"}')
        log_message "WARN" "! Torrent port not listening"
        [ "$overall_status" = "HEALTHY" ] && overall_status="WARNING"
        ((warnings++))
        send_alert "MEDIUM" "Torrent port not listening" "Port 49152 is not listening"
    fi
    
    # Check 6: File System Permissions
    if docker exec qbittorrent touch /config/health_check_test 2>/dev/null && docker exec qbittorrent rm /config/health_check_test 2>/dev/null; then
        check_results+=('{"check": "file_permissions", "status": "PASS", "message": "File system writable"}')
        log_message "INFO" "✓ File system writable"
    else
        check_results+=('{"check": "file_permissions", "status": "FAIL", "message": "File system permission issue"}')
        log_message "ERROR" "✗ File system permission issue"
        overall_status="CRITICAL"
        ((errors++))
        send_alert "HIGH" "File system permission issue" "Cannot write to config directory"
    fi
    
    # Check 7: Memory Usage
    local memory_usage=$(docker stats qbittorrent --no-stream --format "{{.MemUsage}}" 2>/dev/null | cut -d'/' -f1 | tr -d 'B' | tr -d 'i' || echo "UNKNOWN")
    if [ "$memory_usage" != "UNKNOWN" ]; then
        # Extract numeric value (assuming format like "123.4MB")
        local mem_value=$(echo "$memory_usage" | grep -o '[0-9.]*' | head -1)
        local mem_unit=$(echo "$memory_usage" | grep -o '[A-Z]*' | head -1)
        
        if [ "$mem_unit" = "GB" ] && (( $(echo "$mem_value > 2.0" | bc -l 2>/dev/null || echo "0") )); then
            check_results+=('{"check": "memory_usage", "status": "WARN", "message": "High memory usage", "details": "'${memory_usage}'"}')
            log_message "WARN" "! High memory usage: $memory_usage"
            [ "$overall_status" = "HEALTHY" ] && overall_status="WARNING"
            ((warnings++))
            send_alert "MEDIUM" "High memory usage" "Memory usage: $memory_usage"
        else
            check_results+=('{"check": "memory_usage", "status": "PASS", "message": "Memory usage normal", "details": "'${memory_usage}'"}')
            log_message "INFO" "✓ Memory usage normal: $memory_usage"
        fi
    else
        check_results+=('{"check": "memory_usage", "status": "WARN", "message": "Cannot retrieve memory usage"}')
        log_message "WARN" "! Cannot retrieve memory usage"
        [ "$overall_status" = "HEALTHY" ] && overall_status="WARNING"
        ((warnings++))
    fi
    
    # Check 8: Disk Space
    local disk_usage=$(docker exec qbittorrent df -h /downloads | tail -1 | awk '{print $5}' | tr -d '%' || echo "UNKNOWN")
    if [ "$disk_usage" != "UNKNOWN" ] && [ "$disk_usage" -gt 90 ]; then
        check_results+=('{"check": "disk_space", "status": "WARN", "message": "Low disk space", "details": "'${disk_usage}'% used"}')
        log_message "WARN" "! Low disk space: ${disk_usage}% used"
        [ "$overall_status" = "HEALTHY" ] && overall_status="WARNING"
        ((warnings++))
        send_alert "MEDIUM" "Low disk space" "Downloads directory: ${disk_usage}% used"
    elif [ "$disk_usage" != "UNKNOWN" ]; then
        check_results+=('{"check": "disk_space", "status": "PASS", "message": "Disk space sufficient", "details": "'${disk_usage}'% used"}')
        log_message "INFO" "✓ Disk space sufficient: ${disk_usage}% used"
    else
        check_results+=('{"check": "disk_space", "status": "WARN", "message": "Cannot retrieve disk usage"}')
        log_message "WARN" "! Cannot retrieve disk usage"
        [ "$overall_status" = "HEALTHY" ] && overall_status="WARNING"
        ((warnings++))
    fi
    
    # Update status file
    local checks_json=$(printf '%s\n' "${check_results[@]}" | jq -s '.')
    
    cat > "$STATUS_FILE" << EOF
{
    "timestamp": "$check_timestamp",
    "overall_status": "$overall_status",
    "summary": {
        "total_checks": ${#check_results[@]},
        "errors": $errors,
        "warnings": $warnings
    },
    "checks": $checks_json
}
EOF
    
    # Update metrics file
    if [ -f "$METRICS_FILE" ]; then
        # Add to existing metrics
        jq --argjson new_metric "{
            \"timestamp\": \"$check_timestamp\",
            \"status\": \"$overall_status\",
            \"errors\": $errors,
            \"warnings\": $warnings
        }" '.metrics += [$new_metric] | .metrics = (.metrics | sort_by(.timestamp) | .[-100:])' "$METRICS_FILE" > /tmp/metrics_update.json
        mv /tmp/metrics_update.json "$METRICS_FILE"
    else
        # Create new metrics file
        cat > "$METRICS_FILE" << EOF
{
    "service": "qbittorrent",
    "created": "$check_timestamp",
    "metrics": [{
        "timestamp": "$check_timestamp",
        "status": "$overall_status",
        "errors": $errors,
        "warnings": $warnings
    }]
}
EOF
    fi
    
    log_message "INFO" "Health check completed - Status: $overall_status (Errors: $errors, Warnings: $warnings)"
    
    # Return appropriate exit code
    case "$overall_status" in
        "HEALTHY") return 0 ;;
        "WARNING") return 1 ;;
        "CRITICAL") return 2 ;;
        *) return 3 ;;
    esac
}

# Cleanup old log files
cleanup_logs() {
    local log_count=$(ls -1 "$MONITORING_DIR"/health_check_*.log 2>/dev/null | wc -l)
    if [ "$log_count" -gt "$MAX_LOG_FILES" ]; then
        local files_to_remove=$((log_count - MAX_LOG_FILES))
        ls -1t "$MONITORING_DIR"/health_check_*.log | tail -$files_to_remove | xargs rm -f
        log_message "INFO" "Cleaned up $files_to_remove old log files"
    fi
}

# Signal handlers for graceful shutdown
shutdown_handler() {
    log_message "INFO" "Received shutdown signal, exiting gracefully"
    exit 0
}

trap shutdown_handler SIGTERM SIGINT

# Main execution
echo -e "${BLUE}=== qBittorrent Health Monitoring ===${NC}"
echo "Mode: $([ "$CONTINUOUS_MODE" = true ] && echo "Continuous" || echo "Single check")"
echo "Interval: ${CHECK_INTERVAL}s"
echo "Log file: $LOG_FILE"
echo "Status file: $STATUS_FILE"
[ -n "$ALERT_WEBHOOK" ] && echo "Alert webhook: $ALERT_WEBHOOK"

log_message "INFO" "Health monitoring started"

if [ "$CONTINUOUS_MODE" = true ]; then
    echo -e "${GREEN}Starting continuous monitoring (Press Ctrl+C to stop)${NC}"
    
    while true; do
        perform_health_check
        local check_result=$?
        
        # Display current status
        case $check_result in
            0) echo -e "$(date '+%H:%M:%S') - Status: ${GREEN}HEALTHY${NC}" ;;
            1) echo -e "$(date '+%H:%M:%S') - Status: ${YELLOW}WARNING${NC}" ;;
            2) echo -e "$(date '+%H:%M:%S') - Status: ${RED}CRITICAL${NC}" ;;
            *) echo -e "$(date '+%H:%M:%S') - Status: ${RED}UNKNOWN${NC}" ;;
        esac
        
        cleanup_logs
        sleep "$CHECK_INTERVAL"
    done
else
    perform_health_check
    exit_code=$?
    
    echo -e "\nHealth check completed. Status file: $STATUS_FILE"
    echo -e "Overall status: $(jq -r '.overall_status' "$STATUS_FILE")"
    
    exit $exit_code
fi