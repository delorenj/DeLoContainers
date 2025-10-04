#!/bin/bash

# qBittorrent Download Directory Permission Fix Script
# This script ensures proper permissions for qBittorrent download directories

set -e

echo "🔧 Fixing qBittorrent permissions and directory structure..."

# Resolve project root so we can read the canonical .env file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MEDIA_STACK_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$MEDIA_STACK_DIR/.env"

# Default values in case .env is missing
PUID_DEFAULT=1000
PGID_DEFAULT=1000
PUID="$PUID_DEFAULT"
PGID="$PGID_DEFAULT"

# Pull PUID/PGID from .env when available so we stay in sync with compose.yml
if [ -f "$ENV_FILE" ]; then
  ENV_PUID=$(grep -E '^PUID=' "$ENV_FILE" | tail -n 1 | cut -d '=' -f2 | tr -d '\r' | xargs)
  ENV_PGID=$(grep -E '^PGID=' "$ENV_FILE" | tail -n 1 | cut -d '=' -f2 | tr -d '\r' | xargs)

  if [ -n "$ENV_PUID" ]; then
    PUID="$ENV_PUID"
  fi

  if [ -n "$ENV_PGID" ]; then
    PGID="$ENV_PGID"
  fi
fi

echo "Using PUID=$PUID PGID=$PGID"

# Create download directories if they don't exist
mkdir -p /home/delorenj/Downloads/apps
mkdir -p /home/delorenj/Downloads/incomplete
mkdir -p /home/delorenj/Downloads/inbox

# Set proper ownership and permissions
echo "Setting ownership to $PUID:$PGID..."
sudo chown -R $PUID:$PGID /home/delorenj/Downloads/apps
sudo chown -R $PUID:$PGID /home/delorenj/Downloads/incomplete
sudo chown -R $PUID:$PGID /home/delorenj/Downloads/inbox

# Set proper permissions (775 for directories, 664 for files)
echo "Setting directory permissions..."
sudo chmod -R 775 /home/delorenj/Downloads/apps
sudo chmod -R 775 /home/delorenj/Downloads/incomplete
sudo chmod -R 775 /home/delorenj/Downloads/inbox

# Fix qBittorrent config directory permissions
echo "Fixing qBittorrent config permissions..."
sudo chown -R $PUID:$PGID "$MEDIA_STACK_DIR/qbittorrent"
sudo chmod -R 755 "$MEDIA_STACK_DIR/qbittorrent"

# Ensure the NFS staging area matches the same UID/GID when present
if [ -d /home/delorenj/emma_downloads ]; then
  echo "Aligning /home/delorenj/emma_downloads ownership..."
  sudo chown -R $PUID:$PGID /home/delorenj/emma_downloads
fi

echo "✅ qBittorrent permissions fixed successfully!"
echo ""
echo "📁 Download Structure:"
echo "  - Complete downloads: /home/delorenj/Downloads/inbox/"
echo "  - Incomplete downloads: /home/delorenj/Downloads/incomplete/"
echo "  - Apps: /home/delorenj/Downloads/apps/"
echo ""
echo "🔄 Next steps: Restart qBittorrent with 'docker compose restart qbittorrent'"
