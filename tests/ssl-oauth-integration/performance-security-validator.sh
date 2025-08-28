#!/bin/bash

# Performance and Security Validation Test Suite
# Comprehensive testing of SSL/OAuth performance and security measures

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
REPORT_FILE="${LOG_DIR}/performance-security-report.json"
DOMAIN_BASE="delo.sh"

# Create logs directory
mkdir -p "${LOG_DIR}"

# Test domains
TEST_DOMAINS=(
    "traefik.${DOMAIN_BASE}"
    "sync.${DOMAIN_BASE}" 
    "lms.${DOMAIN_BASE}"
    "draw.${DOMAIN_BASE}"
)

# Security test configurations
SECURITY_TESTS=(
    "ssl_labs_rating"
    "cipher_suite_strength"
    "certificate_chain_validation"
    "hsts_implementation"
    "csp_implementation"
    "oauth_security_headers"
    "session_security"
    "vulnerability_scan"
)

# Performance test configurations
PERFORMANCE_TESTS=(
    "page_load_time"
    "ssl_handshake_time"
    "auth_flow_performance"
    "concurrent_connections"
    "cdn_performance"
    "api_response_times"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "${LOG_DIR}/perf-sec-test.log"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1" | tee -a "${LOG_DIR}/perf-sec-test.log"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1" | tee -a "${LOG_DIR}/perf-sec-test.log"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "${LOG_DIR}/perf-sec-test.log"
}

# Initialize JSON report
init_report() {
    cat > "${REPORT_FILE}" <<EOF
{
  "test_run": {
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
    "version": "1.0.0",
    "test_suite": "Performance and Security Validation"
  },
  "results": {},
  "summary": {
    "total_domains": 0,
    "security_score": 0,
    "performance_score": 0,
    "overall_grade": "N/A"
  }
}
EOF
}

# Test SSL Labs rating (simulated)
test_ssl_labs_rating() {
    local domain=$1
    local result=""
    local score=0
    
    log_info "Testing SSL Labs equivalent rating for ${domain}"
    
    # Test multiple SSL/TLS factors
    local factors=()
    
    # Test certificate chain
    if openssl s_client -connect "${domain}:443" -servername "${domain}" \
       -verify_return_error </dev/null 2>/dev/null | grep -q "Verify return code: 0"; then
        factors+=("certificate_valid")
        score=$((score + 25))
    fi
    
    # Test TLS 1.3 support
    if openssl s_client -connect "${domain}:443" -servername "${domain}" \
       -tls1_3 </dev/null 2>/dev/null | grep -q "Protocol.*TLSv1.3"; then
        factors+=("tls13_support")
        score=$((score + 25))
        log_success "TLS 1.3 supported for ${domain}"
    else
        log_warning "TLS 1.3 not supported for ${domain}"
    fi
    
    # Test strong cipher suites
    local cipher_info
    if cipher_info=$(openssl s_client -connect "${domain}:443" -servername "${domain}" \
                     </dev/null 2>/dev/null | grep "Cipher.*:"); then
        if echo "${cipher_info}" | grep -qE "(ECDHE|DHE).*AES.*GCM"; then
            factors+=("strong_ciphers")
            score=$((score + 25))
            log_success "Strong cipher suites for ${domain}"
        else
            log_warning "Weak cipher suites detected for ${domain}"
        fi
    fi
    
    # Test HSTS
    if curl -s -I "https://${domain}" | grep -qi "strict-transport-security"; then
        factors+=("hsts_enabled")
        score=$((score + 25))
        log_success "HSTS enabled for ${domain}"
    else
        log_warning "HSTS not enabled for ${domain}"
    fi
    
    # Determine grade based on score
    local grade
    if [[ ${score} -ge 90 ]]; then
        grade="A+"
        result="PASS"
    elif [[ ${score} -ge 80 ]]; then
        grade="A"
        result="PASS"
    elif [[ ${score} -ge 70 ]]; then
        grade="B"
        result="WARN"
    elif [[ ${score} -ge 60 ]]; then
        grade="C"
        result="WARN"
    else
        grade="F"
        result="FAIL"
    fi
    
    log_info "SSL Labs equivalent grade for ${domain}: ${grade} (${score}/100)"
    echo "${result}|${score}|${grade}"
}

