#!/bin/bash
# Synology NAS Recovery Helper Script
# Run this AFTER completing the physical Mode 1 reset

set -e
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}=== SYNOLOGY NAS POST-RESET RECOVERY HELPER ===${NC}"
echo ""

# Step 1: Find the NAS
echo -e "${GREEN}Step 1: Discovering Synology NAS on network...${NC}"
echo "Attempting automatic discovery..."

# Try to find Synology devices on the network
echo "Scanning for Synology devices (port 5000/5001)..."
for i in {1..254}; do
    (timeout 0.1 nc -zv 192.168.1.$i 5000 2>/dev/null && echo "Found potential Synology at: 192.168.1.$i") &
done
wait

echo ""
echo -e "${YELLOW}Alternative discovery methods:${NC}"
echo "1. Open Synology Assistant: https://www.synology.com/en-us/support/download"
echo "2. Check router DHCP leases for 'DiskStation' or 'Synology'"
echo "3. Try: http://diskstation:5000 or http://diskstation.local:5000"
echo "4. Visit: https://find.synology.com"
echo ""

# Step 2: Access instructions
echo -e "${GREEN}Step 2: Access Your NAS${NC}"
cat << 'EOF'
Once you find your NAS IP, access it at:
  http://[NAS-IP]:5000

Login with:
  Username: admin
  Password: (leave blank)

You'll be prompted to set a new password immediately.
EOF

echo ""

# Step 3: User recreation commands
echo -e "${GREEN}Step 3: After logging in, recreate your user:${NC}"
cat << 'EOF'
1. Navigate to: Control Panel → User & Group
2. Click "Create" to add new user
3. Username: delorenj
4. Set strong password
5. Join group: administrators
6. Apply all shared folder permissions
EOF

echo ""

# Step 4: Fix NFS permissions
echo -e "${GREEN}Step 4: Fix NFS Permissions Properly:${NC}"
cat << 'EOF'
In DSM Control Panel:
1. Go to: Control Panel → Shared Folder
2. Select your 'video' shared folder
3. Click Edit → NFS Permissions
4. Modify the rule:
   - Privilege: Read/Write
   - Squash: Map all users to admin
   - Enable asynchronous: ✓
5. Click OK to save

On your Docker host (this machine), update the mount:
EOF

echo ""
echo "sudo umount /mnt/video 2>/dev/null || true"
echo "sudo mount -t nfs -o rw,uid=1000,gid=1000,vers=3 [NAS-IP]:/volume1/video /mnt/video"
echo ""

# Step 5: Update fstab
echo -e "${GREEN}Step 5: Make NFS Mount Permanent:${NC}"
echo "Add this line to /etc/fstab (replace [NAS-IP] with actual IP):"
echo "[NAS-IP]:/volume1/video /mnt/video nfs rw,uid=1000,gid=1000,vers=3,_netdev 0 0"
echo ""

# Step 6: Verify
echo -e "${GREEN}Step 6: Verification Commands:${NC}"
cat << 'EOF'
# Check if mount succeeded
mount | grep video

# Verify permissions (should show 1000:1000)
ls -la /mnt/video

# Test write access
touch /mnt/video/test-recovery && rm /mnt/video/test-recovery

# Check Docker containers can access
docker exec qbittorrent ls -la /downloads
EOF

echo ""
echo -e "${YELLOW}=== PREVENTION MEASURES ===${NC}"
cat << 'EOF'
1. NEVER run: synouser --rebuild all
2. NEVER edit: /etc/passwd or /etc/group directly
3. ALWAYS use: DSM web interface for user management
4. BACKUP: Control Panel → Update & Restore → Configuration Backup
5. DOCUMENT: Keep IP address and credentials in password manager
EOF

echo ""
echo -e "${GREEN}✅ Recovery helper script ready!${NC}"
echo -e "${YELLOW}Remember: Mode 1 Reset preserves ALL your data${NC}"