#!/bin/bash
# Post-implementation comprehensive validation suite
# Usage: ./comprehensive-validation.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_DIR="/home/delorenj/docker/trunk-main/stacks/media"
TEST_RESULTS_DIR="$SCRIPT_DIR/results"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_FILE="$TEST_RESULTS_DIR/comprehensive_validation_$TIMESTAMP.json"

mkdir -p "$TEST_RESULTS_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== qBittorrent Comprehensive Post-Implementation Validation ===${NC}"
echo "Test started at: $(date)"
echo "Results will be saved to: $REPORT_FILE"

# Initialize results JSON
cat > "$REPORT_FILE" << EOF
{
  "test_suite": "comprehensive_validation",
  "timestamp": "$TIMESTAMP",
  "stack_directory": "$STACK_DIR",
  "validation_phases": [],
  "overall_status": "RUNNING"
}
EOF

# Helper function to add phase result to JSON
add_phase_result() {
    local phase_name="$1"
    local status="$2"
    local message="$3"
    local test_count="$4"
    local pass_count="$5"
    local fail_count="$6"
    local warn_count="$7"
    
    message=$(echo "$message" | sed 's/"/\\"/g')
    
    cat > /tmp/phase_result.json << EOF
{
  "phase": "$phase_name",
  "status": "$status",
  "message": "$message",
  "test_summary": {
    "total": $test_count,
    "passed": $pass_count,
    "failed": $fail_count,
    "warnings": $warn_count
  },
  "timestamp": "$(date -Iseconds)"
}
EOF
    
    jq '.validation_phases += [input]' "$REPORT_FILE" /tmp/phase_result.json > /tmp/updated_report.json
    mv /tmp/updated_report.json "$REPORT_FILE"
    rm -f /tmp/phase_result.json
}

cd "$STACK_DIR"

# Phase 1: Infrastructure Validation
echo -e "\n${BLUE}=== Phase 1: Infrastructure Validation ===${NC}"
INFRA_RESULTS=$(mktemp)

