# NFS Permissions Quick Reference

## Current Status
- **Problem**: `/mnt/video` shows `911:1001` instead of `1000:1000`
- **NFS Source**: `192.168.1.50:/volume1/video`
- **Container**: qBittorrent expects `1000:1000` (PUID/PGID from .env)

## Quick Fix Commands

### 1. Fix Server (Run on Synology NAS)
```bash
# SSH to 192.168.1.50 as admin
./synology-nfs-config.sh
```

### 2. Fix Client (Run on Docker host)
```bash
# Run on this machine
./scripts/fix-nfs-client.sh
```

### 3. Test Fix
```bash
./scripts/test-nfs-permissions.sh qbittorrent
```

## Manual DSM Method
1. DSM > Control Panel > Shared Folder
2. Select `video` > Edit > NFS Permissions
3. Add rule: `192.168.1.0/24` with Read/Write, Map all users to admin

## Manual Mount Method
```bash
sudo umount /mnt/video
sudo mount -t nfs4 -o rw,vers=4.1,uid=1000,gid=1000,rsize=131072,wsize=131072,hard,proto=tcp,timeo=600,retrans=2,sec=sys 192.168.1.50:/volume1/video /mnt/video
```

## Verification Commands
```bash
# Check mount ownership
stat -c "%u:%g" /mnt/video

# Check container access
docker exec qbittorrent stat -c "%u:%g" /emma

# Test write access
docker exec qbittorrent touch /emma/test-write.txt
```

## Success Criteria
✅ `stat -c "%u:%g" /mnt/video` returns `1000:1000`
✅ Container can read/write to `/emma`
✅ No permission errors in container logs