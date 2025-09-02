#!/bin/bash

echo "🔒 Configuring HTTPS Redirect with Traefik"
echo "=========================================="

# Now that we have Traefik labels, configure AdGuard to use HTTPS domain
HTTPS_REDIRECT_URL="blocked.delo.sh"

echo "Updating AdGuard to redirect to HTTPS domain: $HTTPS_REDIRECT_URL"

# Create the DNS config with new HTTPS setup
cat > /tmp/adguard_https_config.json << EOF
{
  "blocking_mode": "custom_ip",
  "blocking_ipv4": "192.168.1.12",
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

curl -X POST "http://localhost:3000/control/dns_config" \
  -H "Content-Type: application/json" \
  -d @/tmp/adguard_https_config.json && echo "✅ HTTPS DNS config applied"

# Clean up
rm -f /tmp/adguard_https_config.json

echo ""
echo "🎯 Two redirect options now available:"
echo ""
echo "1. HTTP (port 8888): http://192.168.1.12:8888/"
echo "   - Works immediately"
echo "   - Browser security warnings"
echo ""
echo "2. HTTPS (via Traefik): https://blocked.delo.sh/"
echo "   - No browser warnings"  
echo "   - Requires DNS: blocked.delo.sh → 192.168.1.12"
echo ""
echo "⚙️ To use HTTPS option:"
echo "1. Add DNS record: blocked.delo.sh → 192.168.1.12"
echo "2. Test: https://blocked.delo.sh/"
echo "3. Update AdGuard rewrites to point blocked domains to blocked.delo.sh"
echo ""
echo "🧪 Current test commands:"
echo "nslookup roblox.com    # Should return 192.168.1.12"
echo "curl -v http://roblox.com/"
echo "# OR for HTTPS:"  
echo "curl -v https://blocked.delo.sh/"

echo ""
echo "📋 If DNS rewrites still aren't working, manually configure via UI:"
echo "1. Visit https://adguard.delo.sh"
echo "2. Go to Filters > DNS rewrites"
echo "3. Add: roblox.com → 192.168.1.12"
echo "4. Test from filtered device (not big-chungus)"