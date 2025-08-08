#!/bin/bash
# Pre-implementation test to verify current qBittorrent issues
# Usage: ./verify-current-issues.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_DIR="/home/delorenj/docker/trunk-main/stacks/media"
TEST_RESULTS_DIR="$SCRIPT_DIR/results"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_FILE="$TEST_RESULTS_DIR/pre_implementation_test_$TIMESTAMP.json"

mkdir -p "$TEST_RESULTS_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== qBittorrent Pre-Implementation Test Suite ===${NC}"
echo "Test started at: $(date)"
echo "Results will be saved to: $REPORT_FILE"

# Initialize results JSON
cat > "$REPORT_FILE" << EOF
{
  "test_suite": "pre_implementation",
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
    
    # Escape quotes in message and details
    message=$(echo "$message" | sed 's/"/\\"/g')
    details=$(echo "$details" | sed 's/"/\\"/g')
    
    # Create temp file with new test result
    cat > /tmp/test_result.json << EOF
{
  "name": "$test_name",
  "status": "$status",
  "message": "$message",
  "details": "$details",
  "timestamp": "$(date -Iseconds)"
}
EOF
    
    # Add to results array
    jq '.tests += [input]' "$REPORT_FILE" /tmp/test_result.json > /tmp/updated_report.json
    mv /tmp/updated_report.json "$REPORT_FILE"
    rm -f /tmp/test_result.json
}

# Test 1: Container Status Check
echo -e "\n${YELLOW}Test 1: Container Status Check${NC}"
cd "$STACK_DIR"
if docker-compose ps qbittorrent | grep -q "Up"; then
    echo -e "${GREEN}✓ qBittorrent container is running${NC}"
    add_test_result "container_status" "PASS" "Container is running" "$(docker-compose ps qbittorrent)"
else
    echo -e "${RED}✗ qBittorrent container is not running${NC}"
    add_test_result "container_status" "FAIL" "Container is not running" "$(docker-compose ps qbittorrent)"
fi

# Test 2: Web UI Accessibility
echo -e "\n${YELLOW}Test 2: Web UI Accessibility${NC}"
WEB_UI_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8091 || echo "000")
if [ "$WEB_UI_RESPONSE" = "200" ] || [ "$WEB_UI_RESPONSE" = "401" ]; then
    echo -e "${GREEN}✓ Web UI is accessible (HTTP $WEB_UI_RESPONSE)${NC}"
    add_test_result "web_ui_access" "PASS" "Web UI accessible" "HTTP response: $WEB_UI_RESPONSE"
else
    echo -e "${RED}✗ Web UI is not accessible (HTTP $WEB_UI_RESPONSE)${NC}"
    add_test_result "web_ui_access" "FAIL" "Web UI not accessible" "HTTP response: $WEB_UI_RESPONSE"
fi

# Test 3: External Access via Traefik
echo -e "\n${YELLOW}Test 3: External Access via Traefik${NC}"
EXTERNAL_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" https://get.delo.sh || echo "000")
if [ "$EXTERNAL_RESPONSE" = "200" ] || [ "$EXTERNAL_RESPONSE" = "401" ]; then
    echo -e "${GREEN}✓ External access working (HTTP $EXTERNAL_RESPONSE)${NC}"
    add_test_result "external_access" "PASS" "External access working" "HTTP response: $EXTERNAL_RESPONSE"
else
    echo -e "${RED}✗ External access failing (HTTP $EXTERNAL_RESPONSE)${NC}"
    add_test_result "external_access" "FAIL" "External access failing" "HTTP response: $EXTERNAL_RESPONSE"
fi

# Test 4: VPN Connection Check
echo -e "\n${YELLOW}Test 4: VPN Connection Check${NC}"
VPN_STATUS=$(docker exec gluetun sh -c "curl -s ipinfo.io/ip" 2>/dev/null || echo "ERROR")
if [ "$VPN_STATUS" != "ERROR" ] && [ -n "$VPN_STATUS" ]; then
    echo -e "${GREEN}✓ VPN is connected (IP: $VPN_STATUS)${NC}"
    add_test_result "vpn_connection" "PASS" "VPN connected" "External IP: $VPN_STATUS"
else
    echo -e "${RED}✗ VPN connection issue${NC}"
    add_test_result "vpn_connection" "FAIL" "VPN connection issue" "Status: $VPN_STATUS"
