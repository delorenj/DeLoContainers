#!/bin/bash

# Master Memory Leak Investigation Script
# Orchestrates all analysis tools and generates comprehensive report

set -euo pipefail

SCRIPT_DIR="/home/delorenj/docker/trunk-main/scripts/log-analysis"
LOG_DIR="$SCRIPT_DIR/reports"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
MASTER_REPORT="$LOG_DIR/master_memory_investigation_$TIMESTAMP.txt"

mkdir -p "$LOG_DIR"

echo "================================================================================================="
echo "COMPREHENSIVE MEMORY LEAK INVESTIGATION"
echo "================================================================================================="
echo "Starting at: $(date)"
echo "Report will be saved to: $MASTER_REPORT"
echo ""

# Initialize master report
cat > "$MASTER_REPORT" << EOF
COMPREHENSIVE MEMORY LEAK INVESTIGATION REPORT
==============================================
Investigation Date: $(date)
System: $(hostname)
Kernel: $(uname -r)
Uptime: $(uptime)

EXECUTIVE SUMMARY
================
This report investigates memory growth patterns on the system, particularly focusing on
"doing nothing" scenarios where memory usage increases without active user intervention.

KEY FINDINGS OVERVIEW:
EOF

# Function to add section to master report
add_section() {
    local title="$1"
    local file="$2"
    
    echo "" >> "$MASTER_REPORT"
    echo "=================================================================================================" >> "$MASTER_REPORT"
    echo "$title" >> "$MASTER_REPORT"
    echo "=================================================================================================" >> "$MASTER_REPORT"
    
    if [ -f "$file" ]; then
        cat "$file" >> "$MASTER_REPORT"
    else
        echo "ERROR: Analysis file $file not found!" >> "$MASTER_REPORT"
    fi
    echo "" >> "$MASTER_REPORT"
}

# Function to analyze immediate findings
analyze_immediate_findings() {
    echo "IMMEDIATE SYSTEM ANALYSIS" >> "$MASTER_REPORT"
    echo "========================" >> "$MASTER_REPORT"
    
    {
        echo "Current Memory Status:"
        free -h
        echo ""
        
        echo "Top Memory Consuming Processes:"
        ps aux --sort=-%mem | head -10
        echo ""
        
        echo "Container Status Summary:"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" | grep -E "(Restarting|unhealthy|Exited)" || echo "All containers appear stable"
        echo ""
        
        echo "System Load:"
        uptime
        cat /proc/loadavg
        echo ""
        
        echo "Disk Usage (potential swap/temp issues):"
        df -h | grep -E "/$|/tmp|/var"
        echo ""
    } >> "$MASTER_REPORT"
}

# Function to identify critical issues
identify_critical_issues() {
    echo "" >> "$MASTER_REPORT"
    echo "CRITICAL ISSUES IDENTIFIED" >> "$MASTER_REPORT"
    echo "=========================" >> "$MASTER_REPORT"
    
    local critical_count=0
    
    # Check for restarting containers
    local restarting_containers=$(docker ps --format "{{.Names}}" | xargs -I {} docker ps --filter "name={}" --format "{{.Status}}" | grep -c "Restarting" || echo "0")
    if [ "$restarting_containers" -gt 0 ]; then
        echo "CRITICAL: $restarting_containers containers are in restart loop" >> "$MASTER_REPORT"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" | grep "Restarting" >> "$MASTER_REPORT"
        critical_count=$((critical_count + 1))
        echo "" >> "$MASTER_REPORT"
    fi
    
    # Check memory usage
    local mem_percent=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
    if [ "$mem_percent" -gt 80 ]; then
        echo "CRITICAL: High memory usage - ${mem_percent}%" >> "$MASTER_REPORT"
        critical_count=$((critical_count + 1))
    fi
    
    # Check for failed services
    local failed_services=$(systemctl list-units --failed --no-pager | wc -l)
    if [ "$failed_services" -gt 2 ]; then  # Account for header
        echo "WARNING: $((failed_services - 2)) failed system services" >> "$MASTER_REPORT"
        systemctl list-units --failed --no-pager >> "$MASTER_REPORT"
        critical_count=$((critical_count + 1))
    fi
    
    if [ "$critical_count" -eq 0 ]; then
        echo "No critical issues detected in immediate analysis." >> "$MASTER_REPORT"
    fi
    
    echo "" >> "$MASTER_REPORT"
}

