#!/bin/bash

# Generate API key for OpenCode Traefik authentication

echo "OpenCode API Key Generator"
echo "========================="
echo ""
echo "This will generate a hashed API key for Traefik authentication."
echo ""

# Generate a random API key if not provided
if [ -z "$1" ]; then
    API_KEY=$(openssl rand -hex 32)
    echo "Generated API Key: $API_KEY"
    echo ""
    echo "SAVE THIS KEY! It cannot be recovered once hashed."
    echo ""
else
    API_KEY=$1
fi

# Generate the hashed version for Traefik
# Using 'api' as the username, but you can change this
HASHED=$(echo $(htpasswd -nbB api "$API_KEY") | sed -e 's/\$/\$\$/g')

echo "Add this to your opencode.yml file under opencode-auth middleware:"
echo ""
echo "        users:"
echo "          - \"$HASHED\""
echo ""
echo "To use the API, send requests with the header:"
echo "X-API-Key: api:$API_KEY"
echo ""
echo "Example curl command:"
echo "curl -H \"X-API-Key: api:$API_KEY\" https://opencode.delo.sh"
echo ""

# If running in container, also save to environment file
if [ -n "$CONTAINER_ENV" ]; then
    echo "OPENCODE_API_KEY=$API_KEY" >> /home/mcp/.env
    echo "OPENCODE_HASHED_KEY=$HASHED" >> /home/mcp/.env
    echo ""
    echo "API key saved to container environment file."
fi
