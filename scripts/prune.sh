#!/bin/bash

# Configuration
LOG_FILE="/home/delorenj/docker/logs/prune_$(date +%Y%m%d_%H%M%S).log"
DAYS_OLD=7

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Start logging
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

echo "🧹 Starting Docker system cleanup at $(date)"
echo "============================================"

# Function to get human-readable size
get_size() {
    local size=$1
    echo "$(echo "scale=2; $size/1024/1024" | bc) MB"
}

# Check space before cleanup
echo "Space usage before cleanup:"
df -h /var/lib/docker

# Stop all containers that are not running
echo -e "\n📦 Stopping stale containers..."
docker ps -a | grep -v "Up" | grep -v "CONTAINER ID" | awk '{print $1}' | xargs -r docker rm -f

# Remove unused containers
echo -e "\n🗑️ Removing unused containers..."
docker container prune -f

# Remove dangling images
echo -e "\n🖼️ Removing dangling images..."
docker image prune -f

# Remove unused volumes
echo -e "\n💾 Removing unused volumes..."
docker volume prune -f

# Remove unused networks
echo -e "\n🌐 Removing unused networks..."
docker network prune -f

# Remove old images (>7 days old)
echo -e "\n🕒 Removing images older than $DAYS_OLD days..."
docker images -a | grep -v "REPOSITORY" | awk '{print $3}' | \
    while read -r id; do
        created=$(docker inspect --format='{{.Created}}' "$id")
        created_date=$(date -d "$created" +%s)
        current_date=$(date +%s)
        days_old=$(( (current_date - created_date) / 86400 ))
        if [ "$days_old" -gt "$DAYS_OLD" ]; then
            docker rmi -f "$id" 2>/dev/null
        fi
    done

# Clean up build cache
echo -e "\n🏗️ Cleaning up build cache..."
docker builder prune -f

# Final cleanup
echo -e "\n🧹 Running system prune..."
docker system prune -f

# Check space after cleanup
echo -e "\nSpace usage after cleanup:"
df -h /var/lib/docker

echo -e "\n✅ Cleanup completed at $(date)"
echo "Log saved to: $LOG_FILE"

# Cleanup old log files (keep last 10)
find "$(dirname "$LOG_FILE")" -name "prune_*.log" -type f | \
    sort -r | tail -n +11 | xargs -r rm

exit 0