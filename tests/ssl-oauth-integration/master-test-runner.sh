#!/bin/bash

# Master SSL/OAuth Integration Test Runner
# Orchestrates all SSL and OAuth integration tests

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
MASTER_REPORT="${LOG_DIR}/master-integration-report.json"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Create logs directory
mkdir -p "${LOG_DIR}"

# Test scripts
TEST_SCRIPTS=(
    "ssl-certificate-validator.sh"
    "oauth-flow-tester.sh"
    "cross-browser-tester.sh"
    "performance-security-validator.sh"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Banner
print_banner() {
    echo -e "${BOLD}${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║               SSL/OAuth Integration Test Suite               ║"
    echo "║                                                              ║"
    echo "║  Comprehensive testing of SSL certificates, OAuth flows,    ║"
    echo "║  cross-browser compatibility, and security validation       ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo
}

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "${LOG_DIR}/master-test.log"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1" | tee -a "${LOG_DIR}/master-test.log"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1" | tee -a "${LOG_DIR}/master-test.log"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "${LOG_DIR}/master-test.log"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing_tools=()
    local required_tools=("curl" "openssl" "jq")
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "${tool}" &> /dev/null; then
            missing_tools+=("${tool}")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_error "Please install missing tools before running tests"
        exit 1
    fi
    
    log_success "All prerequisites satisfied"
}

# Initialize master report
init_master_report() {
    cat > "${MASTER_REPORT}" <<EOF
{
  "test_run": {
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
    "version": "1.0.0",
    "test_suite": "SSL/OAuth Integration Master Suite"
  },
  "test_results": {},
  "summary": {
    "total_test_suites": ${#TEST_SCRIPTS[@]},
    "passed_suites": 0,
    "failed_suites": 0,
    "warning_suites": 0,
    "overall_status": "PENDING"
  },
  "recommendations": []
}
EOF
}

# Run individual test script
run_test_script() {
    local script_name=$1
    local script_path="${SCRIPT_DIR}/${script_name}"
    local result_status="UNKNOWN"
    local exit_code=0
    
    log_info "Running test script: ${script_name}"
    
    if [[ ! -x "${script_path}" ]]; then
        log_error "Test script not found or not executable: ${script_path}"
        result_status="FAIL"
        exit_code=1
    else
        # Run the test script and capture exit code
        local start_time end_time duration
        start_time=$(date +%s)
        
        if "${script_path}" > "${LOG_DIR}/${script_name%.sh}.output" 2>&1; then
            exit_code=0
            result_status="PASS"
            log_success "Test script completed: ${script_name}"
        elif [[ $? -eq 2 ]]; then
            exit_code=2
            result_status="WARN"
            log_warning "Test script completed with warnings: ${script_name}"
        else
            exit_code=1
            result_status="FAIL"
            log_error "Test script failed: ${script_name}"
        fi
        
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        
        # Update master report with individual test results
        update_master_report "${script_name}" "${result_status}" "${exit_code}" "${duration}"
    fi
    
    echo "${result_status}|${exit_code}"
}

# Update master report with test results
update_master_report() {
    local script_name=$1
    local status=$2
    local exit_code=$3
    local duration=$4
    
    # Find the corresponding report file
    local report_file=""
    case "${script_name}" in
        "ssl-certificate-validator.sh")
            report_file="${LOG_DIR}/ssl-validation-report.json"
            ;;
        "oauth-flow-tester.sh")
            report_file="${LOG_DIR}/oauth-test-report.json"
            ;;
        "cross-browser-tester.sh")
            report_file="${LOG_DIR}/browser-compatibility-report.json"
            ;;
        "performance-security-validator.sh")
            report_file="${LOG_DIR}/performance-security-report.json"
            ;;
    esac
    
    # Create temporary file for jq processing
    local temp_file
    temp_file=$(mktemp)
    
    # Extract summary from individual report if it exists
    local individual_summary="{}"
    if [[ -f "${report_file}" ]]; then
        individual_summary=$(jq '.summary // {}' "${report_file}" 2>/dev/null || echo '{}')
    fi
    
    # Update master report
    jq --arg script "${script_name}" \
       --arg status "${status}" \
       --argjson exit_code "${exit_code}" \
       --argjson duration "${duration}" \
       --argjson summary "${individual_summary}" \
       '.test_results[$script] = {
         "status": $status,
         "exit_code": $exit_code,
         "duration_seconds": $duration,
         "individual_summary": $summary,
         "report_file": "'${report_file}'"
       }' "${MASTER_REPORT}" > "${temp_file}"
    
    mv "${temp_file}" "${MASTER_REPORT}"
}

