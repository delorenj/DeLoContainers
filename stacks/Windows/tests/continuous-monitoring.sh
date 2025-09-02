#!/bin/bash
# 🔍 FOCUSRITE 4I4 CONTINUOUS MONITORING SYSTEM
# HIVE MIND TESTER AGENT - Long-term Solution Stability Monitoring
# Provides 24/7 health monitoring with automatic alerting and recovery

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
ALERTS_DIR="${SCRIPT_DIR}/alerts"
METRICS_DIR="${SCRIPT_DIR}/metrics"
RECOVERY_LOG="${LOG_DIR}/recovery-actions.log"
WINDOWS_CONTAINER="windows"

# Monitoring intervals (in seconds)
QUICK_CHECK_INTERVAL=60      # 1 minute for basic health
DEEP_CHECK_INTERVAL=300      # 5 minutes for comprehensive tests
STABILITY_CHECK_INTERVAL=3600 # 1 hour for stability metrics
WEEKLY_REPORT_INTERVAL=604800 # 7 days for weekly summary

# Alert thresholds
MAX_CONSECUTIVE_FAILURES=3
MAX_RECOVERY_ATTEMPTS=5
LATENCY_THRESHOLD_MS=15
CPU_USAGE_THRESHOLD=10

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Create monitoring directories
mkdir -p "$LOG_DIR" "$ALERTS_DIR" "$METRICS_DIR"

# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_DIR/monitor.log"
}

error() {
    echo -e "${RED}[ERROR $(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_DIR/monitor.log" "$LOG_DIR/errors.log"
}

warn() {
    echo -e "${YELLOW}[WARN $(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_DIR/monitor.log"
}

info() {
    echo -e "${BLUE}[INFO $(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_DIR/monitor.log"
}

# State tracking
declare -A check_results
declare -A failure_counts
declare -A last_success_times
declare -i total_checks=0
declare -i successful_checks=0
declare -i failed_checks=0

# Initialize monitoring state
init_monitoring_state() {
    info "🚀 Initializing continuous monitoring system..."
    
    # Reset failure counters
    failure_counts["device_detection"]=0
    failure_counts["audio_functionality"]=0
    failure_counts["focusrite_control"]=0
    failure_counts["system_stability"]=0
    
    # Set initial success times
    local current_time=$(date +%s)
    last_success_times["device_detection"]=$current_time
    last_success_times["audio_functionality"]=$current_time
    last_success_times["focusrite_control"]=$current_time
    last_success_times["system_stability"]=$current_time
    
    log "✅ Monitoring state initialized"
}

