# OpenCode Docker Service

This directory contains the containerized version of the OpenCode service, built on the mcp-base image.

## Quick Start

1. **Copy environment file:**
   ```bash
   cp .env.example .env
   ```

2. **Build and start the service:**
   ```bash
   docker compose up -d --build
   ```

3. **Generate API key (if needed):**
   ```bash
   docker compose exec opencode /home/mcp/generate-apikey.sh
   ```

## Configuration

### Environment Variables

- `OPENCODE_HOSTNAME`: Server hostname (default: 0.0.0.0)
- `OPENCODE_PORT`: Server port (default: 4096)
- `GENERATE_API_KEY`: Auto-generate API key on startup (default: false)
- `OPENCODE_API_KEY`: Pre-configured API key (optional)

### API Key Management

#### Option 1: Auto-generate on startup
Set `GENERATE_API_KEY=true` in your `.env` file. The container will generate a new API key on startup.

#### Option 2: Generate manually
```bash
# Generate a new API key
docker compose exec opencode /home/mcp/generate-apikey.sh

# Generate with specific key
docker compose exec opencode /home/mcp/generate-apikey.sh "your-custom-key"
```

#### Option 3: Pre-configure
Set `OPENCODE_API_KEY` in your `.env` file with your desired API key.

### Traefik Integration

The service is pre-configured with Traefik labels for automatic SSL and routing. Update the Traefik dynamic configuration file (`/core/traefik/traefik-data/dynamic/opencode.yml`) with the generated hashed API key:

```yaml
http:
  middlewares:
    opencode-auth:
      basicAuth:
        headerField: "X-API-Key"
        users:
          - "api:$$2y$$10$$YOUR_GENERATED_HASH_HERE"
```

## Usage

### Access the service
- **Internal**: `http://opencode:4096`
- **External**: `https://opencode.delo.sh` (via Traefik)

### API Authentication
Include the API key in your requests:
```bash
curl -H "X-API-Key: api:your-api-key" https://opencode.delo.sh
```

## File Structure

```
opencode/
├── Dockerfile              # Container definition
├── compose.yml            # Docker Compose configuration
├── start-opencode.sh      # Container startup script
├── generate-apikey.sh     # API key generation utility
├── .env.example          # Environment template
├── README.md             # This file
└── config/               # Configuration directory (mounted as volume)
```

## Volumes

- `opencode_data`: Persistent data storage
- `./config`: Configuration files (read-only mount)

## Health Checks

The container includes health checks that verify the service is responding on the configured port.

## Logs

View container logs:
```bash
docker compose logs -f opencode
```

## Troubleshooting

### Service won't start
1. Check if the OpenCode binary is properly installed in the container
2. Verify port 4096 is not already in use
3. Check container logs for specific error messages

### API authentication issues
1. Verify the API key is correctly generated
2. Ensure the Traefik configuration includes the correct hashed key
3. Check that the `X-API-Key` header format is correct: `api:your-key`

### Traefik routing issues
1. Ensure the `proxy` network exists
2. Verify Traefik can reach the container
3. Check Traefik logs for routing errors

## Migration from Systemd

This containerized version replaces the systemd service. To migrate:

1. Stop the systemd service:
   ```bash
   sudo systemctl stop opencode.service
   sudo systemctl disable opencode.service
   ```

2. Start the containerized version:
   ```bash
   docker compose up -d --build
   ```

3. Update any scripts or configurations that referenced the systemd service.
