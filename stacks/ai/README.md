# AI Services Stack

This directory contains AI-related services for model serving, vector storage, and custom AI applications.

## Services

### LiteLLM
- **Purpose**: LLM model serving proxy
- **Location**: ./litellm/
- **Features**:
  - Model management via UI
  - PostgreSQL backend for state
  - API access on port 4000

### Qdrant
- **Purpose**: Vector database
- **Location**: ./qdrant/
- **Access**: qdrant.delo.sh
- **Features**:
  - REST API (6333)
  - gRPC API (6334)
  - Persistent vector storage

### Letta
- **Purpose**: Custom AI service
- **Location**: ./letta/

### Flowise
- **Purpose**: Visual tool for building LLM applications
- **Location**: ./flowise/
- **Access**: flowise.delo.sh

### Agent Zero
- **Purpose**: Personal, organic agentic framework
- **Location**: ./agent-zero/
- **Access**: agent-zero.delo.sh
- **Features**:
  - General-purpose assistant
  - Persistent memory
  - Computer as a tool (code/terminal execution)
  - Multi-agent cooperation
  - Customizable and extensible via prompts

### Bolt.DIY
- **Purpose**: AI-powered web development assistant
- **Location**: ./bolt-diy/
- **Access**: bolt.delo.sh
- **Features**:
  - Natural language to code generation
  - Full-stack application development
  - Multiple AI model support
  - Real-time code editing and preview
  - GitHub integration

## Architecture

```plaintext
                    ┌─────────────┐
                    │   Traefik   │
                    │  (Routing)  │
                    └─────────────┘
                          │
          ┌──────────────┼──────────────┬──────────────┬───────────────┬─────────────┐
          │              │              │              │               │             │
    ┌─────────┐   ┌───────────┐  ┌──────────┐  ┌───────────┐   ┌─────────────┐ ┌─────────┐
    │ LiteLLM │   │  Qdrant   │  │  Letta   │  │  Flowise  │   │ Agent Zero  │ │Bolt.DIY │
    │ (4000)  │   │(6333/6334)│  │ (internal)│  │  (10010)  │   │   (80)      │ │ (5173)  │
    └─────────┘   └───────────┘  └──────────┘  └───────────┘   └─────────────┘ └─────────┘
         │             │              │              │               │             │
    ┌─────────┐       │              │              │               │             │
    │PostgreSQL│       │              │              │               │             │
    └─────────┘       │              │              │               │             │
                      │              │              │               │             │
```

## Network Configuration

All services are connected to the `proxy` network and accessible through Traefik:
- LiteLLM API endpoint
- Qdrant vector storage
- Custom Letta service endpoints
- Agent Zero UI and API
- Bolt.DIY web development interface

## Storage

- LiteLLM: PostgreSQL database for state
- Qdrant: Local volume for vector storage
- Bolt.DIY: Builds from local source code
- Configuration files stored in respective service directories

## Security

- All services behind Traefik SSL
- API authentication required
- Database credentials managed via environment variables

## Monitoring

- Service health checks
- Database connection monitoring
- API endpoint monitoring

## Development

When adding new AI services:
1. Add service to compose.yml
2. Configure Traefik labels
3. Set up monitoring
4. Document API endpoints
5. Update this README
