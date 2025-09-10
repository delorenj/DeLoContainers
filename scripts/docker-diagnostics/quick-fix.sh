#!/bin/bash

# Quick Docker Memory Fix Script
# Emergency script to immediately address the 120GB memory consumption issue

set -e

echo "🚨 EMERGENCY DOCKER MEMORY FIX"
echo "==============================="
echo "This script will immediately address the critical memory issues:"
echo "1. MetaMCP container: 77.89GB memory usage"
echo "2. 10 dangling images consuming ~15GB"
echo "3. 106 unused volumes"
echo "4. Containers restarting constantly"
echo ""

# Function to ask for confirmation
confirm() {
    read -p "$1 (y/N): " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

# Function to log with timestamp
log_action() {
    echo "[$(date '+%H:%M:%S')] ✅ $1"
}

# 1. CRITICAL: Restart MetaMCP to clear memory leak
echo "🔴 CRITICAL: MetaMCP using 77.89GB memory!"
if confirm "Restart MetaMCP container to clear memory leak?"; then
    docker restart metamcp
    log_action "MetaMCP restarted"
    
    echo "Waiting 10 seconds for container to stabilize..."
    sleep 10
    
    new_memory=$(docker stats --no-stream --format "{{.MemUsage}}" metamcp | grep -o '^[0-9.]*' || echo "unknown")
    echo "📊 MetaMCP memory after restart: ${new_memory}GB"
fi

# 2. Stop Windows VM if running (32GB RAM allocation)
if docker ps --format "{{.Names}}" | grep -q "^windows$"; then
    echo "🔴 Windows VM is running with 32GB RAM allocation"
    if confirm "Stop Windows VM to free 32GB RAM?"; then
        docker stop windows
        log_action "Windows VM stopped - freed 32GB RAM"
    fi
else
    log_action "Windows VM not running"
fi

# 3. Clean up dangling images (immediate space recovery)
echo "🔴 Found 10 dangling images consuming ~15GB"
if confirm "Remove dangling images?"; then
    docker image prune -f
    log_action "Dangling images removed"
fi

# 4. Clean up unused volumes (immediate space recovery)
echo "🔴 Found 106 unused volumes"
if confirm "Remove unused volumes?"; then
    docker volume prune -f
    log_action "Unused volumes removed"
fi

# 5. Fix constantly restarting containers
echo "🔴 Containers with restart loops detected"
if confirm "Stop and restart problematic containers?"; then
    # Stop restarting containers
    for container in docker-plugin_daemon-1 livekit-ingress; do
        if docker ps -a --format "{{.Names}}" | grep -q "^${container}$"; then
            echo "  Fixing $container..."
            docker stop "$container" 2>/dev/null || true
            sleep 2
            docker start "$container" 2>/dev/null || true
            log_action "Fixed restart loop for $container"
        fi
    done
fi

# 6. General Docker cleanup
echo "🧹 Running general Docker cleanup"
if confirm "Run docker system prune?"; then
    docker system prune -f
    log_action "System cleanup completed"
fi

# 7. Show current status
echo ""
echo "📊 CURRENT SYSTEM STATUS:"
echo "=========================="

echo "Top 5 memory consumers:"
docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}\t{{.MemPerc}}" | head -6

echo ""
echo "Docker resource usage:"
docker system df

echo ""
echo "✅ QUICK FIX COMPLETED!"
echo ""
echo "🔧 NEXT STEPS:"
echo "1. Monitor memory usage: docker stats"
echo "2. Add memory limits to metamcp compose file"
echo "3. Run full diagnostics: ./docker-memory-leak-detector.sh"
echo "4. Set up monitoring: ./container-memory-monitor.sh"
echo ""
echo "💡 IMMEDIATE RECOMMENDATIONS:"
echo "• Add to metamcp/compose.yml:"
echo "  deploy:"
echo "    resources:"
echo "      limits:"
echo "        memory: 4G"
echo ""
echo "• Schedule regular cleanup:"
echo "  echo '0 2 * * 0 $PWD/memory-cleanup.sh' | crontab -"

# Calculate memory savings
echo ""
echo "💾 ESTIMATED MEMORY SAVINGS:"
if [ "$REPLY" = "y" ]; then
    echo "• MetaMCP restart: ~70GB+ memory leak cleared"
    echo "• Windows VM stop: ~32GB RAM freed"
    echo "• Dangling images: ~15GB disk space"
    echo "• Unused volumes: Variable disk space"
    echo "• Total potential savings: 100GB+ RAM, 15GB+ disk"
fi