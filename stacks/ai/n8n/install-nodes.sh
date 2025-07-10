#!/bin/bash

# n8n Community Nodes Batch Installer
# This script installs all community nodes from full-list.txt

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NODE_LIST_FILE="$SCRIPT_DIR/full-list.txt"
CONTAINER_NAME="n8n-n8n-1"

echo "🚀 n8n Community Nodes Batch Installer"
echo "======================================"

# Check if container is running
if ! docker ps | grep -q "$CONTAINER_NAME"; then
    echo "❌ Error: n8n container '$CONTAINER_NAME' is not running"
    echo "Please start n8n first: docker compose up -d"
    exit 1
fi

# Check if node list file exists
if [ ! -f "$NODE_LIST_FILE" ]; then
    echo "❌ Error: Node list file not found: $NODE_LIST_FILE"
    exit 1
fi

echo "📋 Reading node list from: $NODE_LIST_FILE"
echo ""

# Extract non-comment, non-empty lines from the file
NODES=$(grep -v '^#' "$NODE_LIST_FILE" | grep -v '^$' | tr '\n' ' ')

if [ -z "$NODES" ]; then
    echo "❌ No nodes found in $NODE_LIST_FILE"
    exit 1
fi

echo "📦 Nodes to install:"
for node in $NODES; do
    echo "  - $node"
done
echo ""

# Install all nodes in one command for better dependency resolution
echo "🔧 Installing all nodes..."
docker exec "$CONTAINER_NAME" sh -c "
    cd /home/node/.n8n/nodes && 
    npm install $NODES --legacy-peer-deps
"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ All nodes installed successfully!"
    echo ""
    echo "🔄 Restarting n8n to load new nodes..."
    cd "$SCRIPT_DIR" && docker compose restart
    
    echo ""
    echo "⏳ Waiting for n8n to start..."
    sleep 15
    
    # Check if n8n is ready
    if docker exec "$CONTAINER_NAME" sh -c "curl -s http://localhost:5678 > /dev/null"; then
        echo "✅ n8n is ready!"
        echo ""
        echo "📊 Installation Summary:"
        NODE_COUNT=$(docker exec "$CONTAINER_NAME" sh -c "cd /home/node/.n8n/nodes && cat package.json | jq '.dependencies | keys | length'" 2>/dev/null || echo "unknown")
        echo "  Total community nodes installed: $NODE_COUNT"
        echo ""
        echo "🎉 Installation complete! You can now use the community nodes in your workflows."
        echo "   Access n8n at: http://localhost:5678 or https://n8n.delo.sh"
    else
        echo "⚠️  n8n may still be starting. Check logs with: docker compose logs n8n"
    fi
else
    echo "❌ Installation failed. Check the error messages above."
    echo "💡 Try installing nodes individually if there are dependency conflicts."
    exit 1
fi
