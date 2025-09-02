#!/bin/bash

# OAuth Authentication Flow Test Suite
# Tests GitHub and Google OAuth integration flows

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
REPORT_FILE="${LOG_DIR}/oauth-test-report.json"
CONFIG_FILE="${SCRIPT_DIR}/oauth-config.json"

# Create logs directory
mkdir -p "${LOG_DIR}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# OAuth endpoints and configuration
OAUTH_PROVIDERS=(
    "github"
    "google"
)

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "${LOG_DIR}/oauth-test.log"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1" | tee -a "${LOG_DIR}/oauth-test.log"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1" | tee -a "${LOG_DIR}/oauth-test.log"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "${LOG_DIR}/oauth-test.log"
}

# Initialize configuration file
init_oauth_config() {
    if [[ ! -f "${CONFIG_FILE}" ]]; then
        cat > "${CONFIG_FILE}" <<EOF
{
  "providers": {
    "github": {
      "auth_url": "https://github.com/login/oauth/authorize",
      "token_url": "https://github.com/login/oauth/access_token",
      "user_url": "https://api.github.com/user",
      "scopes": ["user:email", "read:user"],
      "client_id": "\${GITHUB_CLIENT_ID}",
      "redirect_uri": "https://your-app.delo.sh/auth/github/callback"
    },
    "google": {
      "auth_url": "https://accounts.google.com/o/oauth2/v2/auth",
      "token_url": "https://oauth2.googleapis.com/token",
      "user_url": "https://www.googleapis.com/oauth2/v2/userinfo",
      "scopes": ["openid", "email", "profile"],
      "client_id": "\${GOOGLE_CLIENT_ID}",
      "redirect_uri": "https://your-app.delo.sh/auth/google/callback"
    }
  },
  "test_endpoints": {
    "app_base_url": "https://your-app.delo.sh",
    "auth_endpoints": {
      "login": "/auth/login",
      "logout": "/auth/logout",
      "callback": "/auth/{provider}/callback",
      "profile": "/auth/profile"
    }
  }
}
EOF
        log_warning "Created OAuth configuration template at ${CONFIG_FILE}"
        log_warning "Please update the configuration with your actual OAuth credentials and endpoints"
    fi
}

# Initialize JSON report
init_report() {
    cat > "${REPORT_FILE}" <<EOF
{
  "test_run": {
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
    "version": "1.0.0",
    "test_suite": "OAuth Authentication Flow"
  },
  "results": {},
  "summary": {
    "total_providers": 0,
    "passed": 0,
    "failed": 0,
    "warnings": 0
  }
}
EOF
}

# Test OAuth authorization URL generation
test_oauth_auth_url() {
    local provider=$1
    local result=""
    
    log_info "Testing OAuth authorization URL for ${provider}"
    
    local auth_url client_id scopes redirect_uri
    auth_url=$(jq -r ".providers.${provider}.auth_url" "${CONFIG_FILE}")
    client_id=$(jq -r ".providers.${provider}.client_id" "${CONFIG_FILE}")
    scopes=$(jq -r ".providers.${provider}.scopes | join(\" \")" "${CONFIG_FILE}")
    redirect_uri=$(jq -r ".providers.${provider}.redirect_uri" "${CONFIG_FILE}")
    
    if [[ "${client_id}" == "null" || "${client_id}" == "\${GITHUB_CLIENT_ID}" || "${client_id}" == "\${GOOGLE_CLIENT_ID}" ]]; then
        log_warning "OAuth client ID not configured for ${provider}"
        result="WARN"
    else
        # Construct authorization URL
        local full_auth_url="${auth_url}?client_id=${client_id}&redirect_uri=${redirect_uri}&scope=${scopes// /%20}&response_type=code&state=test_state"
        
        # Test if the authorization URL is accessible
        if curl -s -I --max-time 10 "${auth_url}" | grep -q "200\|302\|404"; then
            log_success "OAuth authorization endpoint accessible for ${provider}"
            result="PASS"
        else
            log_error "OAuth authorization endpoint not accessible for ${provider}"
            result="FAIL"
        fi
    fi
    
    echo "${result}"
}

# Test OAuth token endpoint
test_oauth_token_endpoint() {
    local provider=$1
    local result=""
    
    log_info "Testing OAuth token endpoint for ${provider}"
    
    local token_url
    token_url=$(jq -r ".providers.${provider}.token_url" "${CONFIG_FILE}")
    
    # Test if token endpoint responds (should reject without proper auth)
    local response_code
    if response_code=$(curl -s -w "%{http_code}" -o /dev/null --max-time 10 -X POST "${token_url}"); then
        if [[ "${response_code}" =~ ^(400|401|405)$ ]]; then
            log_success "OAuth token endpoint responding correctly for ${provider} (${response_code})"
            result="PASS"
        elif [[ "${response_code}" =~ ^(2[0-9]{2})$ ]]; then
            log_warning "OAuth token endpoint unexpectedly accepting requests for ${provider} (${response_code})"
            result="WARN"
        else
            log_error "OAuth token endpoint unexpected response for ${provider} (${response_code})"
            result="FAIL"
        fi
    else
        log_error "OAuth token endpoint not accessible for ${provider}"
        result="FAIL"
    fi
    
    echo "${result}"
}

