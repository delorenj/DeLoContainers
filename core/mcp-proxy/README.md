# PluggedIn MCP Proxy

Self-hosted MCP proxy for the DeLoContainer ecosystem.

## Setup

1. Set your API key in `.env`:
   ```
   PLUGGEDIN_API_KEY=your_api_key_here
   ```

2. Start the service:
   ```bash
   docker compose up -d
   ```

3. Test:
   ```bash
   curl http://localhost:12006/health
   ```

## Usage

- **Health**: `http://localhost:12006/health`
- **MCP API**: `http://localhost:12006/mcp`
- **Auth**: Include `Authorization: Bearer YOUR_API_KEY` header

## Management

```bash
docker compose up -d      # Start
docker compose down       # Stop
docker compose logs -f    # View logs
```
