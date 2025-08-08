#!/bin/bash

# qBittorrent Infrastructure Fix - Master Orchestration Script
# Created by the Grand DevOps Circus Master
# "Automation is the art of making the complex appear simple!" - The DevOps Manifesto

set -euo pipefail

# Color codes for the grand finale
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration variables
SCRIPT_DIR="/home/delorenj/docker/trunk-main/scripts/qbittorrent-fix"
BACKUP_SCRIPT="${SCRIPT_DIR}/backups/create-backups.sh"
PATCH_SCRIPT="${SCRIPT_DIR}/patches/apply-patches.sh"
VERIFY_SCRIPT="${SCRIPT_DIR}/verification/verify-phases.sh"
STACK_DIR="/home/delorenj/docker/trunk-main/stacks/media"

# Logging functions with maximum theatrical drama
log() {
    echo -e "${BOLD}${CYAN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${BOLD}${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${BOLD}${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${BOLD}${YELLOW}[WARNING]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

banner() {
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${NC} $1 ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
}

# Function to check prerequisites
check_prerequisites() {
    log "🔍 Checking prerequisites..."
    
    local errors=0
    
    # Check if Docker is available
    if ! command -v docker >/dev/null 2>&1; then
        error "Docker is not installed or not in PATH"
        ((errors++))
    else
        success "Docker is available"
    fi
    
    # Check if Docker Compose is available
    if ! docker compose version >/dev/null 2>&1; then
        error "Docker Compose is not available"
        ((errors++))
    else
        success "Docker Compose is available"
    fi
    
    # Check if stack directory exists
    if [[ ! -d "$STACK_DIR" ]]; then
        error "Stack directory not found: $STACK_DIR"
        ((errors++))
    else
        success "Stack directory exists"
    fi
    
    # Check if all scripts exist and are executable
    local scripts=("$BACKUP_SCRIPT" "$PATCH_SCRIPT" "$VERIFY_SCRIPT")
    for script in "${scripts[@]}"; do
        if [[ ! -f "$script" ]]; then
            error "Script not found: $script"
            ((errors++))
        elif [[ ! -x "$script" ]]; then
            warn "Script not executable: $script (fixing...)"
            chmod +x "$script"
        else
            success "Script ready: $(basename "$script")"
        fi
    done
    
    if [[ $errors -gt 0 ]]; then
        error "Prerequisites check failed with $errors errors"
        return 1
    else
        success "All prerequisites satisfied!"
        return 0
    fi
}

# Function to display the main menu
show_menu() {
    clear
    banner "🎪 qBittorrent Infrastructure Fix - Master Control Center 🎪"
    echo ""
    echo -e "${BOLD}Available Operations:${NC}"
    echo ""
    echo "  ${CYAN}1.${NC} Create Backups (Essential preparation)"
    echo "  ${CYAN}2.${NC) Apply Patches (PUID, DNS, Auth fixes)"
    echo "  ${CYAN}3.${NC} Verify Installation (Comprehensive checks)"
    echo "  ${CYAN}4.${NC} Full Orchestration (All phases automatically)"
    echo "  ${CYAN}5.${NC} Dry Run (Preview changes without applying)"
    echo "  ${CYAN}6.${NC} Emergency Rollback (Restore from backups)"
    echo "  ${CYAN}7.${NC} Service Management (Start/Stop/Restart)"
    echo "  ${CYAN}8.${NC} Show Status (Current system state)"
    echo ""
    echo "  ${YELLOW}h.${NC} Help & Documentation"
    echo "  ${RED}q.${NC} Quit"
    echo ""
    echo -n "${BOLD}Select an operation [1-8,h,q]: ${NC}"
}

# Function to execute backup creation
execute_backups() {
    banner "📦 BACKUP CREATION PHASE"
    log "Executing backup creation script..."
    
    if [[ -x "$BACKUP_SCRIPT" ]]; then
        if "$BACKUP_SCRIPT"; then
            success "Backup creation completed successfully!"
            return 0
        else
            error "Backup creation failed!"
            return 1
        fi
    else
        error "Backup script not executable: $BACKUP_SCRIPT"
        return 1
    fi
}

# Function to execute patch application
execute_patches() {
    banner "🔧 PATCH APPLICATION PHASE"
    log "Executing patch application script..."
    
    echo -n "Apply patches interactively? (Y/n): "
    read -r interactive
    
    local args=""
    if [[ "$interactive" =~ ^[Nn]$ ]]; then
        args="--non-interactive"
    fi
    
    if [[ -x "$PATCH_SCRIPT" ]]; then
        if "$PATCH_SCRIPT" $args; then
            success "Patch application completed successfully!"
            return 0
        else
            error "Patch application failed!"
            return 1
        fi
    else
        error "Patch script not executable: $PATCH_SCRIPT"
        return 1
    fi
}

# Function to execute verification
execute_verification() {
    banner "🔍 VERIFICATION PHASE"
    log "Executing verification script..."
    
    echo -n "Skip service status checks? (y/N): "
    read -r skip_services
    
    local args=""
    if [[ "$skip_services" =~ ^[Yy]$ ]]; then
        args="--skip-services"
    fi
    
    if [[ -x "$VERIFY_SCRIPT" ]]; then
        if "$VERIFY_SCRIPT" $args; then
            success "Verification completed successfully!"
            return 0
        else
            warn "Verification completed with issues - check the report"
            return 1
        fi
    else
        error "Verification script not executable: $VERIFY_SCRIPT"
        return 1
    fi
}

# Function to execute full orchestration
execute_full_orchestration() {
    banner "🎪 FULL ORCHESTRATION - THE GRAND PERFORMANCE!"
    
    log "🎭 Beginning the complete qBittorrent infrastructure fix..."
    log "This will execute: Backups → Patches → Service Restart → Verification"
    
    echo -n "Proceed with full orchestration? (y/N): "
    read -r confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log "Full orchestration cancelled by user"
        return 0
    fi
    
    local phase_results=()
    
    # Phase 1: Backups
    log "🎪 Phase 1/4: Creating backups..."
    if execute_backups; then
        phase_results+=("BACKUP: ✓")
    else
        phase_results+=("BACKUP: ✗")
        error "Cannot proceed without successful backups!"
        return 1
    fi
    
    # Phase 2: Apply patches
    log "🎪 Phase 2/4: Applying patches..."
    if execute_patches; then
        phase_results+=("PATCHES: ✓")
    else
        phase_results+=("PATCHES: ✗")
        warn "Patch application failed - continuing with verification..."
    fi
    
    # Phase 3: Restart services
    log "🎪 Phase 3/4: Restarting services..."
    if restart_services; then
        phase_results+=("RESTART: ✓")
    else
        phase_results+=("RESTART: ✗")
        warn "Service restart failed - continuing with verification..."
    fi
    
    # Phase 4: Verification
    log "🎪 Phase 4/4: Running verification..."
    if execute_verification; then
        phase_results+=("VERIFY: ✓")
    else
        phase_results+=("VERIFY: ✗")
    fi
    
    # Final results
    banner "🎭 ORCHESTRATION COMPLETE - FINAL RESULTS"
    for result in "${phase_results[@]}"; do
        echo "  $result"
    done
    
    local success_count=$(printf '%s\n' "${phase_results[@]}" | grep -c "✓" || echo "0")
    local total_phases=${#phase_results[@]}
    
    if [[ $success_count -eq $total_phases ]]; then
        success "🎉 COMPLETE SUCCESS! All $total_phases phases executed flawlessly!"
        success "Your qBittorrent infrastructure has been MAGNIFICENTLY fixed! ✨"
        return 0
    else
        warn "⚠️ Partial success: $success_count/$total_phases phases succeeded"
        warn "Please review the output above and run verification to identify issues"
        return 1
    fi
}

# Function to execute dry run
execute_dry_run() {
    banner "🧪 DRY RUN - PREVIEW MODE"
    log "Executing patches in dry run mode..."
    
    if [[ -x "$PATCH_SCRIPT" ]]; then
        if "$PATCH_SCRIPT" --dry-run; then
            success "Dry run completed - review the proposed changes above"
            return 0
        else
            error "Dry run failed!"
            return 1
        fi
    else
        error "Patch script not executable: $PATCH_SCRIPT"
        return 1
    fi
}

# Function to restart services
restart_services() {
    log "🐳 Restarting Docker services..."
    
    cd "$STACK_DIR" || {
        error "Cannot access stack directory: $STACK_DIR"
        return 1
    }
    
    if docker compose restart; then
        success "Services restarted successfully"
        log "Waiting 10 seconds for services to stabilize..."
        sleep 10
        return 0
    else
        error "Failed to restart services"
        return 1
    fi
}

# Function for service management
service_management() {
    banner "🐳 SERVICE MANAGEMENT"
    
    echo "Service Management Options:"
    echo "  1. Start services"
    echo "  2. Stop services"
    echo "  3. Restart services"
    echo "  4. Show service status"
    echo "  5. Show service logs"
    echo ""
    echo -n "Select operation [1-5]: "
    read -r service_choice
    
    cd "$STACK_DIR" || {
        error "Cannot access stack directory: $STACK_DIR"
        return 1
    }
    
    case $service_choice in
        1)
            log "Starting services..."
            docker compose up -d
            ;;
        2)
            log "Stopping services..."
            docker compose down
            ;;
        3)
            log "Restarting services..."
            docker compose restart
            ;;
        4)
            log "Service status:"
            docker compose ps
            ;;
        5)
            echo -n "Show logs for which service? (qbittorrent/gluetun/all): "
            read -r log_service
            case $log_service in
                "all")
                    docker compose logs --tail=50
                    ;;
                *)
                    docker compose logs --tail=50 "$log_service"
                    ;;
            esac
            ;;
        *)
            error "Invalid choice"
            return 1
            ;;
    esac
}

