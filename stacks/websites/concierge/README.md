# Concierge AI Gateway

A lightweight ingress service that acts as a gateway to LLM-powered agents and task automation systems.

## Features

- **Health Monitoring**: Service health checks with dependency status
- **Authentication**: API key-based authentication for secure access
- **LLM Proxy**: Direct integration with OpenRouter for AI model access
- **WebSocket Support**: Real-time bidirectional communication
- **CORS Enabled**: Cross-origin resource sharing for web clients

## Endpoints

### Public Endpoints

- `GET /health` - Service health check and status
- `GET /hello` - Basic hello world (public access)

### Authenticated Endpoints (require `X-API-Token` header)

- `GET /hello` - Personalized hello response
- `POST /llm` - LLM proxy to OpenRouter
- `WS /ws` - WebSocket connection for real-time communication

## Quick Start

1. **Environment Setup**
   ```bash
   # Ensure these are set in your .env file
   CONCIERGE_API_KEY=your-secure-api-key
   OPENROUTER_API_KEY=your-openrouter-key
   ```

2. **Deploy the Service**
   ```bash
   cd /home/delorenj/docker/stacks/websites/concierge
   docker-compose up -d
   ```

3. **Test the Service**
   ```bash
   # Health check
   curl https://concierge.delo.sh/health
   
   # Authenticated hello
   curl -H "X-API-Token: your-api-key" https://concierge.delo.sh/hello
   
   # LLM request
   curl -X POST https://concierge.delo.sh/llm \
     -H "Content-Type: application/json" \
     -H "X-API-Token: your-api-key" \
     -d '{
       "messages": [{"role": "user", "content": "Hello!"}],
       "model": "anthropic/claude-3.5-sonnet"
     }'
   ```

## Web Client

Open `test-client.html` in your browser to access a full-featured test interface with:
- Health monitoring
- Authentication testing
- LLM request interface
- WebSocket communication testing

## Configuration

### Environment Variables

- `API_KEY` - Authentication token for secure endpoints
- `OPENROUTER_API_KEY` - OpenRouter API key for LLM access

### Docker Labels

The service is configured with Traefik labels for:
- SSL/TLS termination via Let's Encrypt
- Domain routing to `concierge.delo.sh`
- Health checks and load balancing

## API Reference

### LLM Request Format

```json
{
  "model": "anthropic/claude-3.5-sonnet",
  "messages": [
    {
      "role": "user",
      "content": "Your prompt here"
    }
  ],
  "stream": false,
  "max_tokens": 1000,
  "temperature": 0.7
}
```

### WebSocket Message Format

```json
{
  "type": "message_type",
  "data": "your_data",
  "timestamp": "2025-06-29T03:00:00.000Z"
}
```

## Development Roadmap

### Phase 1: Basic Ingress ✅
- [x] HTTP endpoints with authentication
- [x] Health monitoring
- [x] LLM proxy functionality
- [x] WebSocket support
- [x] CORS configuration

### Phase 2: Core Capabilities (Next)
- [ ] MCP server orchestration
- [ ] Streaming LLM responses
- [ ] Task delegation between AI assistants
- [ ] Enhanced error handling and logging

### Phase 3: Specialized Agents (Future)
- [ ] Project Manager Agent with Trello integration
- [ ] Vector-based memory via OpenMemory MCP
- [ ] Multi-agent coordination
- [ ] Agent marketplace/registry

## Architecture

```
┌─────────────────┐    ┌──────────────┐    ┌─────────────────┐
│   Web Client    │───▶│   Concierge  │───▶│   OpenRouter    │
│                 │    │   Gateway    │    │   (LLM API)     │
└─────────────────┘    └──────────────┘    └─────────────────┘
                              │
                              ▼
                       ┌──────────────┐
                       │ MCP Servers  │
                       │ (Future)     │
                       └──────────────┘
```

## Security

- API key authentication for all sensitive endpoints
- CORS configuration for web client access
- SSL/TLS termination via Traefik
- Environment variable-based configuration

## Monitoring

- Health endpoint provides service status
- Docker health checks for container monitoring
- Traefik integration for load balancer health checks
- Console logging for request tracking

## Troubleshooting

### Common Issues

1. **401 Unauthorized**: Check that `X-API-Token` header matches `CONCIERGE_API_KEY`
2. **500 Internal Server Error**: Verify `OPENROUTER_API_KEY` is set correctly
3. **WebSocket Connection Failed**: Ensure authentication headers are included
4. **CORS Errors**: Service includes CORS headers, check browser console for details

### Logs

```bash
# View service logs
docker-compose logs -f concierge

# Check container status
docker-compose ps
```

## Contributing

1. Update the TypeScript server code in `server.ts`
2. Test changes using the web client or curl commands
3. Update documentation as needed
4. Deploy with `docker-compose up -d --build`
