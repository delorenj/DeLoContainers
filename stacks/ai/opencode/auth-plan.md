# OpenCode API Authentication Implementation Plan

This document outlines the steps to implement proper API key authentication for the OpenCode service using Traefik middleware.

## Overview

Currently, the OpenCode API is exposed on port 4096 without authentication. This plan implements X-API-Key header authentication through Traefik middleware, ensuring the API is protected when accessed via the public URL.

## Implementation Steps

### Step 1: Generate API Key and Hash

```bash
# 1. Generate a secure random API key
export OPENCODE_API_KEY=$(openssl rand -hex 32)

# 2. Save it to the .env file
echo "OPENCODE_API_KEY=${OPENCODE_API_KEY}" >> /home/delorenj/docker/.env

# 3. Generate the htpasswd hash for Traefik
# Note: The dollar signs in the hash need to be doubled for YAML
HASHED_KEY=$(htpasswd -nbB api "$OPENCODE_API_KEY" | sed 's/:/: /' | sed 's/\$/\$\$/g')

# 4. Display the hash for configuration
echo "Add this to your Traefik config:"
echo "$HASHED_KEY"
```

### Step 2: Create Traefik Middleware Configuration

Create or update `/home/delorenj/docker/core/traefik/traefik-data/dynamic/opencode.yml`:

```yaml
http:
  middlewares:
    opencode-auth:
      basicAuth:
        headerField: "X-API-Key"
        users:
          # Replace with your generated hash from Step 1
          - "api: $$2y$$10$$YOUR_GENERATED_HASH_HERE"
    
    opencode-headers:
      headers:
        customRequestHeaders:
          X-Real-IP: "{{.RemoteAddr}}"
        customResponseHeaders:
          X-Content-Type-Options: "nosniff"
          X-Frame-Options: "DENY"
```

### Step 3: Update the CLI Wrapper Script

Update `/home/delorenj/docker/stacks/ai/opencode/oc` to support API key authentication:

```bash
#!/bin/bash

# OpenCode CLI wrapper with API key support
# Usage: oc --provider <provider> --model <model> --prompt "<prompt>"

# Default values
OPENCODE_URL="${OPENCODE_URL:-https://opencode.delo.sh}"  # Use public URL
OPENCODE_API_KEY="${OPENCODE_API_KEY:-}"  # Read from environment
PROVIDER="openai"
MODEL=""
PROMPT=""
VERBOSE=false
USE_LOCAL=false  # Flag to bypass auth for local development

# Add --local flag to command line parsing
while [[ $# -gt 0 ]]; do
    case $1 in
        --local|-l)
            USE_LOCAL=true
            OPENCODE_URL="http://localhost:4096"
            shift
            ;;
        # ... other options ...
    esac
done

# Function to make API calls with authentication
api_call() {
    local endpoint=$1
    local data=$2
    local auth_args=""
    
    # Add API key header if not using local mode
    if [ "$USE_LOCAL" = false ] && [ -n "$OPENCODE_API_KEY" ]; then
        auth_args="-H \"X-API-Key: api:${OPENCODE_API_KEY}\""
    fi
    
    # Make the request
    eval curl -s -X POST "${OPENCODE_URL}${endpoint}" \
        -H "Content-Type: application/json" \
        ${auth_args} \
        -d "'$data'"
}
```

### Step 4: Test the Authentication

```bash
# 1. Test without API key (should fail)
curl -X POST https://opencode.delo.sh/session_create \
    -H "Content-Type: application/json" \
    -d '{}'
# Expected: 401 Unauthorized

# 2. Test with incorrect API key (should fail)
curl -X POST https://opencode.delo.sh/session_create \
    -H "Content-Type: application/json" \
    -H "X-API-Key: api:wrong-key" \
    -d '{}'
# Expected: 401 Unauthorized

# 3. Test with correct API key (should succeed)
curl -X POST https://opencode.delo.sh/session_create \
    -H "Content-Type: application/json" \
    -H "X-API-Key: api:${OPENCODE_API_KEY}" \
    -d '{}'
# Expected: 200 OK with session ID

# 4. Test the wrapper script
export OPENCODE_API_KEY="your-generated-key"
oc --prompt "Hello"
# Expected: Successful response

# 5. Test local development mode
oc --local --prompt "Hello"
# Expected: Works without API key
```

### Step 5: Update Documentation

Update the README.md to include:

1. **Environment Setup**:
   ```bash
   # Required for remote access
   export OPENCODE_API_KEY="your-api-key-here"
   ```

2. **Usage Examples**:
   ```bash
   # Remote access (requires API key)
   oc --prompt "Your question"
   
   # Local development (no API key needed)
   oc --local --prompt "Your question"
   ```

3. **Security Note**:
   > The API key protects access through the public URL (opencode.delo.sh). Local access on port 4096 bypasses authentication for development purposes.

## Security Considerations

1. **API Key Storage**:
   - Never commit API keys to version control
   - Store in `.env` file or secure secret management system
   - Rotate keys periodically

2. **Access Patterns**:
   - Public URL (`https://opencode.delo.sh`) - Requires authentication
   - Local port (`http://localhost:4096`) - No authentication (development only)
   - Container-to-container (`http://opencode:4096`) - No authentication (internal only)

3. **Rate Limiting** (Optional future enhancement):
   Add Traefik rate limit middleware:
   ```yaml
   opencode-ratelimit:
     rateLimit:
       average: 100
       period: 1m
       burst: 50
   ```

## Rollback Plan

If issues arise:

1. **Temporary disable auth**:
   Remove `opencode-auth@file` from the middleware list in compose.yml

2. **Switch wrapper to local mode**:
   ```bash
   export OPENCODE_URL="http://localhost:4096"
   ```

3. **Remove Traefik config**:
   Delete or rename `/core/traefik/traefik-data/dynamic/opencode.yml`

## Verification Checklist

- [ ] API key generated and stored in .env
- [ ] Traefik middleware configuration created
- [ ] Wrapper script updated with auth support
- [ ] Public URL requires authentication
- [ ] Local development still works without auth
- [ ] Documentation updated
- [ ] Team members have API keys