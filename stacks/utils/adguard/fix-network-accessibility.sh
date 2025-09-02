#!/bin/bash

echo "🔧 Fixing Network Accessibility Issue"
echo "====================================="

# The issue: AdGuard returns container IP (172.19.0.15) but LAN devices can't reach it
# The solution: Configure AdGuard to return the host IP (192.168.1.12) instead

HOST_IP="192.168.1.12"
REDIRECT_PORT="8888"

echo "Configuring AdGuard to use host IP ($HOST_IP) for blocked requests..."

# Update AdGuard DNS configuration to use host IP instead of container IP
cat > /tmp/adguard_dns_config.json << EOF
{
  "blocking_mode": "custom_ip",
  "blocking_ipv4": "$HOST_IP",
  "blocking_ipv6": "::",
  "blocked_response_ttl": 300,
  "protection_enabled": true,
  "filtering_enabled": true,
  "parental_enabled": false,
  "safebrowsing_enabled": true,
  "safesearch_enabled": false,
  "resolve_clients": true,
  "use_private_ptr_resolvers": true,
  "local_ptr_upstreams": [],
  "upstream_dns": [
    "https://dns10.quad9.net:443/dns-query",
    "https://dns.cloudflare.com/dns-query"
  ],
  "upstream_dns_file": "",
  "bootstrap_dns": [
    "9.9.9.10",
    "149.112.112.10",
    "1.1.1.1"
  ],
  "fallback_dns": [],
  "upstream_mode": "",
  "fastest_timeout": "1s",
  "allowed_clients": [],
  "disallowed_clients": [],
  "blocked_hosts": [
    "version.bind",
    "id.server",
    "hostname.bind"
  ],
  "cache_size": 4194304,
  "cache_ttl_min": 60,
  "cache_ttl_max": 3600,
  "cache_optimistic": false,
  "bogus_nxdomain": [],
  "aaaa_disabled": false,
  "enable_dnssec": false,
  "edns_client_subnet": {
    "custom_ip": "",
    "enabled": false,
    "use_custom": false
  },
  "max_goroutines": 300,
  "handle_ddr": true,
  "ipset": [],
  "ipset_file": ""
}
EOF

echo "Applying configuration via API..."
curl -X POST "http://localhost:3000/control/dns_config" \
  -H "Content-Type: application/json" \
  -d @/tmp/adguard_dns_config.json

RESULT=$?
if [ $RESULT -eq 0 ]; then
    echo "✅ Configuration applied successfully"
    echo ""
    echo "New flow:"
    echo "1. User requests blocked domain (e.g., roblox.com)"
    echo "2. AdGuard DNS returns: $HOST_IP"
    echo "3. Browser connects to: http://$HOST_IP:$REDIRECT_PORT/"
    echo "4. Redirect service serves countdown page"
    echo "5. JavaScript redirects to: https://nope.delo.sh?sound=true"
    echo ""
else
    echo "❌ API configuration failed. Use manual configuration:"
    echo ""
    echo "1. Visit https://adguard.delo.sh"
    echo "2. Go to Settings > DNS Settings"
    echo "3. Set Blocking mode to 'Custom IP'"
    echo "4. Set Custom blocking IPv4 to: $HOST_IP"
    echo "5. Set Custom blocking IPv6 to: ::"
    echo "6. Click 'Save'"
fi

# Cleanup
rm -f /tmp/adguard_dns_config.json

echo ""
echo "🧪 Testing the fix..."
echo "From any device on your network, run these tests:"
echo ""
echo "# Test 1: Verify redirect service is accessible from LAN"
echo "curl http://$HOST_IP:$REDIRECT_PORT/"
echo ""
echo "# Test 2: Check DNS resolution (should return $HOST_IP)"
echo "nslookup roblox.com $HOST_IP"
echo ""
echo "# Test 3: Test the full redirect flow"
echo "curl -v http://roblox.com/"

echo ""
echo "✨ Expected result: Pages should now redirect properly instead of hanging!"