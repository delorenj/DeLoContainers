#!/bin/bash
# Phase-specific test: Web access validation after auth reset
# Usage: ./test-web-access.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_DIR="/home/delorenj/docker/trunk-main/stacks/media"
TEST_RESULTS_DIR="$SCRIPT_DIR/results"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_FILE="$TEST_RESULTS_DIR/web_access_test_$TIMESTAMP.json"

mkdir -p "$TEST_RESULTS_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== qBittorrent Web Access Test Suite ===${NC}"
echo "Test started at: $(date)"
echo "Results will be saved to: $REPORT_FILE"

# Initialize results JSON
cat > "$REPORT_FILE" << EOF
{
  "test_suite": "web_access",
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

# Test 1: Local Web UI Access
echo -e "\n${YELLOW}Test 1: Local Web UI Access${NC}"
LOCAL_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8091 || echo "000")
if [ "$LOCAL_RESPONSE" = "200" ]; then
    echo -e "${GREEN}✓ Local Web UI accessible without authentication${NC}"
    add_test_result "local_webui_access" "PASS" "Local Web UI accessible" "HTTP response: $LOCAL_RESPONSE"
elif [ "$LOCAL_RESPONSE" = "401" ] || [ "$LOCAL_RESPONSE" = "403" ]; then
    echo -e "${GREEN}✓ Local Web UI accessible (requires authentication)${NC}"
    add_test_result "local_webui_access" "PASS" "Local Web UI accessible with auth" "HTTP response: $LOCAL_RESPONSE"
else
    echo -e "${RED}✗ Local Web UI not accessible (HTTP $LOCAL_RESPONSE)${NC}"
    add_test_result "local_webui_access" "FAIL" "Local Web UI not accessible" "HTTP response: $LOCAL_RESPONSE"
fi

# Test 2: External Web UI Access via Traefik
echo -e "\n${YELLOW}Test 2: External Web UI Access via Traefik${NC}"
EXTERNAL_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" https://get.delo.sh || echo "000")
if [ "$EXTERNAL_RESPONSE" = "200" ]; then
    echo -e "${GREEN}✓ External Web UI accessible without authentication${NC}"
    add_test_result "external_webui_access" "PASS" "External Web UI accessible" "HTTP response: $EXTERNAL_RESPONSE"
elif [ "$EXTERNAL_RESPONSE" = "401" ] || [ "$EXTERNAL_RESPONSE" = "403" ]; then
    echo -e "${GREEN}✓ External Web UI accessible (requires authentication)${NC}"
    add_test_result "external_webui_access" "PASS" "External Web UI accessible with auth" "HTTP response: $EXTERNAL_RESPONSE"
else
    echo -e "${RED}✗ External Web UI not accessible (HTTP $EXTERNAL_RESPONSE)${NC}"
    add_test_result "external_webui_access" "FAIL" "External Web UI not accessible" "HTTP response: $EXTERNAL_RESPONSE"
fi

# Test 3: Web UI Port Configuration
echo -e "\n${YELLOW}Test 3: Web UI Port Configuration${NC}"
PORT_CONFIG=$(docker exec qbittorrent cat /config/qBittorrent/qBittorrent.conf | grep "WebUI\\Port" || echo "PORT_NOT_CONFIGURED")
EXPECTED_PORT="8091"
if echo "$PORT_CONFIG" | grep -q "$EXPECTED_PORT"; then
    echo -e "${GREEN}✓ Web UI port correctly configured: $EXPECTED_PORT${NC}"
    add_test_result "webui_port_config" "PASS" "Web UI port configured correctly" "$PORT_CONFIG"
else
    echo -e "${RED}✗ Web UI port misconfigured${NC}"
    add_test_result "webui_port_config" "FAIL" "Web UI port misconfigured" "$PORT_CONFIG"
fi

