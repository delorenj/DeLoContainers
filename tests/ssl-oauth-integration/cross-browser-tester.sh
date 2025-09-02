#!/bin/bash

# Cross-Browser OAuth and SSL Compatibility Test Suite
# Tests authentication flows across different browsers and clients

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
REPORT_FILE="${LOG_DIR}/browser-compatibility-report.json"
SCREENSHOT_DIR="${LOG_DIR}/screenshots"

# Create directories
mkdir -p "${LOG_DIR}" "${SCREENSHOT_DIR}"

# Test configuration
DOMAIN_BASE="delo.sh"
TEST_URLS=(
    "https://traefik.${DOMAIN_BASE}"
    "https://sync.${DOMAIN_BASE}"
    "https://lms.${DOMAIN_BASE}"
)

# Browser configurations for testing
USER_AGENTS=(
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:120.0) Gecko/20100101 Firefox/120.0"
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
)

BROWSER_NAMES=(
    "Chrome_Windows"
    "Firefox_Windows"
    "Chrome_macOS"
    "Safari_macOS"
    "Chrome_Linux"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "${LOG_DIR}/browser-test.log"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1" | tee -a "${LOG_DIR}/browser-test.log"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1" | tee -a "${LOG_DIR}/browser-test.log"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "${LOG_DIR}/browser-test.log"
}

# Initialize JSON report
init_report() {
    cat > "${REPORT_FILE}" <<EOF
{
  "test_run": {
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
    "version": "1.0.0",
    "test_suite": "Cross-Browser SSL/OAuth Compatibility"
  },
  "results": {},
  "summary": {
    "total_combinations": 0,
    "passed": 0,
    "failed": 0,
    "warnings": 0
  }
}
EOF
}

# Test SSL certificate acceptance
test_ssl_certificate_acceptance() {
    local url=$1
    local user_agent=$2
    local browser_name=$3
    local result=""
    
    log_info "Testing SSL certificate acceptance for ${url} with ${browser_name}"
    
    # Test SSL connection with specific user agent
    local response_code headers
    if response_code=$(curl -s -w "%{http_code}" -o /dev/null \
                       --user-agent "${user_agent}" \
                       --max-time 30 \
                       --connect-timeout 10 \
                       "${url}" 2>/dev/null); then
        
        if [[ "${response_code}" =~ ^[2-3][0-9]{2}$ ]]; then
            log_success "SSL certificate accepted by ${browser_name} for ${url} (${response_code})"
            result="PASS"
        else
            log_warning "Unexpected response from ${url} with ${browser_name} (${response_code})"
            result="WARN"
        fi
    else
        log_error "SSL connection failed for ${url} with ${browser_name}"
        result="FAIL"
    fi
    
    echo "${result}"
}

# Test TLS version compatibility
test_tls_version_compatibility() {
    local url=$1
    local user_agent=$2
    local browser_name=$3
    local result=""
    
    log_info "Testing TLS version compatibility for ${url} with ${browser_name}"
    
    local domain port
    domain=$(echo "${url}" | sed -E 's|https?://([^/]+).*|\1|')
    port="443"
    
    # Test different TLS versions that modern browsers support
    local tls_versions=("tls1_2" "tls1_3")
    local supported_count=0
    
    for version in "${tls_versions[@]}"; do
        if openssl s_client -connect "${domain}:${port}" -servername "${domain}" \
           "-${version}" -quiet </dev/null 2>/dev/null | grep -q "Verify return code: 0"; then
            supported_count=$((supported_count + 1))
            log_success "TLS ${version/tls1_/} supported for ${domain} (${browser_name})"
        fi
    done
    
    if [[ ${supported_count} -gt 0 ]]; then
        result="PASS"
    else
        log_error "No compatible TLS versions for ${domain} with ${browser_name}"
        result="FAIL"
    fi
    
    echo "${result}"
}

