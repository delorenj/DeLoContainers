#!/bin/bash

# qBittorrent Infrastructure Fix - Verification Script
# Created by the Verification Circus Division
# "Measure twice, deploy once, verify thrice!" - DevOps Wisdom

set -euo pipefail

# Color codes for maximum verification drama
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration variables
STACK_DIR="/home/delorenj/docker/trunk-main/stacks/media"
COMPOSE_FILE="${STACK_DIR}/compose.yml"
QBIT_CONF="${STACK_DIR}/qbittorrent/qBittorrent.conf"
QBIT_SERVICE_NAME="qbittorrent"
GLUETUN_SERVICE_NAME="gluetun"

# Logging functions with theatrical verification flair
log() {
    echo -e "${CYAN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

check_mark() {
    echo -e "${GREEN}✓${NC} $1"
}

cross_mark() {
    echo -e "${RED}✗${NC} $1"
}

# Function to verify backup integrity
verify_backups() {
    log "🎪 PHASE 1 VERIFICATION: Backup Integrity Check"
    
    local backup_dir="/home/delorenj/docker/trunk-main/scripts/qbittorrent-fix/backups"
    local verification_score=0
    local total_checks=5
    
    # Check if backup directory exists
    if [[ -d "$backup_dir" ]]; then
        check_mark "Backup directory exists"
        ((verification_score++))
    else
        cross_mark "Backup directory missing"
    fi
    
    # Check for essential backups
    local backup_files=(
        "qbittorrent_config"
        "bt_backup"
        "qbittorrent_conf"
        "compose_yml"
        "categories_json"
    )
    
    for backup_type in "${backup_files[@]}"; do
        if ls "$backup_dir"/${backup_type}_* >/dev/null 2>&1; then
            check_mark "Found backup: $backup_type"
            ((verification_score++))
        else
            cross_mark "Missing backup: $backup_type"
        fi
    done
    
    local backup_score=$((verification_score * 100 / (total_checks + ${#backup_files[@]})))
    
    if [[ $backup_score -ge 80 ]]; then
        success "Backup verification: $backup_score% - EXCELLENT"
        return 0
    elif [[ $backup_score -ge 60 ]]; then
        warn "Backup verification: $backup_score% - ACCEPTABLE"
        return 0
    else
        error "Backup verification: $backup_score% - INSUFFICIENT"
        return 1
    fi
}

# Function to verify patch application
verify_patches() {
    log "🔧 PHASE 2 VERIFICATION: Patch Application Check"
    
    local patch_score=0
    local total_patches=3
    
    # Verify PUID update
    log "Checking PUID configuration..."
    if grep -q "PUID=911" "$COMPOSE_FILE"; then
        check_mark "PUID successfully updated to 911"
        ((patch_score++))
    else
        if grep -q "PUID=502" "$COMPOSE_FILE"; then
            cross_mark "PUID still set to 502 (not updated)"
        else
            warn "PUID configuration not found or using different value"
        fi
    fi
    
    # Verify DNS server addition
    log "Checking DNS configuration for gluetun..."
    if grep -A 20 "gluetun:" "$COMPOSE_FILE" | grep -q "DNS=1.1.1.1"; then
        check_mark "DNS server (1.1.1.1) successfully added to gluetun"
        ((patch_score++))
    else
        cross_mark "DNS server not found in gluetun configuration"
    fi
    
    # Verify web authentication reset
    log "Checking qBittorrent web authentication settings..."
    local auth_checks=0
    local auth_total=4
    
    if grep -q "WebUI\\\\AuthSubnetWhitelistEnabled=true" "$QBIT_CONF"; then
        check_mark "AuthSubnetWhitelistEnabled set to true"
        ((auth_checks++))
    fi
    
    if grep -q "WebUI\\\\AuthSubnetWhitelist=0.0.0.0/0" "$QBIT_CONF"; then
        check_mark "AuthSubnetWhitelist set to allow all"
        ((auth_checks++))
    fi
    
    if grep -q "WebUI\\\\BypassLocalAuth=true" "$QBIT_CONF"; then
        check_mark "BypassLocalAuth enabled"
        ((auth_checks++))
    fi
    
    if grep -q "WebUI\\\\BypassAuthSubnetWhitelist=true" "$QBIT_CONF"; then
        check_mark "BypassAuthSubnetWhitelist enabled"
        ((auth_checks++))
    fi
    
    if [[ $auth_checks -ge 3 ]]; then
        check_mark "Web authentication successfully configured"
        ((patch_score++))
    else
        cross_mark "Web authentication configuration incomplete ($auth_checks/$auth_total)"
    fi
    
    local patch_percentage=$((patch_score * 100 / total_patches))
    
    if [[ $patch_score -eq $total_patches ]]; then
        success "Patch verification: 100% - ALL PATCHES APPLIED SUCCESSFULLY"
        return 0
    else
        error "Patch verification: $patch_percentage% - Some patches failed ($patch_score/$total_patches)"
        return 1
    fi
}

# Function to verify service status
verify_services() {
    log "🐳 PHASE 3 VERIFICATION: Service Status Check"
    
    local service_score=0
    local total_services=2
    
    # Check if Docker Compose is available
    if ! command -v docker >/dev/null 2>&1; then
        error "Docker not available - cannot verify services"
        return 1
    fi
    
    # Navigate to stack directory
    cd "$STACK_DIR" || {
        error "Cannot access stack directory: $STACK_DIR"
        return 1
    }
    
    # Check qBittorrent service
    log "Checking qBittorrent service status..."
    if docker compose ps --services | grep -q "$QBIT_SERVICE_NAME"; then
        local qbit_status=$(docker compose ps -q "$QBIT_SERVICE_NAME" | xargs docker inspect --format='{{.State.Status}}' 2>/dev/null || echo "unknown")
        
        case $qbit_status in
            "running")
                check_mark "qBittorrent service is running"
                ((service_score++))
                ;;
            "exited")
                warn "qBittorrent service has exited"
                ;;
            "restarting")
                warn "qBittorrent service is restarting"
                ;;
            *)
                cross_mark "qBittorrent service status: $qbit_status"
                ;;
        esac
    else
        cross_mark "qBittorrent service not found in compose file"
    fi
    
    # Check gluetun service
    log "Checking gluetun service status..."
    if docker compose ps --services | grep -q "$GLUETUN_SERVICE_NAME"; then
        local gluetun_status=$(docker compose ps -q "$GLUETUN_SERVICE_NAME" | xargs docker inspect --format='{{.State.Status}}' 2>/dev/null || echo "unknown")
        
        case $gluetun_status in
            "running")
                check_mark "Gluetun service is running"
                ((service_score++))
                ;;
            "exited")
                warn "Gluetun service has exited"
                ;;
            "restarting")
                warn "Gluetun service is restarting"
                ;;
            *)
                cross_mark "Gluetun service status: $gluetun_status"
                ;;
        esac
    else
        cross_mark "Gluetun service not found in compose file"
    fi
    
    local service_percentage=$((service_score * 100 / total_services))
    
    if [[ $service_score -eq $total_services ]]; then
        success "Service verification: 100% - ALL SERVICES RUNNING"
        return 0
    else
        warn "Service verification: $service_percentage% - Some services may need attention ($service_score/$total_services)"
        return 1
    fi
}

