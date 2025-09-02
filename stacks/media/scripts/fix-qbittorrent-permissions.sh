#!/bin/bash

# qBittorrent Download Directory Permission Fix Script
# This script ensures proper permissions for qBittorrent download directories

set -e

echo "🔧 Fixing qBittorrent permissions and directory structure..."

# User/Group IDs from .env
PUID=1000
PGID=1000

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
sudo chown -R $PUID:$PGID /home/delorenj/docker/trunk-main/stacks/media/qbittorrent
sudo chmod -R 755 /home/delorenj/docker/trunk-main/stacks/media/qbittorrent

echo "✅ qBittorrent permissions fixed successfully!"
echo ""
echo "📁 Download Structure:"
echo "  - Complete downloads: /home/delorenj/Downloads/inbox/"
echo "  - Incomplete downloads: /home/delorenj/Downloads/incomplete/"
echo "  - Apps: /home/delorenj/Downloads/apps/"
echo ""
echo "🔄 Next steps: Restart qBittorrent with 'docker compose restart qbittorrent'"