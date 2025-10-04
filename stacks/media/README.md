# Media Stack

This stack provides media management services including torrent management and indexing.

## Services

### Prowlarr
- **Purpose**: Indexer manager/proxy for various torrent sites
- **Web UI**: http://localhost:9696
- **Configuration**: Located in `prowlarr/` directory
- **Dependencies**: None

### qBittorrent
- **Purpose**: Torrent client
- **Web UI**: http://localhost:8091
- **Configuration**: Located in `qbittorrent/` directory
- **Dependencies**: Gluetun (VPN)
- **Default Login**: 
  - Username: admin
  - Password: adminadmin

### Gluetun
- **Purpose**: VPN container for secure torrenting
- **Configuration**: Located in `gluetun/` directory
- **Dependencies**: None
- **Important Files**:
  - `netherlands.ovpn`: OpenVPN configuration
  - `servers.json`: VPN server list

## Environment Variables

Required environment variables (defined in root `.env`):
- `VPN_SERVICE_PROVIDER`: Your VPN provider
- `OPENVPN_USER`: VPN username
- `OPENVPN_PASSWORD`: VPN password
- `SERVER_COUNTRIES`: Preferred VPN server countries

## Volumes

### Prowlarr
- `./prowlarr:/config`: Configuration files

### qBittorrent
- `./qbittorrent:/config`: Configuration files
- `/downloads:/downloads`: Download directory

### Gluetun
- `./gluetun:/gluetun`: VPN configuration

## Network

All services are on the same Docker network. qBittorrent traffic is routed through Gluetun VPN container.

## Permissions & NFS

- Verify the host user ID matches the expected compose values: `id delorenj` should report `uid=1000 gid=1000`.
- Run `./scripts/fix-qbittorrent-permissions.sh` to align ownership for the downloads directories and the qBittorrent config using the values in `.env`.
- Mount the NAS share with: `192.168.1.50:/volume1/video /mnt/video nfs4 rw,vers=4.1,rsize=131072,wsize=131072,hard,proto=tcp,timeo=600,retrans=2,sec=sys,_netdev 0 0` in `/etc/fstab` (adjust host paths if needed).
- Validate the NFS share and container permissions end-to-end with `./scripts/test-nfs-permissions.sh qbittorrent`; the script reports mismatched UID/GID values or read/write failures with remediation hints.

## Maintenance

1. Regular Updates
   ```bash
   docker-compose pull
   docker-compose up -d
   ```

2. Backup Configurations
   ```bash
   ./scripts/backup.sh media
   ```

## Troubleshooting

### VPN Issues
1. Check Gluetun logs:
   ```bash
   docker-compose logs gluetun
   ```
2. Verify OpenVPN credentials in `.env`
3. Try different VPN server from `servers.json`

### qBittorrent Issues
1. Ensure Gluetun container is running
2. Check port forwarding settings
3. Verify network settings in qBittorrent configuration

### Prowlarr Issues
1. Check indexer configuration
2. Verify API keys
3. Ensure network connectivity
