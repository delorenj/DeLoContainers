# OpenMemory Hosted Service

This directory contains the configuration for running OpenMemory as a hosted service. OpenMemory is your personal memory layer for LLMs - private, portable, and open-source. Your memories live locally, giving you complete control over your data.

## Setup Instructions

### 1. Configure Environment Variables

Create a `.env` file based on the provided example:

```bash
cp .env.example .env
```

Edit the `.env` file and set:
- `OPENAI_API_KEY`: Your OpenAI API key
- `USER_ID`: The user ID to associate memories with (default: "default_user")

### 2. Start the Service

```bash
docker compose -f openmemory-compose.yml up -d
```

### 3. Access the Service

- **OpenMemory UI**: https://memory.delo.sh
- **OpenMemory API**: https://memory-api.delo.sh
  - API documentation: https://memory-api.delo.sh/docs

## Architecture

The OpenMemory service consists of three main components:

1. **Qdrant Vector Database** (`mem0_store`): Stores and indexes memory embeddings for semantic search
2. **OpenMemory MCP Server** (`openmemory-mcp`): Backend API that handles memory operations
3. **OpenMemory UI** (`openmemory-ui`): Frontend interface for interacting with your memories

## Integration with Traefik

The service is configured to work with your existing Traefik reverse proxy:

- Both the UI and API are exposed via HTTPS with automatic certificate management
- The services are connected to your `proxy` network
- Traefik handles routing based on domain names:
  - `memory.delo.sh` → OpenMemory UI
  - `memory-api.delo.sh` → OpenMemory API

## Data Persistence

All memory data is stored in the `mem0_storage` Docker volume, ensuring your memories persist across container restarts.

## Additional Resources

- [OpenMemory Documentation](https://docs.mem0.ai)
- [Mem0 GitHub Repository](https://github.com/mem0ai/mem0)
