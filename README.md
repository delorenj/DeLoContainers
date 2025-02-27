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
- FlareSolverr
- Jellyfin


### Utils Stack
Located in `stacks/utils/`
- CouchDB
- Marker
- Monitoring
- Scripts

## Getting Started

1. Copy `.env.example` to `.env` and configure your environment variables

> TODO

## Configuration

Each stack has its own `compose.yml` file and README with specific configuration details. Please refer to individual stack documentation for detailed setup instructions.

## Maintenance

> TODO

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Tasks

- health: Simple health status report for each compose.yml file in the stacks directory.
