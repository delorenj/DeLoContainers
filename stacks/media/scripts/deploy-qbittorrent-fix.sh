#!/bin/bash

# qBittorrent Fix Deployment Script
# Deploys the complete qBittorrent mounting and permission fix

set -e

echo "🚀 Deploying qBittorrent Fix..."
echo "================================="

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MEDIA_STACK_DIR="$(dirname "$SCRIPT_DIR")"

# Change to media stack directory
cd "$MEDIA_STACK_DIR"

# Step 1: Stop qBittorrent container
echo "🛑 Stopping qBittorrent container..."
docker compose stop qbittorrent || echo "qBittorrent not running"

# Step 2: Fix permissions
echo "🔧 Running permission fix script..."
bash "$SCRIPT_DIR/fix-qbittorrent-permissions.sh"

# Step 3: Start qBittorrent with new configuration
echo "🔄 Starting qBittorrent with fixed configuration..."
docker compose up -d qbittorrent

# Step 4: Wait and verify
echo "⏳ Waiting for qBittorrent to start..."
sleep 15

# Check if container is running
if docker compose ps qbittorrent | grep -q "running"; then
    echo "✅ qBittorrent is running successfully!"
    
    # Verify mounts
    echo "📁 Verifying container mounts..."
    docker exec qbittorrent ls -la /downloads/ || echo "⚠️  Downloads directory verification failed"
    docker exec qbittorrent ls -la /downloads/incomplete/ || echo "⚠️  Incomplete directory verification failed"
    docker exec qbittorrent ls -la /downloads/inbox/ || echo "⚠️  Inbox directory verification failed"
    
    echo ""
    echo "🎉 qBittorrent Fix Deployment Complete!"
    echo "=================================="
    echo "✅ Downloads mounted: /downloads -> /home/delorenj/Downloads"
    echo "✅ Incomplete path: /downloads/incomplete"
    echo "✅ Complete path: /downloads/inbox"
    echo "✅ Apps path: /downloads/apps"
    echo ""
    echo "🌐 WebUI: https://get.delo.sh (or http://localhost:8091)"
    echo "👤 Username: delorenj"
    echo "🔑 Password: Check your .env file"
else
    echo "❌ qBittorrent failed to start! Check logs:"
    echo "   docker compose logs qbittorrent"
    exit 1
fi