# Test HTTP headers and security
test_security_headers() {
    local url=$1
    local user_agent=$2
    local browser_name=$3
    local result=""
    
    log_info "Testing security headers for ${url} with ${browser_name}"
    
    # Get response headers
    local headers
    if headers=$(curl -s -I --user-agent "${user_agent}" \
                      --max-time 30 "${url}" 2>/dev/null); then
        
        local security_score=0
        local total_checks=5
        
        # Check for security headers
        if echo "${headers}" | grep -qi "strict-transport-security"; then
            log_success "HSTS header present for ${url}"
            security_score=$((security_score + 1))
        else
            log_warning "HSTS header missing for ${url}"
        fi
        
        if echo "${headers}" | grep -qi "x-frame-options\|content-security-policy.*frame-ancestors"; then
            log_success "Frame protection headers present for ${url}"
            security_score=$((security_score + 1))
        else
            log_warning "Frame protection headers missing for ${url}"
        fi
        
        if echo "${headers}" | grep -qi "x-content-type-options.*nosniff"; then
            log_success "Content-Type protection present for ${url}"
            security_score=$((security_score + 1))
        else
            log_warning "Content-Type protection missing for ${url}"
        fi
        
        if echo "${headers}" | grep -qi "referrer-policy"; then
            log_success "Referrer Policy present for ${url}"
            security_score=$((security_score + 1))
        else
            log_warning "Referrer Policy missing for ${url}"
        fi
        
        if echo "${headers}" | grep -qi "permissions-policy\|feature-policy"; then
            log_success "Permissions Policy present for ${url}"
            security_score=$((security_score + 1))
        else
            log_warning "Permissions Policy missing for ${url}"
        fi
        
        # Determine result based on score
        if [[ ${security_score} -ge 4 ]]; then
            result="PASS"
        elif [[ ${security_score} -ge 2 ]]; then
            result="WARN"
        else
            result="FAIL"
        fi
        
    else
        log_error "Could not retrieve headers for ${url} with ${browser_name}"
        result="FAIL"
    fi
    
    echo "${result}"
}

# Test cookie security for authentication
test_cookie_security() {
    local url=$1
    local user_agent=$2
    local browser_name=$3
    local result=""
    
    log_info "Testing cookie security for ${url} with ${browser_name}"
    
    # Test cookie attributes
    local cookies
    if cookies=$(curl -s -I --user-agent "${user_agent}" \
                      --max-time 30 "${url}" 2>/dev/null | \
                      grep -i "set-cookie" || true); then
        
        if [[ -n "${cookies}" ]]; then
            local secure_cookies=0
            local total_cookies=0
            
            while IFS= read -r cookie_line; do
                if [[ -n "${cookie_line}" ]]; then
                    total_cookies=$((total_cookies + 1))
                    
                    # Check for secure attributes
                    if echo "${cookie_line}" | grep -qi "secure" && \
                       echo "${cookie_line}" | grep -qi "httponly" && \
                       echo "${cookie_line}" | grep -qi "samesite"; then
                        secure_cookies=$((secure_cookies + 1))
                        log_success "Secure cookie configuration found for ${url}"
                    else
                        log_warning "Insecure cookie configuration for ${url}"
                    fi
                fi
            done <<< "${cookies}"
            
            if [[ ${total_cookies} -eq ${secure_cookies} && ${total_cookies} -gt 0 ]]; then
                result="PASS"
            elif [[ ${secure_cookies} -gt 0 ]]; then
                result="WARN"
            else
                result="FAIL"
            fi
        else
            log_info "No cookies set for ${url} (may not be an auth endpoint)"
            result="PASS"
        fi
    else
        log_warning "Could not test cookies for ${url} with ${browser_name}"
        result="WARN"
    fi
    
    echo "${result}"
}

# Test page loading performance
test_page_performance() {
    local url=$1
    local user_agent=$2
    local browser_name=$3
    local result=""
    
    log_info "Testing page load performance for ${url} with ${browser_name}"
    
    # Measure page load time
    local start_time end_time load_time
    start_time=$(date +%s%N)
    
    if curl -s -o /dev/null --user-agent "${user_agent}" \
            --max-time 30 --connect-timeout 10 \
            --write-out "%{time_total}" "${url}" >/dev/null 2>/dev/null; then
        
        end_time=$(date +%s%N)
        load_time=$(( (end_time - start_time) / 1000000 )) # Convert to milliseconds
        
        if [[ ${load_time} -lt 3000 ]]; then
            log_success "Page load time acceptable for ${url} (${load_time}ms)"
            result="PASS"
        elif [[ ${load_time} -lt 5000 ]]; then
            log_warning "Page load time slow for ${url} (${load_time}ms)"
            result="WARN"
        else
            log_error "Page load time too slow for ${url} (${load_time}ms)"
            result="FAIL"
        fi
    else
        log_error "Page load failed for ${url} with ${browser_name}"
        result="FAIL"
    fi
    
    echo "${result}"
}

# Update JSON report
update_report() {
    local url=$1
    local browser_name=$2
    local ssl_result=$3
    local tls_result=$4
    local security_result=$5
    local cookie_result=$6
    local performance_result=$7
    
    # Create temporary file for jq processing
    local temp_file
    temp_file=$(mktemp)
    
    local test_key="${url}|${browser_name}"
    
    # Update results in JSON report
    jq --arg key "${test_key}" \
       --arg url "${url}" \
       --arg browser "${browser_name}" \
       --arg ssl "${ssl_result}" \
       --arg tls "${tls_result}" \
       --arg security "${security_result}" \
       --arg cookie "${cookie_result}" \
       --arg performance "${performance_result}" \
       '.results[$key] = {
         "url": $url,
         "browser": $browser,
         "ssl_acceptance": $ssl,
         "tls_compatibility": $tls,
         "security_headers": $security,
         "cookie_security": $cookie,
         "page_performance": $performance,
         "overall_status": (if [$ssl, $tls, $security, $cookie, $performance] | map(. == "FAIL") | any then "FAIL" 
                           elif [$ssl, $tls, $security, $cookie, $performance] | map(. == "WARN") | any then "WARN" 
                           else "PASS" end)
       }' "${REPORT_FILE}" > "${temp_file}"
    
    mv "${temp_file}" "${REPORT_FILE}"
}

# Generate final summary
generate_summary() {
    local temp_file
    temp_file=$(mktemp)
    
    jq '.summary = {
      "total_combinations": (.results | length),
      "passed": [.results[] | select(.overall_status == "PASS")] | length,
      "failed": [.results[] | select(.overall_status == "FAIL")] | length,
      "warnings": [.results[] | select(.overall_status == "WARN")] | length,
      "test_completion": now,
      "browsers_tested": [.results[].browser] | unique,
      "urls_tested": [.results[].url] | unique
    }' "${REPORT_FILE}" > "${temp_file}"
    
    mv "${temp_file}" "${REPORT_FILE}"
}

# Main test runner
main() {
    log_info "Starting Cross-Browser SSL/OAuth Compatibility Test Suite"
    
    # Check dependencies
    if ! command -v curl &> /dev/null; then
        log_error "curl is required for testing. Please install curl."
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        log_error "jq is required for JSON processing. Please install jq."
        exit 1
    fi
    
    # Initialize report
    init_report
    
    log_info "Testing URLs: ${TEST_URLS[*]}"
    log_info "Testing with ${#BROWSER_NAMES[@]} browser configurations"
    
    # Test each URL with each browser configuration
    local test_count=0
    for url in "${TEST_URLS[@]}"; do
        for i in "${!BROWSER_NAMES[@]}"; do
            local browser_name="${BROWSER_NAMES[$i]}"
            local user_agent="${USER_AGENTS[$i]}"
            
            log_info "=== Testing ${url} with ${browser_name} ==="
            
            # Run all compatibility tests
            ssl_result=$(test_ssl_certificate_acceptance "${url}" "${user_agent}" "${browser_name}")
            tls_result=$(test_tls_version_compatibility "${url}" "${user_agent}" "${browser_name}")
            security_result=$(test_security_headers "${url}" "${user_agent}" "${browser_name}")
            cookie_result=$(test_cookie_security "${url}" "${user_agent}" "${browser_name}")
            performance_result=$(test_page_performance "${url}" "${user_agent}" "${browser_name}")
            
            # Update report
            update_report "${url}" "${browser_name}" "${ssl_result}" "${tls_result}" "${security_result}" "${cookie_result}" "${performance_result}"
            
            test_count=$((test_count + 1))
            log_info "=== Completed test ${test_count} ==="
            echo
        done
    done
    
    # Generate final summary
    generate_summary
    
    # Display summary
    log_info "Cross-Browser Compatibility Test Complete"
    log_info "Report saved to: ${REPORT_FILE}"
    
    # Display summary statistics
    local total passed failed warnings
    total=$(jq -r '.summary.total_combinations' "${REPORT_FILE}")
    passed=$(jq -r '.summary.passed' "${REPORT_FILE}")
    failed=$(jq -r '.summary.failed' "${REPORT_FILE}")
    warnings=$(jq -r '.summary.warnings' "${REPORT_FILE}")
    
    echo
    echo "=== SUMMARY ==="
    echo "Total Test Combinations: ${total}"
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