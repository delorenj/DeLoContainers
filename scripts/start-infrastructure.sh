#!/bin/bash

# Infrastructure startup script
# Ensures Traefik starts first to claim port 8080

echo "🚀 Starting core infrastructure..."

# Start Traefik first
echo "📡 Starting Traefik..."
cd /home/delorenj/docker/trunk-main/core/traefik
docker compose up -d

# Wait for Traefik to be ready
echo "⏳ Waiting for Traefik to be ready..."
sleep 5

# Verify Traefik is using port 8080
if netstat -tlnp | grep -q ":8080.*docker-proxy"; then
    echo "✅ Traefik is running on port 8080"
else
    echo "❌ Traefik failed to start on port 8080"
    exit 1
fi

echo "🎉 Infrastructure startup complete!"
