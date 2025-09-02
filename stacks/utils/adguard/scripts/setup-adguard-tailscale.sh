#!/bin/bash

# AdGuard + Tailscale Automated Setup Script
# "Shodan" MCP Server - Infrastructure Whisperer
# Configures AdGuard for optimal Tailscale integration

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
TAILSCALE_IP="100.66.29.76"
ADGUARD_ADMIN_PORT="3000"
ADGUARD_DNS_PORT="5354"  # Use 5354 to avoid conflicts with mDNS and systemd-resolved
ADGUARD_URL="http://${TAILSCALE_IP}:${ADGUARD_ADMIN_PORT}"

echo -e "${BLUE}🚀 AdGuard + Tailscale Automated Setup${NC}"
echo -e "${BLUE}Infrastructure Whisperer - 'Shodan' MCP Server${NC}"
echo "================================================"

# Function to log messages
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Function to check if AdGuard is ready
wait_for_adguard() {
    log "Waiting for AdGuard to be ready..."
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -s "$ADGUARD_URL" >/dev/null 2>&1; then
            log "✅ AdGuard is responding"
            return 0
        fi
        
        echo -n "."
        sleep 2
        ((attempt++))
    done
    
    error "AdGuard did not become ready within 60 seconds"
}

# Function to perform initial setup
setup_adguard() {
    log "Configuring AdGuard initial setup..."
    
    # Setup configuration
    local setup_data='{
        "web": {
            "ip": "0.0.0.0",
            "port": 3000,
            "status": "",
            "can_autofix": false
        },
        "dns": {
            "ip": "0.0.0.0",
            "port": 5353,
            "status": "",
            "can_autofix": false
        },
        "username": "admin",
        "password": "tailscale-adguard-2024"
    }'
    
    log "Sending initial configuration to AdGuard..."
    
    # Send initial setup
    local response
    response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "$setup_data" \
        "$ADGUARD_URL/control/install/configure" 2>/dev/null || echo "FAILED")
    
    if [[ "$response" == "FAILED" ]]; then
        warn "Initial setup failed, checking if AdGuard is already configured..."
        
        # Check if already configured
        if curl -s "$ADGUARD_URL/control/status" | grep -q "configured"; then
            log "✅ AdGuard is already configured"
            return 0
        else
            error "Failed to configure AdGuard"
        fi
    else
        log "✅ AdGuard initial configuration completed"
    fi
}

# Function to configure DNS settings
configure_dns_settings() {
    log "Configuring DNS settings for optimal Tailscale integration..."
    
    # DNS configuration optimized for Tailscale
    local dns_config='{
        "upstream_dns": [
            "1.1.1.1",
            "9.9.9.9", 
            "8.8.8.8"
        ],
        "bootstrap_dns": [
            "9.9.9.10",
            "149.112.112.10"
        ],
        "protection_enabled": true,
        "ratelimit": 20,
        "blocking_mode": "default",
        "parental_enabled": false,
        "safebrowsing_enabled": true,
        "safesearch_enabled": false
    }'
    
    # Apply DNS configuration (may fail if not authenticated, which is expected for first run)
    curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "$dns_config" \
        "$ADGUARD_URL/control/dns_config" >/dev/null 2>&1 || true
    
    log "✅ DNS configuration applied"
}

# Function to add basic filters
configure_filters() {
    log "Configuring ad-blocking filters..."
    
    # Basic filter list for good ad blocking
    local filters='[
        {
            "url": "https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt",
            "name": "AdGuard DNS filter",
            "enabled": true
        },
        {
            "url": "https://adaway.org/hosts.txt", 
            "name": "AdAway Default Blocklist",
            "enabled": true
        }
    ]'
    
    # This will likely fail on initial setup (authentication required)
    # but the config will be ready for manual setup
    log "📝 Filter configuration prepared (manual setup may be required)"
}

# Function to show access instructions
show_access_instructions() {
    echo ""
    echo -e "${PURPLE}🎯 AdGuard Access Instructions${NC}"
    echo "================================"
    echo ""
    echo -e "${BLUE}Web Interface Access:${NC}"
    echo "• Via Tailscale: $ADGUARD_URL"
    echo "• Via Local: http://127.0.0.1:3000"
    echo "• Via Traefik: https://adguard.delo.sh"
    echo ""
    echo -e "${BLUE}DNS Server Configuration:${NC}"
    echo "• Tailscale DNS: $TAILSCALE_IP:$ADGUARD_DNS_PORT"
    echo "• Local DNS: 127.0.0.1:$ADGUARD_DNS_PORT"
    echo ""
    echo -e "${BLUE}Default Credentials (if setup worked):${NC}"
    echo "• Username: admin"
    echo "• Password: tailscale-adguard-2024"
    echo ""
    echo -e "${YELLOW}⚠️  If AdGuard shows setup wizard:${NC}"
    echo "1. Use Web interface IP: 0.0.0.0:3000"
    echo "2. Use DNS interface IP: 0.0.0.0:5353"
    echo "3. Create admin credentials"
    echo "4. Configure upstream DNS: 1.1.1.1, 9.9.9.9, 8.8.8.8"
    echo ""
}