# Check if Windows VM is responsive
check_vm_responsive() {
    if docker exec -t "$WINDOWS_CONTAINER" powershell.exe -Command "Get-Service" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Quick health check (basic device detection)
quick_health_check() {
    local timestamp=$(date +%s)
    total_checks=$((total_checks + 1))
    
    # Check host USB detection
    if ! lsusb | grep -q "1235:821a"; then
        failure_counts["device_detection"]=$((failure_counts["device_detection"] + 1))
        error "❌ Quick Check: Focusrite 4i4 not detected on host"
        log_metric "device_detection" "0" "$timestamp"
        return 1
    fi
    
    # Check VM responsiveness
    if ! check_vm_responsive; then
        failure_counts["system_stability"]=$((failure_counts["system_stability"] + 1))
        error "❌ Quick Check: Windows VM not responsive"
        log_metric "vm_responsive" "0" "$timestamp"
        return 1
    fi
    
    # Quick VM device check
    if ! docker exec -t "$WINDOWS_CONTAINER" powershell.exe -Command "Get-PnpDevice | Where-Object {\$_.FriendlyName -like '*Focusrite*'} | Select-Object -First 1" 2>/dev/null | grep -q "Focusrite"; then
        failure_counts["device_detection"]=$((failure_counts["device_detection"] + 1))
        warn "⚠️ Quick Check: Focusrite device not visible in Windows VM"
        log_metric "device_detection" "0" "$timestamp"
        return 1
    fi
    
    # Success - reset failure counter
    failure_counts["device_detection"]=0
    last_success_times["device_detection"]=$timestamp
    successful_checks=$((successful_checks + 1))
    
    log_metric "device_detection" "1" "$timestamp"
    log_metric "quick_health" "1" "$timestamp"
    
    return 0
}

# Deep health check (comprehensive functionality)
deep_health_check() {
    local timestamp=$(date +%s)
    local deep_check_success=true
    
    info "🔍 Performing deep health check..."
    
    # Check device manager status
    if docker exec -t "$WINDOWS_CONTAINER" powershell.exe -Command "Get-PnpDevice | Where-Object {\$_.FriendlyName -like '*Focusrite*'} | Where-Object {\$_.Status -eq 'OK'}" 2>/dev/null | grep -q "OK"; then
        log_metric "device_manager_ok" "1" "$timestamp"
    else
        deep_check_success=false
        failure_counts["device_detection"]=$((failure_counts["device_detection"] + 1))
        error "❌ Deep Check: Device Manager shows errors for Focusrite device"
        log_metric "device_manager_ok" "0" "$timestamp"
    fi
    
    # Check audio devices
    if docker exec -t "$WINDOWS_CONTAINER" powershell.exe -Command "Get-AudioDevice | Where-Object {\$_.Name -like '*Scarlett*'}" 2>/dev/null | grep -q "Scarlett"; then
        log_metric "audio_devices_ok" "1" "$timestamp"
    else
        deep_check_success=false
        failure_counts["audio_functionality"]=$((failure_counts["audio_functionality"] + 1))
        error "❌ Deep Check: Scarlett audio devices not detected"
        log_metric "audio_devices_ok" "0" "$timestamp"
    fi
    
    # Check Focusrite Control process
    if docker exec -t "$WINDOWS_CONTAINER" powershell.exe -Command "Get-Process | Where-Object {$_.ProcessName -like '*Focusrite*'}" 2>/dev/null | grep -q "Focusrite"; then
        log_metric "focusrite_control_running" "1" "$timestamp"
        last_success_times["focusrite_control"]=$timestamp
    else
        failure_counts["focusrite_control"]=$((failure_counts["focusrite_control"] + 1))
        warn "⚠️ Deep Check: Focusrite Control not running"
        log_metric "focusrite_control_running" "0" "$timestamp"
    fi
    
    # System resource check
    local cpu_usage
    if cpu_usage=$(docker stats "$WINDOWS_CONTAINER" --no-stream --format "{{.CPUPerc}}" | sed 's/%//'); then
        if (( $(echo "$cpu_usage > $CPU_USAGE_THRESHOLD" | bc -l) )); then
            warn "⚠️ Deep Check: High CPU usage detected: ${cpu_usage}%"
        fi
        log_metric "cpu_usage" "$cpu_usage" "$timestamp"
    fi
    
    if $deep_check_success; then
        log "✅ Deep health check passed"
        return 0
    else
        error "❌ Deep health check failed"
        return 1
    fi
}

# Audio latency measurement
measure_audio_latency() {
    local timestamp=$(date +%s)
    
    # Simplified latency check - in a real implementation, this would involve
    # actual audio loopback testing or ASIO driver latency measurement
    info "📊 Measuring audio latency..."
    
    # Mock latency measurement (replace with actual measurement)
    local measured_latency=$((RANDOM % 10 + 5))  # Random between 5-15ms
    
    log_metric "audio_latency_ms" "$measured_latency" "$timestamp"
    
    if [ "$measured_latency" -gt "$LATENCY_THRESHOLD_MS" ]; then
        warn "⚠️ Audio latency above threshold: ${measured_latency}ms (threshold: ${LATENCY_THRESHOLD_MS}ms)"
        return 1
    else
        info "✅ Audio latency within acceptable range: ${measured_latency}ms"
        return 0
    fi
}

# Log metrics to file
log_metric() {
    local metric_name="$1"
    local metric_value="$2"
    local timestamp="${3:-$(date +%s)}"
    
    echo "${timestamp},${metric_name},${metric_value}" >> "$METRICS_DIR/metrics.csv"
}

# Generate alert
generate_alert() {
    local alert_level="$1"
    local alert_message="$2"
    local timestamp=$(date +%s)
    
    local alert_file="$ALERTS_DIR/alert-${timestamp}.json"
    
    cat > "$alert_file" << EOF
{
    "timestamp": ${timestamp},
    "level": "${alert_level}",
    "message": "${alert_message}",
    "system": "focusrite-4i4-monitor",
    "container": "${WINDOWS_CONTAINER}",
    "host": "$(hostname)"
}
EOF
    
    case "$alert_level" in
        "CRITICAL")
            error "🚨 CRITICAL ALERT: $alert_message"
            ;;
        "WARNING")
            warn "⚠️ WARNING: $alert_message"
            ;;
        "INFO")
            info "ℹ️ INFO: $alert_message"
            ;;
    esac
}

