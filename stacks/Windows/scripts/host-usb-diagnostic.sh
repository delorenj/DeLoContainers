#!/bin/bash

# Host USB Diagnostic Script
# Comprehensive USB subsystem analysis for Docker Windows VM USB passthrough
# Focus on Focusrite Scarlett 4i4 and Arturia KeyLab mkII devices

set -euo pipefail

# Configuration
FOCUSRITE_VID="1235"
FOCUSRITE_PID="821a"
ARTURIA_VID="1c75"
ARTURIA_PID="02cb"

LOG_DIR="/tmp/usb-diagnostics"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="${LOG_DIR}/usb-diagnostic-report-${TIMESTAMP}.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local color_code=""
    
    case $level in
        "ERROR")   color_code=$RED ;;
        "SUCCESS") color_code=$GREEN ;;
        "WARNING") color_code=$YELLOW ;;
        "INFO")    color_code=$BLUE ;;
        *)         color_code=$NC ;;
    esac
    
    echo -e "${color_code}[$timestamp] [$level] $message${NC}"
    echo "[$timestamp] [$level] $message" >> "$REPORT_FILE"
}

# Create log directory
mkdir -p "$LOG_DIR"

echo -e "${BLUE}=== HOST USB DIAGNOSTIC TOOL ===${NC}"
echo -e "${BLUE}Focus: Audio Production USB Devices${NC}"
echo -e "${BLUE}Timestamp: $(date)${NC}"
echo ""

# Initialize report
cat > "$REPORT_FILE" << EOF
HOST USB DIAGNOSTIC REPORT
==========================
Generated: $(date)
Hostname: $(hostname)
Kernel: $(uname -r)
Uptime: $(uptime)

Target Devices:
- Focusrite Scarlett 4i4 4th Gen (${FOCUSRITE_VID}:${FOCUSRITE_PID})
- Arturia KeyLab mkII 88 (${ARTURIA_VID}:${ARTURIA_PID})

EOF

log_message "INFO" "Starting comprehensive USB diagnostic scan"

# 1. SYSTEM OVERVIEW
echo -e "\n${GREEN}1. SYSTEM OVERVIEW${NC}"
log_message "INFO" "=== SYSTEM OVERVIEW ==="

# Kernel and system info
log_message "INFO" "Kernel version: $(uname -r)"
log_message "INFO" "Distribution: $(lsb_release -d 2>/dev/null | cut -f2 || echo "Unknown")"
log_message "INFO" "Architecture: $(uname -m)"
log_message "INFO" "System uptime: $(uptime -p)"

# USB subsystem modules
echo "   Checking USB kernel modules..."
if lsmod | grep -q "^usb_common"; then
    log_message "SUCCESS" "USB kernel modules loaded"
else
    log_message "ERROR" "USB kernel modules not properly loaded"
fi

# 2. USB CONTROLLERS AND HUBS
echo -e "\n${GREEN}2. USB CONTROLLERS AND HUBS${NC}"
log_message "INFO" "=== USB CONTROLLERS AND HUBS ==="

echo "   USB Controllers:"
lspci | grep -i usb | while read -r line; do
    log_message "INFO" "Controller: $line"
done

echo "   USB Hub Tree:"
if command -v lsusb >/dev/null 2>&1; then
    lsusb -t | while read -r line; do
        log_message "INFO" "Hub: $line"
    done
else
    log_message "ERROR" "lsusb command not found - please install usbutils"
fi

# 3. TARGET DEVICE DETECTION
echo -e "\n${GREEN}3. TARGET DEVICE DETECTION${NC}"
log_message "INFO" "=== TARGET DEVICE DETECTION ==="

# Function to check specific device
check_usb_device() {
    local vendor_id=$1
    local product_id=$2
    local device_name=$3
    
    echo "   Checking $device_name (${vendor_id}:${product_id})..."
    
    if lsusb -d "${vendor_id}:${product_id}" >/dev/null 2>&1; then
        log_message "SUCCESS" "$device_name detected"
        
        # Get detailed device information
        local device_info=$(lsusb -d "${vendor_id}:${product_id}" -v 2>/dev/null)
        if [[ -n "$device_info" ]]; then
            # Extract key information
            local bus_device=$(lsusb -d "${vendor_id}:${product_id}" | cut -d' ' -f2,4)
            local device_speed=$(echo "$device_info" | grep "bcdUSB" | head -1 | awk '{print $2}')
            local max_power=$(echo "$device_info" | grep "MaxPower" | head -1 | awk '{print $2}')
            
            log_message "INFO" "$device_name bus/device: $bus_device"
            log_message "INFO" "$device_name USB version: $device_speed"
            log_message "INFO" "$device_name max power: ${max_power:-Unknown}"
            
            # Check device path and permissions
            for dev_path in /dev/bus/usb/*/*; do
                if [[ -e "$dev_path" ]]; then
                    local dev_vid_pid=$(lsusb -D "$dev_path" 2>/dev/null | grep "idVendor\|idProduct" | tr '\n' ' ')
                    if echo "$dev_vid_pid" | grep -q "${vendor_id}.*${product_id}"; then
                        local permissions=$(ls -la "$dev_path" | awk '{print $1" "$3" "$4}')
                        log_message "INFO" "$device_name device path: $dev_path ($permissions)"
                        break
                    fi
                fi
            done
        fi
        return 0
    else
        log_message "ERROR" "$device_name NOT DETECTED"
        return 1
    fi
}

# Check target devices
focusrite_detected=false
arturia_detected=false

if check_usb_device "$FOCUSRITE_VID" "$FOCUSRITE_PID" "Focusrite Scarlett 4i4"; then
    focusrite_detected=true
fi

if check_usb_device "$ARTURIA_VID" "$ARTURIA_PID" "Arturia KeyLab mkII"; then
    arturia_detected=true
fi

# 4. USB DEVICE ENUMERATION
echo -e "\n${GREEN}4. COMPLETE USB DEVICE ENUMERATION${NC}"
log_message "INFO" "=== COMPLETE USB DEVICE ENUMERATION ==="

echo "   All connected USB devices:"
lsusb | while read -r line; do
    log_message "INFO" "USB Device: $line"
done

# Count devices by class
echo "   Device summary:"
total_devices=$(lsusb | wc -l)
audio_devices=$(lsusb | grep -i "audio\|sound" | wc -l)
hid_devices=$(lsusb | grep -i "hid\|human interface" | wc -l)

log_message "INFO" "Total USB devices: $total_devices"
log_message "INFO" "Audio-related devices: $audio_devices"
log_message "INFO" "HID devices: $hid_devices"

# 5. PERSISTENT DEVICE LINKS
echo -e "\n${GREEN}5. PERSISTENT DEVICE LINKS${NC}"
log_message "INFO" "=== PERSISTENT DEVICE LINKS ==="

# Check for expected persistent symlinks
check_symlink() {
    local link_path=$1
    local device_name=$2
    
    if [[ -L "$link_path" ]]; then
        local target=$(readlink -f "$link_path")
        local permissions=$(ls -la "$link_path" | awk '{print $1" "$3" "$4}')
        log_message "SUCCESS" "$device_name symlink exists: $link_path -> $target ($permissions)"
        
        # Verify target exists
        if [[ -e "$target" ]]; then
            log_message "SUCCESS" "$device_name target device accessible"
        else
            log_message "ERROR" "$device_name target device not accessible: $target"
        fi
        return 0
    else
        log_message "WARNING" "$device_name symlink missing: $link_path"
        return 1
    fi
}

check_symlink "/dev/focusrite_4i4" "Focusrite Scarlett 4i4"
check_symlink "/dev/arturia_keylab" "Arturia KeyLab mkII"

# Check for alternative device paths
echo "   Alternative device paths:"
for dev in /dev/snd/*; do
    if [[ -e "$dev" ]]; then
        log_message "INFO" "ALSA device: $dev"
    fi
done

# 6. USB POWER MANAGEMENT
echo -e "\n${GREEN}6. USB POWER MANAGEMENT${NC}"
log_message "INFO" "=== USB POWER MANAGEMENT ==="

echo "   USB power management settings:"

# Check autosuspend settings
autosuspend_count=0
autosuspend_enabled=0

for usb_dev in /sys/bus/usb/devices/*/; do
    if [[ -f "${usb_dev}power/autosuspend" ]] && [[ -f "${usb_dev}idVendor" ]] && [[ -f "${usb_dev}idProduct" ]]; then
        vendor=$(cat "${usb_dev}idVendor" 2>/dev/null || echo "")
        product=$(cat "${usb_dev}idProduct" 2>/dev/null || echo "")
        autosuspend=$(cat "${usb_dev}power/autosuspend" 2>/dev/null || echo "")
        control=$(cat "${usb_dev}power/control" 2>/dev/null || echo "")
        
        if [[ "$vendor" == "$FOCUSRITE_VID" ]] && [[ "$product" == "$FOCUSRITE_PID" ]]; then
            log_message "INFO" "Focusrite autosuspend: ${autosuspend}s, control: $control"
            ((autosuspend_count++))
            if [[ "$control" == "auto" ]]; then
                ((autosuspend_enabled++))
            fi
        elif [[ "$vendor" == "$ARTURIA_VID" ]] && [[ "$product" == "$ARTURIA_PID" ]]; then
            log_message "INFO" "Arturia autosuspend: ${autosuspend}s, control: $control"
            ((autosuspend_count++))
            if [[ "$control" == "auto" ]]; then
                ((autosuspend_enabled++))
            fi
        fi
    fi
done

if [[ $autosuspend_enabled -gt 0 ]]; then
    log_message "WARNING" "USB autosuspend enabled for $autosuspend_enabled audio devices (may cause dropouts)"
else
    log_message "SUCCESS" "USB autosuspend properly configured for audio devices"
fi

# 7. KERNEL MESSAGES AND ERRORS
echo -e "\n${GREEN}7. KERNEL MESSAGES AND ERRORS${NC}"
log_message "INFO" "=== KERNEL MESSAGES AND ERRORS ==="

echo "   Recent USB-related kernel messages:"
recent_usb_messages=$(dmesg | grep -i "usb" | tail -10)
if [[ -n "$recent_usb_messages" ]]; then
    echo "$recent_usb_messages" | while read -r line; do
        if echo "$line" | grep -qi "error\|fail\|disconnect"; then
            log_message "WARNING" "Kernel: $line"
        else
            log_message "INFO" "Kernel: $line"
        fi
    done
else
    log_message "INFO" "No recent USB kernel messages"
fi

# Check for USB resets and errors
error_patterns=("reset" "timeout" "error" "failed" "disconnect")
for pattern in "${error_patterns[@]}"; do
    error_count=$(dmesg | grep -i "usb.*$pattern" | wc -l)
    if [[ $error_count -gt 0 ]]; then
        log_message "WARNING" "Found $error_count USB $pattern events in kernel log"
    fi
done

# 8. UDEV RULES
echo -e "\n${GREEN}8. UDEV RULES ANALYSIS${NC}"
log_message "INFO" "=== UDEV RULES ANALYSIS ==="

echo "   Checking for custom USB udev rules..."
udev_rules_found=false

for rules_file in /etc/udev/rules.d/*.rules; do
    if [[ -f "$rules_file" ]] && grep -qi "usb\|${FOCUSRITE_VID}\|${ARTURIA_VID}" "$rules_file" 2>/dev/null; then
        log_message "INFO" "Found USB rules in: $rules_file"
        udev_rules_found=true
        
        # Show relevant rules
        grep -i "usb\|${FOCUSRITE_VID}\|${ARTURIA_VID}" "$rules_file" | while read -r rule; do
            log_message "INFO" "Rule: $rule"
        done
    fi
done

if ! $udev_rules_found; then
    log_message "INFO" "No custom USB udev rules found"
fi

# 9. CONTAINER INTEGRATION CHECK
echo -e "\n${GREEN}9. CONTAINER INTEGRATION CHECK${NC}"
log_message "INFO" "=== CONTAINER INTEGRATION CHECK ==="

echo "   Docker container status:"
if docker ps | grep -q "windows"; then
    log_message "SUCCESS" "Windows container is running"
    
    # Check device mapping in container
    echo "   Checking device mapping in container..."
    for device_path in "/dev/focusrite_4i4" "/dev/arturia_keylab"; do
        if docker exec windows ls -la "$device_path" >/dev/null 2>&1; then
            device_info=$(docker exec windows ls -la "$device_path" 2>/dev/null || echo "info unavailable")
            log_message "SUCCESS" "Container device mapping: $device_path ($device_info)"
        else
            log_message "ERROR" "Container device mapping missing: $device_path"
        fi
    done
    
    # Check QEMU process
    if docker exec windows pgrep qemu >/dev/null 2>&1; then
        log_message "SUCCESS" "QEMU process running in container"
        
        # Check QEMU USB arguments
        qemu_cmdline=$(docker exec windows cat /proc/$(docker exec windows pgrep qemu)/cmdline 2>/dev/null | tr '\0' '\n')
        if echo "$qemu_cmdline" | grep -q "usb-host"; then
            log_message "SUCCESS" "QEMU USB passthrough arguments detected"
            usb_args=$(echo "$qemu_cmdline" | grep "usb-host" | head -3)
            echo "$usb_args" | while read -r arg; do
                log_message "INFO" "QEMU USB arg: $arg"
            done
        else
            log_message "ERROR" "QEMU USB passthrough arguments missing"
        fi
    else
        log_message "ERROR" "QEMU process not running in container"
    fi
else
    log_message "WARNING" "Windows container not running"
fi

# 10. PERFORMANCE AND BANDWIDTH ANALYSIS
echo -e "\n${GREEN}10. PERFORMANCE AND BANDWIDTH ANALYSIS${NC}"
log_message "INFO" "=== PERFORMANCE AND BANDWIDTH ANALYSIS ==="

# USB controller capabilities
echo "   USB controller capabilities:"
for controller in $(lspci | grep -i usb | cut -d' ' -f1); do
    controller_info=$(lspci -v -s "$controller" 2>/dev/null)
    controller_name=$(echo "$controller_info" | head -1 | cut -d':' -f3-)
    log_message "INFO" "Controller $controller:$controller_name"
    
    # Check for USB 3.0 capability
    if echo "$controller_info" | grep -qi "xhci\|usb 3"; then
        log_message "SUCCESS" "USB 3.0+ capability detected"
    elif echo "$controller_info" | grep -qi "ehci\|usb 2"; then
        log_message "WARNING" "Only USB 2.0 capability detected"
    fi
done

# Bandwidth estimation
total_audio_bandwidth=0
if $focusrite_detected; then
    # Focusrite Scarlett 4i4: ~12-24 Mbps for 4 channels at 192kHz
    total_audio_bandwidth=$((total_audio_bandwidth + 24))
fi
if $arturia_detected; then
    # Arturia KeyLab mkII: ~1-2 Mbps for MIDI data
    total_audio_bandwidth=$((total_audio_bandwidth + 2))
fi

log_message "INFO" "Estimated audio bandwidth requirement: ${total_audio_bandwidth} Mbps"
log_message "INFO" "USB 2.0 theoretical maximum: 480 Mbps"
log_message "INFO" "USB 3.0 theoretical maximum: 5000 Mbps"

if [[ $total_audio_bandwidth -lt 100 ]]; then
    log_message "SUCCESS" "Bandwidth requirements well within USB 2.0 limits"
else
    log_message "WARNING" "High bandwidth requirements - USB 3.0 recommended"
fi

# 11. SUMMARY AND RECOMMENDATIONS
echo -e "\n${GREEN}11. DIAGNOSTIC SUMMARY${NC}"
log_message "INFO" "=== DIAGNOSTIC SUMMARY ==="

# Count issues
critical_issues=0
warnings=0
recommendations=()

# Device detection summary
if ! $focusrite_detected; then
    log_message "ERROR" "CRITICAL: Focusrite Scarlett 4i4 not detected"
    ((critical_issues++))
    recommendations+=("Check Focusrite device physical connection and power")
fi

if ! $arturia_detected; then
    log_message "ERROR" "CRITICAL: Arturia KeyLab mkII not detected"
    ((critical_issues++))
    recommendations+=("Check Arturia device physical connection and power")
fi

# Persistent symlinks
if [[ ! -L "/dev/focusrite_4i4" ]]; then
    log_message "WARNING" "Focusrite persistent symlink missing"
    ((warnings++))
    recommendations+=("Create persistent udev rule for Focusrite device")
fi

if [[ ! -L "/dev/arturia_keylab" ]]; then
    log_message "WARNING" "Arturia persistent symlink missing"
    ((warnings++))
    recommendations+=("Create persistent udev rule for Arturia device")
fi

# Power management
if [[ $autosuspend_enabled -gt 0 ]]; then
    log_message "WARNING" "USB autosuspend enabled for audio devices"
    ((warnings++))
    recommendations+=("Disable USB autosuspend for audio devices to prevent dropouts")
fi

# Final assessment
if [[ $critical_issues -eq 0 ]] && [[ $warnings -eq 0 ]]; then
    log_message "SUCCESS" "USB diagnostic completed - No issues detected"
    overall_status="EXCELLENT"
elif [[ $critical_issues -eq 0 ]]; then
    log_message "WARNING" "USB diagnostic completed - $warnings warnings"
    overall_status="GOOD"
else
    log_message "ERROR" "USB diagnostic completed - $critical_issues critical issues, $warnings warnings"
    overall_status="POOR"
fi

echo -e "\n${BLUE}=== FINAL REPORT ===${NC}"
echo -e "Overall Status: $overall_status"
echo -e "Critical Issues: $critical_issues"
echo -e "Warnings: $warnings"
echo -e "Report saved to: $REPORT_FILE"

if [[ ${#recommendations[@]} -gt 0 ]]; then
    echo -e "\n${YELLOW}Top Recommendations:${NC}"
    for i in "${!recommendations[@]}"; do
        if [[ $i -lt 5 ]]; then  # Show top 5 recommendations
            echo -e "  $((i+1)). ${recommendations[$i]}"
            log_message "RECOMMENDATION" "${recommendations[$i]}"
        fi
    done
fi

# Append summary to report
cat >> "$REPORT_FILE" << EOF

=== FINAL SUMMARY ===
Overall Status: $overall_status
Critical Issues: $critical_issues
Warnings: $warnings
Focusrite Detected: $focusrite_detected
Arturia Detected: $arturia_detected
Report Generated: $(date)

=== RECOMMENDATIONS ===
EOF

for rec in "${recommendations[@]}"; do
    echo "$rec" >> "$REPORT_FILE"
done

log_message "INFO" "Diagnostic completed - report saved to $REPORT_FILE"

# Exit with appropriate code
if [[ $critical_issues -gt 0 ]]; then
    exit 2
elif [[ $warnings -gt 0 ]]; then
    exit 1
else
    exit 0
fi