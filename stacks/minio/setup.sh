#\!/bin/bash

# DeLoDrive MinIO Setup Script
set -e

echo "🚀 Setting up DeLoDrive (MinIO Object Storage)..."

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
   echo "⚠️  Please don't run as root"
   exit 1
fi

# Create data directory
echo "📁 Creating data directory..."
mkdir -p /home/delorenj/DeLoDrive
chmod 755 /home/delorenj/DeLoDrive

# Check if Docker is running
if \! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker first."
    exit 1
fi

# Check if proxy network exists
if \! docker network inspect proxy > /dev/null 2>&1; then
    echo "⚠️  Proxy network doesn't exist. Creating it..."
    docker network create proxy
fi

# Check if Traefik is running
if \! docker ps | grep -q traefik; then
    echo "⚠️  Warning: Traefik doesn't appear to be running."
    echo "   MinIO will start but won't be accessible via drive.delo.sh until Traefik is running."
    read -p "   Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ \! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Navigate to minio directory
cd "$(dirname "$0")"

# Pull the latest MinIO image
echo "📦 Pulling MinIO image..."
docker compose pull

# Start MinIO
echo "🎯 Starting MinIO..."
docker compose up -d

# Wait for MinIO to be ready
echo "⏳ Waiting for MinIO to be ready..."
sleep 5

# Check if container is running
if docker ps | grep -q delodrive; then
    echo "✅ DeLoDrive is running\!"
    echo ""
    echo "📊 Access Information:"
    echo "   Web Console: https://drive.delo.sh"
    echo "   Username: delorenj"
    echo "   Password: Ittr5eesol"
    echo ""
    echo "🔧 Useful commands:"
    echo "   View logs: docker compose logs -f"
    echo "   Stop: docker compose down"
    echo "   Restart: docker compose restart"
    echo ""
    echo "📝 Note: Make sure drive.delo.sh points to this server's IP in Cloudflare DNS"
else
    echo "❌ Failed to start DeLoDrive. Check logs with: docker compose logs"
    exit 1
fi
