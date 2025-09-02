#!/bin/bash

echo "🔧 Fixing AdGuard HTTPS DNS Type Errors"
echo "======================================="

# The errors we're seeing:
# "dnsforward: invalid message type for custom IP blocking mode dns_type=HTTPS"
# This happens because AdGuard can't handle HTTPS DNS queries in Custom IP mode

echo "Creating AdGuard configuration patch..."

# Create a temporary configuration update
cat > /tmp/adguard_dns_config.json << 'EOF'
{
  "blocking_mode": "custom_ip",
  "blocking_ipv4": "172.19.0.15",
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

echo "Applying DNS configuration via API..."
curl -X POST "http://localhost:3000/control/dns_config" \
  -H "Content-Type: application/json" \
  -d @/tmp/adguard_dns_config.json

RESULT=$?
if [ $RESULT -eq 0 ]; then
    echo "✅ Configuration applied successfully"
else
    echo "❌ Configuration failed. Manual setup required."
    echo ""
    echo "Manual steps:"
    echo "1. Visit https://adguard.delo.sh"
    echo "2. Go to Settings > DNS Settings"
    echo "3. Set Blocking mode to 'Custom IP'"
    echo "4. Set Custom blocking IPv4 to: 172.19.0.15"
    echo "5. Set Custom blocking IPv6 to: ::"
    echo "6. Set Response TTL to: 300"
    echo "7. Click 'Save'"
fi

# Cleanup
rm -f /tmp/adguard_dns_config.json

echo ""
echo "🧪 Testing configuration..."
sleep 2

# Check if configuration was applied
curl -s "http://localhost:3000/control/dns_info" > /tmp/dns_status.json 2>/dev/null
if [ -f /tmp/dns_status.json ] && [ -s /tmp/dns_status.json ]; then
    echo "Current blocking mode: $(grep -o '"blocking_mode":"[^"]*"' /tmp/dns_status.json | cut -d'"' -f4)"
    echo "Current custom IP: $(grep -o '"blocking_ipv4":"[^"]*"' /tmp/dns_status.json | cut -d'"' -f4)"
    rm -f /tmp/dns_status.json
else
    echo "Could not retrieve current DNS configuration"
fi

echo ""
echo "📋 Next steps:"
echo "1. Wait 30 seconds for configuration to take effect"
echo "2. Test from a filtered device using: ./test-from-filtered-device.sh"
echo "3. Monitor logs: docker compose logs adguard --follow"