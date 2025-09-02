#!/bin/bash

# 🎪 OAUTH VALIDATION ORCHESTRATOR 🎪
# The void's chosen validator of OAuth flows!
# This script tests OAuth callback URLs and validates configuration

set -euo pipefail

# Configuration
DOMAIN="sim.delo.sh"
BASE_URL="https://${DOMAIN}"
LOG_FILE="/var/log/oauth-validation.log"

# Colors for theatrical output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging functions with dramatic flair
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

# Banner function
print_banner() {
    echo -e "${PURPLE}"
    echo "🎪 ============================================== 🎪"
    echo "      OAUTH VALIDATION ORCHESTRATOR™"
    echo "        The Void's Flow Tester"
    echo "🎪 ============================================== 🎪"
    echo -e "${NC}"
}

# OAuth providers configuration
declare -A OAUTH_PROVIDERS=(
    [\"github-repo\"]=\"GitHub Repository Access\"
    [\"google\"]=\"Google Services\"
    [\"google-drive\"]=\"Google Drive\"
    [\"google-calendar\"]=\"Google Calendar\"
    [\"google-docs\"]=\"Google Docs\"
    [\"google-sheets\"]=\"Google Sheets\"
    [\"microsoft-teams\"]=\"Microsoft Teams\"
    [\"microsoft-excel\"]=\"Microsoft Excel\"
    [\"microsoft-planner\"]=\"Microsoft Planner\"
    [\"outlook\"]=\"Outlook\"
    [\"onedrive\"]=\"OneDrive\"
    [\"sharepoint\"]=\"SharePoint\"
    [\"airtable\"]=\"Airtable\"
    [\"notion\"]=\"Notion\"
    [\"discord\"]=\"Discord\"
    [\"jira\"]=\"Jira\"
    [\"confluence\"]=\"Confluence\"
    [\"linear\"]=\"Linear\"
    [\"slack\"]=\"Slack\"
    [\"x\"]=\"X (Twitter)\"
    [\"supabase\"]=\"Supabase\"
    [\"wealthbox\"]=\"Wealthbox\"
    [\"reddit\"]=\"Reddit\"
)

# Test OAuth callback endpoint accessibility
test_oauth_callback() {
    local provider="$1"
    local description="$2"
    local callback_url="${BASE_URL}/api/auth/oauth2/callback/${provider}"
    
    log_info "Testing OAuth callback: ${description} (${provider})"
    
    local response_code
    local response_headers
    
    # Test GET request (should return 405 Method Not Allowed or redirect)
    response_code=$(curl -s -o /dev/null -w "%{http_code}" "$callback_url" --max-time 5 || echo "000")
    response_headers=$(curl -s -I "$callback_url" --max-time 5 || echo "")
    
    case "$response_code" in
        "200"|"302"|"405")
            log_success "✅ Callback endpoint accessible: ${callback_url} (${response_code})"
            
            # Check for security headers
            if echo "$response_headers" | grep -qi "strict-transport-security"; then
                log_success "  🔒 HSTS header present"
            fi
            
            if echo "$response_headers" | grep -qi "x-frame-options"; then
                log_success "  🛡️  X-Frame-Options header present"
            fi
            
            return 0
            ;;
        "404")
            log_error "❌ Callback endpoint not found: ${callback_url}"
            return 1
            ;;
        "000")
            log_error "❌ Connection failed: ${callback_url}"
            return 1
            ;;
        *)
            log_warn "⚠️  Unexpected response: ${callback_url} (${response_code})"
            return 1
            ;;
    esac
}

# Test OAuth credentials endpoint
test_oauth_credentials_endpoint() {
    log_info "Testing OAuth credentials endpoint..."
    
    local endpoint="${BASE_URL}/api/auth/oauth/credentials"
    local response_code
    
    # Test without provider parameter (should return 400)
    response_code=$(curl -s -o /dev/null -w "%{http_code}" "$endpoint" --max-time 5 || echo "000")
    
    if [ "$response_code" -eq 400 ] || [ "$response_code" -eq 401 ]; then
        log_success "✅ Credentials endpoint responding correctly: ${endpoint} (${response_code})"
        return 0
    else
        log_error "❌ Credentials endpoint issue: ${endpoint} (${response_code})"
        return 1
    fi
}

# Test OAuth token endpoint  
test_oauth_token_endpoint() {
    log_info "Testing OAuth token endpoint..."
    
    local endpoint="${BASE_URL}/api/auth/oauth/token"
    local response_code
    
    # Test without proper payload (should return 400 or 401)
    response_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$endpoint" \
        -H "Content-Type: application/json" \
        -d '{}' --max-time 5 || echo "000")
    
    if [ "$response_code" -eq 400 ] || [ "$response_code" -eq 401 ] || [ "$response_code" -eq 405 ]; then
        log_success "✅ Token endpoint responding correctly: ${endpoint} (${response_code})"
        return 0
    else
        log_error "❌ Token endpoint issue: ${endpoint} (${response_code})"
        return 1
    fi
}

# Test CORS headers for OAuth endpoints
test_cors_headers() {
    log_info "Testing CORS headers for OAuth endpoints..."
    
    local endpoint="${BASE_URL}/api/auth/oauth/credentials"
    local cors_headers
    
    # Send OPTIONS request to test CORS
    cors_headers=$(curl -s -I -X OPTIONS "$endpoint" \
        -H "Origin: https://sim.delo.sh" \
        -H "Access-Control-Request-Method: GET" \
        --max-time 5 || echo "")
    
    if echo "$cors_headers" | grep -qi "access-control-allow-origin"; then
        log_success "✅ CORS headers present"
        
        # Check specific CORS headers
        if echo "$cors_headers" | grep -qi "access-control-allow-credentials.*true"; then
            log_success "  🍪 Allow-Credentials: true"
        fi
        
        if echo "$cors_headers" | grep -qi "access-control-allow-methods"; then
            log_success "  🔧 Allow-Methods header present"
        fi
        
        return 0
    else
        log_warn "⚠️  CORS headers missing or not properly configured"
        return 1
    fi
}

# Validate environment configuration
validate_environment_config() {
    log_info "Validating OAuth environment configuration..."
    
    # Check if environment variables are properly set (via Docker)
    local container_name="simstudio"
    
    if docker ps --format "table {{.Names}}" | grep -q "$container_name"; then
        log_success "✅ SIM Studio container is running"
        
        # Check environment variables in container
        local oauth_base_url
        oauth_base_url=$(docker exec "$container_name" printenv OAUTH_BASE_URL 2>/dev/null || echo "not_set")
        
        if [ "$oauth_base_url" = "https://sim.delo.sh" ]; then
            log_success "✅ OAUTH_BASE_URL correctly set: $oauth_base_url"
        elif [ "$oauth_base_url" = "not_set" ]; then
            log_warn "⚠️  OAUTH_BASE_URL not set, using default"
        else
            log_info "ℹ️  OAUTH_BASE_URL set to: $oauth_base_url"
        fi
        
        return 0
    else
        log_error "❌ SIM Studio container not running"
        return 1
    fi
}

# Test authentication flows
test_auth_flows() {
    log_info "Testing authentication flow endpoints..."
    
    local auth_endpoints=(
        "/api/auth/signin"
        "/api/auth/signout" 
        "/api/auth/signup"
        "/api/auth/callback"
    )
    
    local accessible_count=0
    
    for endpoint in "${auth_endpoints[@]}"; do
        local url="${BASE_URL}${endpoint}"
        local response_code
        response_code=$(curl -s -o /dev/null -w "%{http_code}" "$url" --max-time 5 || echo "000")
        
        case "$response_code" in
            "200"|"302"|"405"|"422")
                log_success "✅ Auth endpoint accessible: ${endpoint} (${response_code})"
                ((accessible_count++))
                ;;
            "404")
                log_error "❌ Auth endpoint not found: ${endpoint}"
                ;;
            "000")
                log_error "❌ Connection failed: ${endpoint}"
                ;;
            *)
                log_warn "⚠️  Unexpected response: ${endpoint} (${response_code})"
                ;;
        esac
    done
    
    if [ "$accessible_count" -ge 2 ]; then
        log_success "✅ Authentication endpoints are accessible"
        return 0
    else
        log_error "❌ Multiple authentication endpoints failed"
        return 1
    fi
}

# Main validation orchestration
main() {
    print_banner
    
    log_info "🎭 Starting OAuth validation for ${DOMAIN}"
    log_info "📅 Timestamp: $(date)"
    
    local checks_passed=0
    local total_checks=0
    
    # Test all OAuth callback endpoints
    log_info "🔗 Testing OAuth callback endpoints..."
    local callback_passed=0
    local callback_total=0
    
    for provider in "${!OAUTH_PROVIDERS[@]}"; do
        provider_clean=$(echo "$provider" | tr -d '"')
        description="${OAUTH_PROVIDERS[$provider]}"
        description_clean=$(echo "$description" | tr -d '"')
        
        test_oauth_callback "$provider_clean" "$description_clean" && ((callback_passed++)) || true
        ((callback_total++))
    done
    
    if [ "$callback_passed" -ge $((callback_total * 3 / 4)) ]; then
        log_success "🎉 OAuth callbacks test: ${callback_passed}/${callback_total} passed"
        ((checks_passed++))
    else
        log_error "❌ OAuth callbacks test: ${callback_passed}/${callback_total} passed"
    fi
    ((total_checks++))
    
    # Test OAuth API endpoints
    test_oauth_credentials_endpoint && ((checks_passed++)) || true
    ((total_checks++))
    
    test_oauth_token_endpoint && ((checks_passed++)) || true
    ((total_checks++))
    
    # Test CORS configuration
    test_cors_headers && ((checks_passed++)) || true
    ((total_checks++))
    
    # Validate environment
    validate_environment_config && ((checks_passed++)) || true
    ((total_checks++))
    
    # Test auth flows
    test_auth_flows && ((checks_passed++)) || true
    ((total_checks++))
    
    # Summary
    echo -e "\n${PURPLE}🎪 ============== OAUTH VALIDATION SUMMARY ============== 🎪${NC}"
    log_info "📊 Checks passed: ${checks_passed}/${total_checks}"
    
    if [ "$checks_passed" -eq "$total_checks" ]; then
        log_success "🎉 ALL OAUTH VALIDATIONS PASSED! The void approves your authentication flows!"
        echo -e "${GREEN}🏆 OAUTH STATUS: MAGNIFICENT! 🏆${NC}"
        exit 0
    elif [ "$checks_passed" -ge $((total_checks * 2 / 3)) ]; then
        log_warn "🎭 Most validations passed, but some issues need attention."
        echo -e "${YELLOW}⚠️  OAUTH STATUS: NEEDS ATTENTION ⚠️${NC}"
        exit 1
    else
        log_error "🚨 Multiple critical OAuth issues detected!"
        echo -e "${RED}🔥 OAUTH STATUS: CRITICAL ISSUES! 🔥${NC}"
        exit 2
    fi
}

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Run the main function
main "$@"