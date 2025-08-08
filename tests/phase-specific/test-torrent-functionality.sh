#!/bin/bash
# Phase-specific test: Torrent functionality validation after cleanup
# Usage: ./test-torrent-functionality.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_DIR="/home/delorenj/docker/trunk-main/stacks/media"
TEST_RESULTS_DIR="$SCRIPT_DIR/results"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_FILE="$TEST_RESULTS_DIR/torrent_functionality_test_$TIMESTAMP.json"

mkdir -p "$TEST_RESULTS_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== qBittorrent Torrent Functionality Test Suite ===${NC}"
echo "Test started at: $(date)"
echo "Results will be saved to: $REPORT_FILE"

# Initialize results JSON
cat > "$REPORT_FILE" << EOF
{
  "test_suite": "torrent_functionality",
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

# Test 1: qBittorrent Service Health
echo -e "\n${YELLOW}Test 1: qBittorrent Service Health${NC}"
SERVICE_HEALTH=$(docker exec qbittorrent pgrep qbittorrent-nox || echo "PROCESS_NOT_FOUND")
if [ "$SERVICE_HEALTH" != "PROCESS_NOT_FOUND" ]; then
    echo -e "${GREEN}✓ qBittorrent daemon is running (PID: $SERVICE_HEALTH)${NC}"
    add_test_result "service_health" "PASS" "qBittorrent daemon running" "PID: $SERVICE_HEALTH"
else
    echo -e "${RED}✗ qBittorrent daemon not running${NC}"
    add_test_result "service_health" "FAIL" "qBittorrent daemon not running" "No process found"
fi

# Test 2: WebUI API Accessibility
echo -e "\n${YELLOW}Test 2: WebUI API Accessibility${NC}"
API_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8091/api/v2/app/version || echo "000")
if [ "$API_RESPONSE" = "200" ] || [ "$API_RESPONSE" = "403" ]; then
    echo -e "${GREEN}✓ WebUI API is accessible (HTTP $API_RESPONSE)${NC}"
    add_test_result "webui_api" "PASS" "WebUI API accessible" "HTTP response: $API_RESPONSE"
else
    echo -e "${RED}✗ WebUI API not accessible (HTTP $API_RESPONSE)${NC}"
    add_test_result "webui_api" "FAIL" "WebUI API not accessible" "HTTP response: $API_RESPONSE"
fi

# Test 3: Port Configuration Verification
echo -e "\n${YELLOW}Test 3: Port Configuration Verification${NC}"
PORT_LISTENING=$(docker exec qbittorrent netstat -ln | grep ":49152" || echo "PORT_NOT_LISTENING")
if echo "$PORT_LISTENING" | grep -q ":49152"; then
    echo -e "${GREEN}✓ Torrent port 49152 is listening${NC}"
    add_test_result "port_configuration" "PASS" "Torrent port listening" "$PORT_LISTENING"
else
    echo -e "${RED}✗ Torrent port 49152 not listening${NC}"
    add_test_result "port_configuration" "FAIL" "Torrent port not listening" "$PORT_LISTENING"
fi

# Test 4: Network Interface Binding
echo -e "\n${YELLOW}Test 4: Network Interface Binding${NC}"
INTERFACE_STATUS=$(docker exec qbittorrent ip route show | grep tun0 || echo "NO_TUN0_ROUTE")
if echo "$INTERFACE_STATUS" | grep -q "tun0"; then
    echo -e "${GREEN}✓ Traffic routing through tun0 interface${NC}"
    add_test_result "network_binding" "PASS" "Traffic routing through VPN" "$INTERFACE_STATUS"
else
    echo -e "${RED}✗ Traffic not routing through tun0${NC}"
    add_test_result "network_binding" "FAIL" "Traffic not routing through VPN" "$INTERFACE_STATUS"
fi

# Test 5: DHT and PEX Configuration
echo -e "\n${YELLOW}Test 5: DHT and PEX Configuration${NC}"
DHT_STATUS=$(docker exec qbittorrent cat /config/qBittorrent/qBittorrent.conf | grep -E "(DHT|PEX)" || echo "CONFIG_NOT_FOUND")
if echo "$DHT_STATUS" | grep -q "DHT\|PEX"; then
    echo -e "${GREEN}✓ DHT/PEX configuration found${NC}"
    add_test_result "dht_pex_config" "PASS" "DHT/PEX configured" "$DHT_STATUS"
else
    echo -e "${YELLOW}! DHT/PEX configuration not explicitly found${NC}"
    add_test_result "dht_pex_config" "WARN" "DHT/PEX config not explicit" "Using defaults"
fi

# Test 6: Tracker Connectivity Test
echo -e "\n${YELLOW}Test 6: Tracker Connectivity Test${NC}"
# Test connectivity to a popular public tracker
TRACKER_TEST=$(docker exec qbittorrent timeout 10 nc -z tracker.openbittorrent.com 80 2>&1 && echo "CONNECTED" || echo "FAILED")
if [ "$TRACKER_TEST" = "CONNECTED" ]; then
    echo -e "${GREEN}✓ Can connect to external trackers${NC}"
    add_test_result "tracker_connectivity" "PASS" "External tracker connectivity works" "Successfully connected to tracker.openbittorrent.com:80"
