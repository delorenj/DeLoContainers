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
- **Web UI**: http://localhost:8080
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