# Generate final master summary
generate_master_summary() {
    local temp_file
    temp_file=$(mktemp)
    
    jq '.summary = {
      "total_test_suites": (.test_results | length),
      "passed_suites": [.test_results[] | select(.status == "PASS")] | length,
      "failed_suites": [.test_results[] | select(.status == "FAIL")] | length,
      "warning_suites": [.test_results[] | select(.status == "WARN")] | length,
      "overall_status": (
        if [.test_results[].status] | map(. == "FAIL") | any then "FAIL"
        elif [.test_results[].status] | map(. == "WARN") | any then "WARN"
        else "PASS" end
      ),
      "total_duration": [.test_results[].duration_seconds] | add,
      "test_completion": now
    }' "${MASTER_REPORT}" > "${temp_file}"
    
    mv "${temp_file}" "${MASTER_REPORT}"
}

# Generate recommendations based on test results
generate_recommendations() {
    local temp_file
    temp_file=$(mktemp)
    
    local recommendations=()
    
    # Check SSL certificate issues
    if jq -e '.test_results["ssl-certificate-validator.sh"].individual_summary.failed > 0' "${MASTER_REPORT}" >/dev/null 2>&1; then
        recommendations+=("\"Review SSL certificate configuration and renewal processes\"")
    fi
    
    # Check OAuth configuration issues
    if jq -e '.test_results["oauth-flow-tester.sh"].individual_summary.failed > 0' "${MASTER_REPORT}" >/dev/null 2>&1; then
        recommendations+=("\"Verify OAuth provider configurations and callback URLs\"")
    fi
    
    # Check browser compatibility issues
    if jq -e '.test_results["cross-browser-tester.sh"].individual_summary.failed > 0' "${MASTER_REPORT}" >/dev/null 2>&1; then
        recommendations+=("\"Address cross-browser compatibility issues with security headers\"")
    fi
    
    # Check performance and security issues
    if jq -e '.test_results["performance-security-validator.sh"].individual_summary.failed > 0' "${MASTER_REPORT}" >/dev/null 2>&1; then
        recommendations+=("\"Optimize performance and strengthen security configurations\"")
    fi
    
    # Add general recommendations
    recommendations+=("\"Implement continuous monitoring for SSL certificate expiration\"")
    recommendations+=("\"Consider implementing OAuth state validation and PKCE\"")
    recommendations+=("\"Regularly update security headers and CSP policies\"")
    recommendations+=("\"Monitor performance metrics and set up alerting\"")
    
    # Update master report with recommendations
    local recommendations_json="[$(IFS=','; echo "${recommendations[*]}")]"
    
    jq --argjson recommendations "${recommendations_json}" \
       '.recommendations = $recommendations' "${MASTER_REPORT}" > "${temp_file}"
    
    mv "${temp_file}" "${MASTER_REPORT}"
}

