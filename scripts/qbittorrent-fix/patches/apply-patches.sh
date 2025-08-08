#!/bin/bash

# qBittorrent Infrastructure Fix - Patch Application Script
# Created by the Sed Command Spectacular Division
# "In sed we trust, in backups we verify!" - The DevOps Manifesto

set -euo pipefail

# Color codes for theatrical sed operations
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration variables
STACK_DIR="/home/delorenj/docker/trunk-main/stacks/media"
COMPOSE_FILE="${STACK_DIR}/compose.yml"
QBIT_CONF="${STACK_DIR}/qbittorrent/qBittorrent.conf"
PATCH_DIR="/home/delorenj/docker/trunk-main/scripts/qbittorrent-fix/patches"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Logging functions with maximum drama
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

# Function to create a pre-patch backup
create_pre_patch_backup() {
    local file="$1"
    local backup_file="${file}.pre-patch-${TIMESTAMP}"
    
    log "Creating pre-patch backup: $(basename "$file")"
    cp "$file" "$backup_file" || {
        error "Failed to create pre-patch backup for $file"
        return 1
    }
    success "Pre-patch backup created: $backup_file"
}

# Function to apply sed patch with validation
apply_sed_patch() {
    local file="$1"
    local sed_command="$2"
    local description="$3"
    local dry_run="${4:-false}"
    
    log "Applying patch: $description"
    info "File: $file"
    info "Command: $sed_command"
    
    if [[ ! -f "$file" ]]; then
        error "Target file does not exist: $file"
        return 1
    fi
    
    # Create temporary file for testing
    local temp_file="/tmp/sed_test_${TIMESTAMP}_$(basename "$file")"
    cp "$file" "$temp_file"
    
    # Test the sed command
    if eval "sed -i '$sed_command' '$temp_file'" 2>/dev/null; then
        log "Sed command validation successful"
        
        # Show what would change (first 5 differences)
        log "Preview of changes:"
        diff -u "$file" "$temp_file" | head -20 || true
        
        if [[ "$dry_run" == "true" ]]; then
            info "DRY RUN: Would apply patch to $file"
            rm -f "$temp_file"
            return 0
        fi
        
        # Apply the actual patch
        create_pre_patch_backup "$file" || return 1
        
        eval "sed -i '$sed_command' '$file'" || {
            error "Failed to apply sed patch to $file"
            rm -f "$temp_file"
            return 1
        }
        
        success "Patch applied successfully: $description"
        rm -f "$temp_file"
        return 0
    else
        error "Sed command validation failed for: $sed_command"
        rm -f "$temp_file"
        return 1
    fi
}

# Function to update PUID from 502 to 911
patch_puid_update() {
    local dry_run="${1:-false}"
    
    log "🎯 PATCH 1: PUID Update (502 → 911)"
    
    # Check if PUID=502 exists in the compose file
    if grep -q "PUID=502" "$COMPOSE_FILE"; then
        apply_sed_patch "$COMPOSE_FILE" "s/PUID=502/PUID=911/g" "Update PUID from 502 to 911" "$dry_run"
    else
        warn "PUID=502 not found in $COMPOSE_FILE. Current PUID settings:"
        grep -n "PUID" "$COMPOSE_FILE" || info "No PUID settings found"
        return 1
    fi
}

# Function to add DNS server to gluetun
patch_dns_server_addition() {
    local dry_run="${1:-false}"
    
    log "🌐 PATCH 2: DNS Server Addition to Gluetun"
    
    # Check if gluetun service exists
    if ! grep -q "gluetun:" "$COMPOSE_FILE"; then
        error "Gluetun service not found in $COMPOSE_FILE"
        return 1
    fi
    
    # Check if DNS is already configured
    if grep -A 20 "gluetun:" "$COMPOSE_FILE" | grep -q "DNS="; then
        warn "DNS configuration already exists for gluetun:"
        grep -A 20 "gluetun:" "$COMPOSE_FILE" | grep "DNS="
        return 1
    fi
    
    # Add DNS server after VPN_SERVICE_PROVIDER line in gluetun service
    local sed_cmd="/gluetun:/,/^[[:space:]]*[a-zA-Z]/ { /VPN_SERVICE_PROVIDER/ a\\
      - DNS=1.1.1.1
    }"
    
    apply_sed_patch "$COMPOSE_FILE" "$sed_cmd" "Add DNS=1.1.1.1 to gluetun service" "$dry_run"
}

