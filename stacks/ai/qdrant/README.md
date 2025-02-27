# Qdrant Docker Stack

This repository contains a Docker Compose setup for running Qdrant vector database with persistent storage and automated backups.

## Stack Components

### Docker Compose

The `compose.yml` file sets up Qdrant with:
- REST API on port 6333
- GRPC API on port 6334
- Persistent volume storage
- Automatic container restart

```yaml
services:
  qdrant:
    image: qdrant/qdrant
    ports:
      - "6333:6333"  # REST API
      - "6334:6334"  # GRPC API
    volumes:
      - qdrant_data:/qdrant/storage
    restart: unless-stopped

volumes:
  qdrant_data:
    name: qdrant_data
```

## Backup Solution

The `backup-qdrant.sh` script provides automated backup functionality:

### Features
- Creates compressed backups of the entire Qdrant storage
- Transfers backups to a remote NAS (Synology)
- Maintains a 7-day retention policy
- Includes logging for tracking backup operations

### Usage

1. Start the stack:
```bash
docker compose up -d
```

2. Run a backup:
```bash
./backup-qdrant.sh
```

### Backup Process
1. Creates a temporary snapshot of the running database
2. Compresses the entire storage directory
3. Transfers the backup to remote storage (configured for user@emma:~/qdrant_backups)
4. Cleans up old backups (keeps last 7 days)
5. Maintains a log of all backup operations

### Configuration
The backup script is configured to:
- Store backups in `~/qdrant_backups` on the remote host
- Keep 7 days of backup history
- Log all operations both locally and remotely

## Maintenance

- Backups older than 7 days are automatically removed
- Logs are rotated to prevent excessive growth
- The script can be scheduled via cron for automated backups

## Recovery

To restore from a backup:
1. Stop the container
2. Extract the backup archive
3. Replace the contents of the mounted volume
4. Restart the container

Note: Detailed recovery instructions can be provided if needed.
