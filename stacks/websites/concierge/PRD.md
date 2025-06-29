# Concierge Ingress System PRD

## Overview

Concierge is an ingress service that acts as a gateway to LLM-powered agents and task automation. It will orchestrate various AI coding assistants (AmazonQ, Cursor, Claude) and specialized agents with vector-based memory.

## Architecture Context

- **SSL/TLS**: Handled by existing Traefik proxy via Docker labels
- **Network**: Uses existing `proxy` Docker network
- **LLM Provider**: OpenRouter on host
- **Memory**: Qdrant vector DB with OpenMemory MCP server (already deployed)

## Phase 1: Basic Ingress (Current Focus)

### Endpoints

1. **Public Health Check**
    - `GET /hello` → Returns `{"message": "world"}`
2. **Authenticated Test**
    - `GET /hello` with `X-API-Token` header → Returns `{"message": "hello, jarad"}`

### Docker Configuration

```yaml
services:
  concierge:
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.concierge.rule=Host(`concierge.delo.sh`)"
      - "traefik.http.routers.concierge.tls.certresolver=letsencrypt"
      - "traefik.docker.network=proxy"
    networks:
      - proxy
```

## Phase 2: Core Capabilities

### LLM Integration

- Connect to OpenRouter API on host
- Route requests to appropriate models
- Handle streaming responses

### MCP Server Orchestration

- Spawn and manage MCP server instances:
    - AmazonQ Dev
    - Cursor/OpenCode
    - Claude (via MCP)
- Coordinate task delegation between assistants

### WebSocket Support

- Real-time streaming of LLM responses
- Live task status updates
- Bidirectional communication for interactive sessions

## Phase 3: Specialized Agents

### Project Manager Agent (First Implementation)

- **Memory**: Qdrant vector store via OpenMemory MCP
- **Integration**: mcp-server-trello (custom server)
- **Capabilities**:
    - Manage main project Trello board
    - Remember project context and decisions
    - Track task dependencies and progress

### Agent Framework

- Prepackaged agent templates
- Vector-based long-term memory per agent
- Context switching between agents

## Technical Stack

- **Runtime**: Node.js/Bun (lightweight, fast startup)
- **Framework**: Fastify (WebSocket support built-in)
- **Container**: Alpine-based Docker image
- **API Keys**: Environment variables

## Success Criteria

1. Simple HTTP endpoints working with Traefik labels
2. WebSocket connection establishes successfully
3. Can proxy requests to OpenRouter
4. Basic authentication via API key

## Future Considerations

- Multi-agent coordination protocols
- Task queue for long-running operations
- Agent marketplace/registry
- Persistent conversation threads
- Fine-grained permissions per API key