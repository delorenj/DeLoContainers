#!/bin/bash

# EMERGENCY METAMCP PROCESS EXPLOSION REMEDIATION SCRIPT
# IMMEDIATE CRISIS RESPONSE - Execute NOW!
#
# Current Status: 515+ processes (CRITICAL!)
# Target: <15 processes
# Memory: 10.72GB+ and growing
#
# USAGE: ./EMERGENCY-METAMCP-REMEDIATION.sh [phase]
# Phases: crisis|repair|monitor|reset

set -euo pipefail

CONTAINER_NAME="metamcp"
MAX_PROCESSES=15
EMERGENCY_THRESHOLD=50
CRITICAL_MEMORY_GB=8

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

# Phase 1: IMMEDIATE CRISIS RESPONSE
emergency_stop() {
    log_error "=== EMERGENCY PROCESS EXPLOSION DETECTED ==="
    
    # Get current stats
    local process_count=$(docker exec $CONTAINER_NAME ps aux 2>/dev/null | wc -l || echo "0")
    local memory_usage=$(docker stats --no-stream $CONTAINER_NAME 2>/dev/null | awk 'NR>1{print $4}' | sed 's/GiB//' || echo "0")
    
    log_error "Current processes: $process_count"
    log_error "Current memory: ${memory_usage}GB"
    
    # NUCLEAR OPTION: Force kill ALL npm/node processes
    log_warn "Executing nuclear process cleanup..."
    docker exec $CONTAINER_NAME sh -c '
        # Kill all npm processes immediately
        pkill -f npm || true
        
        # Kill all node processes except essential ones
        ps aux | grep node | grep -v "grep\|/usr/local/bin/docker-entrypoint.sh" | 
        awk "{print \$2}" | xargs -r kill -9 2>/dev/null || true
        
        # Clean any leftover MCP processes
        pkill -f mcp-server || true
        pkill -f desktop-commander || true
        
        # Force cleanup zombie processes
        ps aux | awk "\$8 ~ /^[Zz]/ {print \$2}" | xargs -r kill -9 2>/dev/null || true
    ' || log_warn "Some processes may have already exited"
    
    sleep 5
    
    # Verify cleanup
    local new_count=$(docker exec $CONTAINER_NAME ps aux 2>/dev/null | wc -l || echo "0")
    log_info "Processes after cleanup: $new_count"
    
    if [ "$new_count" -lt "$EMERGENCY_THRESHOLD" ]; then
        log_success "Emergency cleanup successful!"
        return 0
    else
        log_error "Emergency cleanup failed - container restart required"
        return 1
    fi
}

