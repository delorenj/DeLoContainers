# Traefik Configuration Architecture

## Overview
This document explains the Traefik v3 configuration structure and the relationship between different config files.

## Configuration Files

### 1. `compose.yml` (Docker Compose)
**Purpose**: Container orchestration and command-line flags
**Location**: `/home/delorenj/docker/trunk-main/core/traefik/compose.yml`

Contains:
- Container configuration (image, ports, volumes, networks)
- Environment variables for Cloudflare DNS challenge
- Docker labels for Traefik self-routing (traefik.delo.sh)
- Command-line flags that override static configuration

**Current configuration**:
```yaml
command:
  - "--configFile=/traefik.yml"
```

This tells Traefik to load its static configuration from `/traefik.yml` (mounted from `./traefik-data/traefik.yml`).

### 2. `traefik-data/traefik.yml` (Static Configuration)
**Purpose**: Core Traefik settings and providers
**Location**: `/home/delorenj/docker/trunk-main/core/traefik/traefik-data/traefik.yml`

Contains:
- API and dashboard configuration
- EntryPoints (web:80, websecure:443)
- Providers (Docker, File)
- Certificate resolvers (Let's Encrypt with Cloudflare DNS)
- Logging and metrics configuration

**Key sections**:
```yaml
api:
  dashboard: true
  insecure: true  # Allows access on port 8080

entryPoints:
  web:
    address: ":80"
    # Redirects HTTP to HTTPS
  websecure:
    address: ":443"

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: proxy
  file:
    directory: /dynamic
    watch: true

certificatesResolvers:
  letsencrypt:
    acme:
      dnsChallenge:
        provider: cloudflare
```

### 3. `traefik-data/dynamic/*.yml` (Dynamic Configuration)
**Purpose**: Route definitions and middleware for static services
**Location**: `/home/delorenj/docker/trunk-main/core/traefik/traefik-data/dynamic/`

Contains:
- HTTP routers for non-Docker services
- Services pointing to external IPs (e.g., 192.168.1.12)
- Middleware definitions (auth, headers, rate limiting)

**Example**: `traefik-dashboard.yml`
```yaml
http:
  routers:
    traefik-dashboard:
      rule: "Host(`traefik.delo.sh`)"
      service: api@internal
      entryPoints: [websecure]
      middlewares: [auth]
      tls:
        certResolver: letsencrypt
```

### 4. Docker Labels (Per-Container Configuration)
**Purpose**: Dynamic routing for Docker containers
**Location**: In each service's `compose.yml`

Example from metamcp:
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.metamcp.rule=Host(`mcp.delo.sh`)"
  - "traefik.http.routers.metamcp.entrypoints=websecure"
  - "traefik.http.services.metamcp.loadbalancer.server.port=12008"
```

## Configuration Hierarchy

1. **Command-line flags** (compose.yml) → Override everything
2. **Static configuration** (traefik.yml) → Loaded at startup
3. **Dynamic configuration**:
   - File provider (dynamic/*.yml) → Watched for changes
   - Docker provider (container labels) → Auto-discovered

## Why All Three Files Are Needed

### ❌ Not Duplicates - Each Serves a Purpose:

1. **compose.yml**:
   - Manages the Traefik container itself
   - Sets up volumes, networks, environment variables
   - Specifies which config file to use

2. **traefik.yml**:
   - Defines HOW Traefik operates (API, providers, entrypoints)
   - Cannot be changed without restart
   - Single source of truth for static config

3. **dynamic/*.yml**:
   - Defines WHAT Traefik routes (specific services)
   - Can be updated without restart (hot-reload)
   - Useful for services not in Docker

## Configuration Best Practices

### ✅ Do:
- Use `traefik.yml` for all static configuration
- Use only `--configFile=/traefik.yml` in compose.yml command
- Define routes in dynamic files for external services
- Use Docker labels for containerized services
- Enable API in traefik.yml, not via command-line flags

### ❌ Don't:
- Mix command-line flags with traefik.yml settings (flags override file)
- Put route definitions in traefik.yml
- Hardcode container IPs in dynamic configs (use Docker service names)

## Common Issues and Solutions

### Issue 1: API Not Enabled
**Symptom**: `"api is not enabled"` errors in logs
**Cause**: API not configured in traefik.yml
**Solution**: Add to traefik.yml:
```yaml
api:
  dashboard: true
  insecure: true
```

### Issue 2: Container Routes Not Appearing
**Symptom**: Container has labels but Traefik doesn't route to it
**Causes**:
1. Container is unhealthy → Traefik filters it
2. Container not on `proxy` network
3. `traefik.enable=true` label missing
4. Port specification incorrect

**Solution**:
- Ensure container is healthy or disable healthcheck
- Add container to `proxy` network
- Verify labels are correct
- Check logs: `docker logs traefik | grep container-name`

### Issue 3: Service Binds to Wrong Interface
**Symptom**: Healthcheck fails but service works externally
**Cause**: Service binds to container IP instead of 0.0.0.0
**Solution**: Configure app to bind to 0.0.0.0 or disable healthcheck

## File Locations Reference

```
/home/delorenj/docker/trunk-main/core/traefik/
├── compose.yml                    # Container definition
├── traefik-data/
│   ├── traefik.yml               # Static config
│   ├── acme.json                 # Let's Encrypt certificates
│   ├── dynamic/                  # Hot-reload route configs
│   │   ├── traefik-dashboard.yml
│   │   ├── n8n.yml
│   │   ├── nas.yml
│   │   └── ...
│   └── certs/                    # Custom certificates
```

## Verification Commands

```bash
# Check Traefik is running
docker ps --filter "name=traefik"

# Check Traefik logs
docker logs traefik --tail 50

# Check API is working
curl http://localhost:8080/api/overview

# List all routers
docker exec traefik wget -q -O - http://localhost:8080/api/http/routers | jq 'keys[]'

# Check specific container routing
docker logs traefik | grep container-name

# Verify container is on proxy network
docker network inspect proxy --format '{{range .Containers}}{{.Name}} {{end}}'
```

## Troubleshooting Workflow

1. **Container not routing**:
   ```bash
   # Check container health
   docker ps --filter "name=container-name"

   # Check Traefik logs for container
   docker logs traefik | grep container-name

   # Verify labels
   docker inspect container-name --format '{{json .Config.Labels}}' | jq .
   ```

2. **Dashboard not accessible**:
   ```bash
   # Check API is enabled
   docker exec traefik cat /traefik.yml | grep -A 3 "api:"

   # Test API locally
   curl http://localhost:8080/api/overview

   # Check router registration
   docker logs traefik | grep "traefik-dashboard"
   ```

3. **SSL certificate issues**:
   ```bash
   # Check certificate resolver
   docker logs traefik | grep -i "acme\|certificate"

   # Verify Cloudflare credentials
   docker exec traefik env | grep CLOUDFLARE
   ```

## Recent Changes

**2025-11-17**:
- Fixed API configuration: Moved all settings from command-line flags to traefik.yml
- Resolved metamcp routing: Disabled healthcheck due to Next.js binding to container IP
- Confirmed traefik.delo.sh working with basic auth
- Verified mcp.delo.sh routing correctly

**Configuration now uses**:
- Single command flag: `--configFile=/traefik.yml`
- All settings in traefik.yml (API, logging, metrics, entrypoints)
- Clean separation between static and dynamic config
