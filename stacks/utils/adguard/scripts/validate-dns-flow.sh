#!/bin/bash

# DNS Flow Validation Script
# Part of "Shodan" MCP Server - Tailscale + AdGuard Integration
# Infrastructure Whisperer - Comprehensive DNS Testing Suite

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
ADGUARD_PORT="5354"
LOCAL_DNS="127.0.0.53"

# Test domains
TEST_DOMAINS=(
    "google.com"
    "cloudflare.com" 
    "github.com"
    "reddit.com"
    "stackoverflow.com"
)

MALICIOUS_DOMAINS=(
    "malware.testing.com"
    "testmalware.com"
    "roblox.com"  # Should be blocked based on your filters
)

INTERNAL_DOMAINS=(
    "big-chungus"
    "tiny-chungus.tailnet-name.ts.net"
)

echo -e "${BLUE}🔍 DNS Flow Validation Suite${NC}"
echo -e "${BLUE}'Shodan' MCP Server - Infrastructure Whisperer${NC}"
echo "================================================"
echo ""

# Function to perform DNS lookup with detailed output
test_dns_lookup() {
    local domain="$1"
    local dns_server="$2"
    local dns_port="${3:-53}"
    local test_name="$4"
    
    echo -e "${YELLOW}Testing: $test_name${NC}"
    echo "Domain: $domain | DNS: $dns_server:$dns_port"
    
    # Use dig for more detailed output
    if command -v dig >/dev/null 2>&1; then
        local result
        result=$(dig @"$dns_server" -p "$dns_port" "$domain" +short +time=3 +tries=1 2>/dev/null || echo "FAILED")
        
        if [[ "$result" != "FAILED" && -n "$result" ]]; then
            echo -e "${GREEN}✅ SUCCESS${NC}: $result"
            return 0
        else
            echo -e "${RED}❌ FAILED${NC}: No response or timeout"
            return 1
        fi
    else
        # Fallback to nslookup
        if nslookup "$domain" "$dns_server" -port="$dns_port" >/dev/null 2>&1; then
            local ip
            ip=$(nslookup "$domain" "$dns_server" -port="$dns_port" 2>/dev/null | grep -A1 "Name:" | tail -1 | awk '{print $2}' || echo "resolved")
            echo -e "${GREEN}✅ SUCCESS${NC}: $ip"
            return 0
        else
            echo -e "${RED}❌ FAILED${NC}: Resolution failed"
            return 1
        fi
    fi
}

# Function to test DNS latency
test_dns_latency() {
    local domain="$1"
    local dns_server="$2"
    local dns_port="${3:-53}"
    
    if command -v dig >/dev/null 2>&1; then
        local latency
        latency=$(dig @"$dns_server" -p "$dns_port" "$domain" | grep "Query time:" | awk '{print $4}' || echo "unknown")
        if [[ "$latency" != "unknown" && "$latency" =~ ^[0-9]+$ ]]; then
            if (( latency < 50 )); then
                echo -e "${GREEN}⚡ Latency: ${latency}ms (excellent)${NC}"
            elif (( latency < 100 )); then
                echo -e "${YELLOW}⚡ Latency: ${latency}ms (good)${NC}"
            else
                echo -e "${RED}⚡ Latency: ${latency}ms (slow)${NC}"
            fi
        else
            echo -e "${YELLOW}⚡ Latency: unknown${NC}"
        fi
    fi
}

# Function to check AdGuard query logs
check_adguard_logs() {
    echo -e "\n${PURPLE}📊 AdGuard Query Statistics${NC}"
    echo "=============================="
    
    # Try to get query count from AdGuard container logs
    local log_file="/home/delorenj/docker/trunk-main/stacks/utils/adguard/work/data/querylog.json"
    
    if [[ -f "$log_file" ]]; then
        local query_count
        query_count=$(wc -l < "$log_file" 2>/dev/null || echo "0")
        echo "Total queries logged: $query_count"
    else
        echo "Query log file not found - AdGuard might be using different storage"
    fi
    
    # Check container logs for DNS queries
    echo -e "\n${YELLOW}Recent AdGuard activity:${NC}"
    docker compose -f /home/delorenj/docker/trunk-main/stacks/utils/adguard/compose.yml logs --tail=5 adguard 2>/dev/null || echo "Could not fetch container logs"
}

# Function to test Tailscale connectivity
test_tailscale_connectivity() {
    echo -e "\n${PURPLE}🔗 Tailscale Connectivity Tests${NC}"
    echo "================================="
    
    echo -e "${YELLOW}Tailscale Status:${NC}"
    tailscale status | head -5
    
    echo -e "\n${YELLOW}Testing Tailscale interface:${NC}"
    if ping -c 2 "$TAILSCALE_IP" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Tailscale interface ($TAILSCALE_IP) is reachable${NC}"
    else
        echo -e "${RED}❌ Tailscale interface ($TAILSCALE_IP) is not reachable${NC}"
    fi
    
    echo -e "\n${YELLOW}Testing AdGuard port accessibility:${NC}"
    if nc -zv "$TAILSCALE_IP" "$ADGUARD_PORT" 2>/dev/null; then
        echo -e "${GREEN}✅ AdGuard port ($ADGUARD_PORT) is accessible${NC}"
    else
        echo -e "${RED}❌ AdGuard port ($ADGUARD_PORT) is not accessible${NC}"
    fi
}

