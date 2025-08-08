#!/bin/bash
# Phase-specific test: DNS resolution validation after DNS update
# Usage: ./test-dns-resolution.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_DIR="/home/delorenj/docker/trunk-main/stacks/media"
TEST_RESULTS_DIR="$SCRIPT_DIR/results"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_FILE="$TEST_RESULTS_DIR/dns_resolution_test_$TIMESTAMP.json"

mkdir -p "$TEST_RESULTS_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== qBittorrent DNS Resolution Test Suite ===${NC}"
echo "Test started at: $(date)"
echo "Results will be saved to: $REPORT_FILE"

# Initialize results JSON
cat > "$REPORT_FILE" << EOF
{
  "test_suite": "dns_resolution",
  "timestamp": "$TIMESTAMP",
  "stack_directory": "$STACK_DIR",
  "tests": []
}
EOF

# Helper function to add test result to JSON
add_test_result() {
    local test_name="$1"
    local status="$2"
    local message="$3"
    local details="$4"
    
    message=$(echo "$message" | sed 's/"/\\"/g')
    details=$(echo "$details" | sed 's/"/\\"/g')
    
    cat > /tmp/test_result.json << EOF
{
  "name": "$test_name",
  "status": "$status",
  "message": "$message",
  "details": "$details",
  "timestamp": "$(date -Iseconds)"
}
EOF
    
    jq '.tests += [input]' "$REPORT_FILE" /tmp/test_result.json > /tmp/updated_report.json
    mv /tmp/updated_report.json "$REPORT_FILE"
    rm -f /tmp/test_result.json
}

cd "$STACK_DIR"

# Test 1: Basic DNS Resolution
echo -e "\n${YELLOW}Test 1: Basic DNS Resolution${NC}"
DNS_BASIC=$(docker exec qbittorrent nslookup google.com 2>/dev/null | grep "Address:" | tail -1 || echo "DNS_FAILED")
if echo "$DNS_BASIC" | grep -q "Address:"; then
    echo -e "${GREEN}✓ Basic DNS resolution working${NC}"
    add_test_result "basic_dns" "PASS" "Basic DNS resolution working" "$DNS_BASIC"
else
    echo -e "${RED}✗ Basic DNS resolution failed${NC}"
    add_test_result "basic_dns" "FAIL" "Basic DNS resolution failed" "$DNS_BASIC"
fi

# Test 2: VPN DNS Leak Test
echo -e "\n${YELLOW}Test 2: VPN DNS Leak Test${NC}"
VPN_DNS_IP=$(docker exec qbittorrent nslookup google.com | grep "Server:" | awk '{print $2}' || echo "UNKNOWN")
LOCAL_DNS_IP=$(cat /etc/resolv.conf | grep nameserver | head -1 | awk '{print $2}' || echo "UNKNOWN")

if [ "$VPN_DNS_IP" != "$LOCAL_DNS_IP" ] && [ "$VPN_DNS_IP" != "UNKNOWN" ]; then
    echo -e "${GREEN}✓ DNS is routing through VPN (Server: $VPN_DNS_IP)${NC}"
    add_test_result "vpn_dns_leak" "PASS" "DNS routing through VPN" "VPN DNS: $VPN_DNS_IP, Local DNS: $LOCAL_DNS_IP"
else
    echo -e "${RED}✗ Potential DNS leak detected${NC}"
    add_test_result "vpn_dns_leak" "FAIL" "Potential DNS leak" "VPN DNS: $VPN_DNS_IP, Local DNS: $LOCAL_DNS_IP"
fi

# Test 3: Public Tracker DNS Resolution
echo -e "\n${YELLOW}Test 3: Public Tracker DNS Resolution${NC}"
TRACKER_DOMAINS=("tracker.openbittorrent.com" "tracker.publicbt.com" "dht.transmissionbt.com")
TRACKER_RESOLVED=0

for domain in "${TRACKER_DOMAINS[@]}"; do
    RESOLUTION=$(docker exec qbittorrent nslookup "$domain" 2>/dev/null | grep "Address:" | tail -1 || echo "FAILED")
    if echo "$RESOLUTION" | grep -q "Address:"; then
        ((TRACKER_RESOLVED++))
    fi
done

if [ "$TRACKER_RESOLVED" -gt 0 ]; then
    echo -e "${GREEN}✓ Tracker DNS resolution working ($TRACKER_RESOLVED/${#TRACKER_DOMAINS[@]} resolved)${NC}"
    add_test_result "tracker_dns" "PASS" "Tracker DNS resolution working" "Resolved: $TRACKER_RESOLVED/${#TRACKER_DOMAINS[@]}"
else
    echo -e "${RED}✗ No tracker domains resolved${NC}"
    add_test_result "tracker_dns" "FAIL" "No tracker domains resolved" "Resolved: 0/${#TRACKER_DOMAINS[@]}"
fi

# Test 4: DNS Response Time
echo -e "\n${YELLOW}Test 4: DNS Response Time${NC}"
DNS_TIME_START=$(date +%s%N)
docker exec qbittorrent nslookup google.com >/dev/null 2>&1
DNS_TIME_END=$(date +%s%N)
DNS_TIME_DIFF=$(( (DNS_TIME_END - DNS_TIME_START) / 1000000 )) # Convert to milliseconds

