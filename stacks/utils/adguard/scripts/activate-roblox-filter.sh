#!/bin/bash
# Activate Roblox blocking filter in AdGuard Home

set -e

echo "🎮 Activating Roblox Blocking Filter..."

# AdGuard admin credentials (update if needed)
ADMIN_USER="${ADMIN_USER:-admin}"
ADMIN_PASS="${ADMIN_PASS:-admin}"
AG_HOST="${AG_HOST:-localhost:6767}"

# Copy filter to the container if not already there
if [ -f "filters/roblox-block.txt" ]; then
    echo "📋 Filter file found, copying to container..."
    docker cp filters/roblox-block.txt adguard:/opt/adguardhome/filters/roblox-block.txt
    echo "✅ Filter file copied"
fi

# Add the custom filter via API
echo "🔧 Adding Roblox filter to AdGuard Home..."
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "http://${AG_HOST}/control/filtering/add_url" \
  -H "Content-Type: application/json" \
  -u "${ADMIN_USER}:${ADMIN_PASS}" \
  -d '{
    "url": "file:///opt/adguardhome/filters/roblox-block.txt",
    "name": "Roblox Block List",
    "whitelist": false
  }')

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

if [ "$HTTP_CODE" -eq 200 ] || [ "$HTTP_CODE" -eq 201 ]; then
    echo "✅ Roblox filter added successfully!"
elif [ "$HTTP_CODE" -eq 400 ] && echo "$BODY" | grep -q "already exists"; then
    echo "ℹ️  Roblox filter already exists"
else
    echo "❌ Failed to add filter (HTTP $HTTP_CODE): $BODY"
    exit 1
fi

# Force filter update
echo "🔄 Forcing filter refresh..."
curl -s -X POST "http://${AG_HOST}/control/filtering/refresh" \
  -H "Content-Type: application/json" \
  -u "${ADMIN_USER}:${ADMIN_PASS}" \
  -d '{"whitelist": false}' > /dev/null

echo ""
echo "✅ Roblox blocking is now active!"
echo ""
echo "🧪 Test blocking with:"
echo "   nslookup roblox.com 192.168.1.12"
echo "   nslookup rbxcdn.com 192.168.1.12"
echo ""
echo "📱 Configure device 192.168.1.70 to use DNS: 192.168.1.12"