# Function to generate recommendations
generate_recommendations() {
    echo "RECOMMENDATIONS AND NEXT STEPS" >> "$MASTER_REPORT"
    echo "==============================" >> "$MASTER_REPORT"
    
    {
        echo "Based on the analysis, here are the recommended actions:"
        echo ""
        echo "IMMEDIATE ACTIONS:"
        echo "1. Monitor container restart patterns - focus on:"
        docker ps --format "{{.Names}}\t{{.Status}}" | grep -E "(Restarting|unhealthy)" | awk '{print "   - " $1}' || echo "   - No problematic containers currently"
        
        echo ""
        echo "2. Check the following high-memory processes:"
        ps aux --sort=-%mem | head -5 | tail -n +2 | awk '{print "   - " $11 " (PID " $2 ", " $4 "% memory)"}'
        
        echo ""
        echo "ONGOING MONITORING:"
        echo "1. Run continuous memory monitor:"
        echo "   $SCRIPT_DIR/monitors/continuous_memory_monitor.sh &"
        echo ""
        echo "2. Schedule regular analysis (add to cron):"
        echo "   0 */4 * * * $SCRIPT_DIR/utils/master_analyzer.sh"
        echo ""
        echo "3. Monitor specific containers with high restart counts"
        echo ""
        
        echo "INVESTIGATION PRIORITIES:"
        echo "1. Docker containers in restart loops"
        echo "2. Processes with growing memory usage during idle time"
        echo "3. System services with memory leaks"
        echo "4. Background cron jobs that might consume memory"
        echo ""
        
        echo "FILES TO MONITOR:"
        echo "- /var/log/syslog for OOM events"
        echo "- Docker container logs for memory errors"
        echo "- systemd journal for service failures"
        echo ""
        
        echo "TOOLS PROVIDED:"
        echo "- Memory leak analyzer: $SCRIPT_DIR/parsers/memory_leak_analyzer.sh"
        echo "- Docker log analyzer: $SCRIPT_DIR/parsers/docker_log_analyzer.sh"
        echo "- Cron task analyzer: $SCRIPT_DIR/parsers/cron_task_analyzer.sh"
        echo "- Pattern detector: $SCRIPT_DIR/utils/pattern_detector.sh"
        echo "- Continuous monitor: $SCRIPT_DIR/monitors/continuous_memory_monitor.sh"
    } >> "$MASTER_REPORT"
}

echo "Running immediate system analysis..."
analyze_immediate_findings
identify_critical_issues

echo "Running memory leak analysis..."
if ! "$SCRIPT_DIR/parsers/memory_leak_analyzer.sh" > /dev/null 2>&1; then
    echo "Warning: Memory leak analysis encountered issues"
fi

echo "Running Docker analysis..."
if ! "$SCRIPT_DIR/parsers/docker_log_analyzer.sh" > /dev/null 2>&1; then
    echo "Warning: Docker analysis encountered issues"
fi

echo "Running cron task analysis..."
if ! "$SCRIPT_DIR/parsers/cron_task_analyzer.sh" > /dev/null 2>&1; then
    echo "Warning: Cron task analysis encountered issues"
fi

echo "Running pattern detection..."
if ! "$SCRIPT_DIR/utils/pattern_detector.sh" > /dev/null 2>&1; then
    echo "Warning: Pattern detection encountered issues"
fi

echo "Consolidating reports..."

# Find the most recent reports
MEMORY_REPORT=$(ls -t "$LOG_DIR"/memory_leak_analysis_*.txt 2>/dev/null | head -1)
DOCKER_REPORT=$(ls -t "$LOG_DIR"/docker_analysis_*.txt 2>/dev/null | head -1)
CRON_REPORT=$(ls -t "$LOG_DIR"/cron_task_analysis_*.txt 2>/dev/null | head -1)
PATTERN_REPORT=$(ls -t "$LOG_DIR"/memory_patterns_*.txt 2>/dev/null | head -1)

# Add all sections to master report
[ -n "$MEMORY_REPORT" ] && add_section "MEMORY LEAK ANALYSIS" "$MEMORY_REPORT"
[ -n "$DOCKER_REPORT" ] && add_section "DOCKER CONTAINER ANALYSIS" "$DOCKER_REPORT"
[ -n "$CRON_REPORT" ] && add_section "SCHEDULED TASK ANALYSIS" "$CRON_REPORT"
[ -n "$PATTERN_REPORT" ] && add_section "MEMORY PATTERN DETECTION" "$PATTERN_REPORT"

# Generate final recommendations
generate_recommendations

# Add footer
cat >> "$MASTER_REPORT" << EOF

================================================================================================
INVESTIGATION COMPLETED: $(date)
================================================================================================

This comprehensive analysis has examined:
- System memory patterns and OOM events
- Docker container behavior and restart patterns  
- Scheduled tasks and background processes
- Memory usage patterns during idle time
- System service memory consumption

For ongoing monitoring, use the continuous memory monitor:
$SCRIPT_DIR/monitors/continuous_memory_monitor.sh

For regular analysis, schedule this master script in cron:
0 */4 * * * $SCRIPT_DIR/utils/master_analyzer.sh

Report saved to: $MASTER_REPORT
EOF

echo ""
echo "================================================================================================="
echo "INVESTIGATION COMPLETE"
echo "================================================================================================="
echo "Master report saved to: $MASTER_REPORT"
echo ""
echo "Summary of findings:"
echo "- Memory reports generated: $(ls "$LOG_DIR"/*_analysis_*.txt 2>/dev/null | wc -l)"
echo "- Restarting containers: $(docker ps --format "{{.Status}}" | grep -c "Restarting" || echo "0")"
echo "- Current memory usage: $(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')%"
echo ""
echo "Next steps:"
echo "1. Review the master report: $MASTER_REPORT"
echo "2. Start continuous monitoring: $SCRIPT_DIR/monitors/continuous_memory_monitor.sh &"
echo "3. Focus on containers with restart loops"
echo "4. Monitor memory patterns during idle periods"
echo ""