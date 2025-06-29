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
    /generate-apikey.sh
    source /root/.env 2>/dev/null || true
fi

# Display configuration
echo "OpenCode Configuration:"
echo "  Hostname: $HOSTNAME"
echo "  Port: $PORT"
echo "  Working Directory: $(pwd)"

# Check if OpenCode binary exists and is executable
if [ ! -x "/root/.local/bin/pnpm/opencode" ]; then
    echo "ERROR: OpenCode binary not found or not executable at /root/.local/bin/pnpm/opencode"
    echo "Please ensure OpenCode is properly installed in the container."
    exit 1
fi

# Start OpenCode server
echo "Starting OpenCode server on $HOSTNAME:$PORT..."
echo "Binary path: /root/.local/bin/pnpm/opencode"
echo "Binary exists: $(test -f /root/.local/bin/pnpm/opencode && echo 'yes' || echo 'no')"
echo "Binary executable: $(test -x /root/.local/bin/pnpm/opencode && echo 'yes' || echo 'no')"
exec /root/.local/bin/pnpm/opencode serve --hostname "$HOSTNAME" --port "$PORT" --print-logs