# Test 4: Authentication Configuration
echo -e "\n${YELLOW}Test 4: Authentication Configuration${NC}"
AUTH_CONFIG=$(docker exec qbittorrent cat /config/qBittorrent/qBittorrent.conf | grep -E "(Username|LocalHostAuth|AuthSubnet)" || echo "AUTH_NOT_CONFIGURED")
if echo "$AUTH_CONFIG" | grep -q "Username"; then
    echo -e "${GREEN}✓ Authentication is configured${NC}"
    add_test_result "auth_config" "PASS" "Authentication configured" "$AUTH_CONFIG"
else
    echo -e "${YELLOW}! Authentication may not be configured${NC}"
    add_test_result "auth_config" "WARN" "Authentication not explicitly configured" "$AUTH_CONFIG"
fi

# Test 5: SSL/HTTPS Configuration
echo -e "\n${YELLOW}Test 5: SSL/HTTPS Configuration${NC}"
SSL_CONFIG=$(docker exec qbittorrent cat /config/qBittorrent/qBittorrent.conf | grep "HTTPS\\Enabled" || echo "SSL_NOT_CONFIGURED")
if echo "$SSL_CONFIG" | grep -q "false"; then
    echo -e "${GREEN}✓ HTTPS disabled (handled by Traefik)${NC}"
    add_test_result "ssl_config" "PASS" "HTTPS properly disabled for reverse proxy" "$SSL_CONFIG"
elif echo "$SSL_CONFIG" | grep -q "true"; then
    echo -e "${YELLOW}! HTTPS enabled (may conflict with Traefik)${NC}"
    add_test_result "ssl_config" "WARN" "HTTPS enabled - may conflict with proxy" "$SSL_CONFIG"
else
    echo -e "${GREEN}✓ HTTPS not configured (using defaults)${NC}"
    add_test_result "ssl_config" "PASS" "HTTPS using default settings" "Using defaults"
fi

# Test 6: IP Whitelist Configuration
echo -e "\n${YELLOW}Test 6: IP Whitelist Configuration${NC}"
WHITELIST_CONFIG=$(docker exec qbittorrent cat /config/qBittorrent/qBittorrent.conf | grep "AuthSubnetWhitelist" || echo "WHITELIST_NOT_CONFIGURED")
if echo "$WHITELIST_CONFIG" | grep -q "192.168.1.0/24"; then
    echo -e "${GREEN}✓ IP whitelist configured for local network${NC}"
    add_test_result "ip_whitelist" "PASS" "IP whitelist configured" "$WHITELIST_CONFIG"
else
    echo -e "${YELLOW}! IP whitelist not configured${NC}"
    add_test_result "ip_whitelist" "WARN" "IP whitelist not configured" "$WHITELIST_CONFIG"
fi

