#!/bin/bash

# Test script for Self-Hosted MCP Proxy
echo "🧪 Testing Self-Hosted MCP Proxy..."

# Source the API key
source .env

echo "✅ Using API key: ${PLUGGEDIN_API_KEY:0:20}..."

# Test health endpoint (no auth required)
echo "🔍 Testing health endpoint..."
curl -s http://localhost:12006/health | jq .

echo ""
echo "🔍 Testing authenticated endpoint..."

# Test with proper headers
curl -s -X POST http://localhost:12006/mcp \
  -H "Authorization: Bearer $PLUGGEDIN_API_KEY" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","method":"ping","id":1}' | jq .

echo ""
echo "📋 Your self-hosted MCP proxy is running!"
echo "🔑 API Key: $PLUGGEDIN_API_KEY"
echo "🌐 Endpoint: http://localhost:12006/mcp"
echo "📖 Usage: Include 'Authorization: Bearer $PLUGGEDIN_API_KEY' header"
