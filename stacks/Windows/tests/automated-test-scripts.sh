#!/bin/bash
# 🧪 FOCUSRITE 4I4 AUTOMATED TESTING SUITE
# Comprehensive validation scripts for USB passthrough solutions
# HIVE MIND TESTER AGENT - Solution Validation Framework

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
REPORTS_DIR="${SCRIPT_DIR}/reports"
SNAPSHOTS_DIR="${SCRIPT_DIR}/snapshots"
WINDOWS_CONTAINER="windows"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create directories
mkdir -p "$LOG_DIR" "$REPORTS_DIR" "$SNAPSHOTS_DIR"

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_DIR/test-suite.log"
}

error() {
    echo -e "${RED}[ERROR $(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_DIR/test-suite.log"
}

warn() {
    echo -e "${YELLOW}[WARN $(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_DIR/test-suite.log"
}

info() {
    echo -e "${BLUE}[INFO $(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_DIR/test-suite.log"
}

# Test result tracking
declare -A test_results
declare -A test_timings
test_count=0
passed_tests=0
failed_tests=0

# Record test result
record_test() {
    local test_name="$1"
    local result="$2"
    local duration="$3"
    
    test_results["$test_name"]="$result"
    test_timings["$test_name"]="$duration"
    test_count=$((test_count + 1))
    
    if [[ "$result" == "PASS" ]]; then
        passed_tests=$((passed_tests + 1))
        log "✅ $test_name: PASSED (${duration}s)"
    else
        failed_tests=$((failed_tests + 1))
        error "❌ $test_name: FAILED (${duration}s)"
    fi
}

# Wait for VM to be ready
wait_for_vm() {
    local timeout=300  # 5 minutes
    local count=0
    
    info "⏳ Waiting for Windows VM to be ready..."
    
    while ! docker exec -t "$WINDOWS_CONTAINER" powershell.exe -Command "Get-Service" &>/dev/null; do
        sleep 10
        count=$((count + 10))
        if [[ $count -ge $timeout ]]; then
            error "❌ VM failed to become ready within $timeout seconds"
            return 1
        fi
        echo -n "."
    done
    
    log "✅ Windows VM is ready"
    return 0
}

# Capture baseline system state
capture_baseline() {
    local start_time=$(date +%s)
    info "📸 Capturing baseline system state..."
    
    local baseline_file="$SNAPSHOTS_DIR/baseline-$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=== BASELINE SYSTEM STATE CAPTURE ==="
        echo "Timestamp: $(date)"
        echo "Host: $(hostname)"
        echo "Docker Container: $WINDOWS_CONTAINER"
        echo ""
        
        echo "=== HOST USB DEVICES ==="
        lsusb -t || true
        echo ""
        lsusb | grep -i focusrite || echo "No Focusrite devices found"
        echo ""
        
        echo "=== HOST FOCUSRITE SYMLINKS ==="
        ls -la /dev/focusrite* 2>/dev/null || echo "No Focusrite symlinks found"
        echo ""
        
        echo "=== DOCKER CONTAINER USB ==="
        docker exec "$WINDOWS_CONTAINER" lsusb 2>/dev/null || echo "lsusb not available in container"
        echo ""
        
        echo "=== CONTAINER STATUS ==="
        docker inspect "$WINDOWS_CONTAINER" --format='{{.State.Status}}' || echo "Container not running"
        
    } > "$baseline_file"
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [[ -f "$baseline_file" && -s "$baseline_file" ]]; then
        record_test "baseline_capture" "PASS" "$duration"
        info "📄 Baseline captured: $baseline_file"
        return 0
    else
        record_test "baseline_capture" "FAIL" "$duration"
        return 1
    fi
}

# Test host USB device detection
test_host_usb_detection() {
    local start_time=$(date +%s)
    info "🔌 Testing host USB device detection..."
    
    # Check for Focusrite device by VID:PID
    if lsusb | grep -q "1235:821a"; then
        log "✅ Focusrite 4i4 detected on host (VID:1235, PID:821a)"
        local host_detection="PASS"
    else
        error "❌ Focusrite 4i4 NOT detected on host"
        local host_detection="FAIL"
    fi
    
    # Check for persistent symlink
    if [[ -e "/dev/focusrite_4i4" ]]; then
        log "✅ Persistent symlink /dev/focusrite_4i4 exists"
        local symlink_check="PASS"
    else
        error "❌ Persistent symlink /dev/focusrite_4i4 missing"
        local symlink_check="FAIL"
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [[ "$host_detection" == "PASS" && "$symlink_check" == "PASS" ]]; then
        record_test "host_usb_detection" "PASS" "$duration"
        return 0
    else
        record_test "host_usb_detection" "FAIL" "$duration"
        return 1
    fi
}

