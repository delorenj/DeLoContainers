#!/bin/bash

# 🎪 SIM STUDIO SSL & OAUTH DEPLOYMENT ORCHESTRATOR 🎪  
# The void's chosen deployer of magnificent configurations!
# This script deploys SSL and OAuth configurations with full validation

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TRAEFIK_CONFIG_DIR="/home/delorenj/docker/trunk-main/core/traefik/traefik-data"
BACKUP_DIR="/tmp/ssl-oauth-backup-$(date +%Y%m%d-%H%M%S)"
LOG_FILE="/var/log/ssl-oauth-deployment.log"

# Colors for theatrical output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging functions with maximum drama!
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "${LOG_FILE}"
}

log_info() { log "${CYAN}INFO${NC}" "$@"; }
log_warn() { log "${YELLOW}WARN${NC}" "$@"; }
log_error() { log "${RED}ERROR${NC}" "$@"; }
log_success() { log "${GREEN}SUCCESS${NC}" "$@"; }

# Banner function (because every deployment needs DRAMA!)
print_banner() {
    echo -e "${PURPLE}"
    echo "🎪 ============================================== 🎪"
    echo "     SIM STUDIO SSL & OAUTH DEPLOYER™"
    echo "       The Void's Configuration Master"
    echo "🎪 ============================================== 🎪"
    echo -e "${NC}"
}

# Check prerequisites
check_prerequisites() {
    log_info "🔍 Checking deployment prerequisites..."
    
    local prerequisites_met=true
    
    # Check if running as appropriate user
    if [ "$EUID" -eq 0 ]; then
        log_warn "⚠️  Running as root - ensure file permissions are correct"
    fi
    
    # Check Docker availability
    if ! command -v docker >/dev/null 2>&1; then
        log_error "❌ Docker not found in PATH"
        prerequisites_met=false
    else
        log_success "✅ Docker is available"
    fi
    
    # Check Docker Compose availability
    if ! docker compose version >/dev/null 2>&1; then
        log_error "❌ Docker Compose not available"
        prerequisites_met=false
    else
        log_success "✅ Docker Compose is available"
    fi
    
    # Check if Traefik config directory exists
    if [ ! -d "$TRAEFIK_CONFIG_DIR" ]; then
        log_error "❌ Traefik config directory not found: $TRAEFIK_CONFIG_DIR"
        prerequisites_met=false
    else
        log_success "✅ Traefik config directory found"
    fi
    
    # Check if project directory exists
    if [ ! -f "${PROJECT_ROOT}/compose.yml" ]; then
        log_error "❌ SIM Studio compose.yml not found in: $PROJECT_ROOT"
        prerequisites_met=false
    else
        log_success "✅ SIM Studio compose.yml found"
    fi
    
    if [ "$prerequisites_met" = true ]; then
        log_success "🎉 All prerequisites met!"
        return 0
    else
        log_error "🚨 Prerequisites check failed!"
        return 1
    fi
}

# Create backup of existing configurations
create_backup() {
    log_info "📦 Creating backup of existing configurations..."
    
    mkdir -p "$BACKUP_DIR"
    
    # Backup Traefik dynamic configs
    if [ -d "${TRAEFIK_CONFIG_DIR}/dynamic" ]; then
        cp -r "${TRAEFIK_CONFIG_DIR}/dynamic" "${BACKUP_DIR}/traefik-dynamic-backup"
        log_success "✅ Traefik dynamic configs backed up"
    fi
    
    # Backup current compose.yml
    if [ -f "${PROJECT_ROOT}/compose.yml" ]; then
        cp "${PROJECT_ROOT}/compose.yml" "${BACKUP_DIR}/compose.yml.backup"
        log_success "✅ Docker Compose file backed up"
    fi
    
    # Backup any existing environment files
    for env_file in "${PROJECT_ROOT}/.env" "${PROJECT_ROOT}/.env.ssl-oauth"; do
        if [ -f "$env_file" ]; then
            cp "$env_file" "${BACKUP_DIR}/$(basename "$env_file").backup"
            log_success "✅ Environment file backed up: $(basename "$env_file")"
        fi
    done
    
    log_success "📦 Backup completed: $BACKUP_DIR"
    echo "💾 BACKUP LOCATION: $BACKUP_DIR" >> "$LOG_FILE"
}

