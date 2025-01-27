#!/bin/bash

# Set variables
LOCAL_TMP="/tmp/qdrant_backup"
REMOTE_USER="delorenj"
REMOTE_HOST="emma"
REMOTE_DIR="qdrant_backups"
DATE=$(date +%Y%m%d_%H%M%S)
CONTAINER_NAME="qdrant-qdrant-1"
RETENTION_DAYS=7
LOCAL_LOG="/tmp/qdrant_backup.log"

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOCAL_LOG"
    # Also send to remote log if directory exists
    ssh ${REMOTE_USER}@${REMOTE_HOST} "mkdir -p ~/${REMOTE_DIR} && \
        echo \"[$(date +'%Y-%m-%d %H:%M:%S')] $1\" >> ~/${REMOTE_DIR}/backup.log"
}

# Error handling function
handle_error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$LOCAL_LOG"
    # Cleanup
    rm -rf "$LOCAL_TMP"
    exit 1
}

# Ensure local temp directory exists
rm -rf "$LOCAL_TMP"
mkdir -p "$LOCAL_TMP" || handle_error "Failed to create local temporary directory"

# Create a snapshot using Qdrant's REST API
log "Creating snapshot..."
SNAPSHOT_RESPONSE=$(curl -s -X POST 'http://localhost:6333/snapshots')
SNAPSHOT_NAME=$(echo $SNAPSHOT_RESPONSE | jq -r '.result.name')

if [ -z "$SNAPSHOT_NAME" ] || [ "$SNAPSHOT_NAME" == "null" ]; then
    handle_error "Failed to create snapshot. Response: $SNAPSHOT_RESPONSE"
fi

log "Created snapshot: $SNAPSHOT_NAME"

# Wait a moment for the snapshot to complete
sleep 2

# First, create a tar of the entire storage directory
log "Creating storage backup..."
docker exec $CONTAINER_NAME tar -czf /tmp/storage_backup.tar.gz -C /qdrant storage || \
    handle_error "Failed to create storage backup inside container"

# Copy the backup from the container
log "Copying backup from container..."
docker cp "$CONTAINER_NAME:/tmp/storage_backup.tar.gz" "$LOCAL_TMP/storage_backup.tar.gz" || \
    handle_error "Failed to copy backup from container"

# Create final archive with timestamp
log "Creating final archive..."
cp "$LOCAL_TMP/storage_backup.tar.gz" "$LOCAL_TMP/qdrant_backup_$DATE.tar.gz" || \
    handle_error "Failed to create final archive"

# Copy to NAS using rsync
log "Copying backup to NAS..."
rsync -avz "$LOCAL_TMP/qdrant_backup_$DATE.tar.gz" \
    ${REMOTE_USER}@${REMOTE_HOST}:~/${REMOTE_DIR}/ || \
    handle_error "Failed to copy backup to NAS"

# Cleanup temporary files
rm -rf "$LOCAL_TMP"
docker exec $CONTAINER_NAME rm -f /tmp/storage_backup.tar.gz

# Remove old backups (keeping last 7 days)
log "Cleaning up old backups..."
ssh ${REMOTE_USER}@${REMOTE_HOST} "find ~/${REMOTE_DIR} -name 'qdrant_backup_*.tar.gz' -mtime +${RETENTION_DAYS} -delete"

# Clean up old log entries on remote (keeping last 1000 lines)
ssh ${REMOTE_USER}@${REMOTE_HOST} "if [ -f '~/${REMOTE_DIR}/backup.log' ]; then \
    tail -n 1000 '~/${REMOTE_DIR}/backup.log' > '~/${REMOTE_DIR}/backup.log.tmp' && \
    mv '~/${REMOTE_DIR}/backup.log.tmp' '~/${REMOTE_DIR}/backup.log'; \
fi"

log "Backup completed: ~/${REMOTE_DIR}/qdrant_backup_$DATE.tar.gz"
log "----------------------------------------"
