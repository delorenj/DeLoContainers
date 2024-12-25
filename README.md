# DeLoContainers

This repository contains a collection of Docker containers organized into different stacks for various purposes.

## Directory Structure

```
.
├── stacks/
│   ├── ai/         # AI-related services
│   ├── media/      # Media management services
│   ├── proxy/      # Reverse proxy and networking
│   └── utils/      # Utility services
```

## Stack Overview

### Media Stack
Located in `stacks/media/`
- Prowlarr
- qBittorrent
- Gluetun (VPN)

### Proxy Stack
Located in `stacks/proxy/`
- Traefik (Reverse Proxy)

### Utils Stack
Located in `stacks/utils/`
- CouchDB
- Marker

## Getting Started

1. Copy `.env.example` to `.env` and configure your environment variables
2. Use the provided scripts in `scripts/` directory for common operations:
   - `init-stack.sh`: Initialize new stack
   - `backup.sh`: Backup configurations
   - `prune.sh`: Clean up unused Docker resources
   - `traefik.sh`: Manage Traefik configuration
   - `vpn.sh`: VPN management

## Configuration

Each stack has its own `compose.yml` file and README with specific configuration details. Please refer to individual stack documentation for detailed setup instructions.

## Maintenance

Regular maintenance tasks:
1. Run `scripts/backup.sh` to backup configurations
2. Run `scripts/prune.sh` to clean up unused Docker resources
3. Check logs in `logs/` directory for any issues

## Contributing

1. Create a new branch for your changes
2. Follow the existing directory structure
3. Update documentation accordingly
4. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