# Function to run comprehensive DNS tests
run_dns_tests() {
    echo -e "\n${PURPLE}🧪 Comprehensive DNS Resolution Tests${NC}"
    echo "========================================"
    
    local success_count=0
    local total_tests=0
    
    # Test 1: Standard domains via AdGuard
    echo -e "\n${BLUE}Test Suite 1: Standard Domain Resolution via AdGuard${NC}"
    for domain in "${TEST_DOMAINS[@]}"; do
        echo ""
        if test_dns_lookup "$domain" "$TAILSCALE_IP" "$ADGUARD_PORT" "AdGuard DNS ($domain)"; then
            ((success_count++))
            test_dns_latency "$domain" "$TAILSCALE_IP" "$ADGUARD_PORT"
        fi
        ((total_tests++))
    done
    
    # Test 2: Potentially blocked domains
    echo -e "\n${BLUE}Test Suite 2: Filtering Test (these might be blocked)${NC}"
    for domain in "${MALICIOUS_DOMAINS[@]}"; do
        echo ""
        if test_dns_lookup "$domain" "$TAILSCALE_IP" "$ADGUARD_PORT" "Filtering Test ($domain)"; then
            echo -e "${YELLOW}⚠️  Domain was resolved - check if it should be blocked${NC}"
        else
            echo -e "${GREEN}✅ Domain appears to be blocked (expected behavior)${NC}"
        fi
    done
    
    # Test 3: Internal/MagicDNS domains
    echo -e "\n${BLUE}Test Suite 3: MagicDNS and Internal Resolution${NC}"
    for domain in "${INTERNAL_DOMAINS[@]}"; do
        echo ""
        # Test with system DNS (should work via MagicDNS)
        if ping -c 1 "$domain" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ MagicDNS: $domain resolved via system DNS${NC}"
        else
            echo -e "${YELLOW}⚠️  MagicDNS: $domain not resolved - might be expected${NC}"
        fi
    done
    
    # Test 4: System DNS comparison
    echo -e "\n${BLUE}Test Suite 4: System DNS Comparison${NC}"
    echo ""
    test_dns_lookup "google.com" "$LOCAL_DNS" "53" "System DNS (google.com)"
    
    # Summary
    echo -e "\n${PURPLE}📈 Test Summary${NC}"
    echo "==============="
    echo "Successful DNS tests: $success_count/$total_tests"
    
    local success_rate
    success_rate=$(( success_count * 100 / total_tests ))
    
    if (( success_rate >= 80 )); then
        echo -e "${GREEN}✅ Overall DNS health: GOOD ($success_rate%)${NC}"
    elif (( success_rate >= 60 )); then
        echo -e "${YELLOW}⚠️  Overall DNS health: FAIR ($success_rate%)${NC}"
    else
        echo -e "${RED}❌ Overall DNS health: POOR ($success_rate%)${NC}"
    fi
}

# Function to show network diagnostics
show_network_diagnostics() {
    echo -e "\n${PURPLE}🔧 Network Diagnostics${NC}"
    echo "======================"
    
    echo -e "${YELLOW}Network interfaces with IP 100.x.x.x:${NC}"
    ip addr show | grep -E "100\.[0-9]+\.[0-9]+\.[0-9]+" || echo "No Tailscale IPs found"
    
    echo -e "\n${YELLOW}Routing table for Tailscale:${NC}"
    ip route show | grep -E "100\." || echo "No Tailscale routes found"
    
    echo -e "\n${YELLOW}Current DNS configuration:${NC}"
    cat /etc/resolv.conf | head -5
    
    echo -e "\n${YELLOW}Ports listening on 53 and 5353:${NC}"
    ss -tuln | grep -E ":53|:5353" | head -10
}

# Function to generate recommendations
generate_recommendations() {
    echo -e "\n${PURPLE}💡 Optimization Recommendations${NC}"
    echo "================================="
    
    # Check if dig is available
    if ! command -v dig >/dev/null 2>&1; then
        echo -e "${YELLOW}📦 Install dig for better DNS diagnostics: sudo apt install dnsutils${NC}"
    fi
    
    # Check if nc is available
    if ! command -v nc >/dev/null 2>&1; then
        echo -e "${YELLOW}📦 Install nc for port testing: sudo apt install netcat${NC}"
    fi
    
    # Check AdGuard container health
    local container_status
    container_status=$(docker compose -f /home/delorenj/docker/trunk-main/stacks/utils/adguard/compose.yml ps --format "table {{.State}}" | tail -1)
    
    if [[ "$container_status" != "Up" ]]; then
        echo -e "${YELLOW}🐳 AdGuard container is not running optimally: $container_status${NC}"
    fi
    
    echo -e "\n${BLUE}Performance Optimization Tips:${NC}"
    echo "• Monitor AdGuard query logs regularly"
    echo "• Update block lists weekly"
    echo "• Consider DNS caching settings in AdGuard"
    echo "• Monitor DNS latency trends"
    echo "• Set up alerting for DNS failures"
}

# Main execution
main() {
    echo -e "${BLUE}Starting comprehensive DNS flow validation...${NC}"
    
    # Install required packages if missing
    if ! command -v dig >/dev/null 2>&1; then
        echo -e "${YELLOW}Installing DNS utilities...${NC}"
        sudo apt update && sudo apt install -y dnsutils >/dev/null 2>&1 || echo "Could not install dnsutils"
    fi
    
    test_tailscale_connectivity
    run_dns_tests
    check_adguard_logs
    show_network_diagnostics
    generate_recommendations
    
    echo -e "\n${GREEN}🎉 DNS flow validation complete!${NC}"
}

# Handle command line arguments
if [[ "${1:-}" == "--quick" ]]; then
    echo -e "${BLUE}Running quick DNS tests only...${NC}"
    test_dns_lookup "google.com" "$TAILSCALE_IP" "$ADGUARD_PORT" "Quick Test"
elif [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    echo "DNS Flow Validation Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --quick        Run only basic DNS test"
    echo "  --help, -h     Show this help message"
    echo ""
else
    main "$@"
fi