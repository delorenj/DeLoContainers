# Proxy Stack

This stack manages reverse proxy and SSL termination using Traefik.

## Services

### Traefik
- **Purpose**: Reverse proxy and SSL termination
- **Web UI**: http://localhost:8080
- **Configuration**: Located in `traefik-data/` directory
- **Dependencies**: None

## Configuration Files

### traefik.yml
Main Traefik configuration file containing:
- EntryPoints configuration
- Certificate resolvers
- Dashboard settings
- Global middleware

### config.yml
Static configuration including:
- Provider settings
- Default certificate settings
- Global security settings

### dynamic/
Directory containing dynamic configuration files:
- `middleware.yml`: Common middleware configurations
- `lmstudio.yml`: Service-specific configurations

## Environment Variables

Required environment variables (defined in root `.env`):
- `DOMAIN`: Base domain for services
- `CLOUDFLARE_EMAIL`: Cloudflare account email
- `CLOUDFLARE_API_KEY`: Cloudflare API key for DNS challenge

## Volumes

- `./traefik-data:/etc/traefik`: Configuration directory
- `/var/run/docker.sock:/var/run/docker.sock:ro`: Docker socket for container discovery

## Network

Creates a dedicated proxy network (`proxy`) that other stacks connect to for external access.

## SSL Certificates

- Uses Cloudflare DNS challenge for automatic SSL certificate generation
- Certificates are automatically renewed before expiration
- Stored in `traefik-data/` directory

## Maintenance

1. Regular Updates
   ```bash
   docker-compose pull
   docker-compose up -d
   ```

2. Certificate Management
   ```bash
   # Check certificate status
   docker-compose exec traefik traefik certificate info
   ```

3. Configuration Validation
   ```bash
   # Validate Traefik configuration
   docker-compose exec traefik traefik validate config
   ```

## Troubleshooting

### SSL Certificate Issues
1. Verify Cloudflare credentials in `.env`
2. Check Traefik logs:
   ```bash
   docker-compose logs traefik
   ```
3. Ensure DNS records are properly configured in Cloudflare

### Routing Issues
1. Verify service labels in compose files
2. Check middleware configuration
3. Ensure services are on the proxy network

### Dashboard Access Issues
1. Verify dashboard is enabled in `traefik.yml`
2. Check authentication middleware configuration
3. Ensure correct port mapping