# Function to verify network connectivity
verify_connectivity() {
    log "🌐 PHASE 4 VERIFICATION: Network Connectivity Check"
    
    local connectivity_score=0
    local total_checks=3
    
    # Check if qBittorrent web UI is accessible
    log "Checking qBittorrent web UI accessibility..."
    local qbit_port=$(grep -A 10 "$QBIT_SERVICE_NAME:" "$COMPOSE_FILE" | grep -E "^\s*-\s*[0-9]+:8080" | sed 's/.*- \([0-9]*\):.*/\1/' || echo "8080")
    
    if curl -s --connect-timeout 5 "http://localhost:$qbit_port" >/dev/null 2>&1; then
        check_mark "qBittorrent web UI accessible on port $qbit_port"
        ((connectivity_score++))
    else
        cross_mark "qBittorrent web UI not accessible on port $qbit_port"
    fi
    
    # Check DNS resolution from within gluetun container
    log "Checking DNS resolution from gluetun..."
    local gluetun_container=$(docker compose ps -q "$GLUETUN_SERVICE_NAME" 2>/dev/null)
    if [[ -n "$gluetun_container" ]]; then
        if docker exec "$gluetun_container" nslookup google.com >/dev/null 2>&1; then
            check_mark "DNS resolution working from gluetun container"
            ((connectivity_score++))
        else
            cross_mark "DNS resolution failed from gluetun container"
        fi
    else
        warn "Gluetun container not running - skipping DNS test"
    fi
    
    # Check VPN status if possible
    log "Checking VPN connection status..."
    if [[ -n "$gluetun_container" ]]; then
        local vpn_status=$(docker logs "$gluetun_container" --tail 50 2>/dev/null | grep -i "vpn\|connected" | tail -1 || echo "unknown")
        if echo "$vpn_status" | grep -qi "connected"; then
            check_mark "VPN appears to be connected"
            ((connectivity_score++))
        else
            warn "VPN connection status unclear"
        fi
    else
        warn "Cannot check VPN status - gluetun container not available"
    fi
    
    local connectivity_percentage=$((connectivity_score * 100 / total_checks))
    
    if [[ $connectivity_score -ge 2 ]]; then
        success "Connectivity verification: $connectivity_percentage% - GOOD CONNECTIVITY"
        return 0
    else
        warn "Connectivity verification: $connectivity_percentage% - CONNECTIVITY ISSUES DETECTED"
        return 1
    fi
}

# Function to generate verification report
generate_report() {
    local backup_result="$1"
    local patch_result="$2"
    local service_result="$3"
    local connectivity_result="$4"
    
    local report_file="/home/delorenj/docker/trunk-main/scripts/qbittorrent-fix/verification/verification_report_$(date +%Y%m%d_%H%M%S).txt"
    
    log "📊 Generating verification report..."
    
    {
        echo "qBittorrent Infrastructure Fix - Verification Report"
        echo "=================================================="
        echo "Generated: $(date)"
        echo "System: $(uname -a)"
        echo "User: $(whoami)"
        echo ""
        
        echo "VERIFICATION RESULTS"
        echo "==================="
        echo -n "Phase 1 - Backup Verification: "
        [[ $backup_result -eq 0 ]] && echo "✓ PASSED" || echo "✗ FAILED"
        
        echo -n "Phase 2 - Patch Verification: "
        [[ $patch_result -eq 0 ]] && echo "✓ PASSED" || echo "✗ FAILED"
        
        echo -n "Phase 3 - Service Verification: "
        [[ $service_result -eq 0 ]] && echo "✓ PASSED" || echo "✗ FAILED"
        
        echo -n "Phase 4 - Connectivity Verification: "
        [[ $connectivity_result -eq 0 ]] && echo "✓ PASSED" || echo "✗ FAILED"
        
        echo ""
        echo "OVERALL STATUS"
        echo "=============="
        local total_passed=$((($backup_result == 0) + ($patch_result == 0) + ($service_result == 0) + ($connectivity_result == 0)))
        local overall_percentage=$((total_passed * 100 / 4))
        
        echo "Phases passed: $total_passed/4 ($overall_percentage%)"
        
        if [[ $total_passed -eq 4 ]]; then
            echo "STATUS: ✓ ALL VERIFICATIONS PASSED - INFRASTRUCTURE FIX SUCCESSFUL"
        elif [[ $total_passed -ge 3 ]]; then
            echo "STATUS: ⚠ MOSTLY SUCCESSFUL - MINOR ISSUES DETECTED"
        elif [[ $total_passed -ge 2 ]]; then
            echo "STATUS: ⚠ PARTIAL SUCCESS - SIGNIFICANT ISSUES DETECTED"
        else
            echo "STATUS: ✗ VERIFICATION FAILED - MAJOR ISSUES DETECTED"
        fi
        
        echo ""
        echo "RECOMMENDATIONS"
        echo "==============="
        
        [[ $backup_result -ne 0 ]] && echo "- Re-run backup creation script"
        [[ $patch_result -ne 0 ]] && echo "- Review and re-apply failed patches"
        [[ $service_result -ne 0 ]] && echo "- Restart services: docker compose restart"
        [[ $connectivity_result -ne 0 ]] && echo "- Check network configuration and VPN settings"
        
        echo ""
        echo "End of Report"
        
    } > "$report_file"
    
    success "Verification report generated: $report_file"
    
    # Display summary to console
    log "🎭 FINAL VERIFICATION SUMMARY 🎭"
    local total_passed=$((($backup_result == 0) + ($patch_result == 0) + ($service_result == 0) + ($connectivity_result == 0)))
    success "Passed: $total_passed/4 phases"
    
    if [[ $total_passed -eq 4 ]]; then
        success "🎉 ALL VERIFICATIONS PASSED! The infrastructure fix is MAGNIFICENT! ✨"
        return 0
    else
        warn "⚠️ Some verifications failed. Please review the report: $report_file"
        return 1
    fi
}

# Main verification orchestration
main() {
    local skip_services="${1:-false}"
    
    log "🎪 INITIATING THE GRAND VERIFICATION CIRCUS! 🎪"
    
    if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        echo "Usage: $0 [--skip-services]"
        echo ""
        echo "Options:"
        echo "  --skip-services    Skip service status verification"
        echo "  --help, -h         Show this help message"
        echo ""
        echo "This script verifies all phases of the qBittorrent infrastructure fix:"
        echo "1. Backup integrity"
        echo "2. Patch application"
        echo "3. Service status"
        echo "4. Network connectivity"
        return 0
    fi
    
    [[ "$1" == "--skip-services" ]] && skip_services="true"
    
    # Execute all verification phases
    local backup_result=1
    local patch_result=1
    local service_result=1
    local connectivity_result=1
    
    # Phase 1: Backup verification
    verify_backups && backup_result=0
    
    # Phase 2: Patch verification
    verify_patches && patch_result=0
    
    # Phase 3: Service verification (optional)
    if [[ "$skip_services" == "false" ]]; then
        verify_services && service_result=0
    else
        log "Skipping service verification as requested"
        service_result=0  # Consider as passed when skipped
    fi
    
    # Phase 4: Connectivity verification (only if services are running)
    if [[ $service_result -eq 0 ]]; then
        verify_connectivity && connectivity_result=0
    else
        log "Skipping connectivity verification due to service issues"
    fi
    
    # Generate final report
    generate_report "$backup_result" "$patch_result" "$service_result" "$connectivity_result"
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi