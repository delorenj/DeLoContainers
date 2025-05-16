# LiteLLM Proxy Setup

This repository contains a Docker Compose setup for running LiteLLM proxy with Redis caching and PostgreSQL database.

## Components

- **LiteLLM Proxy**: API gateway for multiple LLM providers
- **PostgreSQL**: Database for storing configuration and usage data
- **Redis**: Caching layer for improved performance

## Getting Started

1. Configure your environment variables in `.env` file
2. Start the stack with Docker Compose:

```bash
docker compose up -d
```

3. Access the LiteLLM UI at http://localhost:4000/ui

## Configuration

The main configuration is in `config.yaml`. Key settings include:

- Model configurations
- Routing strategies
- Caching settings
- Rate limiting
- Logging options

## Environment Variables

Make sure to set these in your `.env` file:

- `LITELLM_MASTER_KEY`: Master API key for LiteLLM
- `DATABASE_URL`: PostgreSQL connection string
- `REDIS_HOST`, `REDIS_PORT`, `REDIS_PASSWORD`: Redis connection details
- API keys for various LLM providers (Azure, Google, etc.)

## API Usage

Once running, you can use the proxy with standard OpenAI-compatible API calls:

```bash
curl http://localhost:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-litellm-master-key-replace-me" \
  -d '{
    "model": "gpt-3.5-turbo",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

## Monitoring

The proxy includes built-in monitoring and logging. Access logs at `/app/logs/litellm.log` inside the container.

## Security

- Replace all default passwords and API keys in the `.env` file
- Consider enabling authentication for the UI
- Set appropriate rate limits for production use
