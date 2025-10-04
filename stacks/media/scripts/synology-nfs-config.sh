#!/bin/bash

# Synology NFS Configuration Helper Script
# This script provides safe commands for configuring NFS on Synology
# Run this ON THE SYNOLOGY NAS via SSH

set -euo pipefail

EXPORT_PATH="/volume1/video"
TARGET_UID=1000
TARGET_GID=1000
CLIENT_NETWORK="192.168.1.0/24"

echo "🔧 Synology NFS Configuration Helper"
echo "=================================="
echo "Export Path: $EXPORT_PATH"
echo "Target UID:GID: $TARGET_UID:$TARGET_GID"
echo "Client Network: $CLIENT_NETWORK"
echo ""

# Check if running on Synology
if [ ! -f /etc/synoinfo.conf ]; then
    echo "❌ This script must be run on a Synology NAS"
    exit 1
fi

# Backup current exports
echo "📦 Backing up current NFS exports..."
sudo cp /etc/exports /etc/exports.backup.$(date +%Y%m%d_%H%M%S)

# Check if export already exists
if grep -q "$EXPORT_PATH" /etc/exports; then
    echo "⚠️  Export already exists in /etc/exports"
    echo "Current export line:"
    grep "$EXPORT_PATH" /etc/exports
    echo ""
    read -p "Do you want to update it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Exiting without changes"
        exit 0
    fi

    # Remove existing export line
    sudo sed -i "\|$EXPORT_PATH|d" /etc/exports
fi

# Add new export line
echo "➕ Adding NFS export configuration..."
NEW_EXPORT="$EXPORT_PATH $CLIENT_NETWORK(rw,no_root_squash,insecure,anonuid=$TARGET_UID,anongid=$TARGET_GID,async,no_subtree_check)"
echo "$NEW_EXPORT" | sudo tee -a /etc/exports

echo "✅ Export line added:"
echo "$NEW_EXPORT"
echo ""

# Validate exports file
echo "🔍 Validating exports file..."
if sudo exportfs -s > /dev/null 2>&1; then
    echo "✅ Exports file is valid"
else
    echo "❌ Exports file has errors - restoring backup"
    sudo cp /etc/exports.backup.$(date +%Y%m%d_%H%M%S) /etc/exports
    exit 1
fi

# Export the new configuration
echo "🔄 Applying new export configuration..."
sudo exportfs -ra

# Restart NFS service
echo "🔄 Restarting NFS service..."
sudo synoservice --restart nfsd

# Wait for service to start
sleep 3

# Verify service is running
if sudo synoservice --status nfsd | grep -q "running"; then
    echo "✅ NFS service is running"
else
    echo "❌ NFS service failed to start"
    exit 1
fi

# Show current exports
echo ""
echo "📋 Current NFS exports:"
sudo exportfs -v

echo ""
echo "🎉 NFS configuration completed successfully!"
echo ""
echo "📝 Next steps on the CLIENT machine:"
echo "1. Update /etc/fstab with uid=$TARGET_UID,gid=$TARGET_GID mount options"
echo "2. Remount the NFS share: sudo umount /mnt/video && sudo mount -a"
echo "3. Test permissions: stat -c \"%u:%g\" /mnt/video"
echo ""
echo "💡 Example fstab entry:"
echo "192.168.1.50:$EXPORT_PATH /mnt/video nfs4 rw,vers=4.1,rsize=131072,wsize=131072,hard,proto=tcp,timeo=600,retrans=2,sec=sys,uid=$TARGET_UID,gid=$TARGET_GID,_netdev 0 0"