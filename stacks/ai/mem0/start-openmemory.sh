#!/bin/bash

set -e

echo "🚀 Starting OpenMemory service..."

# Check if .env file exists, create from example if not
if [ ! -f .env ]; then
  echo "⚠️ .env file not found. Creating from .env.example..."
  cp .env.example .env
  echo "⚠️ Please edit .env file and set your OPENAI_API_KEY before continuing."
  exit 1
fi

# Load environment variables
source .env

# Check if OPENAI_API_KEY is set
if [ -z "$OPENAI_API_KEY" ] || [ "$OPENAI_API_KEY" == "sk-your-openai-api-key" ]; then
  echo "❌ OPENAI_API_KEY not properly set in .env file."
  echo "Please edit .env file and set your OPENAI_API_KEY."
  exit 1
fi

# Start the services
echo "🚀 Starting OpenMemory services..."
docker compose -f openmemory-compose.yml up -d

echo "✅ OpenMemory services started successfully!"
echo "✅ OpenMemory UI: https://memory.delo.sh"
echo "✅ OpenMemory API: https://memory-api.delo.sh"
echo "✅ API Documentation: https://memory-api.delo.sh/docs"
