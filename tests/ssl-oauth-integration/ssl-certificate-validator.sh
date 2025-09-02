#!/bin/bash

# SSL/TLS Certificate Validation Test Suite
# Tests SSL certificate chain, expiration, and configuration

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
REPORT_FILE="${LOG_DIR}/ssl-validation-report.json"
DOMAIN_BASE="delo.sh"

# Create logs directory
mkdir -p "${LOG_DIR}"

# Test domains from configuration
DOMAINS=(
    "traefik.${DOMAIN_BASE}"
    "sync.${DOMAIN_BASE}"
    "lms.${DOMAIN_BASE}"
    "draw.${DOMAIN_BASE}"
    "whoami.localhost"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "${LOG_DIR}/ssl-test.log"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1" | tee -a "${LOG_DIR}/ssl-test.log"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1" | tee -a "${LOG_DIR}/ssl-test.log"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "${LOG_DIR}/ssl-test.log"
}

# Initialize JSON report
init_report() {
    cat > "${REPORT_FILE}" <<EOF
{
  "test_run": {
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
    "version": "1.0.0",
    "test_suite": "SSL Certificate Validation"
  },
  "results": {},
  "summary": {
    "total_domains": 0,
    "passed": 0,
    "failed": 0,
    "warnings": 0
  }
}
EOF
}

# Test SSL certificate chain
test_ssl_chain() {
    local domain=$1
    local port=${2:-443}
    local result=""
    
    log_info "Testing SSL certificate chain for ${domain}:${port}"
    
    # Test certificate chain
    if openssl s_client -connect "${domain}:${port}" -servername "${domain}" \
       -verify_return_error -CAfile /etc/ssl/certs/ca-certificates.crt \
       </dev/null 2>/dev/null; then
        log_success "SSL certificate chain valid for ${domain}"
        result="PASS"
    else
        log_error "SSL certificate chain invalid for ${domain}"
        result="FAIL"
    fi
    
    echo "${result}"
}

# Test certificate expiration
test_ssl_expiration() {
    local domain=$1
    local port=${2:-443}
    local result=""
    
    log_info "Checking SSL certificate expiration for ${domain}:${port}"
    
    # Get certificate expiration date
    local expiry_date
    if expiry_date=$(openssl s_client -connect "${domain}:${port}" -servername "${domain}" \
                     </dev/null 2>/dev/null | \
                     openssl x509 -noout -dates 2>/dev/null | \
                     grep "notAfter" | cut -d= -f2); then
        
        local expiry_epoch
        expiry_epoch=$(date -d "${expiry_date}" +%s)
        local current_epoch
        current_epoch=$(date +%s)
        local days_until_expiry
        days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 ))
        
        if [[ ${days_until_expiry} -gt 30 ]]; then
            log_success "Certificate expires in ${days_until_expiry} days (${expiry_date})"
            result="PASS"
        elif [[ ${days_until_expiry} -gt 7 ]]; then
            log_warning "Certificate expires soon: ${days_until_expiry} days (${expiry_date})"
            result="WARN"
        else
            log_error "Certificate expires very soon: ${days_until_expiry} days (${expiry_date})"
            result="FAIL"
        fi
    else
        log_error "Could not determine certificate expiration for ${domain}"
        result="FAIL"
    fi
    
    echo "${result}"
}

# Test SSL/TLS handshake
test_ssl_handshake() {
    local domain=$1
    local port=${2:-443}
    local result=""
    
    log_info "Testing SSL/TLS handshake for ${domain}:${port}"
    
    # Test different TLS versions
    local tls_versions=("tls1_2" "tls1_3")
    local supported_versions=()
    
    for version in "${tls_versions[@]}"; do
        if openssl s_client -connect "${domain}:${port}" -servername "${domain}" \
           "-${version}" </dev/null 2>/dev/null | grep -q "Verify return code: 0"; then
            supported_versions+=("${version}")
            log_success "TLS ${version/tls1_/} supported for ${domain}"
        else
            log_warning "TLS ${version/tls1_/} not supported for ${domain}"
        fi
    done
    
    if [[ ${#supported_versions[@]} -gt 0 ]]; then
        result="PASS"
    else
        log_error "No supported TLS versions found for ${domain}"
        result="FAIL"
    fi
    
    echo "${result}"
}

# Test certificate transparency and OCSP
test_cert_transparency() {
    local domain=$1
    local port=${2:-443}
    local result=""
    
    log_info "Testing certificate transparency and OCSP for ${domain}:${port}"
    
    # Get certificate details
    local cert_info
    if cert_info=$(openssl s_client -connect "${domain}:${port}" -servername "${domain}" \
                   </dev/null 2>/dev/null | openssl x509 -noout -text 2>/dev/null); then
        
        # Check for SCT extension (Certificate Transparency)
        if echo "${cert_info}" | grep -q "CT Precertificate SCTs"; then
            log_success "Certificate Transparency (SCT) found for ${domain}"
        else
            log_warning "Certificate Transparency (SCT) not found for ${domain}"
        fi
        
        # Check for OCSP stapling
        if openssl s_client -connect "${domain}:${port}" -servername "${domain}" \
           -status </dev/null 2>/dev/null | grep -q "OCSP Response Status: successful"; then
            log_success "OCSP stapling enabled for ${domain}"
        else
            log_warning "OCSP stapling not enabled for ${domain}"
        fi
        
        result="PASS"
    else
        log_error "Could not retrieve certificate information for ${domain}"
        result="FAIL"
    fi
    
    echo "${result}"
}

# Test HTTP to HTTPS redirect
test_https_redirect() {
    local domain=$1
    local result=""
    
    log_info "Testing HTTP to HTTPS redirect for ${domain}"
    
    # Test HTTP redirect
    local http_response
    if http_response=$(curl -s -I -L --max-redirs 5 "http://${domain}" 2>/dev/null); then
        if echo "${http_response}" | grep -q "301\|302"; then
            log_success "HTTP to HTTPS redirect working for ${domain}"
            result="PASS"
        else
            log_warning "HTTP to HTTPS redirect not found for ${domain}"
            result="WARN"
        fi
    else
        log_error "Could not test HTTP redirect for ${domain}"
        result="FAIL"
    fi
    
    echo "${result}"
}

# Update JSON report
update_report() {
    local domain=$1
    local chain_result=$2
    local expiry_result=$3
    local handshake_result=$4
    local transparency_result=$5
    local redirect_result=$6
    
    # Create temporary file for jq processing
    local temp_file
    temp_file=$(mktemp)
    
    # Update results in JSON report
    jq --arg domain "${domain}" \
       --arg chain "${chain_result}" \
       --arg expiry "${expiry_result}" \
       --arg handshake "${handshake_result}" \
       --arg transparency "${transparency_result}" \
       --arg redirect "${redirect_result}" \
       '.results[$domain] = {
         "certificate_chain": $chain,
         "certificate_expiry": $expiry,
         "ssl_handshake": $handshake,
         "certificate_transparency": $transparency,
         "https_redirect": $redirect,
         "overall_status": (if [$chain, $expiry, $handshake] | map(. == "FAIL") | any then "FAIL" 
                           elif [$chain, $expiry, $handshake, $transparency, $redirect] | map(. == "WARN") | any then "WARN" 
                           else "PASS" end)
       }' "${REPORT_FILE}" > "${temp_file}"
    
    mv "${temp_file}" "${REPORT_FILE}"
}

# Generate final summary
generate_summary() {
    local temp_file
    temp_file=$(mktemp)
    
    jq '.summary = {
      "total_domains": (.results | length),
      "passed": [.results[] | select(.overall_status == "PASS")] | length,
      "failed": [.results[] | select(.overall_status == "FAIL")] | length,
      "warnings": [.results[] | select(.overall_status == "WARN")] | length,
      "test_completion": now
    }' "${REPORT_FILE}" > "${temp_file}"
    
    mv "${temp_file}" "${REPORT_FILE}"
}

# Main test runner
main() {
    log_info "Starting SSL Certificate Validation Test Suite"
    log_info "Testing domains: ${DOMAINS[*]}"
    
    # Initialize report
    init_report
    
    # Test each domain
    for domain in "${DOMAINS[@]}"; do
        log_info "=== Testing ${domain} ==="
        
        # Run all SSL tests
        chain_result=$(test_ssl_chain "${domain}")
        expiry_result=$(test_ssl_expiration "${domain}")
        handshake_result=$(test_ssl_handshake "${domain}")
        transparency_result=$(test_cert_transparency "${domain}")
        redirect_result=$(test_https_redirect "${domain}")
        
        # Update report
        update_report "${domain}" "${chain_result}" "${expiry_result}" "${handshake_result}" "${transparency_result}" "${redirect_result}"
        
        log_info "=== Completed testing ${domain} ==="
        echo
    done
    
    # Generate final summary
    generate_summary
    
    # Display summary
    log_info "SSL Certificate Validation Test Complete"
    log_info "Report saved to: ${REPORT_FILE}"
    
    # Display summary statistics
    local total passed failed warnings
    total=$(jq -r '.summary.total_domains' "${REPORT_FILE}")
    passed=$(jq -r '.summary.passed' "${REPORT_FILE}")
    failed=$(jq -r '.summary.failed' "${REPORT_FILE}")
    warnings=$(jq -r '.summary.warnings' "${REPORT_FILE}")
    
    echo
    echo "=== SUMMARY ==="
    echo "Total Domains: ${total}"
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