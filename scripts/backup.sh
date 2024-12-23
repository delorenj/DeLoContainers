#!/bin/bash

# Configuration
BACKUP_ROOT="/home/delorenj/docker/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SERVICE=$1

# Service-specific backup configurations
declare -A BACKUP_PATHS=(
    ["prowlarr"]="/home/delorenj/docker/stacks/media/prowlarr/config"
    ["qbittorrent"]="/home/delorenj/docker/stacks/media/qbt/config"
    ["traefik"]="/home/delorenj/docker/stacks/proxy/traefik/config"
)

backup_service() {
    local service=$1
    local backup_path=${BACKUP_PATHS[$service]}
    local backup_dir="$BACKUP_ROOT/$service/$TIMESTAMP"
    
    echo "📦 Backing up $service..."
    
    # Create backup directory
    mkdir -p "$backup_dir"
    
    # Backup service configuration
    if [ -d "$backup_path" ]; then
        tar czf "$backup_dir/config.tar.gz" -C "$backup_path" .
        echo "✅ Configuration backed up to $backup_dir/config.tar.gz"
    else
        echo "❌ Backup path $backup_path not found"
        return 1
    fi
    
    # Service-specific backup procedures
    case $service in
        "prowlarr")
            # Backup Prowlarr database
            docker compose exec prowlarr sqlite3 /config/prowlarr.db ".backup '/config/backup_db/prowlarr.db.bak'"
            cp "$backup_path/backup_db/prowlarr.db.bak" "$backup_dir/"
            ;;
        "qbittorrent")
            # Backup qBittorrent settings
            cp "$backup_path/qBittorrent/qBittorrent.conf" "$backup_dir/"
            ;;
        "traefik")
            # Backup dynamic configurations
            cp -r "$backup_path/dynamic" "$backup_dir/"
            ;;
    esac
    
    # Create backup report
    echo "Backup completed at $(date)" > "$backup_dir/backup_report.txt"
    echo "Service: $service" >> "$backup_dir/backup_report.txt"
    du -sh "$backup_dir"/* >> "$backup_dir/backup_report.txt"
    
    # Cleanup old backups (keep last 5)
    local backup_count=$(ls -1d "$BACKUP_ROOT/$service"/*/ 2>/dev/null | wc -l)
    if [ "$backup_count" -gt 5 ]; then
        echo "🧹 Cleaning up old backups..."
        ls -1d "$BACKUP_ROOT/$service"/*/ | head -n -5 | xargs rm -rf
    fi
    
    echo "✅ Backup completed successfully!"
}

# Main execution
if [ ! -d "$BACKUP_ROOT" ]; then
    mkdir -p "$BACKUP_ROOT"
fi

if [ -z "$SERVICE" ]; then
    # Backup all services
    for service in "${!BACKUP_PATHS[@]}"; do
        backup_service "$service"
        echo "----------------------------------------"
    done
else
    # Backup specific service
    if [[ -v "BACKUP_PATHS[$SERVICE]" ]]; then
        backup_service "$SERVICE"
    else
        echo "❌ Unknown service: $SERVICE"
        echo "Available services: ${!BACKUP_PATHS[*]}"
        exit 1
    fi
fi