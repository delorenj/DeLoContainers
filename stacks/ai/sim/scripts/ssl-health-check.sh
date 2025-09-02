#!/bin/bash

# 🎪 SIM STUDIO SSL HEALTH CHECK SCRIPT 🎪
# The void's chosen guardian of SSL certificates!
# This script monitors SSL certificate health and performs validation

set -euo pipefail

# Configuration
DOMAIN="sim.delo.sh"
CERTIFICATE_PATH="/etc/traefik/acme.json"
LOG_FILE="/var/log/ssl-health-check.log"
ALERT_EMAIL="jaradd@gmail.com"
EXPIRY_THRESHOLD_DAYS=30
SLACK_WEBHOOK="${SLACK_WEBHOOK:-}"

# Colors for dramatic output (because the void loves theatrics!)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging function with theatrical flair
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

# Banner function (because every good script needs drama!)
print_banner() {
    echo -e "${PURPLE}"
    echo "🎪 ============================================== 🎪"
    echo "    SIM STUDIO SSL HEALTH CHECK ORCHESTRATOR"
    echo "       The Void's Certificate Guardian™"
    echo "🎪 ============================================== 🎪"
    echo -e "${NC}"
}

# Check if domain is accessible via HTTPS
check_https_accessibility() {
    log_info "Checking HTTPS accessibility for ${DOMAIN}..."
    
    local response_code
    response_code=$(curl -s -o /dev/null -w "%{http_code}" "https://${DOMAIN}" --max-time 10 || echo "000")
    
    if [ "$response_code" -eq 200 ]; then
        log_success "✅ HTTPS accessible - Response code: ${response_code}"
        return 0
    else
        log_error "❌ HTTPS not accessible - Response code: ${response_code}"
        return 1
    fi
}

# Check SSL certificate expiration
check_certificate_expiration() {
    log_info "Checking SSL certificate expiration for ${DOMAIN}..."
    
    local cert_info
    cert_info=$(openssl s_client -servername "${DOMAIN}" -connect "${DOMAIN}:443" </dev/null 2>/dev/null | openssl x509 -noout -dates 2>/dev/null)
    
    if [ -z "$cert_info" ]; then
        log_error "❌ Failed to retrieve certificate information"
        return 1
    fi
    
    local not_after
    not_after=$(echo "$cert_info" | grep "notAfter=" | cut -d= -f2)
    
    if [ -z "$not_after" ]; then
        log_error "❌ Failed to parse certificate expiration date"
        return 1
    fi
    
    local expiry_date
    expiry_date=$(date -d "$not_after" +%s)
    local current_date
    current_date=$(date +%s)
    local days_until_expiry
    days_until_expiry=$(( (expiry_date - current_date) / 86400 ))
    
    log_info "📅 Certificate expires on: ${not_after}"
    log_info "⏰ Days until expiration: ${days_until_expiry}"
    
    if [ "$days_until_expiry" -lt "$EXPIRY_THRESHOLD_DAYS" ]; then
        log_warn "⚠️  Certificate expires in ${days_until_expiry} days (threshold: ${EXPIRY_THRESHOLD_DAYS} days)"
        send_expiry_alert "$days_until_expiry"
        return 1
    else
        log_success "✅ Certificate is valid for ${days_until_expiry} more days"
        return 0
    fi
}

# Check SSL certificate chain
check_certificate_chain() {
    log_info "Validating SSL certificate chain for ${DOMAIN}..."
    
    local chain_result
    if chain_result=$(openssl s_client -servername "${DOMAIN}" -connect "${DOMAIN}:443" -verify_return_error </dev/null 2>&1); then
        log_success "✅ Certificate chain is valid"
        return 0
    else
        log_error "❌ Certificate chain validation failed:"
        echo "$chain_result" | grep -E "(verify error|error:|unable to)" | head -5
        return 1
    fi
}

# Check SSL security rating (using SSL Labs API simulation)
check_ssl_security() {
    log_info "Checking SSL security configuration for ${DOMAIN}..."
    
    # Check supported TLS versions
    local tls_versions=()
    
    for version in "tls1" "tls1_1" "tls1_2" "tls1_3"; do
        if openssl s_client -servername "${DOMAIN}" -connect "${DOMAIN}:443" "-${version}" </dev/null 2>/dev/null | grep -q "Verify return code: 0"; then
            tls_versions+=("$version")
        fi
    done
    
    log_info "🔒 Supported TLS versions: ${tls_versions[*]}"
    
    # Check for weak protocols (should be disabled)
    local weak_protocols=("tls1" "tls1_1")
    local has_weak=false
    
    for weak in "${weak_protocols[@]}"; do
        if [[ " ${tls_versions[*]} " =~ " ${weak} " ]]; then
            log_warn "⚠️  Weak protocol ${weak} is enabled"
            has_weak=true
        fi
    done
    
    # Check for modern protocols (should be enabled)
    local modern_protocols=("tls1_2" "tls1_3")
    local has_modern=false
    
    for modern in "${modern_protocols[@]}"; do
        if [[ " ${tls_versions[*]} " =~ " ${modern} " ]]; then
            log_success "✅ Modern protocol ${modern} is enabled"
            has_modern=true
        fi
    done
    
    if [ "$has_modern" = true ] && [ "$has_weak" = false ]; then
        log_success "✅ SSL security configuration is optimal"
        return 0
    else
        log_warn "⚠️  SSL security configuration needs improvement"
        return 1
    fi
}

# Check OAuth endpoints accessibility
check_oauth_endpoints() {
    log_info "Checking OAuth callback endpoints accessibility..."
    
    local oauth_paths=(
        "/api/auth/oauth2/callback/github-repo"
        "/api/auth/oauth2/callback/google"
        "/api/auth/oauth/credentials"
        "/api/auth/oauth/token"
    )
    
    local failed_count=0
    
    for path in "${oauth_paths[@]}"; do
        local url="https://${DOMAIN}${path}"
        local response_code
        response_code=$(curl -s -o /dev/null -w "%{http_code}" "$url" --max-time 5 || echo "000")
        
        # OAuth endpoints should return 4xx (not 5xx or 000) when accessed without proper parameters
        if [[ "$response_code" =~ ^[4][0-9][0-9]$ ]]; then
            log_success "✅ OAuth endpoint accessible: ${path} (${response_code})"
        else
            log_error "❌ OAuth endpoint issue: ${path} (${response_code})"
            ((failed_count++))
        fi
    done
    
    if [ "$failed_count" -eq 0 ]; then
        log_success "✅ All OAuth endpoints are accessible"
        return 0
    else
        log_error "❌ ${failed_count} OAuth endpoint(s) failed accessibility check"
        return 1
    fi
}

# Send expiry alert
send_expiry_alert() {
    local days="$1"
    local subject="🚨 SSL Certificate Expiry Alert - ${DOMAIN}"
    local message="The SSL certificate for ${DOMAIN} will expire in ${days} days. Please renew it soon!"
    
    log_warn "📧 Sending expiry alert..."
    
    # Send email if configured
    if command -v mail >/dev/null 2>&1; then
        echo "$message" | mail -s "$subject" "$ALERT_EMAIL" 2>/dev/null || true
    fi
    
    # Send Slack notification if webhook is configured
    if [ -n "$SLACK_WEBHOOK" ]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"$subject\\n$message\"}" \
            "$SLACK_WEBHOOK" 2>/dev/null || true
    fi
    
    log_info "📨 Alert notifications sent"
}

# Check Traefik certificate renewal
check_traefik_renewal() {
    log_info "Checking Traefik Let's Encrypt certificate status..."
    
    if [ -f "$CERTIFICATE_PATH" ]; then
        local cert_count
        cert_count=$(jq -r '.letsencrypt.Certificates | length' "$CERTIFICATE_PATH" 2>/dev/null || echo "0")
        
        if [ "$cert_count" -gt 0 ]; then
            log_success "✅ Traefik has ${cert_count} Let's Encrypt certificate(s)"
            
            # Check if our domain is in the certificates
            local domain_found
            domain_found=$(jq -r ".letsencrypt.Certificates[] | select(.domain.main == \"$DOMAIN\") | .domain.main" "$CERTIFICATE_PATH" 2>/dev/null || echo "")
            
            if [ -n "$domain_found" ]; then
                log_success "✅ Certificate for ${DOMAIN} found in Traefik store"
                return 0
            else
                log_warn "⚠️  Certificate for ${DOMAIN} not found in Traefik store"
                return 1
            fi
        else
            log_error "❌ No Let's Encrypt certificates found in Traefik store"
            return 1
        fi
    else
        log_error "❌ Traefik certificate file not found: ${CERTIFICATE_PATH}"
        return 1
    fi
}

# Main health check orchestration
main() {
    print_banner
    
    log_info "🎭 Starting SSL health check orchestration for ${DOMAIN}"
    log_info "📅 Timestamp: $(date)"
    log_info "🎯 Expiry threshold: ${EXPIRY_THRESHOLD_DAYS} days"
    
    local checks_passed=0
    local total_checks=6
    
    # Run all health checks
    check_https_accessibility && ((checks_passed++)) || true
    check_certificate_expiration && ((checks_passed++)) || true
    check_certificate_chain && ((checks_passed++)) || true
    check_ssl_security && ((checks_passed++)) || true
    check_oauth_endpoints && ((checks_passed++)) || true
    check_traefik_renewal && ((checks_passed++)) || true
    
    # Summary
    echo -e "\n${PURPLE}🎪 ============== HEALTH CHECK SUMMARY ============== 🎪${NC}"
    log_info "📊 Checks passed: ${checks_passed}/${total_checks}"
    
    if [ "$checks_passed" -eq "$total_checks" ]; then
        log_success "🎉 ALL CHECKS PASSED! The void is pleased with your SSL configuration!"
        echo -e "${GREEN}🏆 INFRASTRUCTURE STATUS: MAGNIFICENT! 🏆${NC}"
        exit 0
    elif [ "$checks_passed" -ge $((total_checks * 2 / 3)) ]; then
        log_warn "🎭 Most checks passed, but some issues need attention."
        echo -e "${YELLOW}⚠️  INFRASTRUCTURE STATUS: NEEDS ATTENTION ⚠️${NC}"
        exit 1
    else
        log_error "🚨 Multiple critical issues detected!"
        echo -e "${RED}🔥 INFRASTRUCTURE STATUS: CRITICAL ISSUES! 🔥${NC}"
        exit 2
    fi
}

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Run the main function
main "$@"