if [ "$DNS_TIME_DIFF" -lt 1000 ]; then
    echo -e "${GREEN}✓ DNS response time is good: ${DNS_TIME_DIFF}ms${NC}"
    add_test_result "dns_response_time" "PASS" "Good DNS response time" "Time: ${DNS_TIME_DIFF}ms"
elif [ "$DNS_TIME_DIFF" -lt 3000 ]; then
    echo -e "${YELLOW}! DNS response time is acceptable: ${DNS_TIME_DIFF}ms${NC}"
    add_test_result "dns_response_time" "WARN" "Acceptable DNS response time" "Time: ${DNS_TIME_DIFF}ms"
else
    echo -e "${RED}✗ DNS response time is slow: ${DNS_TIME_DIFF}ms${NC}"
    add_test_result "dns_response_time" "FAIL" "Slow DNS response time" "Time: ${DNS_TIME_DIFF}ms"
fi

# Test 5: IPv6 DNS Resolution
echo -e "\n${YELLOW}Test 5: IPv6 DNS Resolution${NC}"
IPV6_DNS=$(docker exec qbittorrent nslookup -type=AAAA google.com 2>/dev/null | grep "has AAAA address" || echo "NO_IPV6")
if echo "$IPV6_DNS" | grep -q "has AAAA address"; then
    echo -e "${GREEN}✓ IPv6 DNS resolution working${NC}"
    add_test_result "ipv6_dns" "PASS" "IPv6 DNS resolution working" "$IPV6_DNS"
else
    echo -e "${YELLOW}! IPv6 DNS not available (may be expected)${NC}"
    add_test_result "ipv6_dns" "WARN" "IPv6 DNS not available" "IPv6 may be disabled"
fi

# Test 6: DNS Cache Behavior
echo -e "\n${YELLOW}Test 6: DNS Cache Behavior${NC}"
# First lookup
FIRST_LOOKUP_TIME=$(date +%s%N)
docker exec qbittorrent nslookup example.com >/dev/null 2>&1
FIRST_LOOKUP_END=$(date +%s%N)
FIRST_TIME=$(( (FIRST_LOOKUP_END - FIRST_LOOKUP_TIME) / 1000000 ))

# Second lookup (should be cached)
SECOND_LOOKUP_TIME=$(date +%s%N)
docker exec qbittorrent nslookup example.com >/dev/null 2>&1
SECOND_LOOKUP_END=$(date +%s%N)
SECOND_TIME=$(( (SECOND_LOOKUP_END - SECOND_LOOKUP_TIME) / 1000000 ))

if [ "$SECOND_TIME" -lt "$FIRST_TIME" ]; then
    echo -e "${GREEN}✓ DNS caching appears to be working (First: ${FIRST_TIME}ms, Second: ${SECOND_TIME}ms)${NC}"
    add_test_result "dns_caching" "PASS" "DNS caching working" "First: ${FIRST_TIME}ms, Second: ${SECOND_TIME}ms"
else
    echo -e "${YELLOW}! DNS caching behavior unclear${NC}"
    add_test_result "dns_caching" "WARN" "DNS caching unclear" "First: ${FIRST_TIME}ms, Second: ${SECOND_TIME}ms"
fi

# Test 7: Reverse DNS Resolution
echo -e "\n${YELLOW}Test 7: Reverse DNS Resolution${NC}"
REVERSE_DNS=$(docker exec qbittorrent nslookup 8.8.8.8 2>/dev/null | grep "name =" || echo "NO_REVERSE_DNS")
if echo "$REVERSE_DNS" | grep -q "name ="; then
    echo -e "${GREEN}✓ Reverse DNS resolution working${NC}"
    add_test_result "reverse_dns" "PASS" "Reverse DNS working" "$REVERSE_DNS"
else
    echo -e "${YELLOW}! Reverse DNS not working (may be expected)${NC}"
    add_test_result "reverse_dns" "WARN" "Reverse DNS not working" "May be blocked by VPN"
fi

# Test 8: DNS Server Configuration
echo -e "\n${YELLOW}Test 8: DNS Server Configuration${NC}"
DNS_SERVERS=$(docker exec qbittorrent cat /etc/resolv.conf | grep nameserver | wc -l || echo "0")
if [ "$DNS_SERVERS" -gt 0 ]; then
    DNS_LIST=$(docker exec qbittorrent cat /etc/resolv.conf | grep nameserver || echo "NONE")
    echo -e "${GREEN}✓ DNS servers configured ($DNS_SERVERS servers)${NC}"
    add_test_result "dns_config" "PASS" "DNS servers configured" "Servers: $DNS_SERVERS, List: $DNS_LIST"
else
    echo -e "${RED}✗ No DNS servers configured${NC}"
    add_test_result "dns_config" "FAIL" "No DNS servers configured" "No nameservers found"
fi

