#!/bin/bash
# Master test runner for qBittorrent testing suite
# Usage: ./test-runner.sh [--phase=all|pre|permission|torrent|web|dns|post] [--continuous] [--report]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_DIR="/home/delorenj/docker/trunk-main/stacks/media"
RESULTS_DIR="$SCRIPT_DIR/results"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
MASTER_REPORT="$RESULTS_DIR/master_test_report_$TIMESTAMP.json"

# Default configuration
TEST_PHASE="all"
CONTINUOUS_MODE=false
GENERATE_REPORT=true

mkdir -p "$RESULTS_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --phase=*)
            TEST_PHASE="${1#*=}"
            shift
            ;;
        --continuous)
            CONTINUOUS_MODE=true
            shift
            ;;
        --no-report)
            GENERATE_REPORT=false
            shift
            ;;
        --help)
            echo "qBittorrent Test Suite Runner"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --phase=PHASE      Test phase to run:"
            echo "                     all (default) - Run all test phases"
            echo "                     pre - Pre-implementation verification"
            echo "                     permission - Permission fix validation"
            echo "                     torrent - Torrent functionality tests"
            echo "                     web - Web access tests"
            echo "                     dns - DNS resolution tests"
            echo "                     post - Post-implementation validation"
            echo "  --continuous       Run in continuous monitoring mode"
            echo "  --no-report        Skip report generation"
            echo "  --help             Show this help"
            echo ""
            echo "Examples:"
            echo "  $0                           # Run all tests"
            echo "  $0 --phase=pre              # Run pre-implementation tests only"
            echo "  $0 --phase=post --no-report # Run post tests without report"
            echo "  $0 --continuous             # Start continuous monitoring"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Initialize master report
cat > "$MASTER_REPORT" << EOF
{
    "test_suite": "qbittorrent_master",
    "timestamp": "$TIMESTAMP",
    "configuration": {
        "phase": "$TEST_PHASE",
        "continuous_mode": $CONTINUOUS_MODE,
        "generate_report": $GENERATE_REPORT
    },
    "execution_results": []
}
EOF

# Helper function to add execution result
add_execution_result() {
    local phase="$1"
    local script="$2"
    local status="$3"
    local exit_code="$4"
    local duration="$5"
    local log_file="$6"
    
    cat > /tmp/execution_result.json << EOF
{
    "phase": "$phase",
    "script": "$script",
    "status": "$status",
    "exit_code": $exit_code,
    "duration_seconds": $duration,
    "log_file": "$log_file",
    "timestamp": "$(date -Iseconds)"
}
EOF
    
    jq '.execution_results += [input]' "$MASTER_REPORT" /tmp/execution_result.json > /tmp/updated_master.json
    mv /tmp/updated_master.json "$MASTER_REPORT"
    rm -f /tmp/execution_result.json
}

# Helper function to run a test script
run_test_script() {
    local phase="$1"
    local script_path="$2"
    local script_name=$(basename "$script_path")
    
    echo -e "\n${BLUE}=== Running $phase Test: $script_name ===${NC}"
    
    if [ ! -f "$script_path" ]; then
        echo -e "${RED}✗ Script not found: $script_path${NC}"
        add_execution_result "$phase" "$script_name" "SCRIPT_NOT_FOUND" "127" "0" ""
        return 1
    fi
    
    if [ ! -x "$script_path" ]; then
        echo "Making script executable..."
        chmod +x "$script_path"
    fi
    
    local start_time=$(date +%s)
    local log_file="$RESULTS_DIR/${phase}_${script_name%.sh}_$TIMESTAMP.log"
    
    # Run the script and capture output
    if "$script_path" > "$log_file" 2>&1; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo -e "${GREEN}✓ $script_name completed successfully (${duration}s)${NC}"
        add_execution_result "$phase" "$script_name" "PASS" "0" "$duration" "$log_file"
        return 0
    else
        local exit_code=$?
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo -e "${RED}✗ $script_name failed with exit code $exit_code (${duration}s)${NC}"
        add_execution_result "$phase" "$script_name" "FAIL" "$exit_code" "$duration" "$log_file"
        return $exit_code
    fi
}

