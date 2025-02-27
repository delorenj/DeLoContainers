# Radarr

Radarr is an automated movie downloading and management tool. It integrates with various download clients and media servers to help you organize and maintain your movie collection.

## Configuration

- Container: linuxserver/radarr:latest
- Port: 7878
- Network: Uses gluetun VPN network
- Access URL: https://movies.delo.sh or https://movies.delorenzo.family

## Volume Mappings

- `/config`: Container config files
- `/downloads`: Download directory (shared with qBittorrent)
- `/video`: Media library location

## Integration Points

- Prowlarr: Used as indexer
- qBittorrent: Used as download client
- Both run through gluetun VPN

## Updates

### 2024-01-09
- Initial setup with basic configuration
- Added to media stack
- Configured with Traefik for HTTPS access
