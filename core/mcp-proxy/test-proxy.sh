#!/bin/bash

# Test script for MCP Proxy
echo "🧪 Testing MCP Proxy..."

# Check if API key is set
if grep -q "YOUR_API_KEY_HERE" .env; then
    echo "❌ Please set your PLUGGEDIN_API_KEY in .env file"
    echo "Get your API key from: https://plugged.in/api-keys"
    exit 1
fi

# Source the API key
source .env

echo "✅ API key is set"

# Test health endpoint
echo "🔍 Testing health endpoint..."
curl -s http://localhost:12006/health | jq .

# Test tools list
echo "🔍 Testing tools list..."
curl -s -X POST http://localhost:12006/mcp \
  -H "Authorization: Bearer $PLUGGEDIN_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"tools/list","id":1}' | jq .

echo "✅ MCP Proxy test complete!"
