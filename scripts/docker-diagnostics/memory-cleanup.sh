#!/bin/bash

# Docker Memory Cleanup Script
# Safely clean up Docker resources that may be consuming excessive memory

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/memory-cleanup.log"
DRY_RUN=false

# Parse command line options
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help)
            echo "Usage: $0 [--dry-run] [--help]"
            echo "  --dry-run    Show what would be cleaned without actually doing it"
            echo "  --help       Show this help message"
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

# Function to run command with dry-run support
run_command() {
    local cmd="$1"
    local description="$2"
    
    if [ "$DRY_RUN" = true ]; then
        log_message "🔍 [DRY RUN] Would $description: $cmd"
    else
        log_message "🔧 $description..."
        eval "$cmd"
        log_message "✅ Completed: $description"
    fi
}

log_message "🧹 Docker Memory Cleanup Script Started"
if [ "$DRY_RUN" = true ]; then
    log_message "🔍 DRY RUN MODE - No changes will be made"
fi

# 1. Clean up dangling images
log_message "\n📦 Cleaning up dangling images..."
dangling_images=$(docker images -f "dangling=true" -q)
if [ -n "$dangling_images" ]; then
    image_count=$(echo "$dangling_images" | wc -l)
    log_message "Found $image_count dangling images"
    run_command "docker rmi \$(docker images -f 'dangling=true' -q)" "remove dangling images"
else
    log_message "✅ No dangling images found"
fi

# 2. Clean up unused volumes
log_message "\n💾 Cleaning up unused volumes..."
unused_volumes=$(docker volume ls -f "dangling=true" -q)
if [ -n "$unused_volumes" ]; then
    volume_count=$(echo "$unused_volumes" | wc -l)
    log_message "Found $volume_count unused volumes"
    run_command "docker volume prune -f" "remove unused volumes"
else
    log_message "✅ No unused volumes found"
fi

# 3. Clean up stopped containers
log_message "\n🔄 Cleaning up stopped containers..."
stopped_containers=$(docker ps -aq -f status=exited)
if [ -n "$stopped_containers" ]; then
    container_count=$(echo "$stopped_containers" | wc -l)
    log_message "Found $container_count stopped containers"
    run_command "docker container prune -f" "remove stopped containers"
else
    log_message "✅ No stopped containers found"
fi

# 4. Clean up unused networks
log_message "\n🌐 Cleaning up unused networks..."
run_command "docker network prune -f" "remove unused networks"

# 5. Clean up build cache
log_message "\n🏗️  Cleaning up build cache..."
build_cache_size=$(docker system df --format "table {{.BuildCache}}" | tail -n +2)
if [ -n "$build_cache_size" ] && [ "$build_cache_size" != "0B" ]; then
    log_message "Build cache size: $build_cache_size"
    run_command "docker builder prune -f" "clean build cache"
else
    log_message "✅ No significant build cache to clean"
fi

# 6. Restart problematic containers
log_message "\n🔄 Checking for containers that need restart..."

# Check metamcp specifically for memory issues
if docker ps --format "{{.Names}}" | grep -q "metamcp"; then
    metamcp_memory=$(docker stats --no-stream --format "{{.MemUsage}}" metamcp | grep -o '^[0-9.]*')
    if [ -n "$metamcp_memory" ] && [ "$(echo "$metamcp_memory > 10" | bc -l 2>/dev/null || echo 0)" = "1" ]; then
        log_message "🚨 metamcp using excessive memory (${metamcp_memory}GB)"
        run_command "docker restart metamcp" "restart metamcp container"
    else
        log_message "✅ metamcp memory usage is acceptable"
    fi
else
    log_message "ℹ️  metamcp container not running"
fi

# Check for containers with high restart counts (may indicate memory issues)
log_message "\n🔍 Checking containers with high restart counts..."
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" | while read name status image; do
    if [ "$name" != "NAMES" ]; then
        restart_count=$(docker inspect "$name" --format '{{.RestartCount}}' 2>/dev/null || echo "0")
        if [ "$restart_count" -gt 5 ]; then
            log_message "🔴 $name has $restart_count restarts (may need attention)"
        fi
    fi
done

# 7. Clean up log files (Docker container logs can consume significant memory)
log_message "\n📝 Managing container log sizes..."

# Find containers with large log files
docker ps -q | while read container_id; do
    container_name=$(docker ps --filter id="$container_id" --format "{{.Names}}")
    log_file="/var/lib/docker/containers/$container_id/$container_id-json.log"
    
    if [ -f "$log_file" ]; then
        log_size=$(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null || echo "0")
        log_size_mb=$((log_size / 1024 / 1024))
        
        if [ "$log_size_mb" -gt 100 ]; then
            log_message "🔴 Large log file for $container_name: ${log_size_mb}MB"
            if [ "$DRY_RUN" = false ]; then
                log_message "Consider adding log rotation or reducing log level"
            fi
        fi
    fi
done

# 8. System-wide Docker cleanup
log_message "\n🧹 Performing system-wide cleanup..."
run_command "docker system prune -f" "remove all unused Docker objects"

# 9. Display final statistics
log_message "\n📊 Final Docker resource usage:"
{
    docker system df
} | tee -a "$LOG_FILE"

log_message "\n✅ Docker memory cleanup completed"
log_message "💡 Consider running this script regularly as a cron job"
log_message "💡 Monitor containers with: scripts/docker-diagnostics/container-memory-monitor.sh"

# Make scripts executable
chmod +x "$SCRIPT_DIR"/*.sh