# Test cipher suite strength
test_cipher_suite_strength() {
    local domain=$1
    local result=""
    local score=0
    
    log_info "Testing cipher suite strength for ${domain}"
    
    # Get cipher information
    local cipher_info
    if cipher_info=$(openssl s_client -connect "${domain}:443" -servername "${domain}" \
                     -cipher 'HIGH:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!SRP:!CAMELLIA' \
                     </dev/null 2>/dev/null); then
        
        # Check for perfect forward secrecy
        if echo "${cipher_info}" | grep -qE "ECDHE|DHE"; then
            log_success "Perfect Forward Secrecy supported for ${domain}"
            score=$((score + 40))
        else
            log_error "Perfect Forward Secrecy not supported for ${domain}"
        fi
        
        # Check for AEAD ciphers
        if echo "${cipher_info}" | grep -qE "GCM|POLY1305|CCM"; then
            log_success "AEAD ciphers supported for ${domain}"
            score=$((score + 30))
        else
            log_warning "AEAD ciphers not supported for ${domain}"
        fi
        
        # Check key length
        if echo "${cipher_info}" | grep -qE "256.*bits|384.*bits"; then
            log_success "Strong key length for ${domain}"
            score=$((score + 30))
        else
            log_warning "Weak key length for ${domain}"
        fi
        
        if [[ ${score} -ge 70 ]]; then
            result="PASS"
        elif [[ ${score} -ge 50 ]]; then
            result="WARN"
        else
            result="FAIL"
        fi
    else
        log_error "Could not test cipher suites for ${domain}"
        result="FAIL"
    fi
    
    echo "${result}|${score}"
}

# Test HSTS implementation details
test_hsts_implementation() {
    local domain=$1
    local result=""
    local score=0
    
    log_info "Testing HSTS implementation for ${domain}"
    
    local hsts_header
    if hsts_header=$(curl -s -I "https://${domain}" | grep -i "strict-transport-security" | head -1); then
        log_success "HSTS header present for ${domain}"
        score=$((score + 40))
        
        # Check max-age
        if echo "${hsts_header}" | grep -qE "max-age=([1-9][0-9]{6,})"; then
            log_success "HSTS max-age is appropriate for ${domain}"
            score=$((score + 30))
        else
            log_warning "HSTS max-age may be too short for ${domain}"
        fi
        
        # Check includeSubDomains
        if echo "${hsts_header}" | grep -qi "includesubdomains"; then
            log_success "HSTS includeSubDomains enabled for ${domain}"
            score=$((score + 20))
        else
            log_info "HSTS includeSubDomains not enabled for ${domain}"
        fi
        
        # Check preload
        if echo "${hsts_header}" | grep -qi "preload"; then
            log_success "HSTS preload enabled for ${domain}"
            score=$((score + 10))
        else
            log_info "HSTS preload not enabled for ${domain}"
        fi
        
        if [[ ${score} -ge 70 ]]; then
            result="PASS"
        else
            result="WARN"
        fi
    else
        log_error "HSTS not implemented for ${domain}"
        result="FAIL"
    fi
    
    echo "${result}|${score}"
}