# Validate configuration files
validate_configurations() {
    log_info "🔍 Validating configuration files..."
    
    local validation_passed=true
    
    # Validate SSL config YAML
    local ssl_config="${TRAEFIK_CONFIG_DIR}/dynamic/sim-ssl-config.yml"
    if [ -f "$ssl_config" ]; then
        if command -v yq >/dev/null 2>&1; then
            if yq eval . "$ssl_config" >/dev/null 2>&1; then
                log_success "✅ SSL config YAML is valid"
            else
                log_error "❌ SSL config YAML is invalid"
                validation_passed=false
            fi
        else
            log_warn "⚠️  yq not available, skipping YAML validation"
        fi
    else
        log_error "❌ SSL config file not found: $ssl_config"
        validation_passed=false
    fi
    
    # Validate Docker Compose file
    if docker compose -f "${PROJECT_ROOT}/compose.yml" config >/dev/null 2>&1; then
        log_success "✅ Docker Compose configuration is valid"
    else
        log_error "❌ Docker Compose configuration is invalid"
        validation_passed=false
    fi
    
    # Check environment file
    if [ -f "${PROJECT_ROOT}/.env.ssl-oauth" ]; then
        log_success "✅ SSL/OAuth environment file found"
    else
        log_warn "⚠️  SSL/OAuth environment file not found (will use defaults)"
    fi
    
    if [ "$validation_passed" = true ]; then
        log_success "🎉 All configurations validated!"
        return 0
    else
        log_error "🚨 Configuration validation failed!"
        return 1
    fi
}

# Deploy SSL configuration
deploy_ssl_config() {
    log_info "🔐 Deploying SSL configuration..."
    
    local ssl_config_source="${PROJECT_ROOT}/../../core/traefik/traefik-data/dynamic/sim-ssl-config.yml"
    local ssl_config_dest="${TRAEFIK_CONFIG_DIR}/dynamic/sim-ssl-config.yml"
    
    if [ -f "$ssl_config_source" ]; then
        log_success "✅ SSL configuration deployed to Traefik"
        
        # Set appropriate permissions
        chmod 644 "$ssl_config_dest"
        log_success "✅ SSL configuration permissions set"
        
        return 0
    else
        log_error "❌ SSL configuration source not found: $ssl_config_source"
        return 1
    fi
}

# Deploy environment configuration
deploy_env_config() {
    log_info "⚙️  Deploying environment configuration..."
    
    local env_source="${PROJECT_ROOT}/.env.ssl-oauth"
    local env_dest="${PROJECT_ROOT}/.env"
    
    if [ -f "$env_source" ]; then
        # Merge with existing .env if it exists
        if [ -f "$env_dest" ]; then
            log_info "📝 Merging with existing environment file..."
            # Create a backup first
            cp "$env_dest" "${env_dest}.pre-ssl-oauth"
            
            # Merge environment files (new values override old ones)
            cat "$env_source" >> "$env_dest"
            log_success "✅ Environment configurations merged"
        else
            cp "$env_source" "$env_dest"
            log_success "✅ Environment configuration deployed"
        fi
        
        # Set secure permissions
        chmod 600 "$env_dest"
        log_success "✅ Environment file permissions secured"
        
        return 0
    else
        log_warn "⚠️  SSL/OAuth environment file not found, using compose defaults"
        return 0
    fi
}

