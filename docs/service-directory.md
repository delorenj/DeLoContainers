# Service Directory

## Stack to Compose File Mapping

| Stack Name | Compose File Path |
|------------|------------------|
| [core](#core-services) | core/compose.yml |
| [ai](#ai-services) | stacks/ai/LibreChat/docker-compose.yml |
| [media](#media-services) | stacks/media/compose.yml |
| [utils](#utils-services) | stacks/utils/compose.yml |

## Service to Compose File Mapping

### Core Services

| Service Name | Compose File Path |
|--------------|------------------|
| portainer | core/portainer/compose.yml |
| traefik | core/traefik/traefik-data/traefik.yml |

### AI Services

| Service Name | Compose File Path |
|--------------|------------------|
| librechat | stacks/ai/LibreChat/docker-compose.yml |
| litellm | stacks/ai/litellm/config.yaml |

### Media Services

| Service Name | Compose File Path |
|--------------|------------------|
| jellyfin | stacks/media/compose.yml |
| prowlarr | stacks/media/compose.yml |
| qbittorrent | stacks/media/compose.yml |
| radarr | stacks/media/compose.yml |
| exportarr | stacks/media/exportarr/docker-compose.yml |
| gluetun | stacks/media/compose.yml |

### Utils Services

| Service Name | Compose File Path |
|--------------|------------------|
| couchdb | stacks/utils/couchdb/compose.yml |
| monitoring | stacks/utils/compose.yml |