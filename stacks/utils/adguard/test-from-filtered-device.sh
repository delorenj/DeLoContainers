#!/bin/bash

# Script to test the redirect functionality from a device using AdGuard DNS
# Run this on a device that uses 192.168.1.12 as its DNS server

echo "🧪 Testing AdGuard Custom Redirect from Filtered Device"
echo "======================================================"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}1. Testing DNS resolution...${NC}"
echo "Expected: Should resolve to 172.19.0.15 (redirect service)"
nslookup roblox.com

echo -e "\n${BLUE}2. Testing HTTP redirect...${NC}"
echo "Expected: Should get HTML redirect page or redirect response"
echo "Command: curl -v -L --max-time 10 http://roblox.com/"
curl -v -L --max-time 10 http://roblox.com/ 2>&1 | head -20

echo -e "\n${BLUE}3. Testing direct redirect service access...${NC}"
echo "Command: curl -v --max-time 5 http://172.19.0.15/"
curl -v --max-time 5 http://172.19.0.15/ 2>&1 | head -10

echo -e "\n${BLUE}4. Alternative test domains (if Roblox not blocked):${NC}"
echo "Try these other domains:"
echo "• facebook.com"
echo "• instagram.com" 
echo "• tiktok.com"
echo "• youtube.com"

echo -e "\n${YELLOW}💡 Troubleshooting Tips:${NC}"
echo "If you see 'Connection timeout' or 'hangs forever':"
echo "1. The device isn't using AdGuard as DNS server"
echo "2. AdGuard isn't configured for Custom IP blocking mode"
echo "3. The domain isn't in AdGuard's block lists"
echo ""
echo "If you see the redirect page but no redirect happens:"
echo "1. Check if https://nope.delo.sh?sound=true is accessible"
echo "2. Check browser console for JavaScript errors"
echo ""
echo "Expected successful flow:"
echo "DNS Query → 172.19.0.15 → Redirect Page → https://nope.delo.sh?sound=true"