# Complete NFS Permissions Fix Guide - Synology Safe Methods

## Current Problem Analysis

**Issue**: NFS mount at `/mnt/video` shows wrong permissions (911:1001) instead of required (1000:1000)
- **Current ownership**: `911:1001` (LinuxServer.io container defaults)
- **Required ownership**: `1000:1000` (delorenj user)
- **NFS Source**: `192.168.1.50:/volume1/video`

## CORRECT Solutions (Synology-Safe)

### 1. SERVER-SIDE: Synology DSM NFS Export Configuration

#### Method A: DSM Control Panel (Recommended)
1. **Navigate to DSM > Control Panel > Shared Folder**
2. **Select `video` folder > Edit > NFS Permissions**
3. **Configure NFS Rule:**
   ```
   Hostname/IP: * (or specific network: 192.168.1.0/24)
   Privilege: Read/Write
   Squash: Map all users to admin
   Enable async: ✓
   Enable subtree checking: ✗
   ```

#### Method B: Advanced DSM Settings
1. **SSH to Synology as admin**
2. **Edit NFS exports:**
   ```bash
   sudo vim /etc/exports
   ```
3. **Add/modify export line:**
   ```
   /volume1/video *(rw,no_root_squash,insecure,anonuid=1000,anongid=1000,async,no_subtree_check)
   ```
4. **Restart NFS service:**
   ```bash
   sudo synoservice --restart nfsd
   ```

#### Method C: Synology synoNFS Tool
```bash
# On Synology DSM
sudo synonfs --export-list
sudo synonfs --export /volume1/video --rw --no-root-squash --anonuid=1000 --anongid=1000
```

### 2. CLIENT-SIDE: Mount Options (Host Machine)

#### Option A: Update /etc/fstab
```bash
# Add to /etc/fstab
192.168.1.50:/volume1/video /mnt/video nfs4 rw,vers=4.1,rsize=131072,wsize=131072,hard,proto=tcp,timeo=600,retrans=2,sec=sys,uid=1000,gid=1000,_netdev 0 0
```

#### Option B: Manual Mount with UID/GID Mapping
```bash
sudo umount /mnt/video
sudo mount -t nfs4 -o rw,vers=4.1,rsize=131072,wsize=131072,hard,proto=tcp,timeo=600,retrans=2,sec=sys,uid=1000,gid=1000,_netdev 192.168.1.50:/volume1/video /mnt/video
```

#### Option C: NFSv3 with ID Mapping
```bash
sudo mount -t nfs -o nfsvers=3,rw,uid=1000,gid=1000,rsize=131072,wsize=131072 192.168.1.50:/volume1/video /mnt/video
```

### 3. DOCKER: Container Configuration

#### Current Setup (compose.yml)
```yaml
qbittorrent:
  environment:
    - PUID=1000  # ✓ Already correct
    - PGID=1000  # ✓ Already correct
  volumes:
    - /mnt/video:/emma  # Mount point
```

#### Alternative: User Namespace Remapping
```yaml
qbittorrent:
  user: "1000:1000"  # Force container user
  environment:
    - PUID=1000
    - PGID=1000
```

## Step-by-Step Implementation

### Phase 1: Synology NFS Configuration

1. **Login to DSM Web Interface**
2. **Navigate to Control Panel > File Services**
3. **Enable NFS Service** (if not already enabled)
4. **Go to Shared Folder > video > Edit**
5. **Click NFS Permissions tab**
6. **Add/Edit NFS Rule:**
   - **Hostname**: `192.168.1.0/24` or `*`
   - **Privilege**: Read/Write
   - **Squash**: Map all users to admin
   - **Security**: sys
   - **Enable async**: Yes
   - **Allow connections from non-privileged ports**: Yes

### Phase 2: Host Mount Configuration

1. **Backup current fstab:**
   ```bash
   sudo cp /etc/fstab /etc/fstab.backup
   ```

2. **Edit fstab:**
   ```bash
   sudo vim /etc/fstab
   ```

3. **Add/modify NFS entry:**
   ```
   192.168.1.50:/volume1/video /mnt/video nfs4 rw,vers=4.1,rsize=131072,wsize=131072,hard,proto=tcp,timeo=600,retrans=2,sec=sys,uid=1000,gid=1000,_netdev 0 0
   ```

4. **Test mount:**
   ```bash
   sudo umount /mnt/video
   sudo mount -a
   ```

### Phase 3: Validation

1. **Run permission test:**
   ```bash
   ./scripts/test-nfs-permissions.sh qbittorrent
   ```

2. **Manual verification:**
   ```bash
   stat -c "%u:%g %n" /mnt/video
   # Should show: 1000:1000 /mnt/video
   ```

3. **Container test:**
   ```bash
   docker exec qbittorrent stat -c "%u:%g %n" /emma
   # Should show: 1000:1000 /emma
   ```

## Advanced Solutions

### NFSv4 ID Mapping (if basic solutions fail)

1. **Configure idmapd on host:**
   ```bash
   sudo vim /etc/idmapd.conf
   ```
   ```ini
   [General]
   Domain = localdomain

   [Mapping]
   Nobody-User = nobody
   Nobody-Group = nogroup
   ```

2. **Restart idmapd:**
   ```bash
   sudo systemctl restart nfs-idmapd
   ```

### Synology User Creation (Alternative)

1. **Create matching user on Synology:**
   ```bash
   # On Synology DSM
   sudo synouser --add delorenj --pwd [password] --uid 1000 --gid 1000
   ```

2. **Set folder ownership:**
   ```bash
   sudo chown -R delorenj:users /volume1/video
   ```

## Prevention Guidelines

### ❌ NEVER DO THESE ON SYNOLOGY:
- Modify `/etc/passwd` directly
- Use `usermod` commands
- Edit system user files manually
- Force UID changes on system users

### ✅ ALWAYS USE THESE METHODS:
- DSM Control Panel for user management
- `synouser` command for user operations
- DSM NFS permissions interface
- Standard mount options on client side

## Troubleshooting Common Issues

### Issue: "Permission Denied" after mount
**Solution**: Check NFS service is running on Synology
```bash
# On Synology
sudo synoservice --status nfsd
sudo synoservice --restart nfsd
```

### Issue: Files still show wrong ownership
**Solution**: Clear NFS cache and remount
```bash
sudo umount /mnt/video
sudo mount -a
```

### Issue: Container can't write to NFS mount
**Solutions**:
1. Check NFS export has `rw` permission
2. Verify container PUID/PGID environment variables
3. Test with `docker exec container touch /emma/test.txt`

## Monitoring and Maintenance

### Daily Checks
```bash
# Add to crontab for monitoring
*/30 * * * * /home/delorenj/docker/trunk-main/stacks/media/scripts/test-nfs-permissions.sh qbittorrent > /var/log/nfs-check.log 2>&1
```

### Log Analysis
```bash
# NFS client logs
sudo journalctl -u nfs-client.target

# Mount status
mount | grep nfs
```

## Reference Commands

### Synology Commands
```bash
# List NFS exports
sudo synonfs --export-list

# Check NFS service
sudo synoservice --status nfsd

# View current exports
sudo cat /etc/exports
```

### Client Commands
```bash
# Check mount options
mount | grep /mnt/video

# Test NFS connection
showmount -e 192.168.1.50

# NFS statistics
nfsstat
```

---

**SUCCESS CRITERIA**: After implementation, `stat -c "%u:%g" /mnt/video` should return `1000:1000`