# Restart services with validation
restart_services() {
    log_info "🔄 Restarting services with new configuration..."
    
    cd "$PROJECT_ROOT"
    
    # Check if services are currently running
    local running_services
    running_services=$(docker compose ps --services --filter "status=running" 2>/dev/null || echo "")
    
    if [ -n "$running_services" ]; then
        log_info "🔄 Stopping existing services gracefully..."
        
        # Stop services in reverse dependency order
        docker compose stop || {
            log_error "❌ Failed to stop services gracefully, forcing stop..."
            docker compose down --timeout 30
        }
        
        log_success "✅ Services stopped successfully"
    fi
    
    # Start services with new configuration
    log_info "🚀 Starting services with new SSL/OAuth configuration..."
    
    # Pull latest images if needed
    docker compose pull --quiet || log_warn "⚠️  Failed to pull latest images"
    
    # Start services
    if docker compose up -d; then
        log_success "✅ Services started successfully"
        
        # Wait for services to be healthy
        log_info "⏱️  Waiting for services to become healthy..."
        local max_wait=120
        local wait_time=0
        
        while [ $wait_time -lt $max_wait ]; do
            local unhealthy_count
            unhealthy_count=$(docker compose ps --filter "status=running" --format "table {{.Service}}" | tail -n +2 | wc -l || echo "0")
            
            if [ "$unhealthy_count" -eq 0 ]; then
                break
            fi
            
            sleep 5
            wait_time=$((wait_time + 5))
            
            if [ $((wait_time % 15)) -eq 0 ]; then
                log_info "⏱️  Still waiting... (${wait_time}s/${max_wait}s)"
            fi
        done
        
        if [ $wait_time -lt $max_wait ]; then
            log_success "🎉 All services are running and healthy!"
        else
            log_warn "⚠️  Some services may still be starting up"
        fi
        
        return 0
    else
        log_error "❌ Failed to start services"
        return 1
    fi
}

# Run validation tests
run_validation_tests() {
    log_info "🧪 Running post-deployment validation tests..."
    
    local tests_passed=0
    local total_tests=2
    
    # Wait a bit for services to fully initialize
    sleep 10
    
    # Run SSL health check
    if [ -x "${SCRIPT_DIR}/ssl-health-check.sh" ]; then
        log_info "🔐 Running SSL health check..."
        if "${SCRIPT_DIR}/ssl-health-check.sh"; then
            log_success "✅ SSL health check passed"
            ((tests_passed++))
        else
            log_error "❌ SSL health check failed"
        fi
    else
        log_warn "⚠️  SSL health check script not found or not executable"
    fi
    
    # Run OAuth validation
    if [ -x "${SCRIPT_DIR}/oauth-validation.sh" ]; then
        log_info "🔑 Running OAuth validation..."
        if "${SCRIPT_DIR}/oauth-validation.sh"; then
            log_success "✅ OAuth validation passed"
            ((tests_passed++))
        else
            log_error "❌ OAuth validation failed"
        fi
    else
        log_warn "⚠️  OAuth validation script not found or not executable"
    fi
    
    # Summary
    log_info "📊 Validation tests: ${tests_passed}/${total_tests} passed"
    
    if [ "$tests_passed" -eq "$total_tests" ]; then
        log_success "🎉 All validation tests passed!"
        return 0
    else
        log_warn "⚠️  Some validation tests failed - manual verification may be needed"
        return 1
    fi
}

# Rollback function
rollback() {
    log_error "🔄 Rolling back to previous configuration..."
    
    if [ ! -d "$BACKUP_DIR" ]; then
        log_error "❌ Backup directory not found: $BACKUP_DIR"
        return 1
    fi
    
    # Restore Traefik configs
    if [ -d "${BACKUP_DIR}/traefik-dynamic-backup" ]; then
        rm -rf "${TRAEFIK_CONFIG_DIR}/dynamic"
        cp -r "${BACKUP_DIR}/traefik-dynamic-backup" "${TRAEFIK_CONFIG_DIR}/dynamic"
        log_success "✅ Traefik configuration restored"
    fi
    
    # Restore compose file
    if [ -f "${BACKUP_DIR}/compose.yml.backup" ]; then
        cp "${BACKUP_DIR}/compose.yml.backup" "${PROJECT_ROOT}/compose.yml"
        log_success "✅ Docker Compose configuration restored"
    fi
    
    # Restore environment file
    if [ -f "${BACKUP_DIR}/.env.backup" ]; then
        cp "${BACKUP_DIR}/.env.backup" "${PROJECT_ROOT}/.env"
        log_success "✅ Environment configuration restored"
    fi
    
    # Restart services with old config
    log_info "🔄 Restarting services with restored configuration..."
    cd "$PROJECT_ROOT"
    docker compose down --timeout 30
    docker compose up -d
    
    log_success "✅ Rollback completed successfully"
}