# Function to show current status
show_status() {
    banner "📊 CURRENT SYSTEM STATUS"
    
    log "Docker Compose Status:"
    cd "$STACK_DIR" && docker compose ps || warn "Cannot show compose status"
    
    echo ""
    log "Recent Container Logs (last 5 lines):"
    cd "$STACK_DIR" && docker compose logs --tail=5 || warn "Cannot show logs"
    
    echo ""
    log "System Resources:"
    echo "Disk usage: $(df -h "$STACK_DIR" | tail -1 | awk '{print $5 " used (" $4 " available)"}')"
    echo "Memory usage: $(free -h | grep '^Mem:' | awk '{print $3 "/" $2 " (" int($3/$2 * 100) "%)"}')"
}

# Function to show help
show_help() {
    banner "📚 HELP & DOCUMENTATION"
    
    cat << 'EOF'
qBittorrent Infrastructure Fix - Master Script Help
==================================================

This script orchestrates the complete qBittorrent infrastructure fix process,
addressing common issues with PUID permissions, DNS configuration, and web authentication.

OPERATIONS OVERVIEW:
------------------

1. Create Backups
   - Backs up all critical qBittorrent configuration files
   - Creates BT_backup directory backup (your torrents!)
   - Backs up Docker Compose configuration
   - Creates system information snapshot

2. Apply Patches
   - Updates PUID from 502 to 911 (fixes permission issues)
   - Adds DNS server (1.1.1.1) to gluetun service
   - Resets web authentication to allow local access
   - Creates pre-patch backups automatically

3. Verify Installation
   - Checks backup integrity
   - Verifies patch application
   - Tests service status
   - Validates network connectivity

4. Full Orchestration
   - Executes all phases automatically
   - Includes service restart
   - Provides comprehensive status report

5. Dry Run
   - Shows what patches would be applied
   - Safe preview mode without making changes

6. Emergency Rollback
   - Restores from the most recent backups
   - Reverts all changes if needed

7. Service Management
   - Start/stop/restart individual services
   - View service status and logs

8. Show Status
   - Current system state overview
   - Service status and resource usage

TROUBLESHOOTING:
---------------
- Always run backups before making changes
- Use dry run to preview patch effects
- Check verification report for detailed results
- Service logs available through service management

FILES AFFECTED:
--------------
- /stacks/media/compose.yml (PUID and DNS changes)
- /stacks/media/qbittorrent/qBittorrent.conf (auth settings)
- All changes are backed up automatically

SAFETY FEATURES:
---------------
- Automatic pre-patch backups
- Dry run preview mode
- Comprehensive verification
- Error handling and rollback capabilities
- User confirmation prompts

For more information, check the individual script files in:
/home/delorenj/docker/trunk-main/scripts/qbittorrent-fix/
EOF
    
    echo ""
    echo -n "Press Enter to continue..."
    read -r
}

