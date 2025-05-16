# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# DeLoContainers Commands & Guidelines

## Commands
- `just service-map` - Display service directory structure
- `just health` - Check health status of all stacks
- `docker compose -f <stack>/compose.yml up -d` - Start a stack
- `docker compose -f <stack>/compose.yml down` - Stop a stack
- `docker compose -f <stack>/compose.yml logs` - View stack logs
- `mise run up <stack>` - Start a specific stack
- `mise run logs <stack>` - View logs for a stack
- `mise run update <stack>` - Update a stack

## Stack Structure Guidelines
- Each stack should follow template in `scripts/init-stack.sh`
- Stack types: media, ai, proxy, utils
- Each service requires README.md with documentation
- Use environment variables in .env files for configuration
- Follow directory structure: config/, data/, scripts/

## Code Style
- YAML indentation: 2 spaces
- Use standard Docker Compose v3.8+ syntax
- Document ports and configurations in README.md
- Use Traefik labels for service discovery
- Use linuxserver images when possible

## Traefik Reverse Proxy Architecture
The Traefik stack serves as the main reverse proxy and SSL termination point for all services in the infrastructure.

### Key Files
- `/core/traefik/compose.yml` - Main docker compose configuration
- `/core/traefik/traefik-data/traefik.yml` - Static Traefik configuration (requires restart)
- `/core/traefik/traefik-data/dynamic/config.yml` - Dynamic configuration (auto-reloaded)
- `/core/traefik/traefik-data/acme.json` - Let's Encrypt certificates storage

### Network Configuration
- External network: `proxy` (all services connect to this)
- Ports: 80 (HTTP), 443 (HTTPS), 8099 (Dashboard)
- SSL certificates automatically managed via Let's Encrypt
- HTTP traffic auto-redirected to HTTPS

### Service Integration
All services require Traefik labels in their compose.yml:
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.<service-name>.entrypoints=websecure"
  - "traefik.http.routers.<service-name>.rule=Host(`<service>.<domain>`)"
  - "traefik.http.routers.<service-name>.tls.certresolver=letsencrypt"
  - "traefik.http.services.<service-name>.loadbalancer.server.port=<port>"
```

### Middleware
- Basic authentication middleware available (`auth@file`)
- Defined in `/traefik-data/dynamic/config.yml`
- Applied to protected services like the Traefik dashboard