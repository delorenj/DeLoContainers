#!/bin/bash

# Auto-opening MCP Inspector script
# This script runs the inspector and automatically opens the browser with the session token

echo "🚀 Starting MCP Inspector with auto-open..."

# Load environment variables from .env.local
if [ -f .env.local ]; then
    export $(grep -v '^#' .env.local | xargs)
fi

# Start the inspector in the background and capture output
dotenv -e .env.local npx @modelcontextprotocol/inspector dist/index.js \
    -e PLUGGEDIN_API_KEY="${PLUGGEDIN_API_KEY}" \
    -e PLUGGEDIN_API_BASE_URL="${PLUGGEDIN_API_BASE_URL}" \
    -e DANGEROUSLY_OMIT_AUTH=true 2>&1 | \
while IFS= read -r line; do
    echo "$line"
    
    # Check if the line contains the pre-filled URL
    if [[ "$line" == *"http://localhost:6274/?MCP_PROXY_AUTH_TOKEN="* ]]; then
        # Extract the URL
        url=$(echo "$line" | grep -o 'http://localhost:6274/?MCP_PROXY_AUTH_TOKEN=[a-f0-9]*')
        if [ ! -z "$url" ]; then
            echo "🌐 Auto-opening browser with pre-filled token..."
            # Open the URL in the default browser
            if command -v open &> /dev/null; then
                # macOS
                open "$url"
            elif command -v xdg-open &> /dev/null; then
                # Linux
                xdg-open "$url"
            elif command -v start &> /dev/null; then
                # Windows
                start "$url"
            else
                echo "❌ Could not detect browser opener. Please manually open: $url"
            fi
        fi
    fi
done 