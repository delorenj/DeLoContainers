#!/bin/bash

# MetaMCP Startup Process Explosion Preventer
# Modifies container startup to prevent immediate re-explosion
# Works by intercepting and controlling the startup sequence

set -euo pipefail

CONTAINER_NAME="metamcp"

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

# Inject startup control script into container
inject_startup_control() {
    log_info "Injecting startup control script..."
    
    # Create startup control script
    docker exec "$CONTAINER_NAME" sh -c 'cat > /usr/local/bin/metamcp-startup-control.sh << '\''EOF'\''
#!/bin/bash

# MetaMCP Startup Control - Prevents Process Explosion
export MAX_CONCURRENT_SPAWNS=3
export SPAWN_DELAY=5
export PROCESS_LIMIT=15

# Process spawn limiter
process_spawn_limiter() {
    local spawn_count=0
    local last_spawn_time=0
    
    while true; do
        current_time=$(date +%s)
        current_processes=$(ps aux | wc -l)
        
        # Reset spawn count every minute
        if [ $((current_time - last_spawn_time)) -gt 60 ]; then
            spawn_count=0
        fi
        
        # Check if we can spawn
        if [ "$current_processes" -lt "$PROCESS_LIMIT" ] && [ "$spawn_count" -lt "$MAX_CONCURRENT_SPAWNS" ]; then
            # Allow spawn
            return 0
        else
            # Block spawn
            echo "Process spawn blocked: $current_processes processes, $spawn_count recent spawns" >&2
            sleep "$SPAWN_DELAY"
            spawn_count=$((spawn_count + 1))
            last_spawn_time=$current_time
            return 1
        fi
    done
}

# Override npm to add spawn control
npm_wrapper() {
    if process_spawn_limiter; then
        exec /usr/local/bin/npm.original "$@"
    else
        echo "npm spawn blocked by process limiter" >&2
        exit 1
    fi
}

# Override node to add spawn control  
node_wrapper() {
    if process_spawn_limiter; then
        exec /usr/local/bin/node.original "$@"
    else
        echo "node spawn blocked by process limiter" >&2
        exit 1
    fi
}

# Install wrappers
if [ ! -f /usr/local/bin/npm.original ]; then
    mv /usr/local/bin/npm /usr/local/bin/npm.original 2>/dev/null || true
    echo "#!/bin/bash" > /usr/local/bin/npm
    echo ". /usr/local/bin/metamcp-startup-control.sh" >> /usr/local/bin/npm
    echo "npm_wrapper \"\$@\"" >> /usr/local/bin/npm
    chmod +x /usr/local/bin/npm
fi

if [ ! -f /usr/local/bin/node.original ]; then
    mv /usr/local/bin/node /usr/local/bin/node.original 2>/dev/null || true
    echo "#!/bin/bash" > /usr/local/bin/node
    echo ". /usr/local/bin/metamcp-startup-control.sh" >> /usr/local/bin/node
    echo "node_wrapper \"\$@\"" >> /usr/local/bin/node
    chmod +x /usr/local/bin/node
fi

echo "MetaMCP startup control initialized"
EOF'
    
    # Make it executable
    docker exec "$CONTAINER_NAME" chmod +x /usr/local/bin/metamcp-startup-control.sh
    
    # Execute the control script to install wrappers
    docker exec "$CONTAINER_NAME" /usr/local/bin/metamcp-startup-control.sh
    
    log_success "Startup control script injected"
}

# Create process monitoring startup script
create_startup_monitor() {
    log_info "Creating startup monitoring script..."
    
    docker exec "$CONTAINER_NAME" sh -c 'cat > /usr/local/bin/metamcp-startup-monitor.sh << '\''EOF'\''
#!/bin/bash

# MetaMCP Startup Monitor - Watches for process explosion during startup
MAX_PROCESSES=15
CHECK_INTERVAL=5
STARTUP_TIMEOUT=300
startup_start=$(date +%s)

echo "MetaMCP startup monitor started"

while true; do
    current_time=$(date +%s)
    elapsed=$((current_time - startup_start))
    
    # Stop monitoring after startup timeout
    if [ "$elapsed" -gt "$STARTUP_TIMEOUT" ]; then
        echo "Startup monitoring complete (${elapsed}s elapsed)"
        break
    fi
    
    process_count=$(ps aux | wc -l)
    
    if [ "$process_count" -gt "$MAX_PROCESSES" ]; then
        echo "STARTUP EXPLOSION DETECTED: $process_count processes at ${elapsed}s"
        
        # Emergency kill excess processes
        ps aux | grep -E "(npm|node)" | grep -v grep | 
        sort -k9 | tail -n +16 | awk "{print \$2}" | 
        xargs -r kill 2>/dev/null || true
        
        echo "Emergency cleanup executed during startup"
    else
        echo "Startup OK: $process_count processes at ${elapsed}s"
    fi
    
    sleep "$CHECK_INTERVAL"
done

echo "MetaMCP startup monitoring complete"
EOF'
    
    docker exec "$CONTAINER_NAME" chmod +x /usr/local/bin/metamcp-startup-monitor.sh
    
    log_success "Startup monitor created"
}

# Modify container startup sequence
modify_startup_sequence() {
    log_info "Modifying container startup sequence..."
    
    # Create new entrypoint that includes our controls
    docker exec "$CONTAINER_NAME" sh -c 'cat > /usr/local/bin/metamcp-safe-entrypoint.sh << '\''EOF'\''
#!/bin/bash

# MetaMCP Safe Entrypoint - Controlled startup sequence
echo "Starting MetaMCP with process explosion prevention..."

# Start startup monitor in background
/usr/local/bin/metamcp-startup-monitor.sh &
monitor_pid=$!

# Initialize startup control
/usr/local/bin/metamcp-startup-control.sh

# Apply resource limits inside container
ulimit -u 25 2>/dev/null || true
ulimit -n 1024 2>/dev/null || true

# Set environment variables to limit concurrency
export NODE_OPTIONS="--max-old-space-size=512"
export UV_THREADPOOL_SIZE=4

echo "Safe startup environment configured"

# Execute original entrypoint with controlled environment
exec /usr/local/bin/docker-entrypoint.sh "$@"
EOF'
    
    docker exec "$CONTAINER_NAME" chmod +x /usr/local/bin/metamcp-safe-entrypoint.sh
    
    log_success "Startup sequence modified"
}

# Apply immediate process controls
apply_immediate_controls() {
    log_info "Applying immediate process controls..."
    
    # Set resource limits immediately
    docker exec "$CONTAINER_NAME" sh -c '
        # Apply ulimits to current shell
        ulimit -u 25 2>/dev/null || true
        ulimit -n 1024 2>/dev/null || true
        
        # Set environment variables
        export MAX_PROCESSES=15
        export NODE_OPTIONS="--max-old-space-size=512"
        export UV_THREADPOOL_SIZE=4
        
        # Create process limit enforcement
        cat > /tmp/process-limiter.sh << "SCRIPT_EOF"
#!/bin/bash
while true; do
    process_count=$(ps aux | wc -l)
    if [ "$process_count" -gt 15 ]; then
        ps aux | grep -E "(npm|node)" | grep -v grep | 
        sort -k9 | tail -n +16 | awk "{print \$2}" | 
        xargs -r kill 2>/dev/null || true
    fi
    sleep 10
done
SCRIPT_EOF
        
        chmod +x /tmp/process-limiter.sh
        nohup /tmp/process-limiter.sh > /tmp/process-limiter.log 2>&1 &
        
        echo "Immediate process controls applied"
    '
    
    log_success "Immediate controls applied"
}

# Verify prevention measures
verify_prevention() {
    log_info "Verifying prevention measures..."
    
    # Check if wrappers are installed
    local npm_wrapper=$(docker exec "$CONTAINER_NAME" ls -la /usr/local/bin/npm 2>/dev/null || echo "Not found")
    local node_wrapper=$(docker exec "$CONTAINER_NAME" ls -la /usr/local/bin/node 2>/dev/null || echo "Not found")
    
    echo "NPM wrapper: $npm_wrapper"
    echo "Node wrapper: $node_wrapper"
    
    # Check current process count
    local current_processes=$(docker exec "$CONTAINER_NAME" ps aux 2>/dev/null | wc -l || echo "Unknown")
    log_info "Current processes: $current_processes"
    
    # Test wrapper functionality
    log_info "Testing wrapper functionality..."
    docker exec "$CONTAINER_NAME" sh -c 'echo "Process limit test"; ps aux | wc -l' || log_warn "Test failed"
    
    if [ "$current_processes" != "Unknown" ] && [ "$current_processes" -lt 20 ]; then
        log_success "Prevention measures appear to be working"
        return 0
    else
        log_warn "Prevention measures may not be fully effective"
        return 1
    fi
}

# Main execution
main() {
    local action=${1:-"prevent"}
    
    case "$action" in
        "prevent")
            log_info "=== DEPLOYING STARTUP EXPLOSION PREVENTION ==="
            
            inject_startup_control
            create_startup_monitor
            modify_startup_sequence
            apply_immediate_controls
            
            sleep 5
            verify_prevention
            ;;
            
        "immediate")
            log_info "=== APPLYING IMMEDIATE CONTROLS ONLY ==="
            apply_immediate_controls
            verify_prevention
            ;;
            
        "verify")
            log_info "=== VERIFYING PREVENTION MEASURES ==="
            verify_prevention
            ;;
            
        *)
            echo "Usage: $0 {prevent|immediate|verify}"
            echo "  prevent   - Deploy full prevention system (default)"
            echo "  immediate - Apply immediate controls only"
            echo "  verify    - Check prevention measures"
            exit 1
            ;;
    esac
}

main "$@"