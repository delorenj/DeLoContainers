#!/bin/bash
# Wrapper script for MCP Qdrant Server

# Set required environment variables
export QDRANT_COLLECTION_NAME="33GOD"
export QDRANT_URL="http://wet-ham:6333"
export OPENAI_API_KEY="your-openai-api-key-here"

# Directly run the MCP Qdrant server without additional wrappers
exec npx -y @delorenj/mcp-qdrant-memory