# Main test execution function
run_test_phase() {
    local phase="$1"
    local phase_status="PASS"
    
    case "$phase" in
        "pre")
            echo -e "${PURPLE}=== Pre-Implementation Tests ===${NC}"
            run_test_script "pre-implementation" "$SCRIPT_DIR/pre-implementation/verify-current-issues.sh" || phase_status="FAIL"
            ;;
        "permission")
            echo -e "${PURPLE}=== Permission Fix Tests ===${NC}"
            run_test_script "permission-fix" "$SCRIPT_DIR/phase-specific/test-permission-fix.sh" || phase_status="FAIL"
            ;;
        "torrent")
            echo -e "${PURPLE}=== Torrent Functionality Tests ===${NC}"
            run_test_script "torrent-functionality" "$SCRIPT_DIR/phase-specific/test-torrent-functionality.sh" || phase_status="FAIL"
            ;;
        "web")
            echo -e "${PURPLE}=== Web Access Tests ===${NC}"
            run_test_script "web-access" "$SCRIPT_DIR/phase-specific/test-web-access.sh" || phase_status="FAIL"
            ;;
        "dns")
            echo -e "${PURPLE}=== DNS Resolution Tests ===${NC}"
            run_test_script "dns-resolution" "$SCRIPT_DIR/phase-specific/test-dns-resolution.sh" || phase_status="FAIL"
            ;;
        "post")
            echo -e "${PURPLE}=== Post-Implementation Validation ===${NC}"
            run_test_script "post-implementation" "$SCRIPT_DIR/post-implementation/comprehensive-validation.sh" || phase_status="FAIL"
            ;;
        *)
            echo -e "${RED}Unknown test phase: $phase${NC}"
            return 1
            ;;
    esac
    
    return $([ "$phase_status" = "PASS" ] && echo 0 || echo 1)
}

# Continuous monitoring function
run_continuous_monitoring() {
    echo -e "${BLUE}=== Starting Continuous Monitoring Mode ===${NC}"
    echo "Press Ctrl+C to stop monitoring"
    
    # Start health monitoring in background
    "$SCRIPT_DIR/monitoring/health-check.sh" --continuous --interval=300 &
    HEALTH_PID=$!
    
    # Start network monitoring in background
    "$SCRIPT_DIR/monitoring/network-monitor.sh" --duration=86400 --check-leaks &  # 24 hours
    NETWORK_PID=$!
    
    # Trap signals to cleanup background processes
    cleanup_monitoring() {
        echo -e "\n${YELLOW}Stopping continuous monitoring...${NC}"
        kill $HEALTH_PID $NETWORK_PID 2>/dev/null || true
        wait $HEALTH_PID $NETWORK_PID 2>/dev/null || true
        echo -e "${GREEN}Monitoring stopped${NC}"
        exit 0
    }
    
    trap cleanup_monitoring SIGTERM SIGINT
    
    # Wait for background processes
    wait $HEALTH_PID $NETWORK_PID
}