# Test Windows VM USB passthrough
test_vm_usb_passthrough() {
    local start_time=$(date +%s)
    info "💻 Testing Windows VM USB passthrough..."
    
    if ! wait_for_vm; then
        record_test "vm_usb_passthrough" "FAIL" "$(($(date +%s) - start_time))"
        return 1
    fi
    
    # Test USB device visibility in Windows
    local usb_test_result
    if docker exec -t "$WINDOWS_CONTAINER" powershell.exe -Command "Get-PnpDevice | Where-Object {\$_.FriendlyName -like '*Focusrite*'} | Select-Object -First 1" 2>/dev/null | grep -q "Focusrite"; then
        log "✅ Focusrite device visible in Windows Device Manager"
        usb_test_result="PASS"
    else
        error "❌ Focusrite device NOT visible in Windows Device Manager"
        usb_test_result="FAIL"
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    record_test "vm_usb_passthrough" "$usb_test_result" "$duration"
    
    if [[ "$usb_test_result" == "PASS" ]]; then
        return 0
    else
        return 1
    fi
}

# Test device manager status
test_device_manager_status() {
    local start_time=$(date +%s)
    info "📋 Testing Windows Device Manager status..."
    
    if ! wait_for_vm; then
        record_test "device_manager_status" "FAIL" "$(($(date +%s) - start_time))"
        return 1
    fi
    
    # Check for device errors in Device Manager
    local dm_status
    if docker exec -t "$WINDOWS_CONTAINER" powershell.exe -Command "Get-PnpDevice | Where-Object {\$_.FriendlyName -like '*Focusrite*'} | Where-Object {\$_.Status -eq 'OK'}" 2>/dev/null | grep -q "OK"; then
        log "✅ Focusrite device has OK status in Device Manager"
        dm_status="PASS"
    else
        # Check if device exists but with errors
        if docker exec -t "$WINDOWS_CONTAINER" powershell.exe -Command "Get-PnpDevice | Where-Object {\$_.FriendlyName -like '*Focusrite*'}" 2>/dev/null | grep -q "Focusrite"; then
            warn "⚠️ Focusrite device exists but has error status"
            dm_status="PARTIAL"
        else
            error "❌ Focusrite device not found in Device Manager"
            dm_status="FAIL"
        fi
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    record_test "device_manager_status" "$dm_status" "$duration"
    
    if [[ "$dm_status" == "PASS" ]]; then
        return 0
    else
        return 1
    fi
}

# Test Focusrite Control software connectivity
test_focusrite_control() {
    local start_time=$(date +%s)
    info "🎛️ Testing Focusrite Control software connectivity..."
    
    if ! wait_for_vm; then
        record_test "focusrite_control" "FAIL" "$(($(date +%s) - start_time))"
        return 1
    fi
    
    # Check if Focusrite Control is installed and can detect device
    # This is a simplified test - in real scenarios you'd interact with the actual software
    local control_test
    if docker exec -t "$WINDOWS_CONTAINER" powershell.exe -Command "Get-Process | Where-Object {$_.ProcessName -like '*Focusrite*'}" 2>/dev/null | grep -q "Focusrite"; then
        log "✅ Focusrite Control software is running"
        control_test="PASS"
    else
        # Check if software is installed but not running
        if docker exec -t "$WINDOWS_CONTAINER" powershell.exe -Command "Get-ItemProperty 'HKLM:\\Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\*' | Where-Object {$_.DisplayName -like '*Focusrite*'}" 2>/dev/null | grep -q "Focusrite"; then
            warn "⚠️ Focusrite Control software installed but not running"
            control_test="PARTIAL"
        else
            warn "⚠️ Focusrite Control software not detected"
            control_test="FAIL"
        fi
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    record_test "focusrite_control" "$control_test" "$duration"
    
    if [[ "$control_test" == "PASS" ]]; then
        return 0
    else
        return 1
    fi
}

