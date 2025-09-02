#!/bin/bash

echo "🎭 Simulating Blocked Request Flow"
echo "=================================="

echo "1. Testing redirect service directly..."
echo "This simulates what happens when AdGuard redirects a blocked domain:"
curl -v http://localhost:8888/ 2>&1 | head -15

echo -e "\n2. Testing the redirect service with a 'Host' header..."
echo "This simulates a browser request to a blocked domain:"
curl -v -H "Host: roblox.com" http://localhost:8888/ 2>&1 | head -10

echo -e "\n3. Checking if redirect page contains proper JavaScript..."
echo "Looking for the redirect to https://nope.delo.sh?sound=true:"
curl -s http://localhost:8888/ | grep -A 5 -B 5 "nope.delo.sh"

echo -e "\n4. Testing redirect service from AdGuard container..."
echo "This tests internal network connectivity:"
docker exec adguard curl -s http://172.19.0.15/ | head -5

echo -e "\n5. Creating a manual DNS test..."
echo "Simulating what should happen on a filtered device:"
echo ""
echo "Expected flow:"
echo "  User types: roblox.com"
echo "  DNS query goes to AdGuard (192.168.1.12:53)"
echo "  AdGuard returns: 172.19.0.15 (our redirect service)"
echo "  Browser connects to: http://172.19.0.15/"
echo "  Redirect service shows countdown page"
echo "  JavaScript redirects to: https://nope.delo.sh?sound=true&blocked=roblox.com"

echo -e "\n6. Manual testing commands for you to run on a filtered device:"
echo ""
echo "# Test DNS resolution (should return 172.19.0.15)"
echo "nslookup roblox.com"
echo ""
echo "# Test HTTP connection (should show redirect page)"
echo "curl -v http://roblox.com/"
echo ""
echo "# Test with browser - open this URL:"
echo "http://roblox.com/"

echo -e "\n7. Troubleshooting the 'loads forever' issue..."
echo "If pages load forever, it means:"
echo "• DNS is resolving to 172.19.0.15 ✅ (Good)"
echo "• But the HTTP connection to 172.19.0.15:80 is failing ❌"
echo ""
echo "Possible causes:"
echo "a) Firewall blocking port 8888 or internal port 80"
echo "b) Network routing issue between client and docker container"
echo "c) Docker proxy network not accessible from LAN"

echo -e "\n8. Network accessibility test..."
echo "Testing if redirect service is reachable from LAN:"
REDIRECT_INTERNAL_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' adguard-redirect)
echo "Redirect service internal IP: $REDIRECT_INTERNAL_IP"
echo "Redirect service port mapping: 192.168.1.12:8888 → container:80"
echo ""
echo "From any device on your network, test:"
echo "curl http://192.168.1.12:8888/"
echo ""
echo "If that works, the issue is likely that AdGuard isn't properly"
echo "configured to return the redirect service IP for blocked domains."