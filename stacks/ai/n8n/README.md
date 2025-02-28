# n8n

n8n is a workflow automation platform that lets you connect different services and automate tasks.

## Configuration

The n8n service is configured to:
- Run on port 7678 (host) mapped to port 5678 (container)
- Use Traefik for reverse proxy with hostname `n8n.delo.sh`
- Store all data in the `./data` directory

## Usage

### Starting the service

```bash
docker compose up -d
```

### Stopping the service

```bash
docker compose down
```

### Accessing the service

Once running, n8n can be accessed at:
- https://n8n.delo.sh (via Traefik)
- http://localhost:7678 (direct access)

## Integration with AI services

n8n can integrate with other AI services in your stack:
- Connect to Qdrant for vector database operations
- Integrate with LiteLLM for language model access
- Automate workflows that use your AI models