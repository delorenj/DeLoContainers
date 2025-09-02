#!/bin/bash

# Generate Diagnostic Report Script
# Comprehensive automated diagnostic report generation for Windows VM USB configuration
# Consolidates all diagnostic tools and procedures into a single comprehensive report

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS_DIR="$(dirname "$SCRIPT_DIR")/docs"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
REPORT_DIR="/tmp/windows-vm-diagnostics"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="${REPORT_DIR}/comprehensive-diagnostic-report-${TIMESTAMP}.html"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Create report directory
mkdir -p "$REPORT_DIR"

# HTML template for the report
cat > "$REPORT_FILE" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Windows VM USB Diagnostic Report</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            line-height: 1.6;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background-color: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 0 20px rgba(0,0,0,0.1);
        }
        .header {
            text-align: center;
            border-bottom: 3px solid #007acc;
            padding-bottom: 20px;
            margin-bottom: 30px;
        }
        .header h1 {
            color: #007acc;
            margin: 0;
            font-size: 2.5em;
        }
        .header .subtitle {
            color: #666;
            font-size: 1.2em;
            margin-top: 10px;
        }
        .section {
            margin-bottom: 40px;
            border-left: 4px solid #007acc;
            padding-left: 20px;
        }
        .section h2 {
            color: #333;
            border-bottom: 2px solid #eee;
            padding-bottom: 10px;
        }
        .status-good { color: #28a745; font-weight: bold; }
        .status-warning { color: #ffc107; font-weight: bold; }
        .status-error { color: #dc3545; font-weight: bold; }
        .code-block {
            background-color: #f8f9fa;
            border: 1px solid #e9ecef;
            border-radius: 5px;
            padding: 15px;
            font-family: 'Courier New', monospace;
            margin: 15px 0;
            overflow-x: auto;
        }
        .device-card {
            background-color: #f8f9fa;
            border-radius: 8px;
            padding: 20px;
            margin: 15px 0;
            border-left: 5px solid #007acc;
        }
        .metric {
            display: inline-block;
            background-color: #e9ecef;
            padding: 8px 15px;
            margin: 5px;
            border-radius: 20px;
            font-weight: bold;
        }
        .recommendation {
            background-color: #fff3cd;
            border: 1px solid #ffeaa7;
            border-radius: 5px;
            padding: 15px;
            margin: 10px 0;
        }
        .toc {
            background-color: #f8f9fa;
            padding: 20px;
            border-radius: 8px;
            margin-bottom: 30px;
        }
        .toc ul {
            list-style-type: none;
            padding-left: 20px;
        }
        .toc a {
            text-decoration: none;
            color: #007acc;
        }
        .footer {
            text-align: center;
            margin-top: 50px;
            padding-top: 20px;
            border-top: 1px solid #eee;
            color: #666;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔬 Windows VM USB Diagnostic Report</h1>
            <div class="subtitle">
                Comprehensive Analysis for Audio Production Setup<br>
                Generated: TIMESTAMP_PLACEHOLDER<br>
                System: HOSTNAME_PLACEHOLDER
            </div>
        </div>

        <div class="toc">
            <h2>📋 Table of Contents</h2>
            <ul>
                <li><a href="#executive-summary">Executive Summary</a></li>
                <li><a href="#system-overview">System Overview</a></li>
                <li><a href="#host-diagnostics">Host System Diagnostics</a></li>
                <li><a href="#container-analysis">Container Analysis</a></li>
                <li><a href="#windows-guest-analysis">Windows Guest Analysis</a></li>
                <li><a href="#device-analysis">Device-Specific Analysis</a></li>
                <li><a href="#performance-metrics">Performance Metrics</a></li>
                <li><a href="#recommendations">Recommendations & Action Items</a></li>
                <li><a href="#technical-appendix">Technical Appendix</a></li>
            </ul>
        </div>

        <div id="executive-summary" class="section">
            <h2>📊 Executive Summary</h2>
            <div id="summary-content">
                <!-- Summary content will be inserted here -->
            </div>
        </div>

        <div id="system-overview" class="section">
            <h2>🖥️ System Overview</h2>
            <div id="system-content">
                <!-- System overview will be inserted here -->
            </div>
        </div>

        <div id="host-diagnostics" class="section">
            <h2>🏠 Host System Diagnostics</h2>
            <div id="host-content">
                <!-- Host diagnostics will be inserted here -->
            </div>
        </div>

        <div id="container-analysis" class="section">
            <h2>🐳 Container Analysis</h2>
            <div id="container-content">
                <!-- Container analysis will be inserted here -->
            </div>
        </div>

        <div id="windows-guest-analysis" class="section">
            <h2>🪟 Windows Guest Analysis</h2>
            <div id="windows-content">
                <!-- Windows analysis will be inserted here -->
            </div>
        </div>

        <div id="device-analysis" class="section">
            <h2>🎵 Device-Specific Analysis</h2>
            <div id="device-content">
                <!-- Device analysis will be inserted here -->
            </div>
        </div>

        <div id="performance-metrics" class="section">
            <h2>⚡ Performance Metrics</h2>
            <div id="performance-content">
                <!-- Performance metrics will be inserted here -->
            </div>
        </div>

        <div id="recommendations" class="section">
            <h2>🎯 Recommendations & Action Items</h2>
            <div id="recommendations-content">
                <!-- Recommendations will be inserted here -->
            </div>
        </div>

        <div id="technical-appendix" class="section">
            <h2>📚 Technical Appendix</h2>
            <div id="appendix-content">
                <!-- Technical details will be inserted here -->
            </div>
        </div>

        <div class="footer">
            <p>Generated by Windows VM USB Diagnostic Suite<br>
            For technical support, refer to the documentation in the project repository.</p>
        </div>
    </div>
</body>
</html>
EOF

# Function to log messages
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${BLUE}[$timestamp] [$level] $message${NC}"
}

# Function to add content to HTML report
add_html_content() {
    local section_id=$1
    local content=$2
    
    # Escape HTML special characters in content
    content=$(echo "$content" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g')
    
    # Replace content in HTML file
    if [[ "$content" == *"<"* ]]; then
        # Content already contains HTML
        sed -i "s|<!-- ${section_id} content will be inserted here -->|${content}|g" "$REPORT_FILE"
    else
        # Plain text content, wrap in <pre>
        sed -i "s|<!-- ${section_id} content will be inserted here -->|<div class=\"code-block\">${content}</div>|g" "$REPORT_FILE"
    fi
}

# Function to run command and capture output
run_diagnostic_command() {
    local command=$1
    local description=$2
    
    log_message "INFO" "Running: $description"
    
    local output
    local exit_code
    
    if output=$(eval "$command" 2>&1); then
        exit_code=0
    else
        exit_code=$?
    fi
    
    echo "=== $description ==="
    echo "Command: $command"
    echo "Exit Code: $exit_code"
    echo "Output:"
    echo "$output"
    echo ""
    
    return $exit_code
}

echo -e "${CYAN}=== WINDOWS VM USB DIAGNOSTIC REPORT GENERATOR ===${NC}"
echo -e "${CYAN}Starting comprehensive diagnostic analysis...${NC}"
echo ""

# Replace placeholders in HTML
sed -i "s/TIMESTAMP_PLACEHOLDER/$(date)/g" "$REPORT_FILE"
sed -i "s/HOSTNAME_PLACEHOLDER/$(hostname)/g" "$REPORT_FILE"

# 1. SYSTEM OVERVIEW
log_message "INFO" "Gathering system overview"

system_info="$(cat << EOF
Hostname: $(hostname)
Kernel: $(uname -r)
Architecture: $(uname -m)
Distribution: $(lsb_release -d 2>/dev/null | cut -f2 || echo "Unknown")
Uptime: $(uptime -p)
Current User: $(whoami)
Working Directory: $(pwd)
Timestamp: $(date)
EOF
)"

add_html_content "System overview" "<div class=\"device-card\">$system_info</div>"

# 2. HOST SYSTEM DIAGNOSTICS
log_message "INFO" "Running host system diagnostics"

host_diagnostics=""

# Run host USB diagnostic script if available
if [[ -x "$SCRIPT_DIR/host-usb-diagnostic.sh" ]]; then
    log_message "INFO" "Running host USB diagnostic script"
    if host_output=$("$SCRIPT_DIR/host-usb-diagnostic.sh" 2>&1); then
        host_diagnostics="$host_output"
    else
        host_diagnostics="Host USB diagnostic script failed with exit code $?"
    fi
else
    # Manual host diagnostics
    host_diagnostics+="USB Controllers:\n"
    host_diagnostics+="$(lspci | grep -i usb || echo 'No USB controllers found')\n\n"
    
    host_diagnostics+="USB Devices:\n"
    host_diagnostics+="$(lsusb || echo 'lsusb command not available')\n\n"
    
    host_diagnostics+="Target Devices:\n"
    if lsusb -d 1235:821a >/dev/null 2>&1; then
        host_diagnostics+="✓ Focusrite Scarlett 4i4 detected\n"
    else
        host_diagnostics+="✗ Focusrite Scarlett 4i4 NOT detected\n"
    fi
    
    if lsusb -d 1c75:02cb >/dev/null 2>&1; then
        host_diagnostics+="✓ Arturia KeyLab mkII detected\n"
    else
        host_diagnostics+="✗ Arturia KeyLab mkII NOT detected\n"
    fi
fi

add_html_content "Host diagnostics" "$host_diagnostics"

# 3. CONTAINER ANALYSIS
log_message "INFO" "Analyzing container configuration"

container_analysis=""

# Check if Docker is available
if command -v docker >/dev/null 2>&1; then
    # Container status
    if docker ps | grep -q "windows"; then
        container_analysis+="Container Status: ✓ Running\n"
        
        # Container configuration
        container_analysis+="Container Configuration:\n"
        container_analysis+="$(docker inspect windows --format '{{.Config.Image}}' 2>/dev/null || echo 'Unable to inspect container')\n"
        
        # Device mappings
        container_analysis+="Device Mappings:\n"
        if docker exec windows ls -la /dev/focusrite_4i4 >/dev/null 2>&1; then
            container_analysis+="✓ Focusrite device mapped\n"
        else
            container_analysis+="✗ Focusrite device NOT mapped\n"
        fi
        
        if docker exec windows ls -la /dev/arturia_keylab >/dev/null 2>&1; then
            container_analysis+="✓ Arturia device mapped\n"
        else
            container_analysis+="✗ Arturia device NOT mapped\n"
        fi
        
        # QEMU process
        if docker exec windows pgrep qemu >/dev/null 2>&1; then
            container_analysis+="✓ QEMU process running\n"
            
            # QEMU USB arguments
            qemu_args=$(docker exec windows cat /proc/$(docker exec windows pgrep qemu)/cmdline 2>/dev/null | tr '\0' '\n' | grep -E "usb-host|device" | head -5)
            if [[ -n "$qemu_args" ]]; then
                container_analysis+="QEMU USB Arguments:\n$qemu_args\n"
            fi
        else
            container_analysis+="✗ QEMU process NOT running\n"
        fi
        
    else
        container_analysis+="Container Status: ✗ Not Running\n"
    fi
else
    container_analysis+="Docker: Not available\n"
fi

add_html_content "Container analysis" "$container_analysis"

# 4. WINDOWS GUEST ANALYSIS (if container is running)
log_message "INFO" "Analyzing Windows guest (if available)"

windows_analysis=""

if docker ps | grep -q "windows" && docker exec windows powershell "echo 'test'" >/dev/null 2>&1; then
    windows_analysis+="Windows Guest Status: ✓ Accessible\n\n"
    
    # Run Windows diagnostics
    windows_analysis+="USB Device Detection:\n"
    if usb_devices=$(docker exec windows powershell "Get-PnpDevice | Where-Object {\$_.FriendlyName -like '*Focusrite*' -or \$_.FriendlyName -like '*Arturia*'} | Select-Object FriendlyName, Status" 2>/dev/null); then
        windows_analysis+="$usb_devices\n"
    else
        windows_analysis+="Unable to query Windows USB devices\n"
    fi
    
    # Driver conflict detection (run PowerShell script if available)
    if [[ -f "$SCRIPT_DIR/usb-conflict-detection.ps1" ]]; then
        windows_analysis+="\nUSB Conflict Detection:\n"
        if conflict_output=$(docker exec windows powershell -ExecutionPolicy Bypass -File "C:\\temp\\usb-conflict-detection.ps1" -Detailed 2>/dev/null); then
            windows_analysis+="$conflict_output\n"
        else
            windows_analysis+="Conflict detection script not accessible\n"
        fi
    fi
    
else
    windows_analysis+="Windows Guest Status: ✗ Not accessible\n"
    windows_analysis+="Container may not be running or PowerShell not available\n"
fi

add_html_content "Windows analysis" "$windows_analysis"

# 5. DEVICE-SPECIFIC ANALYSIS
log_message "INFO" "Performing device-specific analysis"

device_analysis=""

# Focusrite Scarlett 4i4 Analysis
device_analysis+="=== Focusrite Scarlett 4i4 4th Gen ===\n"
device_analysis+="Vendor ID: 1235, Product ID: 821a\n"

if lsusb -d 1235:821a >/dev/null 2>&1; then
    device_analysis+="Host Detection: ✓ Present\n"
    
    # Get detailed device info
    if device_info=$(lsusb -d 1235:821a -v 2>/dev/null); then
        usb_version=$(echo "$device_info" | grep "bcdUSB" | head -1 | awk '{print $2}')
        max_power=$(echo "$device_info" | grep "MaxPower" | head -1 | awk '{print $2}')
        device_analysis+="USB Version: $usb_version\n"
        device_analysis+="Max Power: $max_power\n"
    fi
    
    # Check persistent symlink
    if [[ -L "/dev/focusrite_4i4" ]]; then
        device_analysis+="Persistent Link: ✓ Present\n"
    else
        device_analysis+="Persistent Link: ✗ Missing\n"
    fi
else
    device_analysis+="Host Detection: ✗ Not Present\n"
fi

device_analysis+="\n=== Arturia KeyLab mkII 88 ===\n"
device_analysis+="Vendor ID: 1c75, Product ID: 02cb\n"

if lsusb -d 1c75:02cb >/dev/null 2>&1; then
    device_analysis+="Host Detection: ✓ Present\n"
    
    # Get detailed device info
    if device_info=$(lsusb -d 1c75:02cb -v 2>/dev/null); then
        usb_version=$(echo "$device_info" | grep "bcdUSB" | head -1 | awk '{print $2}')
        max_power=$(echo "$device_info" | grep "MaxPower" | head -1 | awk '{print $2}')
        device_analysis+="USB Version: $usb_version\n"
        device_analysis+="Max Power: $max_power\n"
    fi
    
    # Check persistent symlink
    if [[ -L "/dev/arturia_keylab" ]]; then
        device_analysis+="Persistent Link: ✓ Present\n"
    else
        device_analysis+="Persistent Link: ✗ Missing\n"
    fi
else
    device_analysis+="Host Detection: ✗ Not Present\n"
fi

add_html_content "Device analysis" "$device_analysis"

# 6. PERFORMANCE METRICS
log_message "INFO" "Collecting performance metrics"

performance_metrics=""

# System performance
performance_metrics+="=== System Performance ===\n"
performance_metrics+="CPU Usage: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)%\n"
performance_metrics+="Memory Usage: $(free | grep Mem | awk '{printf "%.1f%%", $3/$2 * 100.0}')\n"
performance_metrics+="Load Average: $(uptime | awk -F'load average:' '{print $2}')\n"

# USB subsystem performance
performance_metrics+="\n=== USB Subsystem Performance ===\n"
total_usb_devices=$(lsusb | wc -l)
performance_metrics+="Total USB Devices: $total_usb_devices\n"

# Check for USB errors in kernel log
usb_errors=$(dmesg | grep -i "usb.*error\|usb.*fail" | wc -l)
performance_metrics+="USB Errors in Kernel Log: $usb_errors\n"

# Container performance (if running)
if docker ps | grep -q "windows"; then
    container_stats=$(docker stats windows --no-stream --format "CPU: {{.CPUPerc}}, Memory: {{.MemPerc}}" 2>/dev/null || echo "Stats not available")
    performance_metrics+="Container Performance: $container_stats\n"
fi

add_html_content "Performance metrics" "$performance_metrics"

# 7. GENERATE RECOMMENDATIONS
log_message "INFO" "Generating recommendations"

recommendations=""
critical_issues=0
warnings=0

# Check for critical issues
if ! lsusb -d 1235:821a >/dev/null 2>&1; then
    recommendations+="🔴 CRITICAL: Focusrite Scarlett 4i4 not detected on host system\n"
    recommendations+="   → Check USB cable connection and device power\n"
    recommendations+="   → Try different USB port\n"
    recommendations+="   → Verify device is not connected to another system\n\n"
    ((critical_issues++))
fi

if ! lsusb -d 1c75:02cb >/dev/null 2>&1; then
    recommendations+="🔴 CRITICAL: Arturia KeyLab mkII not detected on host system\n"
    recommendations+="   → Check USB cable connection and device power\n"
    recommendations+="   → Try different USB port\n"
    recommendations+="   → Verify device is not connected to another system\n\n"
    ((critical_issues++))
fi

# Check for warnings
if [[ ! -L "/dev/focusrite_4i4" ]]; then
    recommendations+="🟡 WARNING: Focusrite persistent symlink missing\n"
    recommendations+="   → Create udev rule for consistent device naming\n"
    recommendations+="   → Restart container after creating symlink\n\n"
    ((warnings++))
fi

if [[ ! -L "/dev/arturia_keylab" ]]; then
    recommendations+="🟡 WARNING: Arturia persistent symlink missing\n"
    recommendations+="   → Create udev rule for consistent device naming\n"
    recommendations+="   → Restart container after creating symlink\n\n"
    ((warnings++))
fi

if ! docker ps | grep -q "windows"; then
    recommendations+="🟡 WARNING: Windows container not running\n"
    recommendations+="   → Start container: cd $(dirname "$SCRIPT_DIR") && docker compose up -d\n"
    recommendations+="   → Check container logs for startup issues\n\n"
    ((warnings++))
fi

# General recommendations
if [[ $usb_errors -gt 10 ]]; then
    recommendations+="🟡 WARNING: High number of USB errors detected ($usb_errors)\n"
    recommendations+="   → Check USB cables and connections\n"
    recommendations+="   → Consider USB hub power supply\n\n"
    ((warnings++))
fi

# Success message if no issues
if [[ $critical_issues -eq 0 && $warnings -eq 0 ]]; then
    recommendations+="✅ EXCELLENT: No critical issues or warnings detected\n"
    recommendations+="System appears to be configured correctly for audio production.\n\n"
fi

# Add quick fix suggestions
recommendations+="\n=== Quick Fix Checklist ===\n"
recommendations+="1. Verify physical USB connections\n"
recommendations+="2. Restart Windows container: docker compose restart windows\n"
recommendations+="3. Check host USB subsystem: sudo dmesg | tail -20\n"
recommendations+="4. Run device manager cleanup in Windows\n"
recommendations+="5. Update audio device drivers\n"

add_html_content "Recommendations" "$recommendations"

# 8. TECHNICAL APPENDIX
log_message "INFO" "Building technical appendix"

appendix=""

# Configuration files
appendix+="=== Docker Compose Configuration ===\n"
if [[ -f "$(dirname "$SCRIPT_DIR")/compose.yml" ]]; then
    appendix+="$(cat "$(dirname "$SCRIPT_DIR")/compose.yml")\n\n"
else
    appendix+="Configuration file not found\n\n"
fi

# System information
appendix+="=== Detailed System Information ===\n"
appendix+="Kernel: $(uname -a)\n"
appendix+="Distribution: $(cat /etc/os-release 2>/dev/null | head -5 || echo "Unknown")\n"
appendix+="Docker Version: $(docker --version 2>/dev/null || echo "Not available")\n"
appendix+="Available Scripts:\n"
ls -la "$SCRIPT_DIR"/*.sh 2>/dev/null | while read -r line; do
    appendix+="  $line\n"
done

appendix+="\n=== Available Documentation ===\n"
ls -la "$DOCS_DIR"/*.md 2>/dev/null | while read -r line; do
    appendix+="  $line\n"
done

add_html_content "Technical details" "$appendix"

# Create executive summary
summary=""
if [[ $critical_issues -eq 0 && $warnings -eq 0 ]]; then
    summary+="<div class=\"status-good\">🎯 SYSTEM STATUS: EXCELLENT</div>\n"
    summary+="<p>All target USB audio devices are detected and properly configured. System is ready for audio production.</p>\n"
elif [[ $critical_issues -eq 0 ]]; then
    summary+="<div class=\"status-warning\">⚠️ SYSTEM STATUS: GOOD WITH WARNINGS</div>\n"
    summary+="<p>$warnings non-critical issues detected. System functional but optimization recommended.</p>\n"
else
    summary+="<div class=\"status-error\">🚨 SYSTEM STATUS: ISSUES DETECTED</div>\n"
    summary+="<p>$critical_issues critical issues and $warnings warnings detected. Immediate attention required.</p>\n"
fi

# Add metrics
summary+="<div class=\"device-card\">\n"
summary+="<h3>Key Metrics</h3>\n"
summary+="<span class=\"metric\">Critical Issues: $critical_issues</span>\n"
summary+="<span class=\"metric\">Warnings: $warnings</span>\n"
summary+="<span class=\"metric\">USB Devices: $total_usb_devices</span>\n"
summary+="<span class=\"metric\">USB Errors: $usb_errors</span>\n"
summary+="</div>\n"

# Add device status
summary+="<div class=\"device-card\">\n"
summary+="<h3>Target Device Status</h3>\n"
if lsusb -d 1235:821a >/dev/null 2>&1; then
    summary+="<div class=\"status-good\">✓ Focusrite Scarlett 4i4: Detected</div>\n"
else
    summary+="<div class=\"status-error\">✗ Focusrite Scarlett 4i4: Not Detected</div>\n"
fi

if lsusb -d 1c75:02cb >/dev/null 2>&1; then
    summary+="<div class=\"status-good\">✓ Arturia KeyLab mkII: Detected</div>\n"
else
    summary+="<div class=\"status-error\">✗ Arturia KeyLab mkII: Not Detected</div>\n"
fi
summary+="</div>\n"

add_html_content "Summary content" "$summary"

# Finalize report
log_message "SUCCESS" "Diagnostic report generated: $REPORT_FILE"

# Create a simplified text summary
SUMMARY_FILE="${REPORT_DIR}/diagnostic-summary-${TIMESTAMP}.txt"
cat > "$SUMMARY_FILE" << EOF
WINDOWS VM USB DIAGNOSTIC SUMMARY
=================================
Generated: $(date)
Hostname: $(hostname)

OVERALL STATUS: $(if [[ $critical_issues -eq 0 && $warnings -eq 0 ]]; then echo "EXCELLENT"; elif [[ $critical_issues -eq 0 ]]; then echo "GOOD"; else echo "NEEDS ATTENTION"; fi)

CRITICAL ISSUES: $critical_issues
WARNINGS: $warnings

TARGET DEVICES:
- Focusrite Scarlett 4i4: $(if lsusb -d 1235:821a >/dev/null 2>&1; then echo "✓ DETECTED"; else echo "✗ NOT DETECTED"; fi)
- Arturia KeyLab mkII: $(if lsusb -d 1c75:02cb >/dev/null 2>&1; then echo "✓ DETECTED"; else echo "✗ NOT DETECTED"; fi)

CONTAINER STATUS: $(if docker ps | grep -q "windows"; then echo "✓ RUNNING"; else echo "✗ NOT RUNNING"; fi)

NEXT STEPS:
$(if [[ $critical_issues -gt 0 ]]; then echo "1. Address critical device detection issues"; else echo "1. Review warnings and optimization opportunities"; fi)
2. Open full HTML report for detailed analysis: $REPORT_FILE
3. Refer to documentation in docs/ directory
4. Run individual diagnostic scripts as needed

QUICK COMMANDS:
- Host diagnostics: ./scripts/host-usb-diagnostic.sh
- Container restart: docker compose restart windows
- Windows USB check: docker exec windows powershell "Get-PnpDevice | Where {\$_.FriendlyName -like '*Audio*'}"
EOF

echo -e "\n${GREEN}=== DIAGNOSTIC REPORT COMPLETE ===${NC}"
echo -e "${BLUE}Full HTML Report: ${REPORT_FILE}${NC}"
echo -e "${BLUE}Text Summary: ${SUMMARY_FILE}${NC}"
echo ""
echo -e "${YELLOW}Overall Status:${NC} $(if [[ $critical_issues -eq 0 && $warnings -eq 0 ]]; then echo -e "${GREEN}EXCELLENT${NC}"; elif [[ $critical_issues -eq 0 ]]; then echo -e "${YELLOW}GOOD${NC}"; else echo -e "${RED}NEEDS ATTENTION${NC}"; fi)"
echo -e "${YELLOW}Critical Issues:${NC} $critical_issues"
echo -e "${YELLOW}Warnings:${NC} $warnings"
echo ""

if [[ $critical_issues -gt 0 ]]; then
    echo -e "${RED}⚠️  IMMEDIATE ACTION REQUIRED${NC}"
    echo -e "Please review the critical issues section in the full report."
elif [[ $warnings -gt 0 ]]; then
    echo -e "${YELLOW}💡 OPTIMIZATION OPPORTUNITIES AVAILABLE${NC}"
    echo -e "System is functional but can be improved."
else
    echo -e "${GREEN}🎉 SYSTEM READY FOR AUDIO PRODUCTION${NC}"
fi

echo ""
echo -e "Open the HTML report in your browser for detailed analysis:"
echo -e "${CYAN}file://$REPORT_FILE${NC}"

# Exit with appropriate code
if [[ $critical_issues -gt 0 ]]; then
    exit 2
elif [[ $warnings -gt 0 ]]; then
    exit 1
else
    exit 0
fi