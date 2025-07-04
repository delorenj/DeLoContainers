# Portainer CE

Portainer Community Edition - A lightweight Docker management UI.

## Access

- Web UI: https://docker.${DOMAIN} or https://docker.delorenzo.family (HTTPS via Traefik reverse proxy)

## Features

- Container management
- Volume management
- Network configuration
- Docker Swarm management (if enabled)
- Image management
- Registry management

## First Time Setup

1. After starting the container, navigate to https://docker.${DOMAIN}
2. Create your initial admin user
3. Choose "Docker" as the environment type
4. Start managing your containers!

## Security Notes

- The container runs with no-new-privileges security option
- Docker socket is mounted read-only
- Uses named volume for persistent data
- HTTPS enabled by default on port 9443

## Maintenance

- Backup the `/data` directory to preserve your settings
- Updates can be performed by pulling the latest image and recreating the container