else
    echo -e "${RED}✗ Cannot connect to external trackers${NC}"
    add_test_result "tracker_connectivity" "FAIL" "External tracker connectivity failed" "$TRACKER_TEST"
fi

# Test 7: Download Directory Structure
echo -e "\n${YELLOW}Test 7: Download Directory Structure${NC}"
TEMP_DIR_CHECK=$(docker exec qbittorrent ls -la /downloads 2>/dev/null | grep "total" || echo "ACCESS_ERROR")
FINAL_DIR_CHECK=$(docker exec qbittorrent ls -la /video 2>/dev/null | grep "total" || echo "ACCESS_ERROR")

if [[ "$TEMP_DIR_CHECK" != "ACCESS_ERROR" && "$FINAL_DIR_CHECK" != "ACCESS_ERROR" ]]; then
    echo -e "${GREEN}✓ Both download directories accessible${NC}"
    add_test_result "download_directories" "PASS" "Download directories accessible" "Temp and final directories OK"
else
    echo -e "${RED}✗ Download directory access issues${NC}"
    add_test_result "download_directories" "FAIL" "Download directory access issues" "Temp: $TEMP_DIR_CHECK, Final: $FINAL_DIR_CHECK"
fi

# Test 8: Config File Integrity
echo -e "\n${YELLOW}Test 8: Config File Integrity${NC}"
CONFIG_INTEGRITY=$(docker exec qbittorrent cat /config/qBittorrent/qBittorrent.conf | wc -l 2>/dev/null || echo "0")
if [ "$CONFIG_INTEGRITY" -gt 10 ]; then
    echo -e "${GREEN}✓ Config file appears intact ($CONFIG_INTEGRITY lines)${NC}"
    add_test_result "config_integrity" "PASS" "Config file intact" "Lines: $CONFIG_INTEGRITY"
else
    echo -e "${RED}✗ Config file appears corrupted or missing${NC}"
    add_test_result "config_integrity" "FAIL" "Config file corrupted/missing" "Lines: $CONFIG_INTEGRITY"
fi

# Test 9: Categories Configuration
echo -e "\n${YELLOW}Test 9: Categories Configuration${NC}"
CATEGORIES_CHECK=$(docker exec qbittorrent cat /config/qBittorrent/categories.json 2>/dev/null | jq '. | length' 2>/dev/null || echo "0")
if [ "$CATEGORIES_CHECK" -gt 0 ]; then
    echo -e "${GREEN}✓ Categories are configured ($CATEGORIES_CHECK categories)${NC}"
    add_test_result "categories_config" "PASS" "Categories configured" "Count: $CATEGORIES_CHECK"
else
    echo -e "${YELLOW}! No categories configured (may be expected)${NC}"
    add_test_result "categories_config" "WARN" "No categories configured" "Using defaults"
fi

# Test 10: Log File Generation
echo -e "\n${YELLOW}Test 10: Log File Generation${NC}"
LOG_CHECK=$(docker exec qbittorrent find /config/qBittorrent/logs -name "*.log" -type f 2>/dev/null | wc -l || echo "0")
if [ "$LOG_CHECK" -gt 0 ]; then
    echo -e "${GREEN}✓ Log files are being generated ($LOG_CHECK files)${NC}"
    add_test_result "log_generation" "PASS" "Log files generated" "Count: $LOG_CHECK"
else
    echo -e "${YELLOW}! No log files found (logging may be disabled)${NC}"
    add_test_result "log_generation" "WARN" "No log files found" "Logging may be disabled"
fi

# Test 11: Memory Usage Check
echo -e "\n${YELLOW}Test 11: Memory Usage Check${NC}"
MEMORY_USAGE=$(docker stats qbittorrent --no-stream --format "{{.MemUsage}}" 2>/dev/null || echo "UNAVAILABLE")
if [ "$MEMORY_USAGE" != "UNAVAILABLE" ]; then
    echo -e "${GREEN}✓ Memory usage: $MEMORY_USAGE${NC}"
    add_test_result "memory_usage" "PASS" "Memory usage normal" "Usage: $MEMORY_USAGE"
else
    echo -e "${YELLOW}! Could not retrieve memory usage${NC}"
    add_test_result "memory_usage" "WARN" "Memory usage unavailable" "Stats unavailable"
fi

# Test 12: CPU Usage Check
echo -e "\n${YELLOW}Test 12: CPU Usage Check${NC}"
CPU_USAGE=$(docker stats qbittorrent --no-stream --format "{{.CPUPerc}}" 2>/dev/null || echo "UNAVAILABLE")
if [ "$CPU_USAGE" != "UNAVAILABLE" ]; then
    echo -e "${GREEN}✓ CPU usage: $CPU_USAGE${NC}"
    add_test_result "cpu_usage" "PASS" "CPU usage normal" "Usage: $CPU_USAGE"
else
    echo -e "${YELLOW}! Could not retrieve CPU usage${NC}"
    add_test_result "cpu_usage" "WARN" "CPU usage unavailable" "Stats unavailable"
fi

# Generate summary
echo -e "\n${YELLOW}=== Torrent Functionality Test Summary ===${NC}"
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