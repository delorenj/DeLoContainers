# Service Map

This document maps the relationships between stacks, compose files, services, and their reverse proxy URLs. This will be helpful for debugging and the upcoming migration from dynamic traefik configs to service labels.

## Proxy Stack
**Compose File:** `stacks/proxy/compose.yml`
- traefik

## Media Stack 
**Compose File:** `stacks/media/compose.yml`

VPN Gateway:
- gluetun
- vpn-monitor (depends on gluetun)

VPN Clients:
- qbittorrent (via gluetun)
- prowlarr (via gluetun)
- jellyfin (via gluetun)
- flaresolverr (via gluetun)

Other:
- exportarr (depends on prowlarr, gluetun)

## Monitoring Stack
**Compose File:** `stacks/utils/monitoring/compose.yml`
- prometheus
- grafana (depends on prometheus, loki)
- loki
- promtail (depends on loki)
- node-exporter
- cadvisor

## Utils Stack
**Compose File:** `stacks/utils/compose.yml`
- portainer
- couchdb

### Scripts Service
**Compose File:** `stacks/utils/scripts/compose.yml`
- scripts
  - URL: sh.delo.sh

## AI Stack
**Compose File:** `stacks/ai/compose.yml`
- ai_db
- weaviate
- litellm
- bolt
  - URL: ai.delo.sh (proxied to 100.116.213.108:1234)

## Network Configuration
All services are connected to the `proxy` network bridge and use common configuration:
- restart: unless-stopped
- security_opt: no-new-privileges:true

## VPN Configuration
Services using gluetun:
- Use network_mode: "service:gluetun"
- Inherit PUID, PGID, TZ environment variables
- Depend on gluetun service

## Traefik Configuration
### Current Middleware (To be migrated to labels)
- **auth**: Basic authentication middleware
- **securityHeaders**: Security-related HTTP headers
  - STS configuration
  - XSS protection
  - Content type security
  - Frame options
  - Subdomains and preload settings

## Notes
- This service map will be updated during the migration from dynamic traefik configs to service labels
- All reverse proxy configurations will be moved to labels in their respective compose service definitions
- Middleware configurations will be converted to service-specific labels where needed
