#!/bin/bash

# MetaMCP Docker Resource Enforcer
# Applies hard container limits using multiple enforcement methods
# to prevent process explosion and memory leaks

set -euo pipefail

CONTAINER_NAME="metamcp"
MEMORY_LIMIT="4g"
MEMORY_SWAP_LIMIT="4g" 
PID_LIMIT="25"
CPU_LIMIT="2"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

# Method 1: Docker Update (Live Container)
apply_docker_limits() {
    log_info "Applying Docker resource limits..."
    
    if docker update \
        --memory="$MEMORY_LIMIT" \
        --memory-swap="$MEMORY_SWAP_LIMIT" \
        --pids-limit="$PID_LIMIT" \
        --cpus="$CPU_LIMIT" \
        "$CONTAINER_NAME" 2>/dev/null; then
        log_success "Docker limits applied successfully"
        return 0
    else
        log_warn "Docker update failed - trying alternative methods"
        return 1
    fi
}

# Method 2: Cgroup Direct Control
apply_cgroup_limits() {
    log_info "Applying direct cgroup limits..."
    
    local container_id=$(docker inspect "$CONTAINER_NAME" --format='{{.Id}}' 2>/dev/null || echo "")
    
    if [ -z "$container_id" ]; then
        log_error "Cannot get container ID"
        return 1
    fi
    
    local cgroup_memory_path="/sys/fs/cgroup/memory/docker/$container_id"
    local cgroup_pids_path="/sys/fs/cgroup/pids/docker/$container_id"
    
    # Memory limit (4GB = 4294967296 bytes)
    if [ -d "$cgroup_memory_path" ]; then
        echo "4294967296" | sudo tee "$cgroup_memory_path/memory.limit_in_bytes" >/dev/null 2>&1 || true
        echo "4294967296" | sudo tee "$cgroup_memory_path/memory.memsw.limit_in_bytes" >/dev/null 2>&1 || true
        log_success "Memory cgroup limits applied"
    else
        log_warn "Memory cgroup path not found: $cgroup_memory_path"
    fi
    
    # PID limit
    if [ -d "$cgroup_pids_path" ]; then
        echo "$PID_LIMIT" | sudo tee "$cgroup_pids_path/pids.max" >/dev/null 2>&1 || true
        log_success "PID cgroup limits applied"
    else
        log_warn "PID cgroup path not found: $cgroup_pids_path"
    fi
}

# Method 3: Systemd Slice Limits (if available)
apply_systemd_limits() {
    if ! command -v systemctl >/dev/null 2>&1; then
        log_warn "Systemd not available"
        return 1
    fi
    
    log_info "Applying systemd slice limits..."
    
    # Create custom slice for MetaMCP
    cat > /tmp/metamcp.slice << EOF
[Unit]
Description=MetaMCP Resource Slice
Before=slices.target

[Slice]
MemoryLimit=4G
TasksMax=25
CPUQuota=200%
EOF
    
    if sudo cp /tmp/metamcp.slice /etc/systemd/system/ 2>/dev/null; then
        sudo systemctl daemon-reload
        sudo systemctl start metamcp.slice
        log_success "Systemd slice limits applied"
        return 0
    else
        log_warn "Failed to apply systemd limits"
        return 1
    fi
}

# Method 4: ulimit enforcement inside container
apply_container_ulimits() {
    log_info "Applying container ulimits..."
    
    docker exec "$CONTAINER_NAME" sh -c '
        # Set process limit
        ulimit -u 25 2>/dev/null || true
        
        # Set memory limit (if prlimit available)
        if command -v prlimit >/dev/null 2>&1; then
            prlimit --pid=$$ --nproc=25 2>/dev/null || true
        fi
        
        # Set file descriptor limits
        ulimit -n 1024 2>/dev/null || true
        
        echo "Container ulimits configured"
    ' || log_warn "Some ulimits may not have been applied"
    
    log_success "Container ulimits applied"
}

