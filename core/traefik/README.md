# Traefik Reverse Proxy

Traefik serves as the main reverse proxy and SSL termination point for all services.

## Configuration

### Network
- HTTP Port: 80
- HTTPS Port: 443
- Dashboard Port: 8080
- External network: proxy

### SSL/TLS
- Automatic certificate management via Let's Encrypt
- Certificates stored in `./traefik-data/acme.json`
- All services use websecure entrypoint

### File Structure

```plaintext
.
├── certs/                 # SSL certificates directory
├── compose.yml           # Docker compose configuration
├── config/               # Additional configurations
├── entrypoint.sh        # Container entrypoint script
└── traefik-data/
    ├── acme.json        # Let's Encrypt certificates
    ├── config.yml       # Main Traefik configuration
    ├── dynamic/         # Dynamic configuration
    │   └── config.yml   # Dynamic routing rules
    ├── scripts/         # Utility scripts
    │   └── entrypoint.sh
    └── traefik.yml      # Static Traefik configuration
```

## Service Configuration

### Labels
All services should include these basic Traefik labels:
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.<service-name>.entrypoints=websecure"
  - "traefik.http.routers.<service-name>.rule=Host(`<service>.delo.sh`)"
  - "traefik.http.routers.<service-name>.tls.certresolver=letsencrypt"
  - "traefik.http.services.<service-name>.loadbalancer.server.port=<port>"
```

### Security Features
- Basic authentication middleware available
- SSL/TLS encryption for all services
- Automatic certificate management
- Security headers middleware

## Monitoring

### Dashboard
- Available at: traefik.delo.sh
- Protected by authentication
- Shows real-time routing information

### Metrics
- Prometheus metrics enabled
- Custom buckets configured: 0.1, 0.3, 1.2, 5.0
- Available for monitoring system integration

## Maintenance

### Certificate Management
- Certificates auto-renewed by Let's Encrypt
- Stored in `acme.json`
- Backup `acme.json` regularly

### Configuration Updates
1. Static config in `traefik.yml`
2. Dynamic config in `dynamic/config.yml`
3. Restart required for static config changes
4. Dynamic config reloaded automatically

### Troubleshooting
- Check logs with `docker logs traefik`
- Verify routing rules in dashboard
- Ensure network connectivity
- Check certificate status in `acme.json`
