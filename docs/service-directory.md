# Service Directory

## Core Infrastructure

### Traefik
- **URL**: traefik.delo.sh
- **Description**: Reverse proxy and SSL termination
- **Ports**: 80 (HTTP), 443 (HTTPS), 8080 (Dashboard)
- **Features**: 
  - SSL certificate management
  - Service discovery
  - Metrics collection

### Portainer
- **Description**: Container management interface
- **Features**:
  - Container deployment
  - Stack management
  - Resource monitoring

## AI Services

### LiteLLM
- **Port**: 4000
- **Description**: LLM model serving proxy
- **Features**:
  - Model management via UI
  - PostgreSQL backend
  - API access

### Qdrant
- **URL**: qdrant.delo.sh
- **Ports**: 6333 (REST), 6334 (gRPC)
- **Description**: Vector database
- **Features**:
  - Persistent storage
  - REST and gRPC APIs
  - SSL-protected access

## Media Services

### Jellyfin
- **URL**: jelly.delo.sh, jelly.delorenzo.family
- **Port**: 8096
- **Description**: Media server
- **Features**:
  - Video streaming
  - Media library management
  - Multi-user support

### Radarr
- **URL**: movies.delo.sh, movies.delorenzo.family
- **Port**: 7878
- **Description**: Movie collection manager
- **Features**:
  - Automated movie downloads
  - Library management
  - Quality management

### Prowlarr
- **URL**: index.delo.sh, index.delorenzo.family
- **Port**: 9696
- **Description**: Indexer manager
- **Features**:
  - Indexer aggregation
  - Search provider management
  - API integration

### qBittorrent
- **URL**: get.delo.sh, get.delorenzo.family
- **Port**: 8090
- **Description**: Download client
- **Features**:
  - VPN protected
  - Web interface
  - Download management

### FlareSolverr
- **URL**: flaresolverr.delo.sh, flaresolverr.delorenzo.family
- **Port**: 8191
- **Description**: Cloudflare challenge solver
- **Features**:
  - Automated challenge solving
  - API access
  - Headless operation

## Monitoring

### Exportarr
- **URL**: metrics.prowlarr.delo.sh
- **Port**: 9710
- **Description**: Prowlarr metrics exporter
- **Features**:
  - Prometheus metrics
  - System monitoring
  - API status tracking

### VPN Monitor
- **Description**: VPN connection monitor
- **Features**:
  - Connection status checking
  - Metrics generation
  - Health monitoring

## Network Security

### Gluetun
- **Description**: VPN client
- **Features**:
  - OpenVPN support
  - Netherlands endpoint
  - Port forwarding
  - Network isolation

## Access Information

All services are:
- Protected by SSL certificates
- Accessible via both delo.sh and delorenzo.family domains (where applicable)
- Behind Traefik reverse proxy
- Part of the shared proxy network

## Storage

Common storage paths:
- Downloads: ${DOWNLOAD_PATH}
- Video content: ${VIDEO_PATH}
- Service configs: ./servicename/config
