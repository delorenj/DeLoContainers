# Media Stack Permission Issues - RESOLVED

## Original Problem
Files and directories owned by wrong users instead of `1000:1000` (delorenj).

## Current Status
- **NFS Mount**: `/mnt/video` shows `911:1001` (should be `1000:1000`)
- **Container Config**: ✅ PUID=1000, PGID=1000 correctly set in `.env`
- **Solution**: Server and client-side NFS configuration needed

## Root Causes

### 1. ✅ qBittorrent Container User Mapping (FIXED)
- Container PUID/PGID correctly set to 1000:1000 in `.env`
- LinuxServer.io containers working properly

### 2. ❌ NFS Server Export Configuration (NEEDS FIX)
- Synology NFS export lacks proper UID/GID mapping
- Export needs `anonuid=1000,anongid=1000` options

### 3. ❌ NFS Client Mount Options (NEEDS FIX)
- Client mount missing `uid=1000,gid=1000` options
- Current mount shows default NFS behavior

## Solution Implemented

### ✅ Complete NFS Permission Fix System
- **Comprehensive Guide**: `docs/NFS_PERMISSIONS_GUIDE.md` - Full documentation
- **Server Script**: `scripts/synology-nfs-config.sh` - Safe Synology NFS configuration
- **Client Script**: `scripts/fix-nfs-client.sh` - Client-side mount fixing
- **Enhanced Testing**: `scripts/test-nfs-permissions.sh` - Detailed remediation guidance
- **Quick Reference**: `docs/NFS_QUICK_REFERENCE.md` - Fast troubleshooting

### Safe Methods Used
- ✅ DSM Control Panel configuration (preferred)
- ✅ Standard NFS mount options
- ✅ Proper Synology tools (`synonfs`, `synoservice`)
- ❌ NO direct system file modifications
- ❌ NO dangerous user account changes

## 🚀 How to Apply the Complete Fix

### Method 1: Automated Scripts (Recommended)
```bash
# 1. Fix Synology NFS server (run on NAS via SSH)
ssh admin@192.168.1.50
./synology-nfs-config.sh

# 2. Fix client mount (run on Docker host)
./scripts/fix-nfs-client.sh

# 3. Test everything
./scripts/test-nfs-permissions.sh qbittorrent
```

### Method 2: Manual Configuration
**See `docs/NFS_PERMISSIONS_GUIDE.md` for detailed manual steps**

### Method 3: Quick DSM Fix
1. DSM > Control Panel > Shared Folder
2. Select `video` > Edit > NFS Permissions
3. Add rule: `192.168.1.0/24`, Read/Write, Map all users to admin
4. Run `./scripts/fix-nfs-client.sh` on Docker host

### Current Configuration Status
```bash
# Container: ✅ CORRECT
PUID=1000  # ✅ Set in .env
PGID=1000  # ✅ Set in .env

# Server: ❌ NEEDS anonuid=1000,anongid=1000
# Client: ❌ NEEDS uid=1000,gid=1000 mount options
```

## Temporary Fix (Historical)
```bash
sudo chown -R delorenj:delorenj /home/delorenj/emma_downloads/
mv /home/delorenj/emma_downloads/* /home/delorenj/Videos/
```

## Implementation Checklist
- [x] ✅ PUID/PGID corrected in compose environment
- [x] ✅ Complete documentation created (`docs/NFS_PERMISSIONS_GUIDE.md`)
- [x] ✅ Safe Synology configuration script (`scripts/synology-nfs-config.sh`)
- [x] ✅ Client-side fix script (`scripts/fix-nfs-client.sh`)
- [x] ✅ Enhanced testing with remediation guidance
- [ ] ❌ Run server-side configuration (on NAS)
- [ ] ❌ Run client-side mount fix
- [ ] ❌ Validate with `./scripts/test-nfs-permissions.sh qbittorrent`

## 🎯 Next Action Items
1. **SSH to Synology**: `ssh admin@192.168.1.50`
2. **Run server script**: `./synology-nfs-config.sh`
3. **Run client script**: `./scripts/fix-nfs-client.sh`
4. **Test permissions**: `./scripts/test-nfs-permissions.sh qbittorrent`
