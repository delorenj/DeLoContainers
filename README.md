# DeLoContainers

Docker stack configurations for DeLoNET infrastructure.

## Structure
```
core/               # Required infrastructure
  ├── squid/       # Network proxy
  ├── traefik/     # Reverse proxy
  └── portainer/   # Container management

stacks/             # Supplementary services
  ├── media/       # Media management
  │   ├── gluetun
  │   ├── prowlarr
  │   ├── qbittorrent
  │   └── radarr
  ├── utils/       # Utility services
  │   ├── couchdb
  │   ├── marker
  │   └── scripts
  └── ai/          # AI services
      ├── LibreChat
      └── litellm
```

## Auto-Deployment

Stacks auto-deploy on push to main:
1. Core stacks deploy first (required for remote access)
2. Supplementary stacks deploy after core success

Required GitHub Secrets:
- HOST: Target server IP/hostname
- USERNAME: SSH username
- SSH_KEY: SSH private key

### Manual Deployment
```bash
cd stack_directory
docker compose up -d
```

## Adding New Stacks
1. Choose location:
   - core/: Required infrastructure
   - stacks/: Supplementary services
2. Add compose.yml
3. Include README.md
4. Push to main