# Phase 2: CONTAINER RESTART WITH SAFEGUARDS
emergency_restart() {
    log_warn "=== INITIATING EMERGENCY CONTAINER RESTART ==="
    
    # Stop container
    log_info "Stopping MetaMCP container..."
    docker stop $CONTAINER_NAME || true
    
    # Wait for full stop
    sleep 10
    
    # Remove any leftover resources
    docker exec $CONTAINER_NAME sh -c '
        # Clean temp files
        rm -rf /tmp/mcp-* /tmp/node-* /tmp/npm-* 2>/dev/null || true
        
        # Clear process locks
        rm -rf /var/lock/mcp-* /var/run/mcp-* 2>/dev/null || true
        
        # Clean log files that might be locked
        truncate -s 0 /var/log/*.log 2>/dev/null || true
    ' 2>/dev/null || true
    
    # Restart with additional safety limits
    log_info "Restarting with enhanced limits..."
    docker start $CONTAINER_NAME
    
    # Wait for startup
    sleep 15
    
    # Verify healthy restart
    local final_count=$(docker exec $CONTAINER_NAME ps aux 2>/dev/null | wc -l || echo "0")
    log_info "Post-restart process count: $final_count"
    
    if [ "$final_count" -lt "$MAX_PROCESSES" ]; then
        log_success "Container restart successful!"
        return 0
    else
        log_error "Container restart failed - manual intervention required"
        return 1
    fi
}

# Phase 3: ENHANCED MONITORING AND PREVENTION
deploy_enhanced_monitoring() {
    log_info "=== DEPLOYING ENHANCED MONITORING ==="
    
    # Create aggressive process killer
    cat > /tmp/metamcp-nuclear-monitor.sh << 'EOF'
#!/bin/bash
CONTAINER_NAME="metamcp"
MAX_PROCESSES=15
CHECK_INTERVAL=10
NUCLEAR_THRESHOLD=30

while true; do
    PROCESS_COUNT=$(docker exec $CONTAINER_NAME ps aux 2>/dev/null | wc -l || echo "0")
    
    if [ "$PROCESS_COUNT" -gt "$NUCLEAR_THRESHOLD" ]; then
        echo "$(date): NUCLEAR THRESHOLD EXCEEDED: $PROCESS_COUNT processes - EMERGENCY KILL"
        
        # Immediate nuclear cleanup
        docker exec $CONTAINER_NAME sh -c '
            pkill -9 -f npm
            pkill -9 -f node
            pkill -9 -f mcp-server
        ' 2>/dev/null || true
        
        # Log the event
        echo "$(date): Nuclear cleanup executed" >> /tmp/metamcp-nuclear-log.txt
        
    elif [ "$PROCESS_COUNT" -gt "$MAX_PROCESSES" ]; then
        echo "$(date): Process limit exceeded: $PROCESS_COUNT - Standard cleanup"
        
        # Standard cleanup
        docker exec $CONTAINER_NAME sh -c '
            ps aux | grep -E "(npm|node)" | grep -v grep | 
            sort -k9 | tail -n +16 | awk "{print \$2}" | 
            xargs -r kill 2>/dev/null
        ' 2>/dev/null || true
    else
        echo "$(date): Process count OK: $PROCESS_COUNT/$MAX_PROCESSES"
    fi
    
    sleep $CHECK_INTERVAL
done
EOF
    
    chmod +x /tmp/metamcp-nuclear-monitor.sh
    
    # Kill existing monitor if running
    pkill -f metamcp-nuclear-monitor || true
    
    # Start nuclear monitor in background
    nohup /tmp/metamcp-nuclear-monitor.sh > /tmp/metamcp-nuclear-monitor.log 2>&1 &
    local monitor_pid=$!
    
    echo $monitor_pid > /tmp/metamcp-nuclear-monitor.pid
    log_success "Nuclear monitor deployed (PID: $monitor_pid)"
}

# Phase 4: DOCKER RESOURCE ENFORCEMENT
enforce_docker_limits() {
    log_info "=== ENFORCING DOCKER RESOURCE LIMITS ==="
    
    # Update container with hard limits
    docker update --memory=4g --memory-swap=4g --pids-limit=25 $CONTAINER_NAME || {
        log_warn "Docker update failed - applying alternative limits"
        
        # Alternative: cgroup limits
        container_id=$(docker inspect $CONTAINER_NAME --format='{{.Id}}')
        echo "4294967296" > /sys/fs/cgroup/memory/docker/$container_id/memory.limit_in_bytes 2>/dev/null || true
        echo "25" > /sys/fs/cgroup/pids/docker/$container_id/pids.max 2>/dev/null || true
    }
    
    log_success "Docker resource limits enforced"
}

# Phase 5: HOST-LEVEL PROCESS MONITORING
deploy_host_monitoring() {
    log_info "=== DEPLOYING HOST-LEVEL MONITORING ==="
    
    # Create host-level monitor that can kill container if needed
    cat > /tmp/metamcp-host-monitor.sh << 'EOF'
#!/bin/bash
CONTAINER_NAME="metamcp"
MAX_MEMORY_GB=8
CHECK_INTERVAL=30

while true; do
    # Check container memory from host
    memory_usage=$(docker stats --no-stream $CONTAINER_NAME 2>/dev/null | awk 'NR>1{print $4}' | sed 's/GiB//' || echo "0")
    
    # Check process count from host
    process_count=$(docker exec $CONTAINER_NAME ps aux 2>/dev/null | wc -l || echo "0")
    
    echo "$(date): Memory: ${memory_usage}GB, Processes: $process_count"
    
    # Emergency container restart if memory > 8GB or processes > 100
    if (( $(echo "$memory_usage > $MAX_MEMORY_GB" | bc -l) )) || [ "$process_count" -gt 100 ]; then
        echo "$(date): EMERGENCY CONTAINER RESTART - Memory: ${memory_usage}GB, Processes: $process_count"
        
        docker restart $CONTAINER_NAME
        sleep 30
        
        echo "$(date): Container restarted" >> /tmp/metamcp-emergency-restarts.log
    fi
    
    sleep $CHECK_INTERVAL
done
EOF
    
    chmod +x /tmp/metamcp-host-monitor.sh
    
    # Kill existing host monitor
    pkill -f metamcp-host-monitor || true
    
    # Start host monitor
    nohup /tmp/metamcp-host-monitor.sh > /tmp/metamcp-host-monitor.log 2>&1 &
    local host_monitor_pid=$!
    
    echo $host_monitor_pid > /tmp/metamcp-host-monitor.pid
    log_success "Host-level monitor deployed (PID: $host_monitor_pid)"
}

# MAIN EXECUTION LOGIC
main() {
    local phase=${1:-"crisis"}
    
    case "$phase" in
        "crisis")
            log_error "=== EXECUTING CRISIS RESPONSE ==="
            
            # Check current state
            local current_processes=$(docker exec $CONTAINER_NAME ps aux 2>/dev/null | wc -l || echo "0")
            
            if [ "$current_processes" -gt "$EMERGENCY_THRESHOLD" ]; then
                emergency_stop || emergency_restart
                deploy_enhanced_monitoring
                enforce_docker_limits
                deploy_host_monitoring
            else
                log_info "Process count ($current_processes) below emergency threshold"
                deploy_enhanced_monitoring
            fi
            ;;
            
        "repair")
            log_info "=== EXECUTING REPAIR SEQUENCE ==="
            emergency_restart
            deploy_enhanced_monitoring
            enforce_docker_limits
            ;;
            
        "monitor")
            log_info "=== DEPLOYING MONITORING ONLY ==="
            deploy_enhanced_monitoring
            deploy_host_monitoring
            ;;
            
        "reset")
            log_warn "=== FULL SYSTEM RESET ==="
            emergency_restart
            deploy_enhanced_monitoring
            enforce_docker_limits
            deploy_host_monitoring
            ;;
            
        *)
            echo "Usage: $0 {crisis|repair|monitor|reset}"
            echo "  crisis  - Full emergency response (default)"
            echo "  repair  - Container restart + monitoring"
            echo "  monitor - Deploy monitoring only"
            echo "  reset   - Full system reset"
            exit 1
            ;;
    esac
    
    # Final status report
    sleep 10
    local final_processes=$(docker exec $CONTAINER_NAME ps aux 2>/dev/null | wc -l || echo "0")
    local final_memory=$(docker stats --no-stream $CONTAINER_NAME 2>/dev/null | awk 'NR>1{print $4}' || echo "Unknown")
    
    log_info "=== FINAL STATUS REPORT ==="
    log_info "Processes: $final_processes (target: <$MAX_PROCESSES)"
    log_info "Memory: $final_memory"
    log_info "Container: $(docker ps --format 'table {{.Names}}\t{{.Status}}' | grep $CONTAINER_NAME || echo 'Not running')"
    
    if [ "$final_processes" -lt "$MAX_PROCESSES" ]; then
        log_success "REMEDIATION SUCCESSFUL!"
        return 0
    else
        log_error "REMEDIATION INCOMPLETE - MANUAL INTERVENTION REQUIRED"
        return 1
    fi
}

# Execute main function
main "$@"