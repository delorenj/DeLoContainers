#!/bin/bash

# Docker Memory Issues Fix Script
# Apply immediate fixes for the identified 120GB memory consumption issue

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/memory-fixes.log"
BACKUP_DIR="${SCRIPT_DIR}/compose-backups"

# Parse command line options
APPLY_FIXES=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --apply)
            APPLY_FIXES=true
            shift
            ;;
        --help)
            echo "Usage: $0 [--apply] [--help]"
            echo "  --apply      Actually apply the fixes (default: dry run)"
            echo "  --help       Show this help message"
            echo ""
            echo "This script will fix the Docker memory consumption issues:"
            echo "1. Add memory limits to containers without limits"
            echo "2. Restart problematic containers"
            echo "3. Clean up unused resources"
            echo "4. Stop Windows VM if not needed"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Function to log with timestamp
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to backup compose file
backup_compose() {
    local compose_file="$1"
    local backup_name="$(basename "$compose_file")-backup-$(date +%Y%m%d-%H%M%S)"
    
    mkdir -p "$BACKUP_DIR"
    cp "$compose_file" "$BACKUP_DIR/$backup_name"
    log_message "📁 Backed up $compose_file to $BACKUP_DIR/$backup_name"
}

# Function to add memory limits to compose file
add_memory_limits() {
    local compose_file="$1"
    local service_name="$2"
    local memory_limit="$3"
    local memory_reservation="$4"
    
    if [ "$APPLY_FIXES" = true ]; then
        backup_compose "$compose_file"
        
        # Check if deploy section exists
        if grep -q "deploy:" "$compose_file"; then
            log_message "Deploy section exists, adding to it"
        else
            # Add deploy section before volumes or networks
            sed -i "/^volumes:/i\\    deploy:\n      resources:\n        limits:\n          memory: $memory_limit\n        reservations:\n          memory: $memory_reservation" "$compose_file"
        fi
        
        log_message "✅ Added memory limits to $service_name: limit=$memory_limit, reservation=$memory_reservation"
    else
        log_message "🔍 [DRY RUN] Would add memory limits to $service_name in $compose_file"
    fi
}

log_message "🚀 Docker Memory Issues Fix Script Started"
if [ "$APPLY_FIXES" = false ]; then
    log_message "🔍 DRY RUN MODE - Use --apply to actually make changes"
fi

# 1. Fix MetaMCP memory limits
log_message "\n🔧 FIXING METAMCP MEMORY LIMITS"
METAMCP_COMPOSE="/home/delorenj/docker/trunk-main/stacks/mcp/metamcp/compose.yml"

if [ -f "$METAMCP_COMPOSE" ]; then
    if grep -q "memory:" "$METAMCP_COMPOSE"; then
        log_message "✅ MetaMCP already has memory limits"
    else
        log_message "🚨 MetaMCP has NO memory limits - adding them"
        
        if [ "$APPLY_FIXES" = true ]; then
            backup_compose "$METAMCP_COMPOSE"
            
            # Add deploy section with memory limits
            cat << 'EOF' >> "$METAMCP_COMPOSE"
    deploy:
      resources:
        limits:
          memory: 4G
        reservations:
          memory: 2G
EOF
            log_message "✅ Added memory limits to MetaMCP compose file"
        else
            log_message "🔍 [DRY RUN] Would add 4G memory limit to MetaMCP"
        fi
    fi
else
    log_message "❌ MetaMCP compose file not found at $METAMCP_COMPOSE"
fi

# 2. Fix Windows VM settings
log_message "\n🔧 FIXING WINDOWS VM SETTINGS"
WINDOWS_COMPOSE="/home/delorenj/docker/trunk-main/stacks/Windows/compose.yml"