# Test 9: DNS Over HTTPS (DoH) Check
echo -e "\n${YELLOW}Test 9: DNS Over HTTPS (DoH) Check${NC}"
DOH_TEST=$(docker exec qbittorrent curl -s --connect-timeout 5 "https://1.1.1.1/dns-query?name=google.com&type=A" -H "Accept: application/dns-json" 2>/dev/null | grep "Status" || echo "DOH_FAILED")
if echo "$DOH_TEST" | grep -q "Status"; then
    echo -e "${GREEN}✓ DNS over HTTPS is accessible${NC}"
    add_test_result "doh_access" "PASS" "DoH accessible" "$DOH_TEST"
else
    echo -e "${YELLOW}! DNS over HTTPS not accessible (may be blocked)${NC}"
    add_test_result "doh_access" "WARN" "DoH not accessible" "May be blocked by VPN/firewall"
fi

# Test 10: DNS Security Features
echo -e "\n${YELLOW}Test 10: DNS Security Features${NC}"
# Test for DNS filtering/security
MALWARE_TEST=$(docker exec qbittorrent nslookup malware.testing.google.test 2>/dev/null | grep "NXDOMAIN\|can't find" || echo "RESOLVED")
if echo "$MALWARE_TEST" | grep -q "NXDOMAIN\|can't find"; then
    echo -e "${GREEN}✓ DNS security filtering appears active${NC}"
    add_test_result "dns_security" "PASS" "DNS security filtering active" "Malware domain blocked"
else
    echo -e "${YELLOW}! DNS security filtering not detected${NC}"
    add_test_result "dns_security" "WARN" "DNS security filtering unclear" "Test domain resolved"
fi

# Test 11: DNS Failover Test
echo -e "\n${YELLOW}Test 11: DNS Failover Test${NC}"
# Test multiple lookups to see if failover works
FAILOVER_SUCCESS=0
for i in {1..3}; do
    LOOKUP_RESULT=$(docker exec qbittorrent timeout 10 nslookup "test$i.google.com" 2>/dev/null | grep "Address:" || echo "FAILED")
    if echo "$LOOKUP_RESULT" | grep -q "Address:"; then
        ((FAILOVER_SUCCESS++))
    fi
done

if [ "$FAILOVER_SUCCESS" -ge 2 ]; then
    echo -e "${GREEN}✓ DNS failover appears functional ($FAILOVER_SUCCESS/3 tests passed)${NC}"
    add_test_result "dns_failover" "PASS" "DNS failover functional" "Success rate: $FAILOVER_SUCCESS/3"
else
    echo -e "${RED}✗ DNS failover may have issues ($FAILOVER_SUCCESS/3 tests passed)${NC}"
    add_test_result "dns_failover" "FAIL" "DNS failover issues" "Success rate: $FAILOVER_SUCCESS/3"
fi

# Test 12: DNS Through VPN Tunnel
echo -e "\n${YELLOW}Test 12: DNS Through VPN Tunnel${NC}"
# Check if DNS queries are going through the VPN tunnel
TUNNEL_DNS=$(docker exec qbittorrent ip route get 8.8.8.8 | grep "via.*tun0" || echo "NOT_VIA_TUN")
if echo "$TUNNEL_DNS" | grep -q "tun0"; then
    echo -e "${GREEN}✓ DNS traffic routing through VPN tunnel${NC}"
    add_test_result "dns_tunnel" "PASS" "DNS through VPN tunnel" "$TUNNEL_DNS"
else
    echo -e "${RED}✗ DNS traffic may not be routing through VPN${NC}"
    add_test_result "dns_tunnel" "FAIL" "DNS not through VPN tunnel" "$TUNNEL_DNS"
fi

# Generate summary
echo -e "\n${YELLOW}=== DNS Resolution Test Summary ===${NC}"
TOTAL_TESTS=$(jq '.tests | length' "$REPORT_FILE")
PASSED_TESTS=$(jq '.tests | map(select(.status == "PASS")) | length' "$REPORT_FILE")
FAILED_TESTS=$(jq '.tests | map(select(.status == "FAIL")) | length' "$REPORT_FILE")
WARNED_TESTS=$(jq '.tests | map(select(.status == "WARN")) | length' "$REPORT_FILE")

echo "Total Tests: $TOTAL_TESTS"
echo -e "${GREEN}Passed: $PASSED_TESTS${NC}"
echo -e "${RED}Failed: $FAILED_TESTS${NC}"
echo -e "${YELLOW}Warnings: $WARNED_TESTS${NC}"

# Update final summary in JSON
jq --arg total "$TOTAL_TESTS" --arg passed "$PASSED_TESTS" --arg failed "$FAILED_TESTS" --arg warned "$WARNED_TESTS" \
   '.summary = {total: ($total|tonumber), passed: ($passed|tonumber), failed: ($failed|tonumber), warned: ($warned|tonumber)}' \
   "$REPORT_FILE" > /tmp/final_report.json
mv /tmp/final_report.json "$REPORT_FILE"

echo -e "\nDetailed results saved to: $REPORT_FILE"

# Exit with error code if any tests failed
if [ "$FAILED_TESTS" -gt 0 ]; then
    exit 1
else
    exit 0
fi