# Container health
CONTAINER_STATUS=$(docker-compose ps qbittorrent | grep "Up" && echo "HEALTHY" || echo "UNHEALTHY")
# Service ports
PORT_CHECK=$(docker exec qbittorrent netstat -ln | grep -E ":8091|:49152" | wc -l)
# Network connectivity
NETWORK_CHECK=$(docker exec qbittorrent ping -c 1 google.com >/dev/null 2>&1 && echo "CONNECTED" || echo "DISCONNECTED")
# VPN status
VPN_STATUS=$(docker exec gluetun curl -s ipinfo.io/ip 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' && echo "VPN_ACTIVE" || echo "VPN_INACTIVE")

INFRA_PASS=0
INFRA_FAIL=0
INFRA_WARN=0

[ "$CONTAINER_STATUS" = "HEALTHY" ] && ((INFRA_PASS++)) || ((INFRA_FAIL++))
[ "$PORT_CHECK" -ge 2 ] && ((INFRA_PASS++)) || ((INFRA_FAIL++))
[ "$NETWORK_CHECK" = "CONNECTED" ] && ((INFRA_PASS++)) || ((INFRA_FAIL++))
[ "$VPN_STATUS" = "VPN_ACTIVE" ] && ((INFRA_PASS++)) || ((INFRA_FAIL++))

INFRA_TOTAL=4
INFRA_STATUS=$([ "$INFRA_FAIL" -eq 0 ] && echo "PASS" || echo "FAIL")

echo -e "Container Status: $([ "$CONTAINER_STATUS" = "HEALTHY" ] && echo -e "${GREEN}✓ Healthy${NC}" || echo -e "${RED}✗ Unhealthy${NC}")"
echo -e "Port Status: $([ "$PORT_CHECK" -ge 2 ] && echo -e "${GREEN}✓ Ports listening${NC}" || echo -e "${RED}✗ Port issues${NC}")"
echo -e "Network: $([ "$NETWORK_CHECK" = "CONNECTED" ] && echo -e "${GREEN}✓ Connected${NC}" || echo -e "${RED}✗ Disconnected${NC}")"
echo -e "VPN: $([ "$VPN_STATUS" = "VPN_ACTIVE" ] && echo -e "${GREEN}✓ Active${NC}" || echo -e "${RED}✗ Inactive${NC}")"

add_phase_result "infrastructure" "$INFRA_STATUS" "Infrastructure validation completed" "$INFRA_TOTAL" "$INFRA_PASS" "$INFRA_FAIL" "$INFRA_WARN"

# Phase 2: Permission Validation
echo -e "\n${BLUE}=== Phase 2: Permission Validation ===${NC}"

PERM_PASS=0
PERM_FAIL=0
PERM_WARN=0

# UID/GID check
CONTAINER_UID=$(docker exec qbittorrent id -u 2>/dev/null || echo "ERROR")
EXPECTED_UID=$(grep "PUID=" .env | cut -d'=' -f2 2>/dev/null || echo "1000")
[ "$CONTAINER_UID" = "$EXPECTED_UID" ] && ((PERM_PASS++)) || ((PERM_FAIL++))

# Directory permissions
CONFIG_WRITE=$(docker exec qbittorrent touch /config/test_perm 2>/dev/null && docker exec qbittorrent rm /config/test_perm && echo "WRITABLE" || echo "NOT_WRITABLE")
DOWNLOADS_WRITE=$(docker exec qbittorrent touch /downloads/test_perm 2>/dev/null && docker exec qbittorrent rm /downloads/test_perm && echo "WRITABLE" || echo "NOT_WRITABLE")
VIDEO_WRITE=$(docker exec qbittorrent touch /video/test_perm 2>/dev/null && docker exec qbittorrent rm /video/test_perm && echo "WRITABLE" || echo "NOT_WRITABLE")

[ "$CONFIG_WRITE" = "WRITABLE" ] && ((PERM_PASS++)) || ((PERM_FAIL++))
[ "$DOWNLOADS_WRITE" = "WRITABLE" ] && ((PERM_PASS++)) || ((PERM_FAIL++))
[ "$VIDEO_WRITE" = "WRITABLE" ] && ((PERM_PASS++)) || ((PERM_FAIL++))

PERM_TOTAL=4
PERM_STATUS=$([ "$PERM_FAIL" -eq 0 ] && echo "PASS" || echo "FAIL")

echo -e "UID Match: $([ "$CONTAINER_UID" = "$EXPECTED_UID" ] && echo -e "${GREEN}✓ $CONTAINER_UID${NC}" || echo -e "${RED}✗ $CONTAINER_UID (expected: $EXPECTED_UID)${NC}")"
echo -e "Config Write: $([ "$CONFIG_WRITE" = "WRITABLE" ] && echo -e "${GREEN}✓ Writable${NC}" || echo -e "${RED}✗ Not writable${NC}")"
echo -e "Downloads Write: $([ "$DOWNLOADS_WRITE" = "WRITABLE" ] && echo -e "${GREEN}✓ Writable${NC}" || echo -e "${RED}✗ Not writable${NC}")"
echo -e "Video Write: $([ "$VIDEO_WRITE" = "WRITABLE" ] && echo -e "${GREEN}✓ Writable${NC}" || echo -e "${RED}✗ Not writable${NC}")"

add_phase_result "permissions" "$PERM_STATUS" "Permission validation completed" "$PERM_TOTAL" "$PERM_PASS" "$PERM_FAIL" "$PERM_WARN"

# Phase 3: Web Interface Validation
echo -e "\n${BLUE}=== Phase 3: Web Interface Validation ===${NC}"

WEB_PASS=0
WEB_FAIL=0
WEB_WARN=0

# Local access
LOCAL_WEB=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8091 || echo "000")
[ "$LOCAL_WEB" = "200" ] || [ "$LOCAL_WEB" = "401" ] || [ "$LOCAL_WEB" = "403" ] && ((WEB_PASS++)) || ((WEB_FAIL++))