# Test Content Security Policy
test_csp_implementation() {
    local domain=$1
    local result=""
    local score=0
    
    log_info "Testing CSP implementation for ${domain}"
    
    local csp_header
    if csp_header=$(curl -s -I "https://${domain}" | grep -i "content-security-policy" | head -1); then
        log_success "CSP header present for ${domain}"
        score=$((score + 30))
        
        # Check for important directives
        local directives=("default-src" "script-src" "style-src" "img-src" "connect-src" "font-src")
        local found_directives=0
        
        for directive in "${directives[@]}"; do
            if echo "${csp_header}" | grep -qi "${directive}"; then
                found_directives=$((found_directives + 1))
            fi
        done
        
        score=$((score + found_directives * 10))
        
        # Check for unsafe-inline/unsafe-eval
        if echo "${csp_header}" | grep -qiE "unsafe-(inline|eval)"; then
            log_warning "Unsafe CSP directives found for ${domain}"
            score=$((score - 20))
        else
            log_success "No unsafe CSP directives for ${domain}"
        fi
        
        # Check for nonce or hash-based CSP
        if echo "${csp_header}" | grep -qE "'nonce-|'sha(256|384|512)-"; then
            log_success "Hash/nonce-based CSP for ${domain}"
            score=$((score + 20))
        fi
        
        if [[ ${score} -ge 70 ]]; then
            result="PASS"
        elif [[ ${score} -ge 40 ]]; then
            result="WARN"
        else
            result="FAIL"
        fi
    else
        log_warning "CSP not implemented for ${domain}"
        result="WARN"
    fi
    
    echo "${result}|${score}"
}

# Test OAuth security headers
test_oauth_security_headers() {
    local domain=$1
    local result=""
    local score=0
    
    log_info "Testing OAuth security headers for ${domain}"
    
    # Test for OAuth-related security headers
    local headers
    if headers=$(curl -s -I "https://${domain}" 2>/dev/null); then
        
        # Check X-Frame-Options or CSP frame-ancestors
        if echo "${headers}" | grep -qiE "(x-frame-options|frame-ancestors)"; then
            log_success "Clickjacking protection enabled for ${domain}"
            score=$((score + 25))
        else
            log_warning "Clickjacking protection missing for ${domain}"
        fi
        
        # Check X-Content-Type-Options
        if echo "${headers}" | grep -qi "x-content-type-options.*nosniff"; then
            log_success "Content-Type protection enabled for ${domain}"
            score=$((score + 25))
        else
            log_warning "Content-Type protection missing for ${domain}"
        fi
        
        # Check Referrer-Policy
        if echo "${headers}" | grep -qi "referrer-policy"; then
            log_success "Referrer Policy configured for ${domain}"
            score=$((score + 25))
        else
            log_warning "Referrer Policy missing for ${domain}"
        fi
        
        # Check Permissions-Policy
        if echo "${headers}" | grep -qiE "(permissions-policy|feature-policy)"; then
            log_success "Permissions Policy configured for ${domain}"
            score=$((score + 25))
        else
            log_info "Permissions Policy not configured for ${domain}"
        fi
        
        if [[ ${score} -ge 75 ]]; then
            result="PASS"
        elif [[ ${score} -ge 50 ]]; then
            result="WARN"
        else
            result="FAIL"
        fi
    else
        log_error "Could not retrieve headers for ${domain}"
        result="FAIL"
    fi
    
    echo "${result}|${score}"
}

# Test page load performance
test_page_load_performance() {
    local domain=$1
    local result=""
    local score=0
    
    log_info "Testing page load performance for ${domain}"
    
    local url="https://${domain}"
    local load_times=()
    
    # Run multiple tests for average
    for i in {1..3}; do
        local load_time
        load_time=$(curl -s -o /dev/null -w "%{time_total}" --max-time 30 "${url}" 2>/dev/null || echo "30.0")
        load_times+=("${load_time}")
    done
    
    # Calculate average load time
    local total_time=0
    for time in "${load_times[@]}"; do
        total_time=$(echo "${total_time} + ${time}" | bc -l 2>/dev/null || echo "${total_time}")
    done
    local avg_time
    avg_time=$(echo "scale=3; ${total_time} / ${#load_times[@]}" | bc -l 2>/dev/null || echo "0")
    
    # Score based on load time (in seconds)
    if (( $(echo "${avg_time} <= 1.0" | bc -l 2>/dev/null || echo "0") )); then
        score=100
        result="PASS"
        log_success "Excellent page load time for ${domain}: ${avg_time}s"
    elif (( $(echo "${avg_time} <= 2.0" | bc -l 2>/dev/null || echo "0") )); then
        score=80
        result="PASS"
        log_success "Good page load time for ${domain}: ${avg_time}s"
    elif (( $(echo "${avg_time} <= 3.0" | bc -l 2>/dev/null || echo "0") )); then
        score=60
        result="WARN"
        log_warning "Average page load time for ${domain}: ${avg_time}s"
    elif (( $(echo "${avg_time} <= 5.0" | bc -l 2>/dev/null || echo "0") )); then
        score=40
        result="WARN"
        log_warning "Slow page load time for ${domain}: ${avg_time}s"
    else
        score=20
        result="FAIL"
        log_error "Very slow page load time for ${domain}: ${avg_time}s"
    fi
    
    echo "${result}|${score}|${avg_time}"
}

# Test SSL handshake performance
test_ssl_handshake_performance() {
    local domain=$1
    local result=""
    local score=0
    
    log_info "Testing SSL handshake performance for ${domain}"
    
    local handshake_times=()
    
    # Run multiple handshake tests
    for i in {1..3}; do
        local handshake_time
        handshake_time=$(curl -s -o /dev/null -w "%{time_connect}" --max-time 10 "https://${domain}" 2>/dev/null || echo "10.0")
        handshake_times+=("${handshake_time}")
    done
    
    # Calculate average handshake time
    local total_time=0
    for time in "${handshake_times[@]}"; do
        total_time=$(echo "${total_time} + ${time}" | bc -l 2>/dev/null || echo "${total_time}")
    done
    local avg_time
    avg_time=$(echo "scale=3; ${total_time} / ${#handshake_times[@]}" | bc -l 2>/dev/null || echo "0")
    
    # Score based on handshake time
    if (( $(echo "${avg_time} <= 0.2" | bc -l 2>/dev/null || echo "0") )); then
        score=100
        result="PASS"
        log_success "Excellent SSL handshake time for ${domain}: ${avg_time}s"
    elif (( $(echo "${avg_time} <= 0.5" | bc -l 2>/dev/null || echo "0") )); then
        score=80
        result="PASS"
        log_success "Good SSL handshake time for ${domain}: ${avg_time}s"
    elif (( $(echo "${avg_time} <= 1.0" | bc -l 2>/dev/null || echo "0") )); then
        score=60
        result="WARN"
        log_warning "Average SSL handshake time for ${domain}: ${avg_time}s"
    else
        score=40
        result="FAIL"
        log_error "Slow SSL handshake time for ${domain}: ${avg_time}s"
    fi
    
    echo "${result}|${score}|${avg_time}"
}

# Test concurrent connections
test_concurrent_connections() {
    local domain=$1
    local result=""
    local score=0
    
    log_info "Testing concurrent connection handling for ${domain}"
    
    local url="https://${domain}"
    local concurrent_limit=10
    local success_count=0
    
    # Create temporary files for parallel curl
    local temp_dir
    temp_dir=$(mktemp -d)
    
    # Run concurrent requests
    for i in $(seq 1 ${concurrent_limit}); do
        (
            if curl -s -o /dev/null --max-time 15 "${url}" 2>/dev/null; then
                echo "success" > "${temp_dir}/result_${i}"
            else
                echo "fail" > "${temp_dir}/result_${i}"
            fi
        ) &
    done
    
    # Wait for all requests to complete
    wait
    
    # Count successes
    for i in $(seq 1 ${concurrent_limit}); do
        if [[ -f "${temp_dir}/result_${i}" ]] && [[ "$(cat "${temp_dir}/result_${i}")" == "success" ]]; then
            success_count=$((success_count + 1))
        fi
    done
    
    # Clean up
    rm -rf "${temp_dir}"
    
    # Calculate score
    local success_rate
    success_rate=$(( success_count * 100 / concurrent_limit ))
    
    if [[ ${success_rate} -ge 90 ]]; then
        score=100
        result="PASS"
        log_success "Excellent concurrent connection handling for ${domain}: ${success_rate}%"
    elif [[ ${success_rate} -ge 80 ]]; then
        score=80
        result="PASS"
        log_success "Good concurrent connection handling for ${domain}: ${success_rate}%"
    elif [[ ${success_rate} -ge 70 ]]; then
        score=60
        result="WARN"
        log_warning "Average concurrent connection handling for ${domain}: ${success_rate}%"
    else
        score=40
        result="FAIL"
        log_error "Poor concurrent connection handling for ${domain}: ${success_rate}%"
    fi
    
    echo "${result}|${score}|${success_rate}"
}

# Update JSON report
update_report() {
    local domain=$1
    local ssl_labs_result=$2
    local cipher_result=$3
    local hsts_result=$4
    local csp_result=$5
    local oauth_headers_result=$6
    local page_load_result=$7
    local handshake_result=$8
    local concurrent_result=$9
    
    # Parse results (format: status|score|additional_info)
    IFS='|' read -r ssl_status ssl_score ssl_grade <<< "${ssl_labs_result}"
    IFS='|' read -r cipher_status cipher_score _ <<< "${cipher_result}"
    IFS='|' read -r hsts_status hsts_score _ <<< "${hsts_result}"
    IFS='|' read -r csp_status csp_score _ <<< "${csp_result}"
    IFS='|' read -r oauth_status oauth_score _ <<< "${oauth_headers_result}"
    IFS='|' read -r page_status page_score page_time <<< "${page_load_result}"
    IFS='|' read -r handshake_status handshake_score handshake_time <<< "${handshake_result}"
    IFS='|' read -r concurrent_status concurrent_score concurrent_rate <<< "${concurrent_result}"
    
    # Calculate overall scores
    local security_total=$((ssl_score + cipher_score + hsts_score + csp_score + oauth_score))
    local security_avg=$((security_total / 5))
    local performance_total=$((page_score + handshake_score + concurrent_score))
    local performance_avg=$((performance_total / 3))
    local overall_avg=$(( (security_avg + performance_avg) / 2 ))
    
    # Create temporary file for jq processing
    local temp_file
    temp_file=$(mktemp)
    
    # Update results in JSON report
    jq --arg domain "${domain}" \
       --arg ssl_status "${ssl_status}" --argjson ssl_score "${ssl_score}" --arg ssl_grade "${ssl_grade}" \
       --arg cipher_status "${cipher_status}" --argjson cipher_score "${cipher_score}" \
       --arg hsts_status "${hsts_status}" --argjson hsts_score "${hsts_score}" \
       --arg csp_status "${csp_status}" --argjson csp_score "${csp_score}" \
       --arg oauth_status "${oauth_status}" --argjson oauth_score "${oauth_score}" \
       --arg page_status "${page_status}" --argjson page_score "${page_score}" --arg page_time "${page_time}" \
       --arg handshake_status "${handshake_status}" --argjson handshake_score "${handshake_score}" --arg handshake_time "${handshake_time}" \
       --arg concurrent_status "${concurrent_status}" --argjson concurrent_score "${concurrent_score}" --arg concurrent_rate "${concurrent_rate}" \
       --argjson security_avg "${security_avg}" --argjson performance_avg "${performance_avg}" --argjson overall_avg "${overall_avg}" \
       '.results[$domain] = {
         "security_tests": {
           "ssl_labs_rating": {"status": $ssl_status, "score": $ssl_score, "grade": $ssl_grade},
           "cipher_strength": {"status": $cipher_status, "score": $cipher_score},
           "hsts_implementation": {"status": $hsts_status, "score": $hsts_score},
           "csp_implementation": {"status": $csp_status, "score": $csp_score},
           "oauth_headers": {"status": $oauth_status, "score": $oauth_score}
         },
         "performance_tests": {
           "page_load_time": {"status": $page_status, "score": $page_score, "time": $page_time},
           "ssl_handshake_time": {"status": $handshake_status, "score": $handshake_score, "time": $handshake_time},
           "concurrent_connections": {"status": $concurrent_status, "score": $concurrent_score, "rate": $concurrent_rate}
         },
         "scores": {
           "security_average": $security_avg,
           "performance_average": $performance_avg,
           "overall_average": $overall_avg
         },
         "overall_status": (if $overall_avg >= 80 then "PASS" elif $overall_avg >= 60 then "WARN" else "FAIL" end)
       }' "${REPORT_FILE}" > "${temp_file}"
    
    mv "${temp_file}" "${REPORT_FILE}"
}

