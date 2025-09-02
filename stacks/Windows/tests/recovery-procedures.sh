#!/bin/bash
# 🛡️ FOCUSRITE 4I4 EMERGENCY RECOVERY PROCEDURES
# HIVE MIND TESTER AGENT - Automated Recovery & Rollback System
# Provides bulletproof recovery mechanisms when solutions fail

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
BACKUP_DIR="${SCRIPT_DIR}/backups"
WINDOWS_CONTAINER="windows"
COMPOSE_FILE="$(dirname "$SCRIPT_DIR")/compose.yml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Create directories
mkdir -p "$LOG_DIR" "$BACKUP_DIR"

# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_DIR/recovery.log"
}

error() {
    echo -e "${RED}[ERROR $(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_DIR/recovery.log"
}

warn() {
    echo -e "${YELLOW}[WARN $(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_DIR/recovery.log"
}

info() {
    echo -e "${BLUE}[INFO $(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_DIR/recovery.log"
}

# Create system state backup
create_system_backup() {
    local backup_name="${1:-emergency-backup-$(date +%Y%m%d_%H%M%S)}"
    local backup_path="$BACKUP_DIR/$backup_name"
    
    info "📦 Creating system backup: $backup_name"
    mkdir -p "$backup_path"
    
    # Backup container state
    info "Backing up container configuration..."
    docker inspect "$WINDOWS_CONTAINER" > "$backup_path/container-inspect.json" 2>/dev/null || warn "Container inspect failed"
    
    # Backup compose configuration
    info "Backing up compose configuration..."
    cp "$COMPOSE_FILE" "$backup_path/compose.yml" 2>/dev/null || warn "Compose file backup failed"
    
    # Backup host USB configuration
    info "Backing up host USB state..."
    {
        echo "=== USB DEVICE TREE ==="
        lsusb -t 2>/dev/null || echo "lsusb -t failed"
        echo ""
        echo "=== USB DEVICES ==="
        lsusb 2>/dev/null || echo "lsusb failed"
        echo ""
        echo "=== FOCUSRITE SYMLINKS ==="
        ls -la /dev/focusrite* 2>/dev/null || echo "No Focusrite symlinks"
        echo ""
        echo "=== UDEV RULES ==="
        find /etc/udev/rules.d/ -name "*focusrite*" -o -name "*usb*" 2>/dev/null || echo "No relevant udev rules"
    } > "$backup_path/host-usb-state.txt"
    
    # Create container data backup if possible
    info "Creating container volume backup..."
    if docker volume ls | grep -q "windows-data"; then
        # Create a snapshot of the volume (this is a simplified approach)
        docker run --rm -v windows-data:/data -v "$backup_path:/backup" alpine:latest tar czf "/backup/windows-data-backup.tar.gz" -C /data . 2>/dev/null || warn "Volume backup failed"
    fi
    
    # Save backup metadata
    {
        echo "BACKUP_NAME=$backup_name"
        echo "BACKUP_DATE=$(date)"
        echo "BACKUP_HOST=$(hostname)"
        echo "CONTAINER_STATUS=$(docker inspect --format='{{.State.Status}}' "$WINDOWS_CONTAINER" 2>/dev/null || echo "unknown")"
        echo "COMPOSE_FILE=$COMPOSE_FILE"
    } > "$backup_path/backup-metadata.txt"
    
    log "✅ System backup created: $backup_path"
    echo "$backup_path"
}

