# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

DeLoContainers is a personal Docker infrastructure project that manages multiple service stacks using Docker Compose. Services are organized by category (ai, media, monitoring, persistence, utils, websites) with core infrastructure services in the core directory.

## Common Development Commands

### Stack Management

```bash
# List all services with status indicators
just list-services

# Check health of all compose files
just health

# Restart a specific service
just restart <stack-name>

# Build service documentation map
just build-service-map

# Monitor stacks with automated system
sudo systemctl start docker-monitor
sudo systemctl status docker-monitor
```

### Docker Operations

```bash
# Start a stack
docker compose -f stacks/<category>/<service>/compose.yml up -d

# View logs for a service
docker compose -f stacks/<category>/<service>/compose.yml logs -f

# Stop and remove a stack
docker compose -f stacks/<category>/<service>/compose.yml down

# Pull latest images for a stack
docker compose -f stacks/<category>/<service>/compose.yml pull
```

### Testing & Development

```bash
# Validate a compose file
docker compose -f <path-to-compose.yml> config

# Check compose file syntax
docker compose -f <path-to-compose.yml> config --quiet

# Test service connectivity through Traefik
curl -H "Host: <service-name>.delo.sh" http://localhost
```

## Architecture & Structure

### Directory Layout

- `/core/` - Critical infrastructure (Traefik reverse proxy, Portainer management)
- `/stacks/` - Service categories:
  - `ai/` - AI/ML services (Flowise, LangFlow, n8n, etc.)
  - `media/` - Media servers and downloaders
  - `monitoring/` - System monitoring stack
  - `persistence/` - Databases and storage (PostgreSQL, Redis, Qdrant)
  - `utils/` - Utility services (AdGuard, Syncthing, etc.)
  - `websites/` - Web applications
- `/scripts/` - Management and automation scripts
- `/docs/` - Project documentation

### Key Architectural Decisions

1. **Single .env file**: All environment variables are centralized in the root .env file
2. **Traefik routing**: All services expose via `<service>.delo.sh` using Docker labels
3. **Shared proxy network**: All services join the `proxy` network for inter-service communication
4. **Stack monitoring**: Automated monitoring system (`stack-monitor.py`) manages service health
5. **No version key**: Compose files use v3.8+ syntax without the deprecated `version:` key

### Service Integration Pattern

When adding a new service:

1. Clone the service repo to `~/code/` if needed
2. Create directory: `stacks/<category>/<service-name>/`
3. Create `compose.yml` with:
   - Traefik labels for `<service>.delo.sh` routing
   - Connection to `proxy` network
   - Environment variables from root .env
   - LinuxServer images when available
4. Update `stack-config.yml` if monitoring is desired
5. Create humorous yet informative README.md

### Environment Configuration

The root `.env` file contains:

- Network settings (DOMAIN, TZ)
- User/permission settings (PUID, PGID)
- VPN configurations
- Service-specific API keys and credentials
- Path configurations for volumes

Additional secrets may be found in `~/.config/zshyzsh/secrets.zsh`

### Monitoring System

The project includes an automated monitoring system:

- Configuration in `stack-config.yml`
- Priority-based startup ordering
- Automatic recovery attempts
- Configurable intervals and retries
- Systemd service integration

## Important Conventions

1. **Compose files**: Always named `compose.yml` (not docker-compose.yml)
2. **YAML style**: 2-space indentation
3. **Service naming**: Use kebab-case for service names
4. **Traefik labels**: Follow the pattern in existing services
5. **Documentation**: Each service needs a snarky, humorous README.md
6. **Task runner**: Use `just` commands where possible instead of raw scripts

## Development Workflow

1. **Research phase**: Check GitHub for existing containers and alternatives
2. **Integration**: Clone repos to ~/code/, adapt for DeLoContainers standards
3. **Configuration**: Customize compose.yml, link to root .env
4. **Testing**: Validate compose file, test Traefik routing
5. **Documentation**: Create entertaining README.md with setup instructions

## SPARC Development (from global CLAUDE.md)

The project supports SPARC methodology for TDD with AI assistance:

```bash
npx claude-flow sparc modes
npx claude-flow sparc run <mode> "<task>"
npx claude-flow sparc tdd "<feature>"
```

## Notes

- Never include time estimations in planning or architecture discussions
- Update Taskmaster tasks immediately after addressing them
- Prefer editing existing files over creating new ones
- Only create documentation when explicitly requested

## Symlinked Dotfiles

The following dotfiles are symlinked to `/home/delorenj/docker-dotfiles`:

- `.env` → `/home/delorenj/docker-dotfiles/.env`

Created: 2025-07-04 09:03:59

## Symlinked Dotfiles

The following dotfiles are symlinked to `/home/delorenj/docker/trunk-main-dotfiles`:

- `.env` → `/home/delorenj/docker/trunk-main-dotfiles/.env`

Created: 2025-07-04 09:18:41