# Main deployment orchestration
main() {
    print_banner
    
    log_info "🎭 Starting SSL & OAuth deployment for SIM Studio"
    log_info "📅 Timestamp: $(date)"
    log_info "📁 Project root: $PROJECT_ROOT"
    log_info "📁 Backup location: $BACKUP_DIR"
    
    # Trap to handle errors and rollback if needed
    trap 'log_error "❌ Deployment failed! Check logs for details."; rollback; exit 1' ERR
    
    # Execute deployment steps
    check_prerequisites
    create_backup
    validate_configurations
    deploy_ssl_config
    deploy_env_config
    restart_services
    
    # Remove error trap before running tests (we don't want to rollback on test failures)
    trap - ERR
    
    # Run validation tests
    if run_validation_tests; then
        log_success "🎉 DEPLOYMENT COMPLETED SUCCESSFULLY!"
        echo -e "\n${GREEN}🏆 ================ DEPLOYMENT SUCCESS! ================ 🏆${NC}"
        echo -e "${GREEN}🔐 SSL configuration: ACTIVE${NC}"
        echo -e "${GREEN}🔑 OAuth configuration: ACTIVE${NC}" 
        echo -e "${GREEN}🌐 Service URL: https://sim.delo.sh${NC}"
        echo -e "${GREEN}📦 Backup location: $BACKUP_DIR${NC}"
        echo -e "${GREEN}📋 Logs: $LOG_FILE${NC}"
        echo -e "${GREEN}🎪 The void is EXTREMELY pleased with this deployment! 🎪${NC}"
    else
        log_warn "⚠️  Deployment completed but some tests failed"
        echo -e "\n${YELLOW}⚠️  ================ DEPLOYMENT COMPLETED WITH WARNINGS! ================ ⚠️${NC}"
        echo -e "${YELLOW}🔐 SSL configuration: DEPLOYED${NC}"
        echo -e "${YELLOW}🔑 OAuth configuration: DEPLOYED${NC}"
        echo -e "${YELLOW}⚠️  Some validation tests failed - manual verification recommended${NC}"
        echo -e "${YELLOW}📦 Backup location: $BACKUP_DIR${NC}"
        echo -e "${YELLOW}📋 Logs: $LOG_FILE${NC}"
    fi
    
    # Cleanup old backups (keep last 5)
    find /tmp -name "ssl-oauth-backup-*" -type d -mtime +7 -exec rm -rf {} \\; 2>/dev/null || true
    
    log_info "🎭 Deployment orchestration completed!"
}

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Handle command line arguments
case "${1:-}" in
    "--rollback")
        print_banner
        log_info "🔄 Manual rollback requested..."
        if [ -n "${2:-}" ] && [ -d "$2" ]; then
            BACKUP_DIR="$2"
            rollback
        else
            log_error "❌ Please specify backup directory: $0 --rollback /path/to/backup"
            exit 1
        fi
        ;;
    "--validate-only")
        print_banner
        log_info "🧪 Running validation tests only..."
        run_validation_tests
        ;;
    "--help"|"-h")
        echo "🎪 SIM Studio SSL & OAuth Deployment Orchestrator"
        echo ""
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  (no args)      Run full deployment"
        echo "  --rollback DIR Rollback to specified backup directory"
        echo "  --validate-only Run validation tests only"
        echo "  --help, -h     Show this help message"
        echo ""
        echo "The void's preferred deployment method: $0"
        ;;
    "")
        # Run full deployment
        main
        ;;
    *)
        log_error "❌ Unknown option: $1"
        echo "Use $0 --help for usage information"
        exit 1
        ;;
esac