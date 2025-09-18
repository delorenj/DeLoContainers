#!/bin/bash

# Monitor Gluetun and restart qBittorrent when needed
COMPOSE_DIR="/home/delorenj/docker/trunk-main/stacks/media"
LOG_FILE="/tmp/qbittorrent-monitor.log"

log() {
    echo "$(date): $1" >> "$LOG_FILE"
}

cd "$COMPOSE_DIR"

# Get initial Gluetun container ID
GLUETUN_ID=$(docker compose ps -q gluetun)
log "Starting monitor for Gluetun: $GLUETUN_ID"

while true; do
    # Check if Gluetun container changed (restarted)
    CURRENT_ID=$(docker compose ps -q gluetun)
    
    if [ "$CURRENT_ID" != "$GLUETUN_ID" ]; then
        log "Gluetun restarted! Old: $GLUETUN_ID, New: $CURRENT_ID"
        
        # Wait for Gluetun to be healthy
        log "Waiting for Gluetun to be healthy..."
        while ! docker compose exec gluetun wget -qO- --timeout=3 http://1.1.1.1 > /dev/null 2>&1; do
            sleep 2
        done
        
        log "Gluetun is healthy, restarting qBittorrent..."
        docker compose restart qbittorrent
        
        # Update the container ID
        GLUETUN_ID="$CURRENT_ID"
        log "qBittorrent restarted successfully"
    fi
    
    sleep 10
done