# Generate final summary
generate_summary() {
    local temp_file
    temp_file=$(mktemp)
    
    jq '.summary = {
      "total_domains": (.results | length),
      "security_score": ([.results[].scores.security_average] | add / length),
      "performance_score": ([.results[].scores.performance_average] | add / length),
      "overall_grade": (
        if ([.results[].scores.overall_average] | add / length) >= 90 then "A+"
        elif ([.results[].scores.overall_average] | add / length) >= 80 then "A"
        elif ([.results[].scores.overall_average] | add / length) >= 70 then "B"
        elif ([.results[].scores.overall_average] | add / length) >= 60 then "C"
        else "F" end
      ),
      "passed": [.results[] | select(.overall_status == "PASS")] | length,
      "failed": [.results[] | select(.overall_status == "FAIL")] | length,
      "warnings": [.results[] | select(.overall_status == "WARN")] | length,
      "test_completion": now
    }' "${REPORT_FILE}" > "${temp_file}"
    
    mv "${temp_file}" "${REPORT_FILE}"
}

# Main test runner
main() {
    log_info "Starting Performance and Security Validation Test Suite"
    
    # Check dependencies
    if ! command -v curl &> /dev/null; then
        log_error "curl is required for testing. Please install curl."
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        log_error "jq is required for JSON processing. Please install jq."
        exit 1
    fi
    
    if ! command -v openssl &> /dev/null; then
        log_error "openssl is required for SSL testing. Please install openssl."
        exit 1
    fi
    
    if ! command -v bc &> /dev/null; then
        log_warning "bc not found - some calculations may be impacted"
    fi
    
    # Initialize report
    init_report
    
    log_info "Testing domains: ${TEST_DOMAINS[*]}"
    
    # Test each domain
    for domain in "${TEST_DOMAINS[@]}"; do
        log_info "=== Testing ${domain} ==="
        
        # Run security tests
        ssl_labs_result=$(test_ssl_labs_rating "${domain}")
        cipher_result=$(test_cipher_suite_strength "${domain}")
        hsts_result=$(test_hsts_implementation "${domain}")
        csp_result=$(test_csp_implementation "${domain}")
        oauth_headers_result=$(test_oauth_security_headers "${domain}")
        
        # Run performance tests
        page_load_result=$(test_page_load_performance "${domain}")
        handshake_result=$(test_ssl_handshake_performance "${domain}")
        concurrent_result=$(test_concurrent_connections "${domain}")
        
        # Update report
        update_report "${domain}" "${ssl_labs_result}" "${cipher_result}" "${hsts_result}" \
                     "${csp_result}" "${oauth_headers_result}" "${page_load_result}" \
                     "${handshake_result}" "${concurrent_result}"
        
        log_info "=== Completed testing ${domain} ==="
        echo
    done
    
    # Generate final summary
    generate_summary
    
    # Display summary
    log_info "Performance and Security Validation Test Complete"
    log_info "Report saved to: ${REPORT_FILE}"
    
    # Display summary statistics
    local total passed failed warnings security_score performance_score overall_grade
    total=$(jq -r '.summary.total_domains' "${REPORT_FILE}")
    passed=$(jq -r '.summary.passed' "${REPORT_FILE}")
    failed=$(jq -r '.summary.failed' "${REPORT_FILE}")
    warnings=$(jq -r '.summary.warnings' "${REPORT_FILE}")
    security_score=$(jq -r '.summary.security_score' "${REPORT_FILE}")
    performance_score=$(jq -r '.summary.performance_score' "${REPORT_FILE}")
    overall_grade=$(jq -r '.summary.overall_grade' "${REPORT_FILE}")
    
    echo
    echo "=== SUMMARY ==="
    echo "Total Domains: ${total}"
    echo "Passed: ${passed}"
    echo "Failed: ${failed}"
    echo "Warnings: ${warnings}"
    echo "Security Score: ${security_score}/100"
    echo "Performance Score: ${performance_score}/100"
    echo "Overall Grade: ${overall_grade}"
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