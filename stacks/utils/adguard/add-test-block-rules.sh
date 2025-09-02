#!/bin/bash

echo "🚫 Adding Test Block Rules to AdGuard"
echo "===================================="

# Add specific domains to test blocking
echo "Adding Roblox domains to AdGuard block list..."

# Method 1: Add via API to custom rules
curl -X POST "http://localhost:3000/control/filtering/add_url" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Custom Block Test Rules",
    "url": "data:text/plain;base64,'$(echo -e "||roblox.com^\n||*.roblox.com^\n||rbxcdn.com^\n||*.rbxcdn.com^\n||facebook.com^\n||*.facebook.com^\n||instagram.com^\n||*.instagram.com^" | base64 -w 0)'"
  }' || echo "API method failed"

echo ""
echo "Adding DNS rewrites for immediate testing..."

# Method 2: Add DNS rewrites for specific domains
curl -X POST "http://localhost:3000/control/rewrite/add" \
  -H "Content-Type: application/json" \
  -d '{
    "domain": "roblox.com",
    "answer": "192.168.1.12"
  }' && echo "✅ Added roblox.com rewrite"

curl -X POST "http://localhost:3000/control/rewrite/add" \
  -H "Content-Type: application/json" \
  -d '{
    "domain": "*.roblox.com",
    "answer": "192.168.1.12"
  }' && echo "✅ Added *.roblox.com rewrite"

curl -X POST "http://localhost:3000/control/rewrite/add" \
  -H "Content-Type: application/json" \
  -d '{
    "domain": "facebook.com",
    "answer": "192.168.1.12"
  }' && echo "✅ Added facebook.com rewrite"

echo ""
echo "🧪 Testing the configuration..."
sleep 3

echo "Testing DNS resolution:"
nslookup roblox.com localhost
echo ""
nslookup facebook.com localhost

echo ""
echo "📋 Manual AdGuard UI Configuration:"
echo "1. Visit https://adguard.delo.sh"
echo "2. Go to 'Filters' > 'DNS rewrites'"
echo "3. Verify the rules were added"
echo "4. Go to 'Settings' > 'DNS settings'"
echo "5. Ensure 'Blocking mode' = 'Custom IP' with IP: 192.168.1.12"

echo ""
echo "✨ Now test: curl -v http://roblox.com/ or visit in browser!"