# Test OAuth user info endpoint
test_oauth_user_endpoint() {
    local provider=$1
    local result=""
    
    log_info "Testing OAuth user info endpoint for ${provider}"
    
    local user_url
    user_url=$(jq -r ".providers.${provider}.user_url" "${CONFIG_FILE}")
    
    # Test if user endpoint responds (should require authentication)
    local response_code
    if response_code=$(curl -s -w "%{http_code}" -o /dev/null --max-time 10 "${user_url}"); then
        if [[ "${response_code}" =~ ^(401|403)$ ]]; then
            log_success "OAuth user endpoint requiring authentication for ${provider} (${response_code})"
            result="PASS"
        elif [[ "${response_code}" =~ ^(2[0-9]{2})$ ]]; then
            log_warning "OAuth user endpoint not requiring authentication for ${provider} (${response_code})"
            result="WARN"
        else
            log_error "OAuth user endpoint unexpected response for ${provider} (${response_code})"
            result="FAIL"
        fi
    else
        log_error "OAuth user endpoint not accessible for ${provider}"
        result="FAIL"
    fi
    
    echo "${result}"
}

# Test CORS headers for OAuth endpoints
test_oauth_cors() {
    local provider=$1
    local result=""
    
    log_info "Testing CORS configuration for ${provider} OAuth endpoints"
    
    local auth_url
    auth_url=$(jq -r ".providers.${provider}.auth_url" "${CONFIG_FILE}")
    
    # Test preflight CORS request
    local cors_headers
    if cors_headers=$(curl -s -I -X OPTIONS \
                      -H "Origin: https://your-app.delo.sh" \
                      -H "Access-Control-Request-Method: GET" \
                      -H "Access-Control-Request-Headers: Content-Type" \
                      --max-time 10 "${auth_url}" 2>/dev/null); then
        
        if echo "${cors_headers}" | grep -qi "access-control-allow-origin"; then
            log_success "CORS headers present for ${provider}"
            result="PASS"
        else
            log_warning "CORS headers not found for ${provider}"
            result="WARN"
        fi
    else
        log_warning "Could not test CORS for ${provider}"
        result="WARN"
    fi
    
    echo "${result}"
}

# Test application OAuth integration endpoints
test_app_oauth_endpoints() {
    local provider=$1
    local result=""
    
    log_info "Testing application OAuth integration endpoints for ${provider}"
    
    local app_base_url login_endpoint callback_endpoint
    app_base_url=$(jq -r '.test_endpoints.app_base_url' "${CONFIG_FILE}")
    login_endpoint=$(jq -r '.test_endpoints.auth_endpoints.login' "${CONFIG_FILE}")
    callback_endpoint=$(jq -r '.test_endpoints.auth_endpoints.callback' "${CONFIG_FILE}" | sed "s/{provider}/${provider}/")
    
    # Test login endpoint
    local login_response
    if login_response=$(curl -s -I --max-time 10 "${app_base_url}${login_endpoint}" 2>/dev/null); then
        if echo "${login_response}" | grep -q "200\|302\|404"; then
            log_success "Login endpoint accessible at ${app_base_url}${login_endpoint}"
        else
            log_warning "Login endpoint may not be accessible at ${app_base_url}${login_endpoint}"
        fi
    else
        log_warning "Could not reach login endpoint ${app_base_url}${login_endpoint}"
    fi
    
    # Test callback endpoint
    local callback_response
    if callback_response=$(curl -s -I --max-time 10 "${app_base_url}${callback_endpoint}" 2>/dev/null); then
        if echo "${callback_response}" | grep -q "200\|302\|400\|404"; then
            log_success "Callback endpoint accessible at ${app_base_url}${callback_endpoint}"
            result="PASS"
        else
            log_warning "Callback endpoint may not be accessible at ${app_base_url}${callback_endpoint}"
            result="WARN"
        fi
    else
        log_error "Could not reach callback endpoint ${app_base_url}${callback_endpoint}"
        result="FAIL"
    fi
    
    echo "${result}"
}

# Test OAuth state parameter validation
test_oauth_state_validation() {
    local provider=$1
    local result=""
    
    log_info "Testing OAuth state parameter validation for ${provider}"
    
    local app_base_url callback_endpoint
    app_base_url=$(jq -r '.test_endpoints.app_base_url' "${CONFIG_FILE}")
    callback_endpoint=$(jq -r '.test_endpoints.auth_endpoints.callback' "${CONFIG_FILE}" | sed "s/{provider}/${provider}/")
    
    # Test callback with invalid state parameter
    local test_url="${app_base_url}${callback_endpoint}?code=test_code&state=invalid_state"
    local response_code
    
    if response_code=$(curl -s -w "%{http_code}" -o /dev/null --max-time 10 "${test_url}" 2>/dev/null); then
        if [[ "${response_code}" =~ ^(400|401|403)$ ]]; then
            log_success "OAuth state validation working for ${provider} (${response_code})"
            result="PASS"
        else
            log_warning "OAuth state validation may not be implemented for ${provider} (${response_code})"
            result="WARN"
        fi
    else
        log_warning "Could not test OAuth state validation for ${provider}"
        result="WARN"
    fi
    
    echo "${result}"
}