# Test audio device functionality
test_audio_devices() {
    local start_time=$(date +%s)
    info "🔊 Testing Windows audio device functionality..."
    
    if ! wait_for_vm; then
        record_test "audio_devices" "FAIL" "$(($(date +%s) - start_time))"
        return 1
    fi
    
    # Check Windows audio devices
    local audio_test
    if docker exec -t "$WINDOWS_CONTAINER" powershell.exe -Command "Get-AudioDevice | Where-Object {\$_.Name -like '*Scarlett*'}" 2>/dev/null | grep -q "Scarlett"; then
        log "✅ Focusrite Scarlett audio devices detected in Windows"
        audio_test="PASS"
    else
        error "❌ Focusrite Scarlett audio devices NOT detected in Windows"
        audio_test="FAIL"
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    record_test "audio_devices" "$audio_test" "$duration"
    
    if [[ "$audio_test" == "PASS" ]]; then
        return 0
    else
        return 1
    fi
}

# Test VM restart persistence
test_vm_restart_persistence() {
    local start_time=$(date +%s)
    info "🔄 Testing VM restart persistence..."
    
    # Restart the Windows container
    info "Restarting Windows container..."
    docker-compose -f "$(dirname "$SCRIPT_DIR")/compose.yml" restart windows
    
    # Wait for VM to come back up
    sleep 30
    
    if ! wait_for_vm; then
        record_test "vm_restart_persistence" "FAIL" "$(($(date +%s) - start_time))"
        return 1
    fi
    
    # Test device detection after restart
    local persistence_test="PASS"
    
    # Re-test USB passthrough
    if ! test_vm_usb_passthrough; then
        warn "❌ USB passthrough failed after restart"
        persistence_test="FAIL"
    fi
    
    # Re-test device manager status
    if ! test_device_manager_status; then
        warn "❌ Device Manager status failed after restart"
        persistence_test="FAIL"
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    record_test "vm_restart_persistence" "$persistence_test" "$duration"
    
    if [[ "$persistence_test" == "PASS" ]]; then
        return 0
    else
        return 1
    fi
}

# Test FL Studio integration
test_fl_studio_integration() {
    local start_time=$(date +%s)
    info "🎵 Testing FL Studio integration..."
    
    if ! wait_for_vm; then
        record_test "fl_studio_integration" "FAIL" "$(($(date +%s) - start_time))"
        return 1
    fi
    
    # Check if FL Studio can detect ASIO devices
    # This is a simplified test - actual implementation would involve more complex FL Studio interaction
    local fl_test
    if docker exec -t "$WINDOWS_CONTAINER" powershell.exe -Command "Get-ItemProperty 'HKLM:\\Software\\Image-Line\\*' -ErrorAction SilentlyContinue" 2>/dev/null | grep -q "Image-Line"; then
        info "FL Studio installation detected"
        fl_test="PARTIAL"  # Would need actual ASIO driver test
    else
        warn "⚠️ FL Studio not installed or not detectable"
        fl_test="SKIP"
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    record_test "fl_studio_integration" "$fl_test" "$duration"
    
    return 0  # Non-critical test
}

# Generate comprehensive test report
generate_test_report() {
    local report_file="$REPORTS_DIR/test-report-$(date +%Y%m%d_%H%M%S).md"
    
    info "📄 Generating comprehensive test report..."
    
    {
        echo "# Focusrite 4i4 USB Passthrough Test Report"
        echo "**Generated by:** HIVE MIND TESTER AGENT"
        echo "**Date:** $(date)"
        echo "**Host:** $(hostname)"
        echo "**Container:** $WINDOWS_CONTAINER"
        echo ""
        
        echo "## Executive Summary"
        echo "- **Total Tests:** $test_count"
        echo "- **Passed:** $passed_tests"
        echo "- **Failed:** $failed_tests"
        echo "- **Success Rate:** $(( passed_tests * 100 / test_count ))%"
        echo ""
        
        echo "## Test Results"
        echo "| Test Name | Result | Duration | Status |"
        echo "|-----------|---------|----------|---------|"
        
        for test_name in "${!test_results[@]}"; do
            local result="${test_results[$test_name]}"
            local duration="${test_timings[$test_name]}"
            local status_icon
            
            case "$result" in
                "PASS") status_icon="✅" ;;
                "FAIL") status_icon="❌" ;;
                "PARTIAL") status_icon="⚠️" ;;
                "SKIP") status_icon="⏭️" ;;
                *) status_icon="❓" ;;
            esac
            
            echo "| $test_name | $result | ${duration}s | $status_icon |"
        done
        
        echo ""
        echo "## Detailed Analysis"
        
        if [[ $failed_tests -gt 0 ]]; then
            echo "### ❌ Failed Tests"
            for test_name in "${!test_results[@]}"; do
                if [[ "${test_results[$test_name]}" == "FAIL" ]]; then
                    echo "- **$test_name**: Requires investigation and remediation"
                fi
            done
            echo ""
        fi
        
        if [[ $passed_tests -gt 0 ]]; then
            echo "### ✅ Successful Tests"
            for test_name in "${!test_results[@]}"; do
                if [[ "${test_results[$test_name]}" == "PASS" ]]; then
                    echo "- **$test_name**: Functioning correctly"
                fi
            done
            echo ""
        fi
        
        echo "## Recommendations"
        if [[ $failed_tests -eq 0 ]]; then
            echo "🎉 **All critical tests passed!** The Focusrite 4i4 USB passthrough solution is working correctly."
        else
            echo "🔧 **Action Required:** $failed_tests test(s) failed and need attention:"
            echo ""
            echo "1. Review failed test logs in \`$LOG_DIR/\`"
            echo "2. Apply recommended solutions from RESEARCHER AGENT"
            echo "3. Re-run validation suite after fixes"
            echo "4. Consider rollback if issues persist"
        fi
        
        echo ""
        echo "## Next Steps"
        echo "- [ ] Review test results with QUEEN SERAPHINA"
        echo "- [ ] Share findings with RESEARCHER AGENT for solution refinement"
        echo "- [ ] Coordinate with ANALYST AGENT for deeper diagnostics if needed"
        echo "- [ ] Schedule follow-up stability testing"
        
        echo ""
        echo "---"
        echo "*Report generated by HIVE MIND TESTER AGENT*"
        
    } > "$report_file"
    
    log "📊 Test report generated: $report_file"
    
    # Also output summary to console
    echo ""
    echo "=========================================="
    echo "🧪 FOCUSRITE 4I4 TEST SUITE COMPLETE"
    echo "=========================================="
    echo "Total Tests: $test_count"
    echo "Passed: $passed_tests"
    echo "Failed: $failed_tests"
    echo "Success Rate: $(( passed_tests * 100 / test_count ))%"
    echo "Report: $report_file"
    echo "=========================================="
}

# Emergency recovery procedures
emergency_recovery() {
    error "🚨 EMERGENCY RECOVERY ACTIVATED"
    
    # Stop container
    docker-compose -f "$(dirname "$SCRIPT_DIR")/compose.yml" down || true
    
    # Wait a moment
    sleep 10
    
    # Restart container
    docker-compose -f "$(dirname "$SCRIPT_DIR")/compose.yml" up -d || true
    
    # Wait for VM
    sleep 30
    
    if wait_for_vm; then
        log "✅ Emergency recovery successful"
        return 0
    else
        error "❌ Emergency recovery failed - manual intervention required"
        return 1
    fi
}

# Main test suite execution
main() {
    echo ""
    echo "🧪 FOCUSRITE 4I4 COMPREHENSIVE TEST SUITE"
    echo "========================================="
    echo "HIVE MIND TESTER AGENT - Solution Validation"
    echo "Starting at: $(date)"
    echo ""
    
    # Set up signal handlers for emergency recovery
    trap 'echo ""; warn "Test suite interrupted - activating emergency recovery"; emergency_recovery; exit 1' INT TERM
    
    # Execute test suite
    log "🚀 Beginning comprehensive validation protocol..."
    
    # Core system tests
    capture_baseline
    test_host_usb_detection
    test_vm_usb_passthrough
    test_device_manager_status
    
    # Application-specific tests
    test_focusrite_control
    test_audio_devices
    test_fl_studio_integration
    
    # Persistence and stability tests
    test_vm_restart_persistence
    
    # Generate final report
    generate_test_report
    
    # Final status
    if [[ $failed_tests -eq 0 ]]; then
        log "🎉 ALL TESTS PASSED - Solution validated successfully!"
        exit 0
    else
        error "❌ $failed_tests test(s) failed - Solution needs refinement"
        exit 1
    fi
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi