# Build/Test Commands
## Core Commands
- `mise run dev:start` - Start all media services
- `mise run dev:restart` - Restart all services
- `mise run deploy:stop` - Stop all services
- `mise run deployment:update` - Update all container images

## Testing
- `mise run test:troubleshoot` - Run comprehensive troubleshooting
- `mise run test:vpn-logs` - Check VPN connectivity logs

## Maintenance
- `mise run clean` - Clean up qBittorrent (remove stale torrents, fix permissions)
- `mise run status` - Show service and VPN status
- `mise run logs` - Show recent logs

# Code Style Guidelines
## Shell Scripts
- Use `#!/usr/bin/env bash` shebang
- Use `set -euo pipefail` for error handling
- Use descriptive variable names in UPPER_CASE
- Quote all variables: `$VAR`, not $VAR
- Use `echo -e` for colored output, no emojis

## Docker Compose
- Use `restart: unless-stopped` for services
- Prefer environment variables over hardcoded values
- Use descriptive container names
- Document network dependencies in compose.yml

## Environment Variables
- Keep secrets in `.env` file, never in code
- Use descriptive names like `VPNAC_USER`
- Group related variables together

## Naming Conventions
- Container names: lowercase, descriptive (qbittorrent, gluetun)
- Directories: lowercase with hyphens for multi-word (media-stack)
- Environment vars: UPPER_CASE with underscores

## Error Handling
- Always check return codes: `command || error_handler`
- Provide meaningful error messages
- Use `trap` for cleanup on script exit</content>
<parameter name="file_path">CRUSH.md