# Update JSON report
update_report() {
    local provider=$1
    local auth_url_result=$2
    local token_endpoint_result=$3
    local user_endpoint_result=$4
    local cors_result=$5
    local app_endpoints_result=$6
    local state_validation_result=$7
    
    # Create temporary file for jq processing
    local temp_file
    temp_file=$(mktemp)
    
    # Update results in JSON report
    jq --arg provider "${provider}" \
       --arg auth_url "${auth_url_result}" \
       --arg token_endpoint "${token_endpoint_result}" \
       --arg user_endpoint "${user_endpoint_result}" \
       --arg cors "${cors_result}" \
       --arg app_endpoints "${app_endpoints_result}" \
       --arg state_validation "${state_validation_result}" \
       '.results[$provider] = {
         "authorization_url": $auth_url,
         "token_endpoint": $token_endpoint,
         "user_endpoint": $user_endpoint,
         "cors_configuration": $cors,
         "app_endpoints": $app_endpoints,
         "state_validation": $state_validation,
         "overall_status": (if [$auth_url, $token_endpoint, $user_endpoint, $app_endpoints] | map(. == "FAIL") | any then "FAIL" 
                           elif [$auth_url, $token_endpoint, $user_endpoint, $cors, $app_endpoints, $state_validation] | map(. == "WARN") | any then "WARN" 
                           else "PASS" end)
       }' "${REPORT_FILE}" > "${temp_file}"
    
    mv "${temp_file}" "${REPORT_FILE}"
}

# Generate final summary
generate_summary() {
    local temp_file
    temp_file=$(mktemp)
    
    jq '.summary = {
      "total_providers": (.results | length),
      "passed": [.results[] | select(.overall_status == "PASS")] | length,
      "failed": [.results[] | select(.overall_status == "FAIL")] | length,
      "warnings": [.results[] | select(.overall_status == "WARN")] | length,
      "test_completion": now
    }' "${REPORT_FILE}" > "${temp_file}"
    
    mv "${temp_file}" "${REPORT_FILE}"
}

# Main test runner
main() {
    log_info "Starting OAuth Authentication Flow Test Suite"
    
    # Initialize configuration and report
    init_oauth_config
    init_report
    
    # Check if jq is available
    if ! command -v jq &> /dev/null; then
        log_error "jq is required for JSON processing. Please install jq."
        exit 1
    fi
    
    log_info "Testing OAuth providers: ${OAUTH_PROVIDERS[*]}"
    
    # Test each OAuth provider
    for provider in "${OAUTH_PROVIDERS[@]}"; do
        log_info "=== Testing ${provider} OAuth flow ==="
        
        # Run all OAuth tests
        auth_url_result=$(test_oauth_auth_url "${provider}")
        token_endpoint_result=$(test_oauth_token_endpoint "${provider}")
        user_endpoint_result=$(test_oauth_user_endpoint "${provider}")
        cors_result=$(test_oauth_cors "${provider}")
        app_endpoints_result=$(test_app_oauth_endpoints "${provider}")
        state_validation_result=$(test_oauth_state_validation "${provider}")
        
        # Update report
        update_report "${provider}" "${auth_url_result}" "${token_endpoint_result}" "${user_endpoint_result}" "${cors_result}" "${app_endpoints_result}" "${state_validation_result}"
        
        log_info "=== Completed testing ${provider} OAuth flow ==="
        echo
    done
    
    # Generate final summary
    generate_summary
    
    # Display summary
    log_info "OAuth Authentication Flow Test Complete"
    log_info "Report saved to: ${REPORT_FILE}"
    log_info "Configuration template at: ${CONFIG_FILE}"
    
    # Display summary statistics
    local total passed failed warnings
    total=$(jq -r '.summary.total_providers' "${REPORT_FILE}")
    passed=$(jq -r '.summary.passed' "${REPORT_FILE}")
    failed=$(jq -r '.summary.failed' "${REPORT_FILE}")
    warnings=$(jq -r '.summary.warnings' "${REPORT_FILE}")
    
    echo
    echo "=== SUMMARY ==="
    echo "Total Providers: ${total}"
    echo "Passed: ${passed}"
    echo "Failed: ${failed}"
    echo "Warnings: ${warnings}"
    echo
    
    # Return appropriate exit code
    if [[ ${failed} -gt 0 ]]; then
        exit 1
    elif [[ ${warnings} -gt 0 ]]; then
        exit 2
    else
        exit 0
    fi
}

# Run main function
main "$@"