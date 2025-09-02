#!/bin/bash

echo "🔍 AdGuard Custom Redirect Debug Script"
echo "========================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    if [ $2 -eq 0 ]; then
        echo -e "${GREEN}✅ $1${NC}"
    else
        echo -e "${RED}❌ $1${NC}"
    fi
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

echo "1. Checking service status..."
docker compose ps

echo -e "\n2. Testing redirect service health..."
HEALTH_RESPONSE=$(curl -s -w "%{http_code}" http://localhost:8888/health -o /dev/null)
print_status "Redirect service health check" $([[ "$HEALTH_RESPONSE" == "200" ]] && echo 0 || echo 1)

echo -e "\n3. Getting service IP addresses..."
REDIRECT_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' adguard-redirect)
ADGUARD_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' adguard)
echo "Redirect service IP: $REDIRECT_IP"
echo "AdGuard IP: $ADGUARD_IP"

echo -e "\n4. Testing redirect service directly..."
curl -s -I http://localhost:8888/ | head -5
echo ""

echo -e "\n5. Testing internal network connectivity..."
docker exec adguard ping -c 2 $REDIRECT_IP 2>/dev/null
PING_RESULT=$?
print_status "AdGuard can reach redirect service" $PING_RESULT

echo -e "\n6. Simulating DNS queries..."
echo "Testing from big-chungus (should bypass filters):"
nslookup roblox.com localhost 2>/dev/null | grep -A 2 "Name:"

echo -e "\n7. Checking AdGuard query logs for recent activity..."
docker compose logs adguard --tail=5

echo -e "\n8. Configuration recommendations..."
print_warning "Since you're testing from big-chungus (192.168.1.12), you need to:"
echo "   • Configure AdGuard via web UI at https://adguard.delo.sh"
echo "   • Go to Settings > DNS settings"
echo "   • Set Blocking mode to 'Custom IP'"
echo "   • Set Custom blocking IPv4 to: $REDIRECT_IP"
echo "   • Set Custom blocking IPv6 to: ::"
echo ""
print_warning "To test the redirect, use a device that has AdGuard as its DNS server."
echo ""

echo "9. Quick test commands for filtered devices..."
echo "From a filtered device, run these commands:"
echo "   nslookup roblox.com"
echo "   curl -v http://roblox.com/"
echo ""

echo "10. Manual AdGuard configuration check..."
echo "Visit: https://adguard.delo.sh"
echo "Check: Settings > DNS Settings > Blocking mode"
echo "Should be: Custom IP = $REDIRECT_IP"