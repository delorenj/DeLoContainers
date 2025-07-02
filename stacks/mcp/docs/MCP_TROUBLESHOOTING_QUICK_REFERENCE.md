# MCP Troubleshooting Quick Reference

## Common MCP Server Issues & Solutions

### 🔴 "HTTP 401 trying to load well-known OAuth metadata"
**Issue**: Client expects OAuth but server doesn't implement it

**Quick Fix**:
1. Check if server uses path-based auth (e.g., `/client_name/sse/user_id`)
2. Add direct Traefik route for SSE servers:
```yaml
# In traefik dynamic config
http:
  routers:
    server-mcp:
      rule: "Host(`mcp.delo.sh`) && PathPrefix(`/servername`)"
      service: server-mcp
      middlewares:
        - strip-servername
```

### 🔴 "Cannot connect to server"
**Quick Checks**:
```bash
# Is container running?
docker ps | grep container_name

# Is it on the proxy network?
docker network inspect proxy | grep container_name

# Can you reach it directly?
docker exec mcp-proxy-server curl http://container_name:port/health
```

### 🔴 SSE/WebSocket Connection Drops
**Fix**: Route directly through Traefik, not through the proxy
```yaml
# Good: Direct Traefik → Container
# Bad: Traefik → Proxy → Container (for SSE)
```

### 🔴 Server Not Listed in MCP
**Add to two places**:
1. `/stacks/mcp/proxy/main.py` - fallback servers dict
2. `/stacks/mcp/admin/main.py` - default servers list

Then restart:
```bash
docker compose -f /home/delorenj/docker/stacks/mcp/compose.yml restart mcp-proxy mcp-admin
```

## Quick Integration Steps

### For REST API Servers:
1. Add to proxy server list
2. Restart proxy
3. Done!

### For SSE/WebSocket Servers:
1. Add to proxy server list (for discovery)
2. Create Traefik route with path stripping
3. Restart Traefik and proxy
4. Test with: `curl https://mcp.delo.sh/servername/path`

## Useful Commands

```bash
# View MCP proxy logs
docker logs mcp-proxy-server -f

# Test MCP server list
curl -H "X-API-Key: $MCP_API_KEY" https://mcp.delo.sh/servers

# Check specific server
curl -H "X-API-Key: $MCP_API_KEY" https://mcp.delo.sh/servername

# Restart MCP stack
cd /home/delorenj/docker/stacks/mcp && docker compose restart

# View all MCP-related containers
docker ps | grep -E "(mcp|openmemory)"
```

## Authentication Patterns

| Pattern | Example | How to Handle |
|---------|---------|---------------|
| API Key | `X-API-Key: token` | Proxy handles it |
| Path-based | `/client/sse/user` | Direct Traefik route |
| OAuth | Bearer token | Implement middleware |
| None | Internal only | Restrict network access |

## Remember

- **SSE needs special handling** - don't proxy through FastAPI
- **Path parameters != OAuth** - check actual auth mechanism
- **Container names matter** - they become hostnames
- **Networks must match** - everything needs to be on 'proxy' network