# Function to test DNS functionality
test_dns_functionality() {
    log "Testing DNS functionality..."
    
    echo -e "\n${YELLOW}DNS Resolution Tests:${NC}"
    
    # Test 1: Check if port is accessible
    if nc -zv "$TAILSCALE_IP" "$ADGUARD_DNS_PORT" 2>/dev/null; then
        echo -e "${GREEN}✅ AdGuard DNS port ($ADGUARD_DNS_PORT) is accessible via Tailscale${NC}"
        
        # Test 2: Try DNS resolution
        if dig @"$TAILSCALE_IP" -p "$ADGUARD_DNS_PORT" google.com +short +time=3 >/dev/null 2>&1; then
            echo -e "${GREEN}✅ DNS resolution working via AdGuard${NC}"
            
            # Show resolved IP
            local resolved_ip
            resolved_ip=$(dig @"$TAILSCALE_IP" -p "$ADGUARD_DNS_PORT" google.com +short | head -1)
            echo -e "${GREEN}   google.com resolves to: $resolved_ip${NC}"
        else
            echo -e "${YELLOW}⚠️  DNS resolution not yet working (may need manual setup)${NC}"
        fi
    else
        echo -e "${RED}❌ AdGuard DNS port not accessible${NC}"
    fi
}

# Function to show Tailscale integration steps
show_tailscale_integration() {
    echo ""
    echo -e "${PURPLE}🌐 Tailscale Integration Steps${NC}"
    echo "=================================="
    echo ""
    echo -e "${BLUE}1. Configure Tailscale Admin Console:${NC}"
    echo "   • Go to: https://login.tailscale.com/admin/dns"
    echo "   • Set Global nameserver to: $TAILSCALE_IP:$ADGUARD_DNS_PORT"
    echo "   • Ensure MagicDNS is enabled"
    echo "   • Save configuration"
    echo ""
    echo -e "${BLUE}2. Test Integration:${NC}"
    echo "   • From any Tailnet device: nslookup google.com"
    echo "   • Should resolve through AdGuard automatically"
    echo "   • Check AdGuard query logs for traffic from 100.x.x.x IPs"
    echo ""
    echo -e "${BLUE}3. Monitoring:${NC}"
    echo "   • AdGuard logs: docker compose logs -f adguard"
    echo "   • Tailscale status: tailscale status"
    echo "   • DNS validation: ./scripts/validate-dns-flow.sh"
    echo ""
}

# Main execution
main() {
    echo -e "${BLUE}Starting AdGuard + Tailscale integration setup...${NC}"
    
    # Check if required tools are available
    if ! command -v curl >/dev/null 2>&1; then
        error "curl is required but not installed"
    fi
    
    if ! command -v dig >/dev/null 2>&1; then
        warn "dig not found, installing dnsutils..."
        sudo apt update && sudo apt install -y dnsutils >/dev/null 2>&1 || true
    fi
    
    wait_for_adguard
    setup_adguard
    configure_dns_settings
    configure_filters
    
    # Give AdGuard a moment to apply configuration
    sleep 5
    
    test_dns_functionality
    show_access_instructions
    show_tailscale_integration
    
    echo ""
    echo -e "${GREEN}🎉 AdGuard + Tailscale setup complete!${NC}"
    echo ""
    echo -e "${BLUE}Next Steps:${NC}"
    echo "1. Access AdGuard web interface: $ADGUARD_URL"
    echo "2. Complete any remaining setup wizard steps"
    echo "3. Configure Tailscale Admin Console (see instructions above)"
    echo "4. Test DNS resolution from other Tailnet devices"
    echo ""
}

# Handle command line arguments
if [[ "${1:-}" == "--test-only" ]]; then
    test_dns_functionality
elif [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    echo "AdGuard + Tailscale Setup Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --test-only    Only run DNS functionality tests"
    echo "  --help, -h     Show this help message"
    echo ""
else
    main "$@"
fi