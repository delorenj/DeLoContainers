#!/bin/bash

set -e

echo "Starting OpenCode server..."

# Set default values
HOSTNAME=${OPENCODE_HOSTNAME:-0.0.0.0}
PORT=${OPENCODE_PORT:-4096}

# Generate API key if not exists and GENERATE_API_KEY is set
if [ "$GENERATE_API_KEY" = "true" ] && [ -z "$OPENCODE_API_KEY" ]; then
    echo "Generating new API key..."
    export CONTAINER_ENV=true
    /home/mcp/generate-apikey.sh
    source /home/mcp/.env 2>/dev/null || true
fi

# Display configuration
echo "OpenCode Configuration:"
echo "  Hostname: $HOSTNAME"
echo "  Port: $PORT"
echo "  Working Directory: $(pwd)"

# Check if OpenCode binary exists and is executable
if [ ! -x "/home/mcp/.opencode/bin/opencode" ]; then
    echo "ERROR: OpenCode binary not found or not executable at /home/mcp/.opencode/bin/opencode"
    echo "Please ensure OpenCode is properly installed in the container."
    exit 1
fi

# Start OpenCode server
echo "Starting OpenCode server on $HOSTNAME:$PORT..."
exec /home/mcp/.opencode/bin/opencode serve --hostname "$HOSTNAME" --port "$PORT"