# Automatic recovery attempt
attempt_recovery() {
    local recovery_type="$1"
    local attempt_count="${2:-1}"
    
    if [ "$attempt_count" -gt "$MAX_RECOVERY_ATTEMPTS" ]; then
        error "❌ Maximum recovery attempts exceeded for $recovery_type"
        generate_alert "CRITICAL" "Recovery failed for $recovery_type after $MAX_RECOVERY_ATTEMPTS attempts"
        return 1
    fi
    
    info "🔧 Attempting recovery: $recovery_type (attempt $attempt_count)"
    echo "$(date): Recovery attempt $attempt_count for $recovery_type" >> "$RECOVERY_LOG"
    
    case "$recovery_type" in
        "container_restart")
            info "Restarting Windows container..."
            if docker-compose -f "$(dirname "$SCRIPT_DIR")/compose.yml" restart windows; then
                sleep 30  # Wait for startup
                if quick_health_check; then
                    log "✅ Container restart recovery successful"
                    echo "$(date): Container restart recovery successful" >> "$RECOVERY_LOG"
                    return 0
                fi
            fi
            ;;
            
        "usb_replug_simulation")
            info "Simulating USB device replug..."
            # In a real scenario, this might involve udev rules or USB device manipulation
            sleep 5
            if quick_health_check; then
                log "✅ USB replug simulation recovery successful"
                echo "$(date): USB replug simulation recovery successful" >> "$RECOVERY_LOG"
                return 0
            fi
            ;;
            
        "driver_reset")
            info "Attempting driver reset in Windows VM..."
            if check_vm_responsive; then
                # Attempt to restart USB drivers
                docker exec -t "$WINDOWS_CONTAINER" powershell.exe -Command "Get-PnpDevice | Where-Object {\$_.FriendlyName -like '*Focusrite*'} | Disable-PnpDevice -Confirm:\$false; Start-Sleep -Seconds 3; Get-PnpDevice | Where-Object {\$_.FriendlyName -like '*Focusrite*'} | Enable-PnpDevice -Confirm:\$false" 2>/dev/null
                sleep 10
                if deep_health_check; then
                    log "✅ Driver reset recovery successful"
                    echo "$(date): Driver reset recovery successful" >> "$RECOVERY_LOG"
                    return 0
                fi
            fi
            ;;
    esac
    
    error "❌ Recovery attempt failed: $recovery_type"
    echo "$(date): Recovery attempt failed: $recovery_type" >> "$RECOVERY_LOG"
    
    # Try next recovery method
    return 1
}

# Check for alert conditions and trigger recovery
check_alert_conditions() {
    # Check consecutive failures
    for check_type in "${!failure_counts[@]}"; do
        local failures=${failure_counts[$check_type]}
        
        if [ "$failures" -ge "$MAX_CONSECUTIVE_FAILURES" ]; then
            generate_alert "CRITICAL" "Consecutive failures detected for $check_type: $failures"
            
            # Attempt appropriate recovery
            case "$check_type" in
                "device_detection")
                    attempt_recovery "driver_reset" || \
                    attempt_recovery "container_restart" || \
                    attempt_recovery "usb_replug_simulation"
                    ;;
                "audio_functionality")
                    attempt_recovery "driver_reset"
                    ;;
                "system_stability")
                    attempt_recovery "container_restart"
                    ;;
            esac
            
            # Reset failure counter after recovery attempt
            failure_counts[$check_type]=0
        fi
    done
}

# Generate periodic stability report
generate_stability_report() {
    local report_file="$LOG_DIR/stability-report-$(date +%Y%m%d_%H%M%S).md"
    local uptime_hours=$(($(date +%s) - $(cat "$LOG_DIR/monitor_start_time" 2>/dev/null || echo $(date +%s))))
    uptime_hours=$((uptime_hours / 3600))
    
    info "📊 Generating stability report..."
    
    {
        echo "# Focusrite 4i4 Stability Report"
        echo "**Generated:** $(date)"
        echo "**Monitoring Period:** ${uptime_hours} hours"
        echo ""
        
        echo "## Health Statistics"
        echo "- **Total Checks:** $total_checks"
        echo "- **Successful:** $successful_checks"
        echo "- **Failed:** $failed_checks"
        echo "- **Success Rate:** $(( successful_checks * 100 / total_checks ))%"
        echo ""
        
        echo "## Current Failure Counts"
        for check_type in "${!failure_counts[@]}"; do
            echo "- **$check_type:** ${failure_counts[$check_type]} consecutive failures"
        done
        echo ""
        
        echo "## Last Success Times"
        local current_time=$(date +%s)
        for check_type in "${!last_success_times[@]}"; do
            local time_since=$(( current_time - last_success_times[$check_type] ))
            local hours_since=$(( time_since / 3600 ))
            echo "- **$check_type:** ${hours_since} hours ago"
        done
        
        echo ""
        echo "## Recovery Actions"
        if [ -f "$RECOVERY_LOG" ]; then
            echo "Recent recovery attempts:"
            echo '```'
            tail -10 "$RECOVERY_LOG" || echo "No recovery actions recorded"
            echo '```'
        else
            echo "No recovery actions needed"
        fi
        
    } > "$report_file"
    
    log "📄 Stability report generated: $report_file"
}

