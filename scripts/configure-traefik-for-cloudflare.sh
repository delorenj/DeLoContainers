#!/usr/bin/env zsh

# Script to configure Traefik to work with Cloudflare Tunnel
# Uses X-Forwarded-For headers from Cloudflare

echo "Configuring Traefik for Cloudflare Tunnel..."

# Backup current config
TIMESTAMP=$(date +%Y%m%d%H%M%S)
CONFIG_PATH="/home/delorenj/code/DeLoContainers/core/traefik/traefik-data/dynamic/config.yml"
BACKUP_PATH="${CONFIG_PATH}.${TIMESTAMP}.bak"

# Make a backup
cp $CONFIG_PATH $BACKUP_PATH
echo "Backup created at $BACKUP_PATH"

# Check if cloudflare-ip-whitelist middleware already exists
if grep -q "cloudflare-ip-whitelist:" $CONFIG_PATH; then
  echo "Cloudflare IP whitelist already configured."
else
  # Add the cloudflare-ip-whitelist middleware
  cat <<EOF >> $CONFIG_PATH

  # Cloudflare integration
  cloudflare-ip-whitelist:
    ipWhiteList:
      sourceRange:
        - 173.245.48.0/20
        - 103.21.244.0/22
        - 103.22.200.0/22
        - 103.31.4.0/22
        - 141.101.64.0/18
        - 108.162.192.0/18
        - 190.93.240.0/20
        - 188.114.96.0/20
        - 197.234.240.0/22
        - 198.41.128.0/17
        - 162.158.0.0/15
        - 104.16.0.0/13
        - 104.24.0.0/14
        - 172.64.0.0/13
        - 131.0.72.0/22
  
  cf-headers:
    headers:
      hostsProxyHeaders:
        - "X-Forwarded-Host"
      requestHeaders:
        X-Forwarded-Proto: "https"
EOF

  echo "Added Cloudflare IP whitelist and header configuration."
fi

# Update routers to use Cloudflare middlewares
ROUTERS=("traefik-dashboard" "lms-router" "draw-router" "syncthing-router")

for router in "${ROUTERS[@]}"; do
  # Check if the router exists
  if grep -q "$router:" $CONFIG_PATH; then
    # Check if middlewares already include cloudflare-ip-whitelist and cf-headers
    if grep -A10 "$router:" $CONFIG_PATH | grep -q "middlewares:" && 
       grep -A15 "$router:" $CONFIG_PATH | grep -q "cloudflare-ip-whitelist"; then
      echo "Router $router already configured with Cloudflare middlewares."
    else
      # Add or update middlewares
      if grep -A10 "$router:" $CONFIG_PATH | grep -q "middlewares:"; then
        # Add to existing middlewares
        sed -i "/middlewares:/,/\(^ \{4\}\S\|^ \{0,3\}\S\)/{s/- auth/- auth\n        - cloudflare-ip-whitelist\n        - cf-headers/}" $CONFIG_PATH
        echo "Added Cloudflare middlewares to existing middleware list for $router."
      else
        # Add new middlewares section
        sed -i "/$router:/,/\(\s\{2\}\S\)/{s/\(\s\{2\}\S\)/      middlewares:\n        - cloudflare-ip-whitelist\n        - cf-headers\n\1/}" $CONFIG_PATH
        echo "Added new middlewares section with Cloudflare middlewares for $router."
      fi
    fi
  else
    echo "Router $router not found in config."
  fi
done

echo "Restarting Traefik to apply changes..."
cd /home/delorenj/code/DeLoContainers/core/traefik && docker compose restart

echo "Configuration complete!"
echo "Next steps:"
echo "1. Set up Cloudflare Tunnel as described in the README"
echo "2. Make sure all your DNS records in Cloudflare are set to 'proxied' (orange cloud)"