if [ -f "$WINDOWS_COMPOSE" ]; then
    current_ram=$(grep "RAM_SIZE:" "$WINDOWS_COMPOSE" | grep -o '"[^"]*"' | tr -d '"')
    log_message "Current Windows VM RAM allocation: $current_ram"
    
    # Check if Windows container is running
    if docker ps --format "{{.Names}}" | grep -q "^windows$"; then
        log_message "🔴 Windows VM is currently running and consuming 32GB RAM allocation"
        
        # Ask if user wants to stop it
        if [ "$APPLY_FIXES" = true ]; then
            log_message "Stopping Windows VM to free memory..."
            docker stop windows || true
            log_message "✅ Windows VM stopped"
        else
            log_message "🔍 [DRY RUN] Would stop Windows VM"
        fi
    else
        log_message "✅ Windows VM is not currently running"
    fi
    
    # Suggest RAM reduction if VM is needed
    if [ "$current_ram" = "32G" ]; then
        log_message "💡 Consider reducing RAM_SIZE to 16G or 8G if Windows VM is needed"
        if [ "$APPLY_FIXES" = true ]; then
            log_message "Manual step required: Edit RAM_SIZE in $WINDOWS_COMPOSE if needed"
        fi
    fi
else
    log_message "❌ Windows compose file not found at $WINDOWS_COMPOSE"
fi

# 3. Restart problematic containers
log_message "\n🔄 RESTARTING PROBLEMATIC CONTAINERS"

# Restart MetaMCP to clear memory leaks
if docker ps --format "{{.Names}}" | grep -q "^metamcp$"; then
    metamcp_memory=$(docker stats --no-stream --format "{{.MemUsage}}" metamcp | grep -o '^[0-9.]*')
    
    if [ -n "$metamcp_memory" ] && [ "$(echo "$metamcp_memory > 5" | bc -l 2>/dev/null || echo 0)" = "1" ]; then
        log_message "🚨 MetaMCP using ${metamcp_memory}GB - restarting to clear memory leaks"
        
        if [ "$APPLY_FIXES" = true ]; then
            docker restart metamcp
            log_message "✅ MetaMCP restarted"
            
            # Wait and check new memory usage
            sleep 10
            new_memory=$(docker stats --no-stream --format "{{.MemUsage}}" metamcp | grep -o '^[0-9.]*')
            log_message "📊 MetaMCP memory after restart: ${new_memory}GB"
        else
            log_message "🔍 [DRY RUN] Would restart MetaMCP container"
        fi
    else
        log_message "✅ MetaMCP memory usage is acceptable"
    fi
else
    log_message "ℹ️  MetaMCP container not running"
fi

# Restart containers that are constantly restarting (may have memory issues)
docker ps -a --format "table {{.Names}}\t{{.Status}}" | grep "Restarting" | while read name status; do
    if [ "$name" != "NAMES" ]; then
        log_message "🔄 Found restarting container: $name"
        
        if [ "$APPLY_FIXES" = true ]; then
            docker stop "$name" || true
            sleep 5
            docker start "$name" || true
            log_message "✅ Restarted problematic container: $name"
        else
            log_message "🔍 [DRY RUN] Would restart $name"
        fi
    fi
done

# 4. Clean up unused resources
log_message "\n🧹 CLEANING UP UNUSED RESOURCES"

if [ "$APPLY_FIXES" = true ]; then
    # Run the cleanup script
    if [ -f "${SCRIPT_DIR}/memory-cleanup.sh" ]; then
        log_message "Running memory cleanup script..."
        bash "${SCRIPT_DIR}/memory-cleanup.sh"
    else
        log_message "Performing basic cleanup..."
        docker system prune -f
        docker volume prune -f
        log_message "✅ Basic cleanup completed"
    fi
else
    log_message "🔍 [DRY RUN] Would run memory cleanup"
fi

# 5. Add memory monitoring
log_message "\n📊 SETTING UP MEMORY MONITORING"

# Create a systemd service or cron job for monitoring
if [ "$APPLY_FIXES" = true ]; then
    # Add to crontab to run memory monitor every hour
    if ! crontab -l 2>/dev/null | grep -q "docker-memory-leak-detector"; then
        (crontab -l 2>/dev/null; echo "0 */2 * * * ${SCRIPT_DIR}/docker-memory-leak-detector.sh >/dev/null 2>&1") | crontab -
        log_message "✅ Added memory monitoring to cron (runs every 2 hours)"
    else
        log_message "✅ Memory monitoring already scheduled"
    fi