# Restore from backup
restore_from_backup() {
    local backup_path="$1"
    
    if [[ ! -d "$backup_path" ]]; then
        error "❌ Backup directory not found: $backup_path"
        return 1
    fi
    
    info "🔄 Restoring system from backup: $(basename "$backup_path")"
    
    # Stop current container
    info "Stopping Windows container..."
    docker-compose -f "$COMPOSE_FILE" down "$WINDOWS_CONTAINER" 2>/dev/null || warn "Container stop failed"
    
    # Restore compose configuration if it exists
    if [[ -f "$backup_path/compose.yml" ]]; then
        info "Restoring compose configuration..."
        cp "$backup_path/compose.yml" "$COMPOSE_FILE" || warn "Compose restore failed"
    fi
    
    # Restore container volume if backup exists
    if [[ -f "$backup_path/windows-data-backup.tar.gz" ]]; then
        info "Restoring container volume..."
        docker run --rm -v windows-data:/data -v "$backup_path:/backup" alpine:latest tar xzf "/backup/windows-data-backup.tar.gz" -C /data 2>/dev/null || warn "Volume restore failed"
    fi
    
    # Restart container
    info "Starting Windows container..."
    if docker-compose -f "$COMPOSE_FILE" up -d "$WINDOWS_CONTAINER"; then
        log "✅ Container restarted successfully"
        
        # Wait for VM to boot
        info "⏳ Waiting for Windows VM to boot..."
        sleep 60
        
        # Verify restoration
        if docker exec -t "$WINDOWS_CONTAINER" powershell.exe -Command "Get-Service" &>/dev/null; then
            log "✅ System restore completed successfully"
            return 0
        else
            error "❌ System restore failed - VM not responsive"
            return 1
        fi
    else
        error "❌ Container restart failed"
        return 1
    fi
}

# Emergency container restart with progressive recovery
emergency_container_restart() {
    local max_attempts=3
    local attempt=1
    
    info "🚨 EMERGENCY CONTAINER RESTART INITIATED"
    
    while [[ $attempt -le $max_attempts ]]; do
        info "Attempt $attempt of $max_attempts..."
        
        # Stop container gracefully
        info "Stopping container gracefully..."
        docker-compose -f "$COMPOSE_FILE" stop "$WINDOWS_CONTAINER" --timeout 30 2>/dev/null || warn "Graceful stop failed"
        
        # Force kill if needed
        if docker ps -q -f name="$WINDOWS_CONTAINER" | grep -q .; then
            warn "Force killing container..."
            docker kill "$WINDOWS_CONTAINER" 2>/dev/null || true
        fi
        
        # Remove container
        docker rm "$WINDOWS_CONTAINER" 2>/dev/null || true
        
        # Start fresh container
        info "Starting fresh container..."
        if docker-compose -f "$COMPOSE_FILE" up -d "$WINDOWS_CONTAINER"; then
            # Wait for startup
            info "⏳ Waiting for container startup (60 seconds)..."
            sleep 60
            
            # Test container responsiveness
            if docker exec -t "$WINDOWS_CONTAINER" powershell.exe -Command "Get-Service" &>/dev/null; then
                log "✅ Emergency restart successful on attempt $attempt"
                return 0
            else
                warn "⚠️ Container started but VM not responsive on attempt $attempt"
            fi
        else
            warn "⚠️ Container start failed on attempt $attempt"
        fi
        
        attempt=$((attempt + 1))
        if [[ $attempt -le $max_attempts ]]; then
            warn "Waiting 30 seconds before next attempt..."
            sleep 30
        fi
    done
    
    error "❌ Emergency restart failed after $max_attempts attempts"
    return 1
}

