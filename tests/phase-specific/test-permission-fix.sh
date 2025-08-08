#!/bin/bash
# Phase-specific test: Permission fix validation after PUID change
# Usage: ./test-permission-fix.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_DIR="/home/delorenj/docker/trunk-main/stacks/media"
TEST_RESULTS_DIR="$SCRIPT_DIR/results"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_FILE="$TEST_RESULTS_DIR/permission_fix_test_$TIMESTAMP.json"

mkdir -p "$TEST_RESULTS_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== qBittorrent Permission Fix Test Suite ===${NC}"
echo "Test started at: $(date)"
echo "Results will be saved to: $REPORT_FILE"

# Initialize results JSON
cat > "$REPORT_FILE" << EOF
{
  "test_suite": "permission_fix",
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

# Test 1: Container User ID Verification
echo -e "\n${YELLOW}Test 1: Container User ID Verification${NC}"
CONTAINER_UID=$(docker exec qbittorrent id -u 2>/dev/null || echo "ERROR")
EXPECTED_UID=$(grep "PUID=" .env | cut -d'=' -f2 || echo "1000")

if [ "$CONTAINER_UID" = "$EXPECTED_UID" ]; then
    echo -e "${GREEN}✓ Container running with correct UID: $CONTAINER_UID${NC}"
    add_test_result "container_uid" "PASS" "Container UID matches expected" "UID: $CONTAINER_UID, Expected: $EXPECTED_UID"
else
    echo -e "${RED}✗ Container UID mismatch: $CONTAINER_UID (expected: $EXPECTED_UID)${NC}"
    add_test_result "container_uid" "FAIL" "Container UID mismatch" "UID: $CONTAINER_UID, Expected: $EXPECTED_UID"
fi

# Test 2: Container Group ID Verification
echo -e "\n${YELLOW}Test 2: Container Group ID Verification${NC}"
CONTAINER_GID=$(docker exec qbittorrent id -g 2>/dev/null || echo "ERROR")
EXPECTED_GID=$(grep "PGID=" .env | cut -d'=' -f2 || echo "1000")

if [ "$CONTAINER_GID" = "$EXPECTED_GID" ]; then
    echo -e "${GREEN}✓ Container running with correct GID: $CONTAINER_GID${NC}"
    add_test_result "container_gid" "PASS" "Container GID matches expected" "GID: $CONTAINER_GID, Expected: $EXPECTED_GID"
else
    echo -e "${RED}✗ Container GID mismatch: $CONTAINER_GID (expected: $EXPECTED_GID)${NC}"
    add_test_result "container_gid" "FAIL" "Container GID mismatch" "GID: $CONTAINER_GID, Expected: $EXPECTED_GID"
fi

# Test 3: Config Directory Permissions
echo -e "\n${YELLOW}Test 3: Config Directory Permissions${NC}"
CONFIG_PERMS=$(docker exec qbittorrent ls -ld /config 2>/dev/null || echo "ERROR")
if echo "$CONFIG_PERMS" | grep -q "drwx"; then
    echo -e "${GREEN}✓ Config directory has proper permissions${NC}"
    add_test_result "config_permissions" "PASS" "Config directory accessible" "$CONFIG_PERMS"
else
    echo -e "${RED}✗ Config directory permission issue${NC}"
    add_test_result "config_permissions" "FAIL" "Config directory permission issue" "$CONFIG_PERMS"
fi

# Test 4: Config File Write Test
echo -e "\n${YELLOW}Test 4: Config File Write Test${NC}"
WRITE_TEST=$(docker exec qbittorrent touch /config/test_write_permissions 2>&1 || echo "WRITE_ERROR")
if [ "$WRITE_TEST" = "" ]; then
    docker exec qbittorrent rm -f /config/test_write_permissions
    echo -e "${GREEN}✓ Can write to config directory${NC}"
    add_test_result "config_write_test" "PASS" "Config directory writable" "Write test successful"
else
    echo -e "${RED}✗ Cannot write to config directory${NC}"
    add_test_result "config_write_test" "FAIL" "Config directory not writable" "$WRITE_TEST"
fi

# Test 5: Downloads Directory Permissions
echo -e "\n${YELLOW}Test 5: Downloads Directory Permissions${NC}"
DOWNLOADS_PERMS=$(docker exec qbittorrent ls -ld /downloads 2>/dev/null || echo "ERROR")
DOWNLOADS_WRITE=$(docker exec qbittorrent touch /downloads/test_write_permissions 2>&1 || echo "WRITE_ERROR")

if [ "$DOWNLOADS_WRITE" = "" ]; then
    docker exec qbittorrent rm -f /downloads/test_write_permissions
    echo -e "${GREEN}✓ Downloads directory has proper permissions${NC}"
    add_test_result "downloads_permissions" "PASS" "Downloads directory writable" "$DOWNLOADS_PERMS"
else
    echo -e "${RED}✗ Downloads directory permission issue${NC}"
    add_test_result "downloads_permissions" "FAIL" "Downloads directory not writable" "$DOWNLOADS_WRITE"
fi

# Test 6: Video Directory Permissions
echo -e "\n${YELLOW}Test 6: Video Directory Permissions${NC}"
VIDEO_PERMS=$(docker exec qbittorrent ls -ld /video 2>/dev/null || echo "ERROR")
VIDEO_WRITE=$(docker exec qbittorrent touch /video/test_write_permissions 2>&1 || echo "WRITE_ERROR")

if [ "$VIDEO_WRITE" = "" ]; then
    docker exec qbittorrent rm -f /video/test_write_permissions
    echo -e "${GREEN}✓ Video directory has proper permissions${NC}"
    add_test_result "video_permissions" "PASS" "Video directory writable" "$VIDEO_PERMS"
else
    echo -e "${RED}✗ Video directory permission issue${NC}"
    add_test_result "video_permissions" "FAIL" "Video directory not writable" "$VIDEO_WRITE"
fi

# Test 7: NFS Mount Permissions (Video Volume)
echo -e "\n${YELLOW}Test 7: NFS Mount Permissions${NC}"
NFS_MOUNT_INFO=$(docker exec qbittorrent mount | grep "/video" || echo "NO_NFS_MOUNT")
if echo "$NFS_MOUNT_INFO" | grep -q "nfs"; then
    echo -e "${GREEN}✓ NFS mount detected for video directory${NC}"
    add_test_result "nfs_mount" "PASS" "NFS mount active" "$NFS_MOUNT_INFO"
else
    echo -e "${YELLOW}! No NFS mount detected (may be expected)${NC}"
    add_test_result "nfs_mount" "WARN" "No NFS mount detected" "$NFS_MOUNT_INFO"
fi

# Test 8: qBittorrent Process User
echo -e "\n${YELLOW}Test 8: qBittorrent Process User${NC}"
QB_PROCESS=$(docker exec qbittorrent ps aux | grep qbittorrent-nox | head -1 || echo "PROCESS_ERROR")
PROCESS_USER=$(echo "$QB_PROCESS" | awk '{print $1}' || echo "UNKNOWN")

if [ "$PROCESS_USER" != "root" ] && [ "$PROCESS_USER" != "UNKNOWN" ]; then
    echo -e "${GREEN}✓ qBittorrent running as non-root user: $PROCESS_USER${NC}"
    add_test_result "process_user" "PASS" "Running as non-root user" "User: $PROCESS_USER"
else
    echo -e "${RED}✗ qBittorrent process user issue: $PROCESS_USER${NC}"
    add_test_result "process_user" "FAIL" "Process user issue" "User: $PROCESS_USER, Process: $QB_PROCESS"
fi

# Test 9: File Ownership Verification
echo -e "\n${YELLOW}Test 9: File Ownership Verification${NC}"
CONFIG_OWNER=$(docker exec qbittorrent stat -c "%u:%g" /config/qBittorrent/qBittorrent.conf 2>/dev/null || echo "ERROR")
if [ "$CONFIG_OWNER" = "$EXPECTED_UID:$EXPECTED_GID" ]; then
    echo -e "${GREEN}✓ Config file has correct ownership: $CONFIG_OWNER${NC}"
    add_test_result "file_ownership" "PASS" "Config file ownership correct" "Owner: $CONFIG_OWNER"
else
    echo -e "${RED}✗ Config file ownership issue: $CONFIG_OWNER (expected: $EXPECTED_UID:$EXPECTED_GID)${NC}"
    add_test_result "file_ownership" "FAIL" "Config file ownership incorrect" "Owner: $CONFIG_OWNER, Expected: $EXPECTED_UID:$EXPECTED_GID"
fi

# Test 10: Service Restart After Permission Fix
echo -e "\n${YELLOW}Test 10: Service Restart After Permission Fix${NC}"
echo "Restarting qBittorrent service..."
docker-compose restart qbittorrent

# Wait for service to come up
sleep 10

# Check if service is running
SERVICE_STATUS=$(docker-compose ps qbittorrent | grep "Up" || echo "SERVICE_DOWN")
if echo "$SERVICE_STATUS" | grep -q "Up"; then
    echo -e "${GREEN}✓ Service restarted successfully after permission fix${NC}"
    add_test_result "service_restart" "PASS" "Service restart successful" "$SERVICE_STATUS"
else
    echo -e "${RED}✗ Service failed to restart after permission fix${NC}"
    add_test_result "service_restart" "FAIL" "Service restart failed" "$SERVICE_STATUS"
fi

# Generate summary
echo -e "\n${YELLOW}=== Permission Fix Test Summary ===${NC}"
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