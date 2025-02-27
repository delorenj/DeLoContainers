# Core Infrastructure

This directory contains the core infrastructure services that support the entire stack.

## Services

### Traefik
- Reverse proxy and SSL termination
- Configuration in `./traefik/`
- Handles routing and SSL for all services

### Portainer
- Container management interface
- Configuration in `./portainer/`
- Used for monitoring and managing containers

## Network Architecture

The core infrastructure establishes a shared `proxy` network that other services connect to for communication. This network is created as external and is used by all stacks for service discovery and routing.

## Configuration

The main `compose.yml` includes:
- Traefik configuration
- Portainer setup
- Shared network definition

## Security

- SSL termination handled by Traefik
- Basic authentication for admin interfaces
- Automatic certificate management via Let's Encrypt

## Maintenance

When adding new services:
1. Connect them to the `proxy` network
2. Add appropriate Traefik labels for routing
3. Use SSL where possible
4. Follow the established naming conventions

## Monitoring

- Traefik dashboard available at traefik.delo.sh
- Prometheus metrics enabled for monitoring
- Container status visible in Portainer
