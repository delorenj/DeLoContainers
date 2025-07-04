# Documentation Directory

This directory contains documentation for the infrastructure and services.

## Contents

### Service Directory
- [Service Directory](service-directory.md) - Comprehensive list of all services, their URLs, ports, and features

### Additional Documentation
- `logs/` - Logging configuration and management
- `rules/` - System rules and policies
- `session/` - Session management documentation

## API Access

### Ollama API
The Ollama service is protected with API key authentication. To make requests:

**Base URL:** `https://ollama.${DOMAIN}`

**Authentication:** Include the `X-API-Key` header with your requests.

**API Key:** Available as `$OLLAMA_API_KEY` environment variable.

#### Example Requests

**Generate text completion:**
```bash
curl -H "X-API-Key: $OLLAMA_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "model": "llama2",
       "prompt": "Hello, how are you?",
       "stream": false
     }' \
     https://ollama.${DOMAIN}/api/generate
```

**List available models:**
```bash
curl -H "X-API-Key: $OLLAMA_API_KEY" \
     https://ollama.${DOMAIN}/api/tags
```

**Chat completion:**
```bash
curl -H "X-API-Key: $OLLAMA_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "model": "llama2",
       "messages": [
         {
           "role": "user",
           "content": "Why is the sky blue?"
         }
       ]
     }' \
     https://ollama.${DOMAIN}/api/chat
```

**Using with OpenAI-compatible clients:**
Many tools that support OpenAI's API can be configured to use Ollama:
```bash
# Set environment variables
export OPENAI_API_KEY="$OLLAMA_API_KEY"
export OPENAI_BASE_URL="https://ollama.${DOMAIN}/v1"
```

## Documentation Structure

The documentation is organized into several key areas:

1. **Service Information**
   - Service endpoints and access methods
   - Configuration details
   - Dependencies and relationships

2. **System Configuration**
   - Network setup
   - Security policies
   - Storage management

3. **Monitoring and Logging**
   - Log management
   - Metrics collection
   - System monitoring

## Maintaining Documentation

When updating services or infrastructure:
1. Update the service directory
2. Document any new endpoints or access methods
3. Keep configuration examples current
4. Maintain security-related documentation
