# Service Directory

## Service Name to Compose File Mapping

| Service Name | Compose File Path |
|--------------|------------------|
| portainer | core/portainer/compose.yml |
| traefik | core/traefik/traefik-data/traefik.yml |
| librechat | stacks/ai/LibreChat/docker-compose.yml |
| litellm | stacks/ai/litellm/config.yaml |
| jellyfin | stacks/media/compose.yml |
| prowlarr | stacks/media/compose.yml |
| qbittorrent | stacks/media/compose.yml |
| radarr | stacks/media/compose.yml |
| exportarr | stacks/media/exportarr/docker-compose.yml |
| gluetun | stacks/media/compose.yml |
| couchdb | stacks/utils/couchdb/compose.yml |
| monitoring | stacks/utils/compose.yml |

## Stack Name to Compose File Mapping

| Stack Name | Compose File Path |
|------------|------------------|
| core | core/compose.yml |
| ai | stacks/ai/LibreChat/docker-compose.yml |
| media | stacks/media/compose.yml |
| utils | stacks/utils/compose.yml |