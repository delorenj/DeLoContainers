# Websites Stack

This stack contains web applications and services that provide user-facing interfaces and APIs.

## Services

### Concierge AI Gateway
- **URL**: https://concierge.delo.sh
- **Description**: AI-powered gateway service for LLM interactions and agent orchestration
- **Features**:
  - Health monitoring and status checks
  - LLM proxy to OpenRouter
  - WebSocket support for real-time communication
  - API key authentication
  - CORS-enabled for web clients

### AI Learning Hub (Symlinked)
- **Description**: Educational platform for AI/ML learning
- **Status**: Symlinked to external repository

## Quick Start

```bash
# Deploy all website services
cd /home/delorenj/docker/stacks/websites
docker compose up -d

# Deploy individual services
cd /home/delorenj/docker/stacks/websites/concierge
docker compose up -d
```

## Configuration

Environment variables are loaded from the main `.env` file in the docker root directory.

### Required Environment Variables

```bash
# Concierge Service
CONCIERGE_API_KEY=your-secure-api-key
OPENROUTER_API_KEY=your-openrouter-key

# Domain Configuration
DOMAIN=delo.sh
```

## Service URLs

| Service | URL | Authentication |
|---------|-----|----------------|
| Concierge | https://concierge.delo.sh | API Key |
| AI Learning Hub | (External) | - |

## Testing

Each service includes its own testing utilities:

```bash
# Test Concierge service
cd concierge && ./test.sh

# Use web-based test client
open concierge/test-client.html
```

## Monitoring

- Health checks are configured for all services
- Traefik provides SSL termination and load balancing
- Container health status available via Docker

## Development

1. **Adding New Services**:
   - Create service directory under `stacks/websites/`
   - Add service configuration to main `compose.yml`
   - Create Traefik dynamic configuration if needed
   - Update this README

2. **Service Requirements**:
   - Must include health check endpoint
   - Should use Traefik labels for routing
   - Must connect to `proxy` network
   - Should include proper restart policies

## Architecture

```
┌─────────────────┐    ┌──────────────┐    ┌─────────────────┐
│   Internet      │───▶│   Traefik    │───▶│   Concierge     │
│                 │    │   (SSL/LB)   │    │   Gateway       │
└─────────────────┘    └──────────────┘    └─────────────────┘
                              │
                              ▼
                       ┌──────────────┐
                       │ Other Web    │
                       │ Services     │
                       └──────────────┘
```

## Security

- All services use SSL/TLS via Traefik
- API key authentication where applicable
- CORS configuration for web clients
- Environment variable-based secrets

## Troubleshooting

### Common Issues

1. **Service not accessible**: Check Traefik configuration and DNS
2. **Environment variables not loaded**: Verify `.env` symlink exists
3. **SSL certificate issues**: Check Let's Encrypt configuration
4. **Container health failures**: Review service logs and health check endpoints

### Useful Commands

```bash
# Check service status
docker compose ps

# View service logs
docker compose logs -f [service_name]

# Restart services
docker compose restart [service_name]

# Update and redeploy
docker compose pull && docker compose up -d
```
