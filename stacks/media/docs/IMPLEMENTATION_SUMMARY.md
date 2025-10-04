# NFS Permissions Implementation Summary

## Problem Statement
The NFS mount at `/mnt/video` from Synology NAS `192.168.1.50:/volume1/video` shows incorrect ownership `911:1001` instead of the required `1000:1000`, causing permission issues for Docker containers.

## Solution Overview

### What Was Created
1. **Comprehensive Documentation**: Complete NFS permissions guide with all methods
2. **Automated Scripts**: Safe, tested scripts for both server and client configuration
3. **Enhanced Testing**: Detailed validation with specific remediation steps
4. **Quick Reference**: Fast troubleshooting guide for common issues

### Files Created/Modified

#### New Documentation
- `/docs/NFS_PERMISSIONS_GUIDE.md` - Complete implementation guide
- `/docs/NFS_QUICK_REFERENCE.md` - Quick troubleshooting reference
- `/docs/IMPLEMENTATION_SUMMARY.md` - This summary document

#### New Scripts
- `/scripts/synology-nfs-config.sh` - Safe Synology NFS server configuration
- `/scripts/fix-nfs-client.sh` - Client-side mount option fixes

#### Enhanced Scripts
- `/scripts/test-nfs-permissions.sh` - Added detailed remediation guidance

#### Updated Documentation
- `PERMISSION_ISSUES.md` - Updated with complete solution approach

## Technical Approach

### Safe Synology Methods Used
✅ **DSM Control Panel**: Primary recommended method
✅ **Standard Synology Tools**: `synonfs`, `synoservice`, `exportfs`
✅ **Standard NFS Mount Options**: `uid=1000,gid=1000`
✅ **Backup and Validation**: All changes include backups

### Dangerous Methods Avoided
❌ Direct `/etc/passwd` modification
❌ `usermod` commands on Synology
❌ Force UID changes on system users
❌ Manual system file editing without backups

## Current Status

### ✅ Container Configuration (Already Correct)
```env
PUID=1000
PGID=1000
```

### ❌ Server Configuration (Needs Implementation)
**Required**: NFS export with `anonuid=1000,anongid=1000`
**Current**: Default Synology export without UID mapping

### ❌ Client Configuration (Needs Implementation)
**Required**: Mount with `uid=1000,gid=1000` options
**Current**: Basic NFS4 mount without UID mapping

## Implementation Steps

### Step 1: Server Configuration (On Synology NAS)
```bash
# SSH to NAS
ssh admin@192.168.1.50

# Run automated configuration
./synology-nfs-config.sh

# OR manual DSM configuration:
# DSM > Control Panel > Shared Folder > video > Edit > NFS Permissions
# Add rule: 192.168.1.0/24, Read/Write, Map all users to admin
```

### Step 2: Client Configuration (On Docker Host)
```bash
# Run automated fix
./scripts/fix-nfs-client.sh

# OR manual fstab entry:
# 192.168.1.50:/volume1/video /mnt/video nfs4 rw,vers=4.1,uid=1000,gid=1000,...
```

### Step 3: Validation
```bash
./scripts/test-nfs-permissions.sh qbittorrent
```

## Expected Results After Implementation

### Host Mount
```bash
$ stat -c "%u:%g" /mnt/video
1000:1000
```

### Container Access
```bash
$ docker exec qbittorrent stat -c "%u:%g" /emma
1000:1000
```

### Write Test
```bash
$ docker exec qbittorrent touch /emma/test-write.txt
# Should succeed without errors
```

## Why This Approach is Correct

### 1. **Server-Side UID Mapping**
- Uses NFS `anonuid`/`anongid` to map all anonymous users to UID 1000
- Maintains Synology system integrity
- Standard NFS practice for cross-system compatibility

### 2. **Client-Side Mount Options**
- Uses standard NFS `uid`/`gid` mount options
- Forces ownership interpretation at mount level
- Compatible with Docker user namespace mapping

### 3. **Container Configuration**
- LinuxServer.io containers properly configured with PUID/PGID
- No container-side changes needed
- Maintains security isolation

### 4. **Docker Volume Mapping**
- Standard bind mount from host to container
- Permissions inherited from host mount point
- No special Docker configuration required

## Alternative Methods Considered

### Why Not Direct Synology User Creation?
- **Risk**: Could conflict with existing system users
- **Complexity**: Requires ongoing user management
- **Maintenance**: User could be lost during system updates

### Why Not Container User Remapping?
- **Limited**: Only fixes one container
- **Incomplete**: Host still shows wrong permissions
- **Fragile**: Breaks with container updates

### Why Not Force Ownership Changes?
- **Temporary**: Permissions reset on remount
- **Inefficient**: Requires ongoing maintenance
- **Dangerous**: Could break other NFS clients

## Success Criteria

After implementation, all of these should be true:
- [ ] `stat -c "%u:%g" /mnt/video` returns `1000:1000`
- [ ] `docker exec qbittorrent stat -c "%u:%g" /emma` returns `1000:1000`
- [ ] `docker exec qbittorrent touch /emma/test-write.txt` succeeds
- [ ] `./scripts/test-nfs-permissions.sh qbittorrent` shows all green checkmarks
- [ ] No permission errors in container logs
- [ ] Jellyfin can read video files from `/EmmaVideo`

## Maintenance Notes

### Regular Monitoring
- Run `./scripts/test-nfs-permissions.sh` weekly
- Monitor container logs for permission errors
- Verify after Synology DSM updates

### Troubleshooting
- Use enhanced test script for detailed diagnosis
- Check both server and client configurations
- Refer to comprehensive guide for manual intervention

---

**Implementation Status**: Ready for deployment
**Next Action**: Run server-side configuration on Synology NAS