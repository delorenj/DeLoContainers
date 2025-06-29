# MCP Proxy Stack

This stack provides a centralized MCP (Model Context Protocol) proxy with web dashboard for managing multiple MCP servers.

## Architecture

```
Traefik → plugged.in Dashboard + MCP Proxy → Individual MCP Servers
```

## URLs

- **Admin Dashboard**: https://mcp-admin.delo.sh
- **API Endpoint**: https://mcp.delo.sh
- **Server Routes**: 
  - https://mcp.delo.sh/ffmpeg - FFmpeg operations
  - https://mcp.delo.sh/puppeteer - Browser automation
  - https://mcp.delo.sh/memory-bank - Memory management
  - https://mcp.delo.sh/taskmaster - Task management
  - https://mcp.delo.sh/magic-ui - UI component generation
  - https://mcp.delo.sh/context7 - Documentation analysis
  - https://mcp.delo.sh/trello - Trello board management
  - https://mcp.delo.sh/circleci - CircleCI operations
  - https://mcp.delo.sh/ideogram - AI image generation
  - https://mcp.delo.sh/claude-code - Code analysis tools
  - https://mcp.delo.sh/datetime - Date/time utilities
  - https://mcp.delo.sh/github - GitHub operations

## Services

### Core Services
- **pluggedin-app**: Web dashboard for MCP server management
- **mcp-proxy**: API proxy that routes requests to individual MCP servers

### MCP Servers
- **ffmpeg-mcp**: FFmpeg operations (audio extraction, video processing)
- **puppeteer-mcp**: Browser automation and web scraping
- **memory-bank-mcp**: Memory management and storage operations
- **taskmaster-mcp**: Task management and project organization
- **magic-ui-mcp**: UI component generation and design tools
- **context7-mcp**: Context-aware documentation and code analysis
- **trello-mcp**: Trello board management and card operations
- **circleci-mcp**: CircleCI build management and monitoring
- **ideogram-mcp**: AI image generation and manipulation
- **claude-code-mcp**: Code analysis, generation, and development tools
- **mcp-datetime**: Date and time utilities and formatting
- **github-mcp**: GitHub repository management and operations

## Setup

1. **Review environment variables**:
   ```bash
   cat .env
   ```

2. **Start the stack**:
   ```bash
   docker compose up -d
   ```

3. **Check status**:
   ```bash
   docker compose ps
   ```

## Usage

### Admin Dashboard
1. Visit https://mcp-admin.delo.sh
2. Create an account
3. Configure your MCP servers
4. Monitor server status and logs

### API Access
Use the MCP API with authentication:

```bash
# Example API call
curl -H "X-API-Key: YOUR_MCP_API_KEY" \
     https://mcp.delo.sh/taskmaster/get_tasks \
     -d '{"status": "pending"}'
```

### Adding New MCP Servers

1. Add service to `compose.yml`
2. Configure in the plugged.in dashboard
3. Access via `https://mcp.delo.sh/your-server-name`

## Monitoring

```bash
# View all logs
docker compose logs -f

# View specific service logs
docker compose logs -f mcp-proxy
docker compose logs -f pluggedin-app

# Check service status
docker compose ps
```

## Configuration

### Environment Variables
- `NEXTAUTH_SECRET`: Authentication secret for dashboard
- `PLUGGEDIN_API_KEY`: API key for plugged.in integration
- `MCP_API_KEY`: API key for MCP proxy access

### Volumes
- `pluggedin_data`: Dashboard database and configuration
- `mcp_proxy_data`: Proxy configuration and cache
- `*_data`: Individual MCP server data

## Security

- All services use API key authentication
- Traefik handles SSL termination
- Internal network isolation between services
- No direct external access to MCP servers

## Troubleshooting

### Common Issues

1. **Services not starting**: Check logs with `docker compose logs`
2. **API authentication failing**: Verify `MCP_API_KEY` in `.env`
3. **Dashboard not accessible**: Check Traefik configuration and DNS
4. **MCP servers not responding**: Check internal network connectivity

### Health Checks

```bash
# Test dashboard
curl -k https://mcp-admin.delo.sh

# Test API (requires API key)
curl -H "X-API-Key: YOUR_KEY" https://mcp.delo.sh/health

# Check internal connectivity
docker compose exec mcp-proxy ping pluggedin-app
```
