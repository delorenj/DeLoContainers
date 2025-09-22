#!/bin/bash
# Test script for NFS mount permissions
# Usage: ./test-nfs-permissions.sh [container_name]

set -euo pipefail

CONTAINER=${1:-qbittorrent}

echo "🔍 Testing NFS mount permissions for $CONTAINER"
echo "================================================="

# Check if container is running
if ! docker compose ps $CONTAINER | grep -q "Up"; then
    echo "❌ Container $CONTAINER is not running"
    exit 1
fi

echo "✅ Container $CONTAINER is running"

# Test basic mount existence
if docker exec $CONTAINER ls -la / | grep -q emma; then
    echo "✅ NFS mount /emma exists in container"
else
    echo "❌ NFS mount /emma not found in container"
    exit 1
fi

# Test read permissions
if docker exec $CONTAINER ls -la /emma > /dev/null 2>&1; then
    echo "✅ Read permission test passed"
elseif docker exec $CONTAINER ls /emma 2>/dev/null | head -1 > /dev/null; then
    echo "✅ Read permission test passed (directory listing)"
else
    echo "❌ Read permission test failed"
    exit 1
fi

# Test write permissions
if docker exec $CONTAINER touch /emma/test-write-${CONTAINER}.txt 2>/dev/null; then
    echo "✅ Write permission test passed"
    # Clean up test file
    docker exec $CONTAINER rm /emma/test-write-${CONTAINER}.txt 2>/dev/null || true
else
    echo "❌ Write permission test failed - NFS export is readonly"
    echo "💡 Fix: Enable write permissions in Synology DSM > Storage Manager > Shared Folders"
    exit 1
fi

echo ""
echo "🎉 NFS mount is fully functional!"
echo "   Container: $CONTAINER"
echo "   Mount point: /emma"
echo "   NFS source: 192.168.1.50:/volume1/video"