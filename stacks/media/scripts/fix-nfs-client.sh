#!/bin/bash

# NFS Client Configuration Fix Script
# This script fixes NFS mount permissions on the CLIENT side
# Run this on the Docker host machine

set -euo pipefail

NFS_SERVER="192.168.1.50"
NFS_PATH="/volume1/video"
MOUNT_POINT="/mnt/video"
TARGET_UID=1000
TARGET_GID=1000

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MEDIA_STACK_DIR="$(dirname "$SCRIPT_DIR")"

echo "🔧 NFS Client Permission Fix"
echo "============================"
echo "NFS Server: $NFS_SERVER"
echo "NFS Path: $NFS_PATH"
echo "Mount Point: $MOUNT_POINT"
echo "Target UID:GID: $TARGET_UID:$TARGET_GID"
echo ""

# Check if running as root or with sudo access
if [ "$EUID" -ne 0 ] && ! sudo -n true 2>/dev/null; then
    echo "❌ This script requires sudo access"
    exit 1
fi

# Function to run commands with proper privileges
run_cmd() {
    if [ "$EUID" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

# Check if mount point exists
if [ ! -d "$MOUNT_POINT" ]; then
    echo "📁 Creating mount point: $MOUNT_POINT"
    run_cmd mkdir -p "$MOUNT_POINT"
fi

# Check current mount status
if mountpoint -q "$MOUNT_POINT"; then
    echo "📊 Current mount info:"
    mount | grep "$MOUNT_POINT"
    echo "Current ownership: $(stat -c "%u:%g" "$MOUNT_POINT" 2>/dev/null || echo "unknown")"
    echo ""

    echo "🔄 Unmounting current NFS mount..."
    run_cmd umount "$MOUNT_POINT"
    echo "✅ Unmounted successfully"
else
    echo "ℹ️  Mount point is not currently mounted"
fi

# Backup fstab
echo "📦 Backing up /etc/fstab..."
run_cmd cp /etc/fstab /etc/fstab.backup.$(date +%Y%m%d_%H%M%S)

# Remove any existing fstab entries for this mount
echo "🧹 Cleaning existing fstab entries..."
run_cmd sed -i "\|$MOUNT_POINT|d" /etc/fstab

# Add new fstab entry with proper UID/GID mapping
echo "➕ Adding new fstab entry..."
FSTAB_ENTRY="$NFS_SERVER:$NFS_PATH $MOUNT_POINT nfs4 rw,vers=4.1,rsize=131072,wsize=131072,hard,proto=tcp,timeo=600,retrans=2,sec=sys,uid=$TARGET_UID,gid=$TARGET_GID,_netdev 0 0"
echo "$FSTAB_ENTRY" | run_cmd tee -a /etc/fstab

echo "✅ Added fstab entry:"
echo "$FSTAB_ENTRY"
echo ""

# Test mount
echo "🔍 Testing NFS connection..."
if showmount -e "$NFS_SERVER" >/dev/null 2>&1; then
    echo "✅ NFS server is accessible"
else
    echo "❌ Cannot connect to NFS server $NFS_SERVER"
    echo "Please check:"
    echo "1. NFS server is running"
    echo "2. Network connectivity"
    echo "3. Firewall settings"
    exit 1
fi

# Mount the filesystem
echo "🔗 Mounting NFS filesystem..."
if run_cmd mount -a; then
    echo "✅ Mount successful"
else
    echo "❌ Mount failed"
    echo "Checking mount manually..."
    run_cmd mount -t nfs4 -o rw,vers=4.1,rsize=131072,wsize=131072,hard,proto=tcp,timeo=600,retrans=2,sec=sys,uid=$TARGET_UID,gid=$TARGET_GID "$NFS_SERVER:$NFS_PATH" "$MOUNT_POINT"
fi

# Verify mount
if mountpoint -q "$MOUNT_POINT"; then
    echo "✅ Mount point is active"

    # Check ownership
    CURRENT_OWNERSHIP=$(stat -c "%u:%g" "$MOUNT_POINT" 2>/dev/null || echo "unknown")
    echo "Current ownership: $CURRENT_OWNERSHIP"

    if [ "$CURRENT_OWNERSHIP" = "$TARGET_UID:$TARGET_GID" ]; then
        echo "✅ Ownership is correct!"
    else
        echo "⚠️  Ownership mismatch. Expected: $TARGET_UID:$TARGET_GID, Got: $CURRENT_OWNERSHIP"
        echo "This may be due to server-side configuration. Check NFS export settings."
    fi

    # Test read access
    if ls "$MOUNT_POINT" >/dev/null 2>&1; then
        echo "✅ Read access confirmed"
    else
        echo "❌ Read access failed"
    fi

    # Test write access
    TEST_FILE="$MOUNT_POINT/nfs-write-test-$(date +%s).tmp"
    if touch "$TEST_FILE" 2>/dev/null; then
        echo "✅ Write access confirmed"
        rm -f "$TEST_FILE" 2>/dev/null || true
    else
        echo "❌ Write access failed"
        echo "Check NFS export permissions on server"
    fi

else
    echo "❌ Mount failed"
    exit 1
fi

echo ""
echo "🎉 NFS client configuration completed!"
echo ""
echo "📋 Summary:"
echo "- Mount point: $MOUNT_POINT"
echo "- NFS source: $NFS_SERVER:$NFS_PATH"
echo "- Target ownership: $TARGET_UID:$TARGET_GID"
echo "- Current ownership: $(stat -c "%u:%g" "$MOUNT_POINT" 2>/dev/null || echo "unknown")"
echo ""
echo "🔍 To test container access, run:"
echo "./scripts/test-nfs-permissions.sh qbittorrent"
echo ""
echo "📝 Mount options used:"
echo "rw,vers=4.1,rsize=131072,wsize=131072,hard,proto=tcp,timeo=600,retrans=2,sec=sys,uid=$TARGET_UID,gid=$TARGET_GID,_netdev"