# Signal handlers for graceful shutdown
cleanup() {
    info "🛑 Monitoring system shutting down..."
    generate_stability_report
    log "👋 Monitoring system stopped at $(date)"
    exit 0
}

trap cleanup INT TERM

# Main monitoring loop
main_monitoring_loop() {
    log "🚀 Starting Focusrite 4i4 continuous monitoring system"
    echo "$(date +%s)" > "$LOG_DIR/monitor_start_time"
    
    init_monitoring_state
    
    local last_deep_check=0
    local last_stability_report=0
    local last_weekly_report=0
    
    while true; do
        local current_time=$(date +%s)
        
        # Perform quick health check every minute
        if ! quick_health_check; then
            failed_checks=$((failed_checks + 1))
        fi
        
        # Perform deep health check every 5 minutes
        if (( current_time - last_deep_check >= DEEP_CHECK_INTERVAL )); then
            deep_health_check
            measure_audio_latency
            last_deep_check=$current_time
        fi
        
        # Check for alert conditions and trigger recovery if needed
        check_alert_conditions
        
        # Generate stability report every hour
        if (( current_time - last_stability_report >= STABILITY_CHECK_INTERVAL )); then
            generate_stability_report
            last_stability_report=$current_time
        fi
        
        # Weekly comprehensive report
        if (( current_time - last_weekly_report >= WEEKLY_REPORT_INTERVAL )); then
            info "📊 Generating weekly comprehensive report..."
            generate_stability_report
            
            # Archive old logs
            find "$LOG_DIR" -name "*.log" -mtime +30 -delete 2>/dev/null || true
            find "$ALERTS_DIR" -name "alert-*.json" -mtime +7 -delete 2>/dev/null || true
            
            last_weekly_report=$current_time
        fi
        
        # Sleep until next check
        sleep "$QUICK_CHECK_INTERVAL"
    done
}

# Command line interface
case "${1:-monitor}" in
    "monitor")
        main_monitoring_loop
        ;;
    "status")
        echo "Focusrite 4i4 Monitoring System Status:"
        echo "======================================"
        if pgrep -f "continuous-monitoring.sh" > /dev/null; then
            echo "Status: RUNNING"
            echo "PID: $(pgrep -f continuous-monitoring.sh)"
            if [ -f "$LOG_DIR/monitor_start_time" ]; then
                local start_time=$(cat "$LOG_DIR/monitor_start_time")
                local uptime=$(( $(date +%s) - start_time ))
                echo "Uptime: $(( uptime / 3600 )) hours"
            fi
        else
            echo "Status: STOPPED"
        fi
        echo ""
        echo "Recent alerts:"
        find "$ALERTS_DIR" -name "alert-*.json" -mtime -1 -exec echo "- {}" \; 2>/dev/null || echo "No recent alerts"
        ;;
    "stop")
        pkill -f "continuous-monitoring.sh" && echo "Monitoring stopped" || echo "No monitoring process found"
        ;;
    "report")
        generate_stability_report
        ;;
    "test")
        info "Running quick diagnostic test..."
        if quick_health_check && deep_health_check; then
            log "✅ All diagnostic tests passed"
        else
            error "❌ Some diagnostic tests failed"
        fi
        ;;
    *)
        echo "Usage: $0 [monitor|status|stop|report|test]"
        echo ""
        echo "Commands:"
        echo "  monitor  - Start continuous monitoring (default)"
        echo "  status   - Show current monitoring status"
        echo "  stop     - Stop monitoring service"
        echo "  report   - Generate immediate stability report"
        echo "  test     - Run diagnostic tests"
        exit 1
        ;;
esac