# Media Stack

Media download and management services behind VPN.

## Components
- Gluetun: VPN container
- Prowlarr: Indexer management
- qBittorrent: Download client
- Radarr: Movie management

## Network
All services inherit network from gluetun container

## Volumes
- Downloads: Shared between qBittorrent and *arr services
- Config: Individual per service