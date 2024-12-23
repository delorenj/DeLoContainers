#!/bin/bash

# Configuration
STACKS_DIR="/home/delorenj/docker/stacks"
STACK_NAME=$1
STACK_TYPE=$2

# Templates for different stack types
MEDIA_STACK_TEMPLATE='version: "3.8"

services:
  app:
    image: ${IMAGE}
    container_name: ${SERVICE_NAME}
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
    volumes:
      - ./config:/config
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.${SERVICE_NAME}.rule=Host(`${DOMAIN}`)"
      - "traefik.http.services.${SERVICE_NAME}.loadbalancer.server.port=${PORT}"

networks:
  proxy:
    external: true'

AI_STACK_TEMPLATE='version: "3.8"

services:
  app:
    image: ${IMAGE}
    container_name: ${SERVICE_NAME}
    environment:
      - NVIDIA_VISIBLE_DEVICES=all
    volumes:
      - ./config:/config
      - ./data:/data
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.${SERVICE_NAME}.rule=Host(`${DOMAIN}`)"
      - "traefik.http.services.${SERVICE_NAME}.loadbalancer.server.port=${PORT}"

networks:
  proxy:
    external: true'

PROXY_STACK_TEMPLATE='version: "3.8"

services:
  app:
    image: ${IMAGE}
    container_name: ${SERVICE_NAME}
    environment:
      - TZ=America/New_York
    volumes:
      - ./config:/config
    networks:
      - proxy
    ports:
      - "${PORT}:${PORT}"
    labels:
      - "traefik.enable=true"

networks:
  proxy:
    external: true'

# Function to validate stack name
validate_stack_name() {
    if [[ ! $1 =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "❌ Invalid stack name. Use only letters, numbers, underscores, and hyphens."
        exit 1
    fi
}

# Function to create stack directory and files
create_stack() {
    local name=$1
    local type=$2
    local dir="$STACKS_DIR/$type/$name"
    
    echo "🏗️ Creating new $type stack: $name"
    
    # Create directory structure
    mkdir -p "$dir"/{config,data,scripts}
    
    # Create docker-compose.yml based on stack type
    case $type in
        "media")
            echo "$MEDIA_STACK_TEMPLATE" > "$dir/docker-compose.yml"
            ;;
        "ai")
            echo "$AI_STACK_TEMPLATE" > "$dir/docker-compose.yml"
            ;;
        "proxy")
            echo "$PROXY_STACK_TEMPLATE" > "$dir/docker-compose.yml"
            ;;
        *)
            echo "❌ Invalid stack type. Use: media, ai, or proxy"
            exit 1
            ;;
    esac
    
    # Create .env file
    cat > "$dir/.env" << EOF
# Stack Configuration
SERVICE_NAME=$name
DOMAIN=$name.delo.sh
PORT=8080
IMAGE=

# Service-specific settings
EOF
    
    # Create README.md
    cat > "$dir/README.md" << EOF
# $name Stack

## Overview
Description of the $name service goes here.

## Configuration
1. Edit .env file with appropriate values
2. Configure service-specific settings in config/
3. Start the stack with: mise run up $name

## Maintenance
- Backup location: /home/delorenj/docker/backups/$name
- Logs: mise run logs $name
- Update: mise run update $name

## Notes
Add any special considerations or requirements here.
EOF
    
    # Create update script
    cat > "$dir/scripts/update.sh" << EOF
#!/bin/bash

echo "🔄 Updating $name stack..."
cd "\$(dirname "\$0")/.." || exit 1

# Pull new images
docker compose pull

# Restart services
docker compose up -d

echo "✅ Update complete!"
EOF
    chmod +x "$dir/scripts/update.sh"
    
    echo "✅ Stack created successfully at $dir"
    echo "Next steps:"
    echo "1. Edit $dir/.env with your configuration"
    echo "2. Update docker-compose.yml as needed"
    echo "3. Run 'mise run up $name' to start the stack"
}

# Main execution
if [ -z "$STACK_NAME" ] || [ -z "$STACK_TYPE" ]; then
    echo "Usage: $0 <stack_name> <stack_type>"
    echo "Stack types: media, ai, proxy"
    exit 1
fi

validate_stack_name "$STACK_NAME"
create_stack "$STACK_NAME" "$STACK_TYPE"