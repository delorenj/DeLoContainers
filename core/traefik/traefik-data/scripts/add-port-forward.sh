#!/bin/bash

# Helper script to add new port forwarding rules
# Usage: ./add-port-forward.sh <port> <target_ip> [service_name]

if [ $# -lt 2 ]; then
    echo "Usage: $0 <port> <target_ip> [service_name]"
    echo "Example: $0 8080 192.168.1.100 my-app"
    exit 1
fi

PORT=$1
TARGET_IP=$2
SERVICE_NAME=${3:-"port-${PORT}"}

# Add entry point to traefik.yml
echo "Adding entry point for port $PORT..."
if ! grep -q "port-${PORT}:" ../traefik.yml; then
    sed -i "/# Add more ports as needed/i\\  port-${PORT}:\n    address: \":${PORT}\"" ../traefik.yml
fi

# Create or update the port forwarding config
CONFIG_FILE="../dynamic/port-forward-${PORT}.yml"

cat > "$CONFIG_FILE" << EOF
tcp:
  routers:
    ${SERVICE_NAME}-forward:
      rule: "HostSNI(\`*\`)"
      service: ${SERVICE_NAME}-service
      middlewares:
        - tcp-home-network-only
      entryPoints:
        - port-${PORT}

  services:
    ${SERVICE_NAME}-service:
      loadBalancer:
        servers:
          - address: "${TARGET_IP}:${PORT}"

  middlewares:
    tcp-home-network-only:
      ipWhiteList:
        sourceRange:
          - "192.168.0.0/16"
          - "127.0.0.1/32"
          - "::1/128"
EOF

echo "Created port forwarding rule for port $PORT -> $TARGET_IP:$PORT"
echo "Config saved to: $CONFIG_FILE"
echo "Restart Traefik to apply changes."
