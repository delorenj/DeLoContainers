# OpenCode Docker Service 🤖

This directory contains the containerized version of the OpenCode service with secure API key authentication. The service is accessible both locally for development and remotely via HTTPS with authentication.

## Quick Start

1. **Copy environment file:**
   ```bash
   cp .env.example .env
   ```

2. **Build and start the service:**
   ```bash
   docker compose up -d --build
   ```

3. **Set up authentication:**
   ```bash
   # Generate API key and update configurations
   ./manage-opencode.sh generate-key
   
   # Test authentication setup
   ./manage-opencode.sh test-auth
   ```

## Authentication Setup

### Environment Setup
For remote access, you need to set the API key in your environment:

```bash
# Add to your shell profile (.bashrc, .zshrc, etc.)
export OPENCODE_API_KEY="your-generated-api-key-here"
```

### API Key Management

The service includes a management script for easy API key operations:

```bash
# Generate new API key and update all configurations
./manage-opencode.sh generate-key

# Test authentication setup
./manage-opencode.sh test-auth

# Check service status
./manage-opencode.sh status

# Restart services after configuration changes
./manage-opencode.sh restart
```

## Usage

### CLI Wrapper

The `oc` script provides easy access to the OpenCode API:

```bash
# Remote access (requires API key)
oc --prompt "What is 2+2?"

# Local development (no API key needed)
oc --local --prompt "What is 2+2?"

# Specify provider and model
oc --provider deepseek --model deepseek-chat --prompt "Hello"

# Verbose output
oc --verbose --prompt "Explain quantum computing"
```

### Access Methods

- **Remote (Authenticated)**: `https://opencode.delo.sh` - Requires X-API-Key header
- **Local Development**: `http://localhost:4096` - No authentication required
- **Container-to-Container**: `http://opencode:4096` - No authentication required

### API Authentication

Include the API key in your requests to the remote endpoint:

```bash
# Using curl
curl -H "X-API-Key: api:your-api-key" https://opencode.delo.sh/openapi

# Create a session
curl -X POST -H "X-API-Key: api:your-api-key" -H "Content-Type: application/json" \
  https://opencode.delo.sh/session_create -d '{}'
```

## Configuration

### Environment Variables

- `OPENCODE_HOSTNAME`: Server hostname (default: 0.0.0.0)
- `OPENCODE_PORT`: Server port (default: 4096)
- `OPENCODE_API_KEY`: API key for authentication
- `OPENCODE_HASHED_KEY`: Hashed key for Traefik (auto-generated)

### Security Features

1. **API Key Authentication**: All remote access requires X-API-Key header
2. **Local Development Mode**: Bypass authentication for local development
3. **Automatic SSL**: HTTPS via Traefik with Let's Encrypt certificates
4. **CORS Protection**: Configured headers for secure cross-origin requests

## Available API Endpoints

- `GET /openapi` - OpenAPI documentation
- `GET /event` - Server-sent events stream
- `POST /app_info` - Get app information
- `POST /session_create` - Create a new session
- `POST /session_list` - List all sessions
- `POST /session_chat` - Chat with a model
- `POST /provider_list` - List available providers
- `POST /file_search` - Search for files

## File Structure

```
opencode/
├── Dockerfile              # Container definition
├── compose.yml            # Docker Compose configuration
├── start-opencode.sh      # Container startup script
├── manage-opencode.sh     # Management script for auth and deployment
├── oc                     # CLI wrapper with auth support
├── .env.example          # Environment template
├── .env                  # Environment configuration
├── README.md             # This file
├── auth-plan.md          # Authentication implementation plan
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

### Authentication Issues

```bash
# Check service status
./manage-opencode.sh status

# Test authentication
./manage-opencode.sh test-auth

# Generate new API key if needed
./manage-opencode.sh generate-key
```

### Service Issues

1. **Service won't start**: Check provider credentials (OPENAI_API_KEY, etc.)
2. **Port conflicts**: Verify port 4096 is available
3. **Container logs**: `docker compose logs -f opencode`

### API Access Issues

1. **Remote access fails**: Ensure OPENCODE_API_KEY is set in environment
2. **Local access fails**: Use `--local` flag or check if service is running
3. **Authentication errors**: Verify API key format: `api:your-key`

## Security Considerations

1. **API Key Storage**: Never commit API keys to version control
2. **Access Patterns**:
   - Public URL (`https://opencode.delo.sh`) - Requires authentication
   - Local port (`http://localhost:4096`) - No authentication (development only)
   - Container-to-container (`http://opencode:4096`) - No authentication (internal only)
3. **Key Rotation**: Regularly rotate API keys using the management script

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

3. Set up authentication:
   ```bash
   ./manage-opencode.sh generate-key
   ```

4. Update any scripts or configurations that referenced the systemd service.