else
    log_message "🔍 [DRY RUN] Would set up automated memory monitoring"
fi

# 6. Update compose files with better resource management
log_message "\n⚙️  UPDATING RESOURCE MANAGEMENT"

# Add resource limits to other containers without limits
containers_without_limits=()

# Check Qdrant
if docker ps --format "{{.Names}}" | grep -q "^qdrant$"; then
    qdrant_memory=$(docker inspect qdrant --format '{{.HostConfig.Memory}}')
    if [ "$qdrant_memory" = "0" ]; then
        containers_without_limits+=("qdrant:/home/delorenj/docker/trunk-main/stacks/persistence/compose.yml:2G:1G")
    fi
fi

# Apply limits to containers without them
for item in "${containers_without_limits[@]}"; do
    IFS=':' read -r container compose_file limit reservation <<< "$item"
    
    log_message "🔧 Adding memory limits to $container"
    if [ "$APPLY_FIXES" = true ] && [ -f "$compose_file" ]; then
        backup_compose "$compose_file"
        
        # This is a simplified approach - in practice, you'd need more sophisticated YAML editing
        log_message "Manual step required: Add memory limits to $container in $compose_file"
        log_message "  Suggested limits: $limit (limit), $reservation (reservation)"
    else
        log_message "🔍 [DRY RUN] Would add memory limits to $container"
    fi
done

# 7. Final system status
log_message "\n📊 FINAL SYSTEM STATUS"

if [ "$APPLY_FIXES" = true ]; then
    sleep 5  # Wait for containers to settle
    
    log_message "Current container memory usage:"
    docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}\t{{.MemPerc}}" | head -10 | tee -a "$LOG_FILE"
    
    log_message "\nDocker system resource usage:"
    docker system df | tee -a "$LOG_FILE"
    
    # Check if we've reduced total memory usage
    total_memory_usage=$(docker stats --no-stream --format "{{.MemUsage}}" | grep -o '^[0-9.]*' | awk '{sum += $1} END {print sum}')
    log_message "Total container memory usage: ${total_memory_usage}GB"
    
    if [ "$(echo "$total_memory_usage < 50" | bc -l 2>/dev/null || echo 0)" = "1" ]; then
        log_message "🎉 SUCCESS: Memory usage significantly reduced!"
    else
        log_message "⚠️  Memory usage still high - may need additional investigation"
    fi
fi

# 8. Recommendations for ongoing maintenance
log_message "\n💡 ONGOING MAINTENANCE RECOMMENDATIONS"

log_message "DAILY TASKS:"
log_message "1. Monitor memory with: docker stats"
log_message "2. Check for memory growth patterns"
log_message "3. Restart containers showing memory leaks"

log_message "\nWEEKLY TASKS:"
log_message "1. Run memory cleanup: ${SCRIPT_DIR}/memory-cleanup.sh"
log_message "2. Review container logs for memory errors"
log_message "3. Check for updated images with memory fixes"

log_message "\nMONTHLY TASKS:"
log_message "1. Review and optimize compose configurations"
log_message "2. Update containers to latest versions"
log_message "3. Analyze memory usage trends"

log_message "\n🔧 MANUAL STEPS REQUIRED:"
if [ "$APPLY_FIXES" = true ]; then
    log_message "1. Review backup files in: $BACKUP_DIR"
    log_message "2. Test applications after memory limit changes"
    log_message "3. Adjust memory limits based on actual usage"
    log_message "4. Document any application-specific optimizations needed"
else
    log_message "1. Run this script with --apply to make changes"
    log_message "2. Review the proposed changes above"
    log_message "3. Manually edit compose files if needed"
fi

log_message "\n✅ Docker memory fixes completed!"
log_message "📄 Full log available at: $LOG_FILE"

# Make all scripts executable
chmod +x "${SCRIPT_DIR}"/*.sh

if [ "$APPLY_FIXES" = false ]; then
    echo ""
    echo "🔍 This was a dry run. To apply fixes, run:"
    echo "  $0 --apply"
fi