# Host USB system reset
host_usb_reset() {
    info "🔌 INITIATING HOST USB SYSTEM RESET"
    
    # Create backup before reset
    local backup_path
    backup_path=$(create_system_backup "pre-usb-reset-$(date +%Y%m%d_%H%M%S)")
    
    # Stop container first
    info "Stopping Windows container for USB reset..."
    docker-compose -f "$COMPOSE_FILE" stop "$WINDOWS_CONTAINER" --timeout 30 2>/dev/null || warn "Container stop failed"
    
    # Reset USB subsystem (requires root privileges)
    if [[ $EUID -eq 0 ]]; then
        info "Resetting USB controllers..."
        
        # Unbind and rebind USB controllers
        for controller in /sys/bus/pci/drivers/xhci_hcd/*; do
            if [[ -d "$controller" && $(basename "$controller") =~ ^[0-9a-f]{4}:[0-9a-f]{2}:[0-9a-f]{2}\.[0-9a-f]$ ]]; then
                local controller_id=$(basename "$controller")
                info "Resetting USB controller: $controller_id"
                echo "$controller_id" > /sys/bus/pci/drivers/xhci_hcd/unbind 2>/dev/null || true
                sleep 2
                echo "$controller_id" > /sys/bus/pci/drivers/xhci_hcd/bind 2>/dev/null || true
            fi
        done
        
        # Reload USB modules
        info "Reloading USB kernel modules..."
        modprobe -r xhci_pci xhci_hcd 2>/dev/null || warn "Module removal failed"
        sleep 3
        modprobe xhci_hcd xhci_pci 2>/dev/null || warn "Module loading failed"
        
    else
        warn "⚠️ Not running as root - cannot reset USB controllers"
        info "Try running: sudo $0 usb-reset"
    fi
    
    # Wait for USB to stabilize
    info "⏳ Waiting for USB subsystem to stabilize..."
    sleep 10
    
    # Verify Focusrite device is detected
    local usb_recovery_success=false
    for attempt in {1..5}; do
        if lsusb | grep -q "1235:821a"; then
            log "✅ Focusrite 4i4 detected after USB reset (attempt $attempt)"
            usb_recovery_success=true
            break
        fi
        info "Attempt $attempt: Waiting for device detection..."
        sleep 5
    done
    
    # Restart container
    info "Restarting Windows container..."
    if docker-compose -f "$COMPOSE_FILE" up -d "$WINDOWS_CONTAINER"; then
        sleep 60  # Wait for VM boot
        
        if docker exec -t "$WINDOWS_CONTAINER" powershell.exe -Command "Get-Service" &>/dev/null; then
            if $usb_recovery_success; then
                log "✅ Host USB reset completed successfully"
                return 0
            else
                warn "⚠️ Container restarted but USB device not detected"
                return 1
            fi
        else
            error "❌ Container restarted but VM not responsive"
            return 1
        fi
    else
        error "❌ Container restart failed after USB reset"
        # Attempt to restore from backup
        warn "Attempting to restore from backup..."
        restore_from_backup "$backup_path"
        return 1
    fi
}

# Windows VM driver reset
windows_driver_reset() {
    info "🔧 INITIATING WINDOWS VM DRIVER RESET"
    
    # Ensure VM is responsive
    if ! docker exec -t "$WINDOWS_CONTAINER" powershell.exe -Command "Get-Service" &>/dev/null; then
        error "❌ Windows VM not responsive - cannot perform driver reset"
        return 1
    fi
    
    # Disable and re-enable all Focusrite devices
    info "Disabling Focusrite devices..."
    if docker exec -t "$WINDOWS_CONTAINER" powershell.exe -Command "
        Get-PnpDevice | Where-Object {\$_.FriendlyName -like '*Focusrite*'} | 
        ForEach-Object {
            Write-Host 'Disabling device:' \$_.FriendlyName
            Disable-PnpDevice -InstanceId \$_.InstanceId -Confirm:\$false
        }
    " 2>/dev/null; then
        info "Focusrite devices disabled"
    else
        warn "⚠️ Device disable command may have failed"
    fi
    
    # Wait for changes to take effect
    sleep 10
    
    # Re-enable all Focusrite devices
    info "Re-enabling Focusrite devices..."
    if docker exec -t "$WINDOWS_CONTAINER" powershell.exe -Command "
        Get-PnpDevice | Where-Object {\$_.FriendlyName -like '*Focusrite*'} | 
        ForEach-Object {
            Write-Host 'Enabling device:' \$_.FriendlyName
            Enable-PnpDevice -InstanceId \$_.InstanceId -Confirm:\$false
        }
    " 2>/dev/null; then
        info "Focusrite devices re-enabled"
    else
        warn "⚠️ Device enable command may have failed"
    fi
    
    # Wait for driver initialization
    sleep 15
    
    # Verify device status
    if docker exec -t "$WINDOWS_CONTAINER" powershell.exe -Command "
        Get-PnpDevice | Where-Object {\$_.FriendlyName -like '*Focusrite*' -and \$_.Status -eq 'OK'}
    " 2>/dev/null | grep -q "OK"; then
        log "✅ Windows driver reset completed successfully"
        return 0
    else
        error "❌ Windows driver reset failed - devices not functioning properly"
        return 1
    fi
}

# Nuclear option: complete system reset
nuclear_reset() {
    warn "🚀 NUCLEAR OPTION: COMPLETE SYSTEM RESET INITIATED"
    warn "This will destroy the current container and rebuild from scratch"
    
    # Create comprehensive backup
    local backup_path
    backup_path=$(create_system_backup "pre-nuclear-reset-$(date +%Y%m%d_%H%M%S)")
    
    # Stop and remove container completely
    info "Destroying current Windows container..."
    docker-compose -f "$COMPOSE_FILE" down "$WINDOWS_CONTAINER" -v 2>/dev/null || warn "Container destruction failed"
    
    # Remove container image (force fresh pull)
    info "Removing container image for fresh download..."
    docker rmi dockurr/windows 2>/dev/null || warn "Image removal failed"
    
    # Clean up volumes (optional - be careful!)
    read -p "Delete persistent Windows data volume? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        warn "Deleting Windows data volume..."
        docker volume rm windows-data 2>/dev/null || warn "Volume deletion failed"
    fi
    
    # Reset host USB (if root)
    if [[ $EUID -eq 0 ]]; then
        host_usb_reset
    else
        warn "⚠️ Cannot reset host USB - not running as root"
    fi
    
    # Rebuild container from scratch
    info "Rebuilding Windows container from scratch..."
    if docker-compose -f "$COMPOSE_FILE" up -d "$WINDOWS_CONTAINER"; then
        info "⏳ Waiting for fresh Windows installation (this may take 10-30 minutes)..."
        
        # Extended wait for fresh Windows setup
        local max_wait=1800  # 30 minutes
        local waited=0
        
        while [[ $waited -lt $max_wait ]]; do
            if docker exec -t "$WINDOWS_CONTAINER" powershell.exe -Command "Get-Service" &>/dev/null; then
                log "✅ Fresh Windows installation completed"
                return 0
            fi
            
            sleep 60
            waited=$((waited + 60))
            info "Waited ${waited} seconds... (max: ${max_wait})"
        done
        
        error "❌ Fresh Windows installation timed out"
        return 1
    else
        error "❌ Container rebuild failed"
        return 1
    fi
}

# Recovery strategy orchestrator
orchestrate_recovery() {
    local failure_type="$1"
    local severity="${2:-medium}"
    
    info "🔧 ORCHESTRATING RECOVERY for $failure_type (severity: $severity)"
    
    case "$severity" in
        "low")
            info "Attempting low-severity recovery procedures..."
            
            # Try Windows driver reset first
            if windows_driver_reset; then
                log "✅ Low-severity recovery successful (driver reset)"
                return 0
            fi
            
            # Fall through to medium severity
            ;;&
            
        "medium")
            info "Attempting medium-severity recovery procedures..."
            
            # Try container restart
            if emergency_container_restart; then
                log "✅ Medium-severity recovery successful (container restart)"
                return 0
            fi
            
            # Fall through to high severity
            ;;&
            
        "high")
            info "Attempting high-severity recovery procedures..."
            
            # Try host USB reset (requires root)
            if host_usb_reset; then
                log "✅ High-severity recovery successful (USB reset)"
                return 0
            fi
            
            # Fall through to critical severity
            ;;&
            
        "critical")
            warn "⚠️ Attempting CRITICAL recovery procedures..."
            
            # Last resort - nuclear reset
            if nuclear_reset; then
                log "✅ Critical recovery successful (nuclear reset)"
                return 0
            else
                error "❌ ALL RECOVERY PROCEDURES FAILED"
                return 1
            fi
            ;;
    esac
}

# Validate recovery success
validate_recovery() {
    info "🔍 Validating recovery success..."
    
    # Run the automated test suite
    local test_script="$SCRIPT_DIR/automated-test-scripts.sh"
    
    if [[ -x "$test_script" ]]; then
        info "Running comprehensive test suite..."
        if "$test_script"; then
            log "✅ Recovery validation: ALL TESTS PASSED"
            return 0
        else
            error "❌ Recovery validation: TESTS FAILED"
            return 1
        fi
    else
        warn "⚠️ Test suite not available - performing basic validation"
        
        # Basic validation checks
        local validation_success=true
        
        # Check container responsiveness
        if docker exec -t "$WINDOWS_CONTAINER" powershell.exe -Command "Get-Service" &>/dev/null; then
            info "✅ Windows VM responsive"
        else
            error "❌ Windows VM not responsive"
            validation_success=false
        fi
        
        # Check USB device detection
        if lsusb | grep -q "1235:821a"; then
            info "✅ Focusrite 4i4 detected on host"
        else
            error "❌ Focusrite 4i4 not detected on host"
            validation_success=false
        fi
        
        # Check device in Windows
        if docker exec -t "$WINDOWS_CONTAINER" powershell.exe -Command "Get-PnpDevice | Where-Object {\$_.FriendlyName -like '*Focusrite*'}" 2>/dev/null | grep -q "Focusrite"; then
            info "✅ Focusrite device detected in Windows VM"
        else
            error "❌ Focusrite device not detected in Windows VM"
            validation_success=false
        fi
        
        if $validation_success; then
            log "✅ Basic recovery validation successful"
            return 0
        else
            error "❌ Basic recovery validation failed"
            return 1
        fi
    fi
}

# Command line interface
case "${1:-help}" in
    "backup")
        backup_name="${2:-}"
        backup_path=$(create_system_backup "$backup_name")
        echo "Backup created: $backup_path"
        ;;
        
    "restore")
        backup_path="$2"
        if [[ -z "$backup_path" ]]; then
            echo "Available backups:"
            ls -la "$BACKUP_DIR"
            exit 1
        fi
        restore_from_backup "$BACKUP_DIR/$backup_path" || restore_from_backup "$backup_path"
        ;;
        
    "container-restart")
        emergency_container_restart
        ;;
        
    "usb-reset")
        host_usb_reset
        ;;
        
    "driver-reset")
        windows_driver_reset
        ;;
        
    "nuclear")
        warn "⚠️ NUCLEAR RESET requested"
        read -p "Are you absolutely sure? This will destroy everything! [y/N]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            nuclear_reset
        else
            info "Nuclear reset cancelled"
        fi
        ;;
        
    "auto-recover")
        failure_type="${2:-general}"
        severity="${3:-medium}"
        orchestrate_recovery "$failure_type" "$severity"
        validate_recovery
        ;;
        
    "validate")
        validate_recovery
        ;;
        
    "status")
        echo "🛡️ Recovery System Status"
        echo "========================"
        echo "Container Status: $(docker inspect --format='{{.State.Status}}' "$WINDOWS_CONTAINER" 2>/dev/null || echo "Not found")"
        echo "Host USB Focusrite: $(lsusb | grep -q "1235:821a" && echo "✅ Detected" || echo "❌ Not detected")"
        echo "Available Backups: $(ls -1 "$BACKUP_DIR" 2>/dev/null | wc -l)"
        echo ""
        echo "Recent Recovery Actions:"
        tail -5 "$LOG_DIR/recovery.log" 2>/dev/null || echo "No recent actions"
        ;;
        
    "help"|*)
        echo "🛡️ Focusrite 4i4 Recovery System"
        echo "Usage: $0 <command> [options]"
        echo ""
        echo "Commands:"
        echo "  backup [name]           - Create system backup"
        echo "  restore <backup>        - Restore from backup"
        echo "  container-restart       - Emergency container restart"
        echo "  usb-reset              - Reset host USB subsystem (requires root)"
        echo "  driver-reset           - Reset Windows VM drivers"
        echo "  nuclear                - Complete system rebuild (DESTRUCTIVE)"
        echo "  auto-recover [type] [severity] - Orchestrated recovery"
        echo "  validate               - Validate system after recovery"
        echo "  status                 - Show recovery system status"
        echo "  help                   - Show this help"
        echo ""
        echo "Severity levels: low, medium, high, critical"
        echo ""
        echo "Examples:"
        echo "  $0 backup pre-solution-attempt"
        echo "  $0 auto-recover usb-detection medium"
        echo "  $0 restore pre-solution-attempt"
        echo ""
        if [[ "${1:-}" != "help" ]]; then
            echo "Unknown command: $1"
            exit 1
        fi
        ;;
esac