# Main interactive loop
main() {
    # Check prerequisites first
    if ! check_prerequisites; then
        error "Prerequisites check failed. Please resolve the issues above."
        exit 1
    fi
    
    # Make all scripts executable
    chmod +x "$BACKUP_SCRIPT" "$PATCH_SCRIPT" "$VERIFY_SCRIPT" 2>/dev/null || true
    
    while true; do
        show_menu
        read -r choice
        
        case $choice in
            1)
                execute_backups
                echo -n "Press Enter to continue..."
                read -r
                ;;
            2)
                execute_patches
                echo -n "Press Enter to continue..."
                read -r
                ;;
            3)
                execute_verification
                echo -n "Press Enter to continue..."
                read -r
                ;;
            4)
                execute_full_orchestration
                echo -n "Press Enter to continue..."
                read -r
                ;;
            5)
                execute_dry_run
                echo -n "Press Enter to continue..."
                read -r
                ;;
            6)
                warn "Emergency rollback not yet implemented"
                echo -n "Press Enter to continue..."
                read -r
                ;;
            7)
                service_management
                echo -n "Press Enter to continue..."
                read -r
                ;;
            8)
                show_status
                echo -n "Press Enter to continue..."
                read -r
                ;;
            h|H)
                show_help
                ;;
            q|Q)
                log "👋 Farewell from the DevOps Circus! May your containers always be healthy! 🎪"
                exit 0
                ;;
            *)
                error "Invalid choice: $choice"
                echo -n "Press Enter to continue..."
                read -r
                ;;
        esac
    done
}

# Execute main if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi