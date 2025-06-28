#!/bin/bash
# Simple health status report for each compose.yml file in the stacks directory

DOCKER_ROOT="/home/delorenj/docker"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Docker Stack Health Report ==="
echo "Generated: $(date)"
echo ""

# Function to check stack health
check_stack_health() {
    local compose_file="$1"
    local stack_name="$2"
    
    if [ ! -f "$compose_file" ]; then
        echo "❌ $stack_name - Compose file not found"
        return
    fi
    
    cd "$(dirname "$compose_file")"
    
    # Get container status
    containers=$(docker compose ps --format "table {{.Name}}\t{{.State}}\t{{.Status}}" 2>/dev/null)
    
    if [ $? -ne 0 ] || [ -z "$containers" ]; then
        echo "🔴 $stack_name - No containers or error"
        return
    fi
    
    # Count running vs total
    total=$(echo "$containers" | tail -n +2 | wc -l)
    running=$(echo "$containers" | grep -c "running" || echo "0")
    
    if [ "$running" -eq "$total" ] && [ "$total" -gt 0 ]; then
        echo "🟢 $stack_name - All $total containers running"
    elif [ "$running" -gt 0 ]; then
        echo "🟡 $stack_name - $running/$total containers running"
    else
        echo "🔴 $stack_name - No containers running"
    fi
    
    # Show container details
    echo "$containers" | tail -n +2 | while read line; do
        echo "   $line"
    done
    echo ""
}

# Check core services
echo "=== Core Services ==="
check_stack_health "$DOCKER_ROOT/core/traefik/compose.yml" "Traefik"

# Check AI stack
echo "=== AI Stack ==="
for compose_file in "$DOCKER_ROOT"/stacks/ai/*/compose.yml "$DOCKER_ROOT"/stacks/ai/*/docker-compose.yml; do
    if [ -f "$compose_file" ]; then
        stack_name=$(basename "$(dirname "$compose_file")")
        check_stack_health "$compose_file" "AI/$stack_name"
    fi
done

# Check Media stack
echo "=== Media Stack ==="
if [ -f "$DOCKER_ROOT/stacks/media/compose.yml" ]; then
    check_stack_health "$DOCKER_ROOT/stacks/media/compose.yml" "Media"
fi

# Check Utils stack
echo "=== Utils Stack ==="
if [ -f "$DOCKER_ROOT/stacks/utils/compose.yml" ]; then
    check_stack_health "$DOCKER_ROOT/stacks/utils/compose.yml" "Utils"
fi

# Check MCP servers
echo "=== MCP Servers ==="
for compose_file in "$DOCKER_ROOT"/*/docker-compose.yml; do
    if [ -f "$compose_file" ]; then
        stack_name=$(basename "$(dirname "$compose_file")")
        if [[ "$stack_name" == *"mcp"* ]]; then
            check_stack_health "$compose_file" "MCP/$stack_name"
        fi
    fi
done

echo "=== Summary ==="
echo "Use 'python3 $SCRIPT_DIR/stack-monitor.py status' for detailed monitoring"
echo "Use '$SCRIPT_DIR/manage-stacks.sh status' for configuration-based status"