# External access
EXTERNAL_WEB=$(curl -s -o /dev/null -w "%{http_code}" https://get.delo.sh || echo "000")
[ "$EXTERNAL_WEB" = "200" ] || [ "$EXTERNAL_WEB" = "401" ] || [ "$EXTERNAL_WEB" = "403" ] && ((WEB_PASS++)) || ((WEB_FAIL++))

# API access
API_RESPONSE=$(curl -s http://localhost:8091/api/v2/app/version 2>/dev/null || echo "API_ERROR")
[[ "$API_RESPONSE" =~ ^v[0-9]+\.[0-9]+\.[0-9]+ ]] || [ "$API_RESPONSE" = "Forbidden" ] && ((WEB_PASS++)) || ((WEB_FAIL++))

# Response time
RESPONSE_TIME=$(curl -s -w "%{time_total}" -o /dev/null http://localhost:8091 2>/dev/null || echo "99")
(( $(echo "$RESPONSE_TIME < 5.0" | bc -l 2>/dev/null || echo "0") )) && ((WEB_PASS++)) || ((WEB_WARN++))

WEB_TOTAL=4
WEB_STATUS=$([ "$WEB_FAIL" -eq 0 ] && echo "PASS" || echo "FAIL")

echo -e "Local Access: $([ "$LOCAL_WEB" = "200" ] || [ "$LOCAL_WEB" = "401" ] || [ "$LOCAL_WEB" = "403" ] && echo -e "${GREEN}✓ HTTP $LOCAL_WEB${NC}" || echo -e "${RED}✗ HTTP $LOCAL_WEB${NC}")"
echo -e "External Access: $([ "$EXTERNAL_WEB" = "200" ] || [ "$EXTERNAL_WEB" = "401" ] || [ "$EXTERNAL_WEB" = "403" ] && echo -e "${GREEN}✓ HTTP $EXTERNAL_WEB${NC}" || echo -e "${RED}✗ HTTP $EXTERNAL_WEB${NC}")"
echo -e "API Access: $([[ "$API_RESPONSE" =~ ^v[0-9]+\.[0-9]+\.[0-9]+ ]] || [ "$API_RESPONSE" = "Forbidden" ] && echo -e "${GREEN}✓ Available${NC}" || echo -e "${RED}✗ Unavailable${NC}")"
echo -e "Response Time: $((( $(echo "$RESPONSE_TIME < 5.0" | bc -l 2>/dev/null || echo "0") )) && echo -e "${GREEN}✓ ${RESPONSE_TIME}s${NC}" || echo -e "${YELLOW}! ${RESPONSE_TIME}s${NC}")"

add_phase_result "web_interface" "$WEB_STATUS" "Web interface validation completed" "$WEB_TOTAL" "$WEB_PASS" "$WEB_FAIL" "$WEB_WARN"

# Phase 4: Torrent Functionality Validation
echo -e "\n${BLUE}=== Phase 4: Torrent Functionality Validation ===${NC}"

TORRENT_PASS=0
TORRENT_FAIL=0
TORRENT_WARN=0

# qBittorrent daemon
QB_DAEMON=$(docker exec qbittorrent pgrep qbittorrent-nox >/dev/null 2>&1 && echo "RUNNING" || echo "NOT_RUNNING")
[ "$QB_DAEMON" = "RUNNING" ] && ((TORRENT_PASS++)) || ((TORRENT_FAIL++))

# Port listening
TORRENT_PORT=$(docker exec qbittorrent netstat -ln | grep ":49152" >/dev/null 2>&1 && echo "LISTENING" || echo "NOT_LISTENING")
[ "$TORRENT_PORT" = "LISTENING" ] && ((TORRENT_PASS++)) || ((TORRENT_FAIL++))

# Network interface binding
INTERFACE_BIND=$(docker exec qbittorrent ip route show | grep tun0 >/dev/null 2>&1 && echo "BOUND" || echo "NOT_BOUND")
[ "$INTERFACE_BIND" = "BOUND" ] && ((TORRENT_PASS++)) || ((TORRENT_FAIL++))

# Tracker connectivity
TRACKER_CONN=$(docker exec qbittorrent timeout 10 nc -z tracker.openbittorrent.com 80 2>/dev/null && echo "CONNECTED" || echo "FAILED")
[ "$TRACKER_CONN" = "CONNECTED" ] && ((TORRENT_PASS++)) || ((TORRENT_WARN++))

TORRENT_TOTAL=4
TORRENT_STATUS=$([ "$TORRENT_FAIL" -eq 0 ] && echo "PASS" || echo "FAIL")

echo -e "qBittorrent Daemon: $([ "$QB_DAEMON" = "RUNNING" ] && echo -e "${GREEN}✓ Running${NC}" || echo -e "${RED}✗ Not running${NC}")"
echo -e "Torrent Port: $([ "$TORRENT_PORT" = "LISTENING" ] && echo -e "${GREEN}✓ Listening${NC}" || echo -e "${RED}✗ Not listening${NC}")"
echo -e "Interface Binding: $([ "$INTERFACE_BIND" = "BOUND" ] && echo -e "${GREEN}✓ Bound to tun0${NC}" || echo -e "${RED}✗ Not bound${NC}")"
echo -e "Tracker Connectivity: $([ "$TRACKER_CONN" = "CONNECTED" ] && echo -e "${GREEN}✓ Connected${NC}" || echo -e "${YELLOW}! Connection failed${NC}")"

add_phase_result "torrent_functionality" "$TORRENT_STATUS" "Torrent functionality validation completed" "$TORRENT_TOTAL" "$TORRENT_PASS" "$TORRENT_FAIL" "$TORRENT_WARN"

# Phase 5: DNS and Network Validation
echo -e "\n${BLUE}=== Phase 5: DNS and Network Validation ===${NC}"

DNS_PASS=0
DNS_FAIL=0
DNS_WARN=0

# Basic DNS resolution
DNS_BASIC=$(docker exec qbittorrent nslookup google.com >/dev/null 2>&1 && echo "WORKING" || echo "FAILED")
[ "$DNS_BASIC" = "WORKING" ] && ((DNS_PASS++)) || ((DNS_FAIL++))

# VPN DNS leak test
VPN_DNS_IP=$(docker exec qbittorrent nslookup google.com 2>/dev/null | grep "Server:" | awk '{print $2}' || echo "UNKNOWN")
LOCAL_DNS_IP=$(cat /etc/resolv.conf | grep nameserver | head -1 | awk '{print $2}' || echo "UNKNOWN")
[ "$VPN_DNS_IP" != "$LOCAL_DNS_IP" ] && [ "$VPN_DNS_IP" != "UNKNOWN" ] && ((DNS_PASS++)) || ((DNS_FAIL++))

# DNS through VPN tunnel
DNS_TUNNEL=$(docker exec qbittorrent ip route get 8.8.8.8 | grep "tun0" >/dev/null 2>&1 && echo "VPN_ROUTE" || echo "NO_VPN_ROUTE")
[ "$DNS_TUNNEL" = "VPN_ROUTE" ] && ((DNS_PASS++)) || ((DNS_FAIL++))

DNS_TOTAL=3
DNS_STATUS=$([ "$DNS_FAIL" -eq 0 ] && echo "PASS" || echo "FAIL")

echo -e "Basic DNS: $([ "$DNS_BASIC" = "WORKING" ] && echo -e "${GREEN}✓ Working${NC}" || echo -e "${RED}✗ Failed${NC}")"
echo -e "VPN DNS: $([ "$VPN_DNS_IP" != "$LOCAL_DNS_IP" ] && [ "$VPN_DNS_IP" != "UNKNOWN" ] && echo -e "${GREEN}✓ No leak${NC}" || echo -e "${RED}✗ Potential leak${NC}")"
echo -e "DNS Tunnel: $([ "$DNS_TUNNEL" = "VPN_ROUTE" ] && echo -e "${GREEN}✓ Through VPN${NC}" || echo -e "${RED}✗ Not through VPN${NC}")"

add_phase_result "dns_network" "$DNS_STATUS" "DNS and network validation completed" "$DNS_TOTAL" "$DNS_PASS" "$DNS_FAIL" "$DNS_WARN"

# Phase 6: Configuration Integrity
echo -e "\n${BLUE}=== Phase 6: Configuration Integrity ===${NC}"

CONFIG_PASS=0
CONFIG_FAIL=0
CONFIG_WARN=0

# Config file integrity
CONFIG_LINES=$(docker exec qbittorrent cat /config/qBittorrent/qBittorrent.conf 2>/dev/null | wc -l || echo "0")
[ "$CONFIG_LINES" -gt 10 ] && ((CONFIG_PASS++)) || ((CONFIG_FAIL++))

# Critical settings
WEBUI_PORT=$(docker exec qbittorrent cat /config/qBittorrent/qBittorrent.conf | grep "WebUI\\Port.*8091" >/dev/null 2>&1 && echo "CORRECT" || echo "INCORRECT")
[ "$WEBUI_PORT" = "CORRECT" ] && ((CONFIG_PASS++)) || ((CONFIG_FAIL++))

INTERFACE_SETTING=$(docker exec qbittorrent cat /config/qBittorrent/qBittorrent.conf | grep "Interface.*tun0" >/dev/null 2>&1 && echo "CORRECT" || echo "INCORRECT")
[ "$INTERFACE_SETTING" = "CORRECT" ] && ((CONFIG_PASS++)) || ((CONFIG_WARN++))

CONFIG_TOTAL=3
CONFIG_STATUS=$([ "$CONFIG_FAIL" -eq 0 ] && echo "PASS" || echo "FAIL")

echo -e "Config File: $([ "$CONFIG_LINES" -gt 10 ] && echo -e "${GREEN}✓ Intact ($CONFIG_LINES lines)${NC}" || echo -e "${RED}✗ Corrupted/Missing${NC}")"
echo -e "WebUI Port: $([ "$WEBUI_PORT" = "CORRECT" ] && echo -e "${GREEN}✓ Correct${NC}" || echo -e "${RED}✗ Incorrect${NC}")"
echo -e "Interface Setting: $([ "$INTERFACE_SETTING" = "CORRECT" ] && echo -e "${GREEN}✓ Correct${NC}" || echo -e "${YELLOW}! Not set${NC}")"

add_phase_result "configuration_integrity" "$CONFIG_STATUS" "Configuration integrity validation completed" "$CONFIG_TOTAL" "$CONFIG_PASS" "$CONFIG_FAIL" "$CONFIG_WARN"

# Overall Summary
echo -e "\n${BLUE}=== Overall Validation Summary ===${NC}"

TOTAL_PHASES=6
PASSED_PHASES=$(jq '.validation_phases | map(select(.status == "PASS")) | length' "$REPORT_FILE")
FAILED_PHASES=$(jq '.validation_phases | map(select(.status == "FAIL")) | length' "$REPORT_FILE")

OVERALL_TESTS=$(jq '.validation_phases | map(.test_summary.total) | add' "$REPORT_FILE")
OVERALL_PASS=$(jq '.validation_phases | map(.test_summary.passed) | add' "$REPORT_FILE")
OVERALL_FAIL=$(jq '.validation_phases | map(.test_summary.failed) | add' "$REPORT_FILE")
OVERALL_WARN=$(jq '.validation_phases | map(.test_summary.warnings) | add' "$REPORT_FILE")

OVERALL_STATUS=$([ "$FAILED_PHASES" -eq 0 ] && echo "PASS" || echo "FAIL")

echo "Validation Phases: $TOTAL_PHASES"
echo -e "${GREEN}Passed Phases: $PASSED_PHASES${NC}"
echo -e "${RED}Failed Phases: $FAILED_PHASES${NC}"
echo ""
echo "Individual Tests: $OVERALL_TESTS"
echo -e "${GREEN}Passed: $OVERALL_PASS${NC}"
echo -e "${RED}Failed: $OVERALL_FAIL${NC}"
echo -e "${YELLOW}Warnings: $OVERALL_WARN${NC}"

# Update final status in JSON
jq --arg status "$OVERALL_STATUS" --arg total_phases "$TOTAL_PHASES" --arg passed_phases "$PASSED_PHASES" --arg failed_phases "$FAILED_PHASES" \
   --arg total_tests "$OVERALL_TESTS" --arg passed_tests "$OVERALL_PASS" --arg failed_tests "$OVERALL_FAIL" --arg warned_tests "$OVERALL_WARN" \
   '.overall_status = $status | .summary = {
     phases: {total: ($total_phases|tonumber), passed: ($passed_phases|tonumber), failed: ($failed_phases|tonumber)},
     tests: {total: ($total_tests|tonumber), passed: ($passed_tests|tonumber), failed: ($failed_tests|tonumber), warnings: ($warned_tests|tonumber)}
   }' \
   "$REPORT_FILE" > /tmp/final_comprehensive.json
mv /tmp/final_comprehensive.json "$REPORT_FILE"

echo -e "\n${BLUE}Overall Status: $([ "$OVERALL_STATUS" = "PASS" ] && echo -e "${GREEN}✓ PASS${NC}" || echo -e "${RED}✗ FAIL${NC}")${NC}"
echo -e "\nDetailed results saved to: $REPORT_FILE"

# Exit with error code if any phases failed
if [ "$FAILED_PHASES" -gt 0 ]; then
    exit 1
else
    exit 0
fi