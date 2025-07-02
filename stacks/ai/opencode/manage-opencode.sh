#!/bin/bash

# OpenCode Management Script
# Provides utilities for managing OpenCode authentication and deployment

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
TRAEFIK_CONFIG="$DOCKER_ROOT/core/traefik/traefik-data/dynamic/opencode.yml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

generate_api_key() {
    log_info "Generating new API key..."
    
    # Generate new API key
    NEW_API_KEY=$(openssl rand -hex 32)
    
    # Generate hash for Traefik
    HASHED_KEY=$(htpasswd -nbB api "$NEW_API_KEY" | sed 's/:/: /' | sed 's/\$/\$\$/g')
    
    # Update .env file
    if [ -f "$SCRIPT_DIR/.env" ]; then
        sed -i "s/^OPENCODE_API_KEY=.*/OPENCODE_API_KEY=$NEW_API_KEY/" "$SCRIPT_DIR/.env"
        sed -i "s/^OPENCODE_HASHED_KEY=.*/OPENCODE_HASHED_KEY=$HASHED_KEY/" "$SCRIPT_DIR/.env"
    else
        log_error ".env file not found at $SCRIPT_DIR/.env"
        return 1
    fi
    
    # Update main .env file
    if [ -f "$DOCKER_ROOT/.env" ]; then
        if grep -q "^OPENCODE_API_KEY=" "$DOCKER_ROOT/.env"; then
            sed -i "s/^OPENCODE_API_KEY=.*/OPENCODE_API_KEY=$NEW_API_KEY/" "$DOCKER_ROOT/.env"
        else
            echo "OPENCODE_API_KEY=$NEW_API_KEY" >> "$DOCKER_ROOT/.env"
        fi
    fi
    
    # Update Traefik configuration
    if [ -f "$TRAEFIK_CONFIG" ]; then
        # Extract just the hash part for the YAML file
        YAML_HASH=$(echo "$HASHED_KEY" | cut -d' ' -f2-)
        sed -i "s/- \"api:\\\$\\\$.*\"/- \"api:$YAML_HASH\"/" "$TRAEFIK_CONFIG"
        log_info "Updated Traefik configuration"
    else
        log_error "Traefik config not found at $TRAEFIK_CONFIG"
        return 1
    fi
    
    log_info "New API key generated: $NEW_API_KEY"
    log_info "Hash for Traefik: $HASHED_KEY"
    log_warn "Remember to restart Traefik to apply the new configuration"
    
    # Export for current session
    export OPENCODE_API_KEY="$NEW_API_KEY"
    log_info "API key exported to current session"
}

test_auth() {
    log_info "Testing OpenCode authentication..."
    
    # Load API key from .env
    if [ -f "$SCRIPT_DIR/.env" ]; then
        source "$SCRIPT_DIR/.env"
    fi
    
    if [ -z "$OPENCODE_API_KEY" ]; then
        log_error "OPENCODE_API_KEY not found in .env file"
        return 1
    fi
    
    # Test without API key (should fail)
    log_info "Testing without API key (should fail)..."
    RESPONSE=$(curl -s -w "%{http_code}" -X POST https://opencode.delo.sh/session_create \
        -H "Content-Type: application/json" \
        -d '{}' -o /dev/null)
    
    if [ "$RESPONSE" = "401" ]; then
        log_info "✓ Unauthorized access correctly blocked"
    else
        log_warn "⚠ Expected 401, got $RESPONSE"
    fi
    
    # Test with correct API key (should succeed)
    log_info "Testing with correct API key (should succeed)..."
    RESPONSE=$(curl -s -w "%{http_code}" -u "api:$OPENCODE_API_KEY" -X POST https://opencode.delo.sh/session_create \
        -H "Content-Type: application/json" \
        -d '{}' -o /tmp/opencode_test.json)
    
    if [ "$RESPONSE" = "200" ]; then
        log_info "✓ Authenticated access successful"
        SESSION_ID=$(jq -r '.id // empty' /tmp/opencode_test.json 2>/dev/null)
        if [ -n "$SESSION_ID" ]; then
            log_info "✓ Session created: $SESSION_ID"
        fi
    else
        log_error "✗ Authentication failed, got $RESPONSE"
        if [ -f /tmp/opencode_test.json ]; then
            cat /tmp/opencode_test.json
        fi
        return 1
    fi
    
    # Test local access (should work without auth)
    log_info "Testing local access (should work without auth)..."
    RESPONSE=$(curl -s -w "%{http_code}" -X POST http://localhost:4096/session_create \
        -H "Content-Type: application/json" \
        -d '{}' -o /dev/null 2>/dev/null)
    
    if [ "$RESPONSE" = "200" ]; then
        log_info "✓ Local access working"
    else
        log_warn "⚠ Local access failed (service may not be running)"
    fi
    
    # Clean up
    rm -f /tmp/opencode_test.json
}

show_status() {
    log_info "OpenCode Status:"
    echo
    
    # Check if service is running
    if docker ps | grep -q "opencode"; then
        log_info "✓ OpenCode container is running"
    else
        log_warn "⚠ OpenCode container is not running"
    fi
    
    # Check API key
    if [ -f "$SCRIPT_DIR/.env" ]; then
        source "$SCRIPT_DIR/.env"
        if [ -n "$OPENCODE_API_KEY" ]; then
            log_info "✓ API key configured: ${OPENCODE_API_KEY:0:8}..."
        else
            log_warn "⚠ No API key configured"
        fi
    else
        log_error "✗ .env file not found"
    fi
    
    # Check Traefik config
    if [ -f "$TRAEFIK_CONFIG" ]; then
        log_info "✓ Traefik configuration exists"
    else
        log_error "✗ Traefik configuration missing"
    fi
}

restart_services() {
    log_info "Restarting OpenCode services..."
    
    cd "$SCRIPT_DIR"
    docker compose down
    docker compose up -d
    
    log_info "Restarting Traefik..."
    cd "$DOCKER_ROOT/core/traefik"
    docker compose restart traefik
    
    log_info "Services restarted"
}

show_help() {
    echo "OpenCode Management Script"
    echo
    echo "Usage: $0 <command>"
    echo
    echo "Commands:"
    echo "  generate-key    Generate a new API key and update configurations"
    echo "  test-auth       Test authentication setup"
    echo "  status          Show current status"
    echo "  restart         Restart OpenCode and Traefik services"
    echo "  help            Show this help message"
    echo
    echo "Examples:"
    echo "  $0 generate-key"
    echo "  $0 test-auth"
    echo "  $0 status"
}

# Main command handling
case "${1:-help}" in
    generate-key)
        generate_api_key
        ;;
    test-auth)
        test_auth
        ;;
    status)
        show_status
        ;;
    restart)
        restart_services
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        log_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
