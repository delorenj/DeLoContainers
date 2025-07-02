#!/bin/bash

echo "Starting OpenCode server..."

# Set default values
HOSTNAME=${OPENCODE_HOSTNAME:-0.0.0.0}
PORT=${OPENCODE_PORT:-4096}

# Display configuration
echo "OpenCode Configuration:"
echo "  Hostname: $HOSTNAME"
echo "  Port: $PORT"
echo "  Working Directory: $(pwd)"

# Configure environment for providers (if needed)
if [ -n "$OPENAI_API_KEY" ]; then
    echo "  OpenAI API Key: Configured"
fi

# Start OpenCode server using bun
echo "Starting OpenCode server on $HOSTNAME:$PORT..."
cd /app && bun run ./packages/opencode/src/index.ts serve --hostname "$HOSTNAME" --port "$PORT" --print-logs