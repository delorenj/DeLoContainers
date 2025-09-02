#!/bin/bash

# AdGuard Custom Redirect Configuration Script
# This script configures AdGuard Home to redirect blocked requests to your custom landing page

set -e

echo "🚀 Configuring AdGuard Home for custom redirect to https://nope.delo.sh?sound=true"

# Get the container's IP address for the redirect service
REDIRECT_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' adguard-redirect 2>/dev/null || echo "172.19.0.10")

echo "📍 Redirect service IP: $REDIRECT_IP"

# Backup current configuration
if [ -f "./conf/AdGuardHome.yaml" ]; then
    echo "📋 Backing up current AdGuard configuration..."
    cp ./conf/AdGuardHome.yaml ./conf/AdGuardHome.yaml.backup.$(date +%Y%m%d_%H%M%S)
fi

echo "⚙️ Configuring AdGuard Home to use custom blocking mode..."

# API configuration to set custom blocking IP
curl -s -X POST "http://localhost:3000/control/dns_config" \
  -H "Content-Type: application/json" \
  -d "{
    \"blocking_mode\": \"custom_ip\",
    \"blocking_ipv4\": \"$REDIRECT_IP\",
    \"blocking_ipv6\": \"::\",
    \"blocked_response_ttl\": 300
  }" || echo "⚠️ Could not configure via API (AdGuard may not be running yet)"

echo "✅ Configuration complete!"
echo ""
echo "📝 Next steps:"
echo "1. Start the services: docker compose up -d"
echo "2. Access AdGuard admin panel at https://adguard.delo.sh"
echo "3. Go to Settings > DNS settings"
echo "4. Set 'Blocking mode' to 'Custom IP'"
echo "5. Set 'Custom blocking IPv4' to: $REDIRECT_IP"
echo "6. Set 'Custom blocking IPv6' to: ::"
echo ""
echo "🎯 When AdGuard blocks a request, users will see a redirect page"
echo "   that automatically forwards them to: https://nope.delo.sh?sound=true"
echo ""
echo "🔍 Test by trying to access a blocked domain after configuration"