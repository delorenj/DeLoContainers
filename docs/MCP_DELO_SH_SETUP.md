# MetaMCP (mcp.delo.sh) Setup Documentation

## Problem Summary
MetaMCP at mcp.delo.sh repeatedly experiences configuration issues after updates, particularly with:
- Network configuration (proxy vs metamcp_network)
- Environment variables (BETTER_AUTH_SECRET, APP_URL, DATABASE_URL)
- Port mapping (app runs on 12009, not 3000)
- AdGuard catch-all behavior (not blocking, just catching missing routes)

## Working Configuration

### Key Facts
1. **Network**: Must use `proxy` network (external), NOT `metamcp_network`
2. **Port**: Application runs on port **12009**, not 3000
3. **Image**: Use pre-built `delorenj/metamcp:latest` for stability
4. **Traefik**: Routes via Docker labels, no port exposure needed

### Current Working Setup

The working configuration is in `/home/delorenj/code/utils/metamcp/compose.yml`:

```yaml
services:
  metamcp:
    image: delorenj/metamcp:latest  # Pre-built stable image
    container_name: metamcp
    restart: unless-stopped
    environment:
      - NODE_ENV=production
      - DATABASE_URL=postgresql://postgres:postgres@postgres:5432/metamcp
      - BETTER_AUTH_SECRET=95f815281b98c36acdb205414d6f9babec8acef5e2d4feeda5ec5b80043d0f7e
      - APP_URL=https://mcp.delo.sh
      - NEXT_PUBLIC_APP_URL=https://mcp.delo.sh
    # NO ports exposed - Traefik handles routing
    depends_on:
      - postgres
    networks:
      - proxy  # MUST be proxy network
    labels:
      # Traefik configuration
      - "traefik.enable=true"
      - "traefik.docker.network=proxy"
      - "traefik.http.services.metamcp.loadbalancer.server.port=12009"  # Port 12009!
      - "traefik.http.routers.metamcp.rule=Host(`mcp.delo.sh`)"
      - "traefik.http.routers.metamcp.entrypoints=websecure"
      - "traefik.http.routers.metamcp.tls.certresolver=letsencrypt"
    # Resource limits to prevent memory leaks
    mem_limit: 4g
    memswap_limit: 4g
    cpus: 2.0
    pids_limit: 25

  postgres:
    image: postgres:15-alpine
    container_name: metamcp-postgres
    restart: unless-stopped
    environment:
      - POSTGRES_DB=metamcp
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - proxy

volumes:
  postgres_data:

networks:
  proxy:
    external: true  # Uses existing Traefik proxy network
```

### Critical Environment Variables

These MUST be set correctly or the container will crash-loop:

```bash
DATABASE_URL=postgresql://postgres:postgres@postgres:5432/metamcp
BETTER_AUTH_SECRET=95f815281b98c36acdb205414d6f9babec8acef5e2d4feeda5ec5b80043d0f7e
APP_URL=https://mcp.delo.sh
NEXT_PUBLIC_APP_URL=https://mcp.delo.sh
```

## Common Issues and Solutions

### 1. "metamcp_network not found"
**Solution**: Change to `proxy` network (external: true)

### 2. Container crash-looping
**Check**:
- Missing BETTER_AUTH_SECRET
- Missing APP_URL
- Wrong DATABASE_URL
- Database schema not initialized

**Solution**: Ensure all environment variables are set correctly

### 3. Traefik not routing / 502 Bad Gateway
**Solution**:
- Confirm `traefik.http.services.metamcp.loadbalancer.server.port=12009`
- NOT port 3000!

### 4. AdGuard showing instead of app
**Reality**: AdGuard is a catch-all for missing routes, NOT blocking
**Check**:
- Container is running: `docker ps | grep metamcp`
- Logs: `docker logs metamcp`
- Traefik routing: Labels must be exactly as shown above

### 5. Memory leaks / Process explosion
**Solution**: Resource limits are already in compose.yml:
- `mem_limit: 4g`
- `pids_limit: 25` (prevents process explosion)

## Deployment Commands

```bash
# Navigate to MetaMCP directory
cd /home/delorenj/code/utils/metamcp

# Deploy with the working configuration
docker-compose -f compose.yml up -d

# Check status
docker ps | grep metamcp

# View logs if issues
docker logs metamcp

# Test the endpoint
curl -I https://mcp.delo.sh
```

## What NOT to Do

1. **Don't use docker-compose.production.yml** - It has database/env issues
2. **Don't change network from `proxy`** - Traefik won't work
3. **Don't expose ports** - Let Traefik handle routing
4. **Don't set port to 3000** - App runs on 12009
5. **Don't assume AdGuard is blocking** - It's just a catch-all

## Verification

When working correctly:
1. `curl -I https://mcp.delo.sh` returns 307 redirect to `/en/`
2. Browser shows MetaMCP interface with sidebar navigation
3. No AdGuard catch-all page
4. Container stays running (not restarting)

## Memory Leak Prevention

The configuration includes built-in memory leak prevention:
- Memory limit: 4GB
- PID limit: 25 processes max
- Auto-restart on failure
- Resource monitoring via Docker

## GitHub Repository

Fixes have been committed to: https://github.com/delorenj/metamcp
- Commit 8a64c77: Added memory leak prevention configuration
- Commit cf19dad: Documented memory leak fixes

## Quick Recovery

If mcp.delo.sh stops working again:
1. Use this exact compose.yml configuration
2. Ensure proxy network exists
3. Set all environment variables
4. Use port 12009 in Traefik label
5. Deploy with: `docker-compose -f compose.yml up -d`