fi

# Test 5: Network Interface Check
echo -e "\n${YELLOW}Test 5: Network Interface Check${NC}"
INTERFACE_CHECK=$(docker exec qbittorrent ip link show tun0 2>/dev/null | grep "state UP" || echo "DOWN")
if echo "$INTERFACE_CHECK" | grep -q "state UP"; then
    echo -e "${GREEN}✓ tun0 interface is UP${NC}"
    add_test_result "network_interface" "PASS" "tun0 interface UP" "$INTERFACE_CHECK"
else
    echo -e "${RED}✗ tun0 interface issue${NC}"
    add_test_result "network_interface" "FAIL" "tun0 interface issue" "$INTERFACE_CHECK"
fi

# Test 6: File Permissions Check
echo -e "\n${YELLOW}Test 6: File Permissions Check${NC}"
CONFIG_PERMS=$(ls -la "$STACK_DIR/qbittorrent/qBittorrent.conf" 2>/dev/null || echo "FILE_NOT_FOUND")
if echo "$CONFIG_PERMS" | grep -q "qBittorrent.conf"; then
    echo -e "${YELLOW}! Config file permissions: $CONFIG_PERMS${NC}"
    add_test_result "file_permissions" "WARN" "Config file exists but may have permission issues" "$CONFIG_PERMS"
else
    echo -e "${RED}✗ Config file not accessible${NC}"
    add_test_result "file_permissions" "FAIL" "Config file not accessible" "$CONFIG_PERMS"
fi

# Test 7: Download Directory Access
echo -e "\n${YELLOW}Test 7: Download Directory Access${NC}"
DOWNLOAD_TEST=$(docker exec qbittorrent ls -la /downloads 2>/dev/null || echo "ACCESS_ERROR")
if echo "$DOWNLOAD_TEST" | grep -q "total"; then
    echo -e "${GREEN}✓ Download directory accessible${NC}"
    add_test_result "download_directory" "PASS" "Download directory accessible" "Directory listing successful"
else
    echo -e "${RED}✗ Download directory access issue${NC}"
    add_test_result "download_directory" "FAIL" "Download directory access issue" "$DOWNLOAD_TEST"
fi

# Test 8: Video Directory Access
echo -e "\n${YELLOW}Test 8: Video Directory Access${NC}"
VIDEO_TEST=$(docker exec qbittorrent ls -la /video 2>/dev/null || echo "ACCESS_ERROR")
if echo "$VIDEO_TEST" | grep -q "total"; then
    echo -e "${GREEN}✓ Video directory accessible${NC}"
    add_test_result "video_directory" "PASS" "Video directory accessible" "Directory listing successful"
else
    echo -e "${RED}✗ Video directory access issue${NC}"
    add_test_result "video_directory" "FAIL" "Video directory access issue" "$VIDEO_TEST"
fi

# Test 9: Port Connectivity
echo -e "\n${YELLOW}Test 9: Port Connectivity${NC}"
PORT_TEST=$(docker exec qbittorrent netstat -ln | grep ":8091" || echo "PORT_NOT_LISTENING")
if echo "$PORT_TEST" | grep -q ":8091"; then
    echo -e "${GREEN}✓ Port 8091 is listening${NC}"
    add_test_result "port_connectivity" "PASS" "Port 8091 listening" "$PORT_TEST"
else
    echo -e "${RED}✗ Port 8091 not listening${NC}"
    add_test_result "port_connectivity" "FAIL" "Port 8091 not listening" "$PORT_TEST"
fi

# Test 10: DNS Resolution
echo -e "\n${YELLOW}Test 10: DNS Resolution${NC}"
DNS_TEST=$(docker exec qbittorrent nslookup google.com 2>/dev/null | grep "Address" || echo "DNS_ERROR")
if echo "$DNS_TEST" | grep -q "Address"; then
    echo -e "${GREEN}✓ DNS resolution working${NC}"
    add_test_result "dns_resolution" "PASS" "DNS resolution working" "$DNS_TEST"
else
    echo -e "${RED}✗ DNS resolution issue${NC}"
    add_test_result "dns_resolution" "FAIL" "DNS resolution issue" "$DNS_TEST"
fi

# Test Summary
echo -e "\n${YELLOW}=== Test Summary ===${NC}"
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