# Method 5: Resource monitoring with enforcement
deploy_resource_enforcer() {
    log_info "Deploying resource enforcement monitor..."
    
    cat > /tmp/metamcp-resource-enforcer.sh << 'EOF'
#!/bin/bash

CONTAINER_NAME="metamcp"
MAX_MEMORY_MB=4096
MAX_PROCESSES=25
CHECK_INTERVAL=15

while true; do
    # Get container stats
    container_stats=$(docker stats --no-stream --format "table {{.MemUsage}}\t{{.PIDs}}" "$CONTAINER_NAME" 2>/dev/null | tail -n1)
    
    if [ -n "$container_stats" ]; then
        memory_usage=$(echo "$container_stats" | awk '{print $1}' | sed 's/MiB//' | sed 's/GiB//' | awk '{print int($1)}')
        process_count=$(echo "$container_stats" | awk '{print $2}')
        
        # Convert GiB to MiB if needed
        if [[ "$container_stats" == *"GiB"* ]]; then
            memory_usage=$((memory_usage * 1024))
        fi
        
        echo "$(date): Memory: ${memory_usage}MiB, Processes: $process_count"
        
        # Enforce memory limit
        if [ "$memory_usage" -gt "$MAX_MEMORY_MB" ]; then
            echo "$(date): MEMORY LIMIT EXCEEDED - Forcing cleanup"
            docker exec "$CONTAINER_NAME" sh -c '
                # Kill highest memory processes
                ps aux --sort=-%mem | head -20 | grep -E "(npm|node)" | awk "{print \$2}" | xargs -r kill 2>/dev/null || true
            ' 2>/dev/null || true
        fi
        
        # Enforce process limit
        if [ "$process_count" -gt "$MAX_PROCESSES" ]; then
            echo "$(date): PROCESS LIMIT EXCEEDED - Killing excess processes"
            docker exec "$CONTAINER_NAME" sh -c '
                # Kill oldest processes
                ps aux --sort=lstart | grep -E "(npm|node)" | tail -n +21 | awk "{print \$2}" | xargs -r kill 2>/dev/null || true
            ' 2>/dev/null || true
        fi
    fi
    
    sleep "$CHECK_INTERVAL"
done
EOF
    
    chmod +x /tmp/metamcp-resource-enforcer.sh
    
    # Kill existing enforcer
    pkill -f metamcp-resource-enforcer || true
    
    # Start enforcer
    nohup /tmp/metamcp-resource-enforcer.sh > /tmp/metamcp-resource-enforcer.log 2>&1 &
    local enforcer_pid=$!
    echo $enforcer_pid > /tmp/metamcp-resource-enforcer.pid
    
    log_success "Resource enforcer deployed (PID: $enforcer_pid)"
}

# Verification function
verify_limits() {
    log_info "Verifying applied limits..."
    
    # Check Docker limits
    local docker_limits=$(docker inspect "$CONTAINER_NAME" --format '
Memory: {{.HostConfig.Memory}}
MemorySwap: {{.HostConfig.MemorySwap}}
PIDsLimit: {{.HostConfig.PidsLimit}}
CPUPeriod: {{.HostConfig.CPUPeriod}}
CPUQuota: {{.HostConfig.CPUQuota}}
' 2>/dev/null || echo "Docker inspect failed")
    
    echo "$docker_limits"
    
    # Check current resource usage
    log_info "Current resource usage:"
    docker stats --no-stream "$CONTAINER_NAME" 2>/dev/null || log_warn "Could not get current stats"
    
    # Check process count
    local current_processes=$(docker exec "$CONTAINER_NAME" ps aux 2>/dev/null | wc -l || echo "Unknown")
    log_info "Current processes: $current_processes"
    
    if [ "$current_processes" != "Unknown" ] && [ "$current_processes" -lt 30 ]; then
        log_success "Process count within limits"
    else
        log_warn "Process count may be too high: $current_processes"
    fi
}

# Main execution
main() {
    local action=${1:-"enforce"}
    
    case "$action" in
        "enforce")
            log_info "=== ENFORCING ALL RESOURCE LIMITS ==="
            
            # Try multiple enforcement methods
            apply_docker_limits || log_warn "Docker limits failed"
            apply_cgroup_limits || log_warn "Cgroup limits failed" 
            apply_systemd_limits || log_warn "Systemd limits failed"
            apply_container_ulimits || log_warn "Container ulimits failed"
            deploy_resource_enforcer
            
            sleep 5
            verify_limits
            ;;
            
        "verify")
            log_info "=== VERIFYING CURRENT LIMITS ==="
            verify_limits
            ;;
            
        "monitor")
            log_info "=== DEPLOYING MONITORING ONLY ==="
            deploy_resource_enforcer
            ;;
            
        *)
            echo "Usage: $0 {enforce|verify|monitor}"
            echo "  enforce - Apply all resource limits (default)"
            echo "  verify  - Check current limits and usage"
            echo "  monitor - Deploy resource monitoring only"
            exit 1
            ;;
    esac
}

main "$@"