#!/bin/bash

# Make sure 1Password CLI is logged in
if ! op account get >/dev/null 2>&1; then
    echo "Logging into 1Password..."
    eval $(op signin)
fi

# Create or clear .env file
echo "# AI Stack Environment Variables - Generated $(date)" > .env

# Array of key names to fetch from 1Password
declare -A keys=(
    ["GROQ_API_KEY"]="Groq API Key"
    ["HUGGINGFACE_API_KEY"]="HuggingFace API Key"
    ["OPENAI_API_KEY"]="OpenAI API Key"
    ["ANTHROPIC_API_KEY"]="Anthropic API Key"
    ["OPEN_ROUTER_API_KEY"]="OpenRouter API Key"
    ["GOOGLE_GENERATIVE_AI_API_KEY"]="Google Gemini API Key"
    ["TOGETHER_API_KEY"]="Together AI API Key"
)

# Fetch each key from 1Password and add to .env
for env_key in "${!keys[@]}"; do
    item_name="${keys[$env_key]}"
    echo "Fetching $item_name..."
    value=$(op item get "$item_name" --fields credential 2>/dev/null)
    if [ $? -eq 0 ] && [ ! -z "$value" ]; then
        echo "$env_key=$value" >> .env
    else
        echo "# $env_key= # Not found in 1Password" >> .env
    fi
done

# Add static configurations
echo "" >> .env
echo "# Static configurations" >> .env
echo "OLLAMA_API_BASE_URL=http://host.docker.internal:11434" >> .env
echo "TOGETHER_API_BASE_URL=https://api.together.xyz" >> .env

echo "Environment file updated successfully!"