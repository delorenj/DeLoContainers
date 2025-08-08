# qBittorrent Infrastructure Research Findings

## Current Configuration Analysis

### Environment Variables (.env file)
- **PUID**: 502
- **PGID**: 20
- **Location**: `/home/delorenj/DevCloud/docker-dotfiles/.env`

### Host System User
- **delorenj UID**: 1000
- **delorenj GID**: 1000
- **Groups**: docker, sudo, others

### Container Configuration (compose.yml)
```yaml
qbittorrent:
  image: linuxserver/qbittorrent:latest
  container_name: qbittorrent
  restart: unless-stopped
  network_mode: "service:gluetun"
  environment:
    - WEBUI_PORT=8091
    - PUID=${PUID}  # Currently 502
    - PGID=${PGID}  # Currently 20
  volumes:
    - ./qbittorrent:/config
    - ./downloads:/downloads:cached
    - emma_video:/video:cached
    - ./home/delorenj/Videos/tonny:/tonny:cached
```

## Permission Issues Identified

### 🚨 ROOT CAUSE: UID/GID Mismatch
- **Container PUID**: 502 (from .env)
- **Container PGID**: 20 (from .env)
- **Host User**: 1000:1000 (delorenj)
- **Config Directory Ownership**: 502:dialout (created by container)

### Host Directory Permissions
```
/home/delorenj/docker/trunk-main/stacks/media/qbittorrent/
├── Owner: 502:dialout (container user)
├── Host user delorenj (1000:1000) cannot write
└── Files created by container with wrong ownership
```

### Downloads Directory
```
/home/delorenj/docker/trunk-main/stacks/media/downloads/
├── Empty directory
├── Owner: 502:dialout
└── Inaccessible to host user
```

### NFS Volume Status
- **emma_video**: Properly mounted NFS volume to 192.168.1.50:/volume1/video
- **Container Access**: ✅ Working - can see video files
- **Host Access**: ❌ Limited - NFS volume not directly accessible from host
- **Video files**: Various movies/shows with mixed ownership (911:1001, 1024:qbittorrent, etc.)

## Container Logs Analysis
- **Status**: Container running successfully
- **WebUI**: Accessible on port 8091
- **VPN**: Using gluetun with tun0 interface
- **No Permission Errors**: Container itself works fine, but host cannot manage files

## Configuration Issues

### qBittorrent.conf Settings
- **DefaultSavePath**: `/video` (NFS mount - ✅ Good)
- **TempPath**: `/downloads` (local directory - ❌ Wrong ownership)
- **WebUI Port**: 8091 (✅ Working)
- **VPN Bind**: tun0 interface (✅ Working)

### Path Mapping Problems
1. **Download Path**: Maps to local directory with wrong ownership
2. **Video Path**: Maps to NFS with mixed file ownership
3. **Config Path**: Host user cannot modify qBittorrent settings files

## Recommendations

### 1. Fix UID/GID Mismatch (CRITICAL)
```env
# Change in .env file:
PUID=1000  # Match host user delorenj
PGID=1000  # Match host user delorenj
```

### 2. Fix Existing Directory Ownership
```bash
# After changing PUID/PGID, fix ownership:
sudo chown -R 1000:1000 /home/delorenj/docker/trunk-main/stacks/media/qbittorrent/
sudo chown -R 1000:1000 /home/delorenj/docker/trunk-main/stacks/media/downloads/
```

### 3. Container Recreation Required
- Must recreate container after PUID/PGID changes
- Existing files will need ownership correction

### 4. NFS Mount Considerations
- NFS files show mixed ownership (likely from different systems)
- May need NFS client mapping configuration
- Consider uid/gid mapping options in NFS mount

## Impact Assessment

### Current Problems
- Host user cannot manage downloaded files
- Cannot modify qBittorrent configuration files from host
- File organization and cleanup requires sudo access
- Backup and migration complications

### Post-Fix Benefits
- Direct file access and management from host
- Easier configuration management
- Simplified backup procedures
- Better integration with host file system

## Next Steps
1. Update .env file with correct PUID/PGID values
2. Stop qBittorrent container
3. Fix directory ownership
4. Recreate container
5. Verify file permissions and functionality
6. Test download and file management workflows