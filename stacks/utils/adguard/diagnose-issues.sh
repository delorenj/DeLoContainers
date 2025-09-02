#!/bin/bash

echo "🔍 Diagnosing AdGuard Issues"
echo "============================"

echo "1. Checking AdGuard container status..."
docker compose ps adguard

echo -e "\n2. Testing AdGuard web interface accessibility..."
curl -s -I http://localhost:3000/ | head -3

echo -e "\n3. Checking if AdGuard is responding to API calls..."
curl -s -w "HTTP Status: %{http_code}\n" http://localhost:3000/control/status -o /dev/null

echo -e "\n4. Checking AdGuard recent logs for errors..."
docker compose logs adguard --tail=10

echo -e "\n5. Testing DNS from big-chungus (should bypass AdGuard)..."
echo "dig roblox.com @localhost"
dig roblox.com @localhost | grep -A 5 "ANSWER SECTION" || nslookup roblox.com localhost

echo -e "\n6. Testing if port 53 is accessible..."
ss -tulnp | grep :53

echo -e "\n7. Network configuration checks..."
echo "AdGuard container IP:"
docker inspect adguard | grep -A 5 '"IPAddress"' | grep -v '""'

echo -e "\nHost network interfaces:"
ip addr show | grep "inet " | grep -E "(192\.168\.|172\.)"

echo -e "\n8. Manual verification steps needed:"
echo "=================================================="
echo ""
echo "📱 For your phone (local network):"
echo "1. Check phone DNS settings - should be 192.168.1.12"
echo "2. Test: nslookup roblox.com (should return 192.168.1.12 if AdGuard is working)"
echo "3. If not, phone might not be using AdGuard DNS"
echo ""
echo "📱 For your iPad (Tailscale):"
echo "1. Tailscale might be overriding DNS settings"
echo "2. Check Tailscale DNS configuration"
echo "3. AdGuard needs to be configured as Tailscale DNS server"
echo ""
echo "🛠️ Quick fixes to try:"
echo "1. Restart AdGuard: docker compose restart adguard"
echo "2. Check router DHCP - is it assigning 192.168.1.12 as DNS?"
echo "3. Check Tailscale DNS settings in admin panel"
echo ""
echo "🧪 Test commands for devices:"
echo "Phone: nslookup roblox.com"
echo "iPad:  nslookup roblox.com" 
echo "(Both should return 192.168.1.12 if using AdGuard DNS)"