# Function to reset web authentication in qBittorrent.conf
patch_web_auth_reset() {
    local dry_run="${1:-false}"
    
    log "🔐 PATCH 3: Web Authentication Reset"
    
    if [[ ! -f "$QBIT_CONF" ]]; then
        error "qBittorrent.conf not found: $QBIT_CONF"
        return 1
    fi
    
    # Show current authentication settings
    info "Current web authentication settings:"
    grep -E "(WebUI\\\\|WebUI/)" "$QBIT_CONF" | grep -i auth || info "No auth settings found"
    
    # Reset authentication (disable password requirement)
    local auth_patches=(
        "s/^WebUI\\\\AuthSubnetWhitelistEnabled=.*/WebUI\\\\AuthSubnetWhitelistEnabled=true/"
        "s/^WebUI\\\\AuthSubnetWhitelist=.*/WebUI\\\\AuthSubnetWhitelist=0.0.0.0\\/0/"
        "s/^WebUI\\\\BypassLocalAuth=.*/WebUI\\\\BypassLocalAuth=true/"
        "s/^WebUI\\\\BypassAuthSubnetWhitelist=.*/WebUI\\\\BypassAuthSubnetWhitelist=true/"
    )
    
    for patch in "${auth_patches[@]}"; do
        local setting_name=$(echo "$patch" | sed 's/.*WebUI\\\\\\([^=]*\\).*/\\1/')
        
        if grep -q "WebUI\\\\$setting_name=" "$QBIT_CONF"; then
            apply_sed_patch "$QBIT_CONF" "$patch" "Reset WebUI $setting_name" "$dry_run"
        else
            if [[ "$dry_run" == "false" ]]; then
                log "Adding new setting: WebUI\\$setting_name"
                echo "WebUI\\$setting_name=true" >> "$QBIT_CONF"
            fi
        fi
    done
}

# Function to show patch summary
show_patch_summary() {
    log "📋 PATCH SUMMARY"
    echo "================"
    echo "1. PUID Update: 502 → 911 (fixes permission issues)"
    echo "2. DNS Addition: Add 1.1.1.1 to gluetun (improves connectivity)"
    echo "3. Web Auth Reset: Disable password requirement (fixes access)"
    echo ""
    echo "Files to be modified:"
    echo "- $COMPOSE_FILE"
    echo "- $QBIT_CONF"
    echo ""
}

# Main patch orchestration function
main() {
    local dry_run="${1:-false}"
    local interactive="${2:-true}"
    
    log "🎪 INITIATING THE SED COMMAND SPECTACULAR! 🎪"
    
    if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        echo "Usage: $0 [--dry-run] [--non-interactive]"
        echo ""
        echo "Options:"
        echo "  --dry-run          Show what would be changed without applying"
        echo "  --non-interactive  Apply all patches without prompts"
        echo "  --help, -h         Show this help message"
        echo ""
        show_patch_summary
        return 0
    fi
    
    if [[ "$1" == "--dry-run" ]]; then
        dry_run="true"
        log "🧪 DRY RUN MODE: Showing what would be changed"
    fi
    
    if [[ "$2" == "--non-interactive" ]] || [[ "$1" == "--non-interactive" ]]; then
        interactive="false"
    fi
    
    show_patch_summary
    
    if [[ "$interactive" == "true" ]] && [[ "$dry_run" == "false" ]]; then
        echo -n "Proceed with applying patches? (y/N): "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log "Patch application cancelled by user"
            return 0
        fi
    fi
    
    local success_count=0
    local total_patches=3
    
    # Apply patches with error handling
    log "🚀 Beginning patch application sequence..."
    
    # Patch 1: PUID Update
    if patch_puid_update "$dry_run"; then
        ((success_count++))
    else
        error "Failed to apply PUID update patch"
    fi
    
    # Patch 2: DNS Server Addition
    if patch_dns_server_addition "$dry_run"; then
        ((success_count++))
    else
        error "Failed to apply DNS server addition patch"
    fi
    
    # Patch 3: Web Authentication Reset
    if patch_web_auth_reset "$dry_run"; then
        ((success_count++))
    else
        error "Failed to apply web authentication reset patch"
    fi
    
    # Final results with theatrical flair
    log "🎭 PATCH APPLICATION COMPLETE! 🎭"
    success "Successfully applied: $success_count/$total_patches patches"
    
    if [[ $success_count -eq $total_patches ]]; then
        success "ALL PATCHES APPLIED SUCCESSFULLY! The infrastructure gods smile upon us! ✨"
        if [[ "$dry_run" == "false" ]]; then
            log "Pre-patch backups created with timestamp: $TIMESTAMP"
            log "Ready for service restart and verification!"
        fi
        return 0
    else
        error "Some patches failed to apply. Please review the output above."
        return 1
    fi
}

# Execute the main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi