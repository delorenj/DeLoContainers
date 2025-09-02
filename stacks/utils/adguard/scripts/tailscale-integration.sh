#!/bin/bash

# Tailscale + AdGuard Integration Script
# "Shodan" MCP Server Implementation
# Infrastructure Whisperer - DNS Integration Automation

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TAILSCALE_IP="100.66.29.76"
ADGUARD_PORT="5354"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADGUARD_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}🌐 Tailscale + AdGuard Integration Script${NC}"
echo -e "${BLUE}Infrastructure Whisperer - 'Shodan' MCP Server${NC}"
echo "=============================================="

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

# Function to check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if Tailscale is installed and running
    if ! command -v tailscale &> /dev/null; then
        error "Tailscale is not installed"
    fi
    
    if ! systemctl is-active --quiet tailscaled; then
        error "Tailscale daemon is not running"
    fi
    
    # Check if we have the expected Tailscale IP
    CURRENT_TS_IP=$(tailscale ip -4 2>/dev/null || echo "none")
    if [[ "$CURRENT_TS_IP" != "$TAILSCALE_IP" ]]; then
        warn "Expected Tailscale IP $TAILSCALE_IP but found $CURRENT_TS_IP"
        TAILSCALE_IP="$CURRENT_TS_IP"
    fi
    
    # Check if AdGuard container is running
    if ! docker compose -f "$ADGUARD_DIR/compose.yml" ps | grep -q "Up.*healthy"; then
        error "AdGuard container is not running or healthy"
    fi
    
    log "✅ All prerequisites met"
}

# Function to test DNS resolution
test_dns_resolution() {
    local test_domain="$1"
    local dns_server="$2"
    local dns_port="$3"
    
    log "Testing DNS resolution: $test_domain via $dns_server:$dns_port"
    
    if nslookup "$test_domain" "$dns_server" -port="$dns_port" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ SUCCESS: $test_domain resolved via $dns_server:$dns_port${NC}"
        return 0
    else
        echo -e "${RED}❌ FAILED: $test_domain could not be resolved via $dns_server:$dns_port${NC}"
        return 1
    fi
}

# Function to validate current setup
validate_current_setup() {
    log "Validating current setup..."
    
    # Test AdGuard DNS resolution
    if test_dns_resolution "google.com" "$TAILSCALE_IP" "$ADGUARD_PORT"; then
        log "✅ AdGuard DNS resolution working"
    else
        error "AdGuard DNS resolution failed"
    fi
    
    # Test Tailscale connectivity
    if ping -c 1 "$TAILSCALE_IP" >/dev/null 2>&1; then
        log "✅ Tailscale interface accessible"
    else
        error "Cannot reach Tailscale interface"
    fi
    
    # Check if port 5353 is accessible from Tailscale interface
    if nc -zv "$TAILSCALE_IP" "$ADGUARD_PORT" 2>/dev/null; then
        log "✅ AdGuard port accessible via Tailscale interface"
    else
        error "AdGuard port not accessible via Tailscale interface"
    fi
}

# Function to create backup
create_backup() {
    log "Creating configuration backup..."
    
    local backup_dir="$ADGUARD_DIR/backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Backup AdGuard configuration
    if [[ -d "$ADGUARD_DIR/conf" ]]; then
        cp -r "$ADGUARD_DIR/conf" "$backup_dir/"
        log "✅ AdGuard configuration backed up"
    fi
    
    # Backup Tailscale status
    tailscale status --json > "$backup_dir/tailscale-status.json" 2>/dev/null || true
    
    # Save current DNS configuration
    cp /etc/resolv.conf "$backup_dir/resolv.conf" 2>/dev/null || true
    
    log "✅ Backup created at: $backup_dir"
}

# Function to show Tailscale admin console instructions
show_admin_instructions() {
    echo ""
    echo -e "${BLUE}🎯 MANUAL CONFIGURATION REQUIRED${NC}"
    echo "========================================="
    echo ""
    echo -e "${YELLOW}⚠️  YOU MUST CONFIGURE TAILSCALE ADMIN CONSOLE MANUALLY:${NC}"
    echo ""
    echo "1. Open your browser and go to: https://login.tailscale.com/admin/dns"
    echo ""
    echo "2. In the 'Global nameservers' section, add:"
    echo -e "   ${GREEN}$TAILSCALE_IP:$ADGUARD_PORT${NC}"
    echo ""
    echo "3. Ensure 'MagicDNS' is enabled (should be checked)"
    echo ""
    echo "4. Click 'Save' to apply the configuration"
    echo ""
    echo -e "${BLUE}This will route ALL DNS queries from Tailnet devices through AdGuard${NC}"
    echo ""
}

# Function to test the integration
test_integration() {
    log "Testing Tailscale + AdGuard integration..."
    
    echo ""
    echo -e "${BLUE}🧪 INTEGRATION TESTS${NC}"
    echo "===================="
    
    # Test 1: Basic DNS resolution through AdGuard
    echo -e "\n${YELLOW}Test 1: DNS Resolution via AdGuard${NC}"
    test_dns_resolution "google.com" "$TAILSCALE_IP" "$ADGUARD_PORT"
    
    # Test 2: AdGuard filtering (if configured)
    echo -e "\n${YELLOW}Test 2: DNS Filtering Test${NC}"
    if test_dns_resolution "malware.testing.com" "$TAILSCALE_IP" "$ADGUARD_PORT"; then
        warn "Malware test domain was resolved - check AdGuard filters"
    else
        log "✅ Malware test domain blocked (good if intended)"
    fi
    
    # Test 3: MagicDNS still working
    echo -e "\n${YELLOW}Test 3: MagicDNS Functionality${NC}"
    if ping -c 1 big-chungus >/dev/null 2>&1; then
        log "✅ MagicDNS working (big-chungus resolved)"
    else
        warn "MagicDNS might not be working (big-chungus not resolved)"
    fi
    
    # Test 4: Tailscale peer connectivity
    echo -e "\n${YELLOW}Test 4: Tailscale Peer Status${NC}"
    local peer_count=$(tailscale status | grep -c "^100\." || echo "0")
    log "✅ Tailscale peers visible: $peer_count"
}

# Function to show post-setup instructions
show_post_setup_instructions() {
    echo ""
    echo -e "${GREEN}🎉 INTEGRATION SETUP COMPLETE${NC}"
    echo "=============================="
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "1. Configure Tailscale Admin Console (see instructions above)"
    echo "2. Test DNS resolution from other Tailnet devices"
    echo "3. Monitor AdGuard query logs for Tailnet traffic"
    echo "4. Adjust AdGuard filters as needed"
    echo ""
    echo -e "${BLUE}Monitoring:${NC}"
    echo "• AdGuard admin: https://adguard.delo.sh"
    echo "• AdGuard logs: docker compose -f $ADGUARD_DIR/compose.yml logs -f"
    echo "• Tailscale status: tailscale status"
    echo ""
    echo -e "${BLUE}DNS Configuration Summary:${NC}"
    echo "• Tailscale IP: $TAILSCALE_IP"
    echo "• AdGuard DNS Port: $ADGUARD_PORT"
    echo "• Global Nameserver: $TAILSCALE_IP:$ADGUARD_PORT"
    echo ""
}

# Main execution
main() {
    echo -e "${BLUE}Starting Tailscale + AdGuard integration...${NC}"
    
    check_prerequisites
    create_backup
    validate_current_setup
    show_admin_instructions
    
    echo ""
    read -p "Have you configured the Tailscale Admin Console? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        test_integration
        show_post_setup_instructions
    else
        echo ""
        echo -e "${YELLOW}⚠️  Please configure the Tailscale Admin Console first, then run this script again${NC}"
        echo "   Or run: $0 --test-only to skip the admin console check"
    fi
}

# Handle command line arguments
if [[ "${1:-}" == "--test-only" ]]; then
    check_prerequisites
    validate_current_setup
    test_integration
elif [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    echo "Tailscale + AdGuard Integration Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --test-only    Run tests without requiring admin console configuration"
    echo "  --help, -h     Show this help message"
    echo ""
else
    main "$@"
fi