# Test 7: API Access Test
echo -e "\n${YELLOW}Test 7: API Access Test${NC}"
API_VERSION=$(curl -s http://localhost:8091/api/v2/app/version 2>/dev/null || echo "API_ERROR")
if [[ "$API_VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+ ]]; then
    echo -e "${GREEN}✓ API accessible and responding: $API_VERSION${NC}"
    add_test_result "api_access" "PASS" "API accessible" "Version: $API_VERSION"
elif [ "$API_VERSION" = "Forbidden" ]; then
    echo -e "${GREEN}✓ API accessible but requires authentication${NC}"
    add_test_result "api_access" "PASS" "API accessible with auth required" "Response: Forbidden"
else
    echo -e "${RED}✗ API not accessible${NC}"
    add_test_result "api_access" "FAIL" "API not accessible" "Response: $API_VERSION"
fi

# Test 8: Web UI Response Time
echo -e "\n${YELLOW}Test 8: Web UI Response Time${NC}"
RESPONSE_TIME=$(curl -s -w "%{time_total}" -o /dev/null http://localhost:8091 2>/dev/null || echo "TIMEOUT")
if [[ "$RESPONSE_TIME" =~ ^[0-9]+\.[0-9]+$ ]] && (( $(echo "$RESPONSE_TIME < 5.0" | bc -l) )); then
    echo -e "${GREEN}✓ Web UI response time is good: ${RESPONSE_TIME}s${NC}"
    add_test_result "response_time" "PASS" "Good response time" "Time: ${RESPONSE_TIME}s"
elif [[ "$RESPONSE_TIME" =~ ^[0-9]+\.[0-9]+$ ]]; then
    echo -e "${YELLOW}! Web UI response time is slow: ${RESPONSE_TIME}s${NC}"
    add_test_result "response_time" "WARN" "Slow response time" "Time: ${RESPONSE_TIME}s"
else
    echo -e "${RED}✗ Could not measure response time${NC}"
    add_test_result "response_time" "FAIL" "Could not measure response time" "Result: $RESPONSE_TIME"
fi

# Test 9: JavaScript/CSS Resource Loading
echo -e "\n${YELLOW}Test 9: JavaScript/CSS Resource Loading${NC}"
# Check if main resources are loading properly
RESOURCE_CHECK=$(curl -s http://localhost:8091 2>/dev/null | grep -c -E "(\.js|\.css)" || echo "0")
if [ "$RESOURCE_CHECK" -gt 0 ]; then
    echo -e "${GREEN}✓ Web UI resources loading properly ($RESOURCE_CHECK resources found)${NC}"
    add_test_result "resource_loading" "PASS" "Web UI resources loading" "Resources found: $RESOURCE_CHECK"
else
    echo -e "${YELLOW}! Could not verify resource loading${NC}"
    add_test_result "resource_loading" "WARN" "Could not verify resource loading" "Resources found: $RESOURCE_CHECK"
fi

# Test 10: Cross-Origin Configuration
echo -e "\n${YELLOW}Test 10: Cross-Origin Configuration${NC}"
CORS_HEADERS=$(curl -s -I http://localhost:8091 2>/dev/null | grep -i "access-control" || echo "NO_CORS_HEADERS")
if echo "$CORS_HEADERS" | grep -q "access-control"; then
    echo -e "${GREEN}✓ CORS headers present${NC}"
    add_test_result "cors_config" "PASS" "CORS headers configured" "$CORS_HEADERS"
else
    echo -e "${YELLOW}! No CORS headers found (may be expected)${NC}"
    add_test_result "cors_config" "WARN" "No CORS headers found" "Default behavior"
fi

# Test 11: Session Management
echo -e "\n${YELLOW}Test 11: Session Management${NC}"
SESSION_COOKIE=$(curl -s -I http://localhost:8091 2>/dev/null | grep -i "set-cookie" || echo "NO_SESSION_COOKIE")
if echo "$SESSION_COOKIE" | grep -q -i "cookie"; then
    echo -e "${GREEN}✓ Session management working${NC}"
    add_test_result "session_management" "PASS" "Session management active" "Cookie found"
else
    echo -e "${YELLOW}! No session cookie found${NC}"
    add_test_result "session_management" "WARN" "No session cookie found" "May require authentication"
fi

# Test 12: Traefik Integration
echo -e "\n${YELLOW}Test 12: Traefik Integration${NC}"
TRAEFIK_LABELS=$(docker inspect qbittorrent | jq -r '.[] | .Config.Labels | keys[]' 2>/dev/null | grep traefik | wc -l || echo "0")
if [ "$TRAEFIK_LABELS" -gt 0 ]; then
    echo -e "${GREEN}✓ Traefik labels configured ($TRAEFIK_LABELS labels)${NC}"
    add_test_result "traefik_integration" "PASS" "Traefik integration configured" "Labels: $TRAEFIK_LABELS"
else
    echo -e "${RED}✗ Traefik labels not found${NC}"
    add_test_result "traefik_integration" "FAIL" "Traefik integration not configured" "No labels found"
fi

# Generate summary
echo -e "\n${YELLOW}=== Web Access Test Summary ===${NC}"
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