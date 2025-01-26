# Traefik Reverse Proxy

Handles routing and SSL termination for DeLoNET services.

## Configuration
- Port 80: HTTP
- Port 443: HTTPS
- Docker socket mounted for auto-discovery
- Config stored in ./config directory

## SSL Certificates
```bash
touch acme.json
chmod 600 acme.json
```

## Dashboard
Access at `https://proxy.delonet.home`

## Labels
Add to services for Traefik routing:
```yaml
labels:
  - traefik.enable=true
  - traefik.http.routers.myapp.rule=Host(`app.delonet.home`)
  - traefik.http.services.myapp.loadbalancer.server.port=8080