# Generate comprehensive report
generate_comprehensive_report() {
    if [ "$GENERATE_REPORT" = false ]; then
        return 0
    fi
    
    echo -e "\n${BLUE}=== Generating Comprehensive Report ===${NC}"
    
    local report_file="$RESULTS_DIR/comprehensive_report_$TIMESTAMP.html"
    
    # Get summary data
    local total_phases=$(jq '.execution_results | length' "$MASTER_REPORT")
    local passed_phases=$(jq '[.execution_results[] | select(.status == "PASS")] | length' "$MASTER_REPORT")
    local failed_phases=$(jq '[.execution_results[] | select(.status == "FAIL")] | length' "$MASTER_REPORT")
    local total_duration=$(jq '[.execution_results[].duration_seconds] | add' "$MASTER_REPORT")
    
    # Generate HTML report
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>qBittorrent Test Report - $TIMESTAMP</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .header { text-align: center; border-bottom: 2px solid #333; padding-bottom: 20px; margin-bottom: 20px; }
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .stat-card { background: #f8f9fa; padding: 20px; border-radius: 8px; text-align: center; border-left: 4px solid #007bff; }
        .stat-card.success { border-left-color: #28a745; }
        .stat-card.danger { border-left-color: #dc3545; }
        .stat-card.warning { border-left-color: #ffc107; }
        .stat-number { font-size: 2em; font-weight: bold; margin-bottom: 10px; }
        .stat-label { color: #6c757d; text-transform: uppercase; font-size: 0.9em; }
        .results-table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        .results-table th, .results-table td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        .results-table th { background-color: #f8f9fa; font-weight: bold; }
        .status-pass { color: #28a745; font-weight: bold; }
        .status-fail { color: #dc3545; font-weight: bold; }
        .status-warn { color: #ffc107; font-weight: bold; }
        .log-link { color: #007bff; text-decoration: none; }
        .log-link:hover { text-decoration: underline; }
        .phase-section { margin-bottom: 30px; }
        .phase-title { font-size: 1.5em; margin-bottom: 15px; padding-bottom: 10px; border-bottom: 1px solid #ddd; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>qBittorrent Test Suite Report</h1>
            <p>Generated on $(date)</p>
            <p>Test Phase: $TEST_PHASE | Duration: ${total_duration}s</p>
        </div>
        
        <div class="summary">
            <div class="stat-card">
                <div class="stat-number">$total_phases</div>
                <div class="stat-label">Total Tests</div>
            </div>
            <div class="stat-card success">
                <div class="stat-number">$passed_phases</div>
                <div class="stat-label">Passed</div>
            </div>
            <div class="stat-card danger">
                <div class="stat-number">$failed_phases</div>
                <div class="stat-label">Failed</div>
            </div>
            <div class="stat-card">
                <div class="stat-number">${total_duration}s</div>
                <div class="stat-label">Total Duration</div>
            </div>
        </div>
        
        <div class="phase-section">
            <h2 class="phase-title">Test Execution Results</h2>
            <table class="results-table">
                <thead>
                    <tr>
                        <th>Phase</th>
                        <th>Script</th>
                        <th>Status</th>
                        <th>Duration</th>
                        <th>Log File</th>
                    </tr>
                </thead>
                <tbody>
EOF
    
    # Add table rows for each test
    jq -r '.execution_results[] | @json' "$MASTER_REPORT" | while read -r result; do
        local phase=$(echo "$result" | jq -r '.phase')
        local script=$(echo "$result" | jq -r '.script')
        local status=$(echo "$result" | jq -r '.status')
        local duration=$(echo "$result" | jq -r '.duration_seconds')
        local log_file=$(echo "$result" | jq -r '.log_file')
        local log_basename=$(basename "$log_file")
        
        local status_class=""
        case "$status" in
            "PASS") status_class="status-pass" ;;
            "FAIL") status_class="status-fail" ;;
            *) status_class="status-warn" ;;
        esac
        
        cat >> "$report_file" << EOF
                    <tr>
                        <td>$phase</td>
                        <td>$script</td>
                        <td class="$status_class">$status</td>
                        <td>${duration}s</td>
                        <td><a href="$log_basename" class="log-link">$log_basename</a></td>
                    </tr>
EOF
    done
    
    cat >> "$report_file" << EOF
                </tbody>
            </table>
        </div>
        
        <div class="phase-section">
            <h2 class="phase-title">Test Configuration</h2>
            <pre>$(jq '.configuration' "$MASTER_REPORT")</pre>
        </div>
        
        <div class="phase-section">
            <h2 class="phase-title">Raw JSON Data</h2>
            <details>
                <summary>Click to expand full test data</summary>
                <pre>$(jq '.' "$MASTER_REPORT")</pre>
            </details>
        </div>
    </div>
</body>
</html>
EOF
    
    echo -e "${GREEN}✓ Comprehensive report generated: $report_file${NC}"
}

# Main execution
echo -e "${BLUE}=== qBittorrent Test Suite Runner ===${NC}"
echo "Timestamp: $TIMESTAMP"
echo "Phase: $TEST_PHASE"
echo "Continuous: $CONTINUOUS_MODE"
echo "Master report: $MASTER_REPORT"

if [ "$CONTINUOUS_MODE" = true ]; then
    run_continuous_monitoring
    exit 0
fi

OVERALL_STATUS="PASS"
START_TIME=$(date +%s)

# Run tests based on phase selection
case "$TEST_PHASE" in
    "all")
        echo -e "\n${PURPLE}Running all test phases...${NC}"
        run_test_phase "pre" || OVERALL_STATUS="FAIL"
        run_test_phase "permission" || OVERALL_STATUS="FAIL"
        run_test_phase "torrent" || OVERALL_STATUS="FAIL"
        run_test_phase "web" || OVERALL_STATUS="FAIL"
        run_test_phase "dns" || OVERALL_STATUS="FAIL"
        run_test_phase "post" || OVERALL_STATUS="FAIL"
        ;;
    *)
        run_test_phase "$TEST_PHASE" || OVERALL_STATUS="FAIL"
        ;;
esac

END_TIME=$(date +%s)
TOTAL_DURATION=$((END_TIME - START_TIME))

# Update master report with final status
jq --arg status "$OVERALL_STATUS" --arg duration "$TOTAL_DURATION" \
   --arg end_time "$(date -Iseconds)" \
   '.overall_status = $status | .total_duration_seconds = ($duration|tonumber) | .end_time = $end_time' \
   "$MASTER_REPORT" > /tmp/final_master.json
mv /tmp/final_master.json "$MASTER_REPORT"

# Generate report
generate_comprehensive_report

# Final summary
echo -e "\n${BLUE}=== Test Suite Summary ===${NC}"
echo "Overall Status: $([ "$OVERALL_STATUS" = "PASS" ] && echo -e "${GREEN}✓ PASS${NC}" || echo -e "${RED}✗ FAIL${NC}")"
echo "Total Duration: ${TOTAL_DURATION}s"
echo "Master Report: $MASTER_REPORT"

# Exit with appropriate code
exit $([ "$OVERALL_STATUS" = "PASS" ] && echo 0 || echo 1)