# Display comprehensive summary
display_summary() {
    echo
    echo -e "${BOLD}${BLUE}=== COMPREHENSIVE TEST SUMMARY ===${NC}"
    echo
    
    # Extract summary data
    local total_suites passed_suites failed_suites warning_suites overall_status total_duration
    total_suites=$(jq -r '.summary.total_test_suites' "${MASTER_REPORT}")
    passed_suites=$(jq -r '.summary.passed_suites' "${MASTER_REPORT}")
    failed_suites=$(jq -r '.summary.failed_suites' "${MASTER_REPORT}")
    warning_suites=$(jq -r '.summary.warning_suites' "${MASTER_REPORT}")
    overall_status=$(jq -r '.summary.overall_status' "${MASTER_REPORT}")
    total_duration=$(jq -r '.summary.total_duration' "${MASTER_REPORT}")
    
    # Display summary
    echo "Test Suites Run: ${total_suites}"
    echo "Passed: ${passed_suites}"
    echo "Failed: ${failed_suites}"
    echo "Warnings: ${warning_suites}"
    echo "Total Duration: ${total_duration} seconds"
    echo
    
    # Overall status with color
    case "${overall_status}" in
        "PASS")
            echo -e "Overall Status: ${GREEN}${overall_status}${NC}"
            ;;
        "WARN")
            echo -e "Overall Status: ${YELLOW}${overall_status}${NC}"
            ;;
        "FAIL")
            echo -e "Overall Status: ${RED}${overall_status}${NC}"
            ;;
        *)
            echo "Overall Status: ${overall_status}"
            ;;
    esac
    
    echo
    echo "=== INDIVIDUAL TEST RESULTS ==="
    
    # Display individual test results
    for script in "${TEST_SCRIPTS[@]}"; do
        local script_status script_duration
        script_status=$(jq -r ".test_results[\"${script}\"].status // \"UNKNOWN\"" "${MASTER_REPORT}")
        script_duration=$(jq -r ".test_results[\"${script}\"].duration_seconds // 0" "${MASTER_REPORT}")
        
        case "${script_status}" in
            "PASS")
                echo -e "${GREEN}✓${NC} ${script} (${script_duration}s)"
                ;;
            "WARN")
                echo -e "${YELLOW}⚠${NC} ${script} (${script_duration}s)"
                ;;
            "FAIL")
                echo -e "${RED}✗${NC} ${script} (${script_duration}s)"
                ;;
            *)
                echo -e "${RED}?${NC} ${script} - Status unknown"
                ;;
        esac
    done
    
    echo
    echo "=== RECOMMENDATIONS ==="
    local recommendations
    recommendations=$(jq -r '.recommendations[]' "${MASTER_REPORT}" 2>/dev/null)
    if [[ -n "${recommendations}" ]]; then
        while IFS= read -r recommendation; do
            echo "• ${recommendation}"
        done <<< "${recommendations}"
    else
        echo "No specific recommendations at this time."
    fi
    
    echo
    echo "=== REPORT LOCATIONS ==="
    echo "Master Report: ${MASTER_REPORT}"
    echo "Individual Reports:"
    echo "  - SSL Validation: ${LOG_DIR}/ssl-validation-report.json"
    echo "  - OAuth Testing: ${LOG_DIR}/oauth-test-report.json"
    echo "  - Browser Compatibility: ${LOG_DIR}/browser-compatibility-report.json"
    echo "  - Performance & Security: ${LOG_DIR}/performance-security-report.json"
    echo "Log Files: ${LOG_DIR}/"
    echo
}

# Main execution function
main() {
    local start_time end_time total_duration
    start_time=$(date +%s)
    
    print_banner
    
    log_info "Starting SSL/OAuth Integration Test Suite"
    log_info "Timestamp: $(date)"
    echo
    
    # Check prerequisites
    check_prerequisites
    
    # Initialize master report
    init_master_report
    
    # Track results
    local failed_tests=0
    local warning_tests=0
    
    # Run all test scripts
    for script in "${TEST_SCRIPTS[@]}"; do
        echo -e "${BOLD}${BLUE}=== Running ${script} ===${NC}"
        
        local result
        result=$(run_test_script "${script}")
        
        # Parse result
        IFS='|' read -r status exit_code <<< "${result}"
        
        case "${status}" in
            "FAIL")
                failed_tests=$((failed_tests + 1))
                ;;
            "WARN")
                warning_tests=$((warning_tests + 1))
                ;;
        esac
        
        echo
    done
    
    # Generate final summaries and recommendations
    generate_master_summary
    generate_recommendations
    
    # Calculate total duration
    end_time=$(date +%s)
    total_duration=$((end_time - start_time))
    
    # Update master report with total duration
    local temp_file
    temp_file=$(mktemp)
    jq --argjson duration "${total_duration}" \
       '.summary.actual_total_duration = $duration' "${MASTER_REPORT}" > "${temp_file}"
    mv "${temp_file}" "${MASTER_REPORT}"
    
    # Display comprehensive summary
    display_summary
    
    log_info "SSL/OAuth Integration Test Suite completed in ${total_duration} seconds"
    
    # Return appropriate exit code
    if [[ ${failed_tests} -gt 0 ]]; then
        exit 1
    elif [[ ${warning_tests} -gt 0 ]]; then
        exit 2
    else
        exit 0
    fi
}

# Handle script arguments
case "${1:-}" in
    "--help"|"-h")
        echo "SSL/OAuth Integration Test Suite"
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --version, -v  Show version information"
        echo ""
        echo "This script runs a comprehensive test suite for SSL certificates"
        echo "and OAuth authentication flows, including:"
        echo "  - SSL certificate validation"
        echo "  - OAuth flow testing"
        echo "  - Cross-browser compatibility"
        echo "  - Performance and security validation"
        exit 0
        ;;
    "--version"|"-v")
        echo "SSL/OAuth Integration Test Suite v1.0.0"
        exit 0
        ;;
    "")
        # No arguments, run normally
        main "$@"
        ;;
    *)
        echo "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac