# MCP Server Integration Guide

## Overview

This guide documents the learnings from integrating various MCP (Model Context Protocol) servers into a unified proxy infrastructure. It covers different authentication mechanisms, transport protocols, and integration patterns discovered while troubleshooting the OpenMemory (Big-chungus) MCP server.

## Key Learnings

### 1. MCP Server Types

MCP servers can be implemented in different ways:

- **REST API-based**: Standard HTTP endpoints (e.g., FFmpeg, Trello)
- **SSE-based (Server-Sent Events)**: Real-time streaming connections (e.g., OpenMemory)
- **WebSocket-based**: Bidirectional communication channels
- **Hybrid**: Combination of multiple transport methods

### 2. Authentication Mechanisms

Different MCP servers may require different authentication:

- **API Key**: Simple header-based authentication (most common)
- **OAuth/OAuth2**: Token-based authentication with well-known metadata endpoints
- **Context Variables**: Authentication via path parameters or context (OpenMemory style)
- **No Auth**: Some servers run without authentication in trusted environments

### 3. OpenMemory MCP Server Specifics

OpenMemory implements a unique MCP server pattern:

```python
# SSE endpoint pattern
/{client_name}/sse/{user_id}

# POST messages endpoint
/{client_name}/sse/{user_id}/messages/
```

Key characteristics:
- Uses SSE (Server-Sent Events) for real-time communication
- Authentication is handled via URL path parameters, not headers
- Requires proper SSE-compatible proxy configuration
- Implements lazy initialization for resilience

### 4. Proxy Architecture Patterns

#### Simple REST Proxy
```python
# Standard proxying for REST-based MCP servers
@app.api_route("/{server_name}/{path:path}", methods=["GET", "POST", "PUT", "DELETE"])
async def proxy_request(server_name: str, path: str, request: Request):
    # Forward to appropriate backend
```

#### SSE-Compatible Routing
For SSE-based servers, direct Traefik routing is often better than proxying through FastAPI:

```yaml
# Traefik configuration for SSE support
http:
  routers:
    openmemory-mcp:
      rule: "Host(`mcp.delo.sh`) && PathPrefix(`/openmemory`)"
      service: openmemory-mcp
      middlewares:
        - openmemory-strip-prefix
  
  middlewares:
    openmemory-strip-prefix:
      stripPrefix:
        prefixes:
          - "/openmemory"
```

### 5. Integration Checklist

When adding a new MCP server:

1. **Identify the transport protocol**
   - REST API → Use standard proxy
   - SSE/WebSocket → Consider direct Traefik routing
   
2. **Understand authentication requirements**
   - Check for OAuth metadata endpoints
   - Look for API key headers
   - Identify context-based auth patterns

3. **Configure the proxy layer**
   ```python
   # Add to proxy server list
   "server_name": "http://container_name:port"
   ```

4. **Configure Traefik if needed**
   - Add appropriate routers
   - Configure middleware (auth, headers, path stripping)
   - Ensure proper service backends

5. **Test the integration**
   - Health check endpoints
   - Authentication flow
   - Actual MCP operations

### 6. Common Pitfalls and Solutions

#### Problem: 401 OAuth Metadata Error
**Symptom**: "HTTP 401 trying to load well-known OAuth metadata"

**Solution**: The server might not actually use OAuth. Check if it uses:
- Path-based authentication (like OpenMemory)
- No authentication for internal services
- Different auth mechanism than expected

#### Problem: SSE Connection Failures
**Symptom**: Connection timeouts or dropped connections

**Solution**: 
- Use direct Traefik routing instead of proxying through FastAPI
- Ensure proper WebSocket/SSE support in reverse proxy
- Check for path rewriting requirements

#### Problem: Network Connectivity
**Symptom**: "Cannot connect to server"

**Solution**:
- Ensure containers are on the same Docker network
- Check service names match container names
- Verify ports are correctly mapped

### 7. Example Implementations

#### REST API MCP Server
```python
# Simple REST-based MCP server
@app.get("/tools")
async def list_tools():
    return {"tools": ["tool1", "tool2"]}

@app.post("/execute/{tool_name}")
async def execute_tool(tool_name: str, params: dict):
    return {"result": "success"}
```

#### SSE-based MCP Server
```python
# SSE-based MCP server (OpenMemory style)
from mcp.server.sse import SseServerTransport

sse = SseServerTransport("/mcp/messages/")

@router.get("/{client_name}/sse/{user_id}")
async def handle_sse(request: Request):
    # Extract context from path
    uid = request.path_params.get("user_id")
    client_name = request.path_params.get("client_name")
    
    # Handle SSE connection
    async with sse.connect_sse(...) as (read_stream, write_stream):
        await mcp_server.run(read_stream, write_stream)
```

### 8. Debugging Tips

1. **Check container logs**
   ```bash
   docker logs <container_name> --tail 50
   ```

2. **Test direct connectivity**
   ```bash
   curl -v http://container_name:port/health
   ```

3. **Verify network configuration**
   ```bash
   docker network inspect proxy | grep container_name
   ```

4. **Monitor Traefik logs**
   ```bash
   docker logs traefik --tail 50 | grep error
   ```

### 9. Future Considerations

- **Unified Authentication**: Consider implementing a unified auth layer for all MCP servers
- **Service Discovery**: Automatic registration of new MCP servers
- **Health Monitoring**: Centralized health checks and alerting
- **Load Balancing**: For high-traffic MCP servers
- **Circuit Breakers**: Resilience patterns for unreliable backends

## Conclusion

MCP server integration requires understanding the specific implementation patterns of each server. While some follow standard REST patterns, others like OpenMemory use more complex SSE-based approaches. The key is to identify the transport mechanism and authentication requirements early, then choose the appropriate integration strategy (proxy vs. direct routing).