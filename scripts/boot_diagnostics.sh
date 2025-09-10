#!/bin/bash

# Automated Boot Diagnostics Script
# This script runs on boot to capture initial system state and monitor memory growth
# Usage: Add to systemd service or crontab @reboot

set -euo pipefail

# Configuration
LOG_DIR="/var/log/boot-diagnostics"
SESSION_ID="boot-$(date +%Y%m%d_%H%M%S)"
OUTPUT_BASE="$LOG_DIR/$SESSION_ID"
MONITOR_DURATION=7200  # 2 hours of monitoring
SAMPLE_INTERVAL=60     # Sample every minute
ALERT_THRESHOLD=80     # Memory alert threshold percentage

# Colors for output (if terminal supports it)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# Ensure we're running with appropriate privileges
if [ "$EUID" -ne 0 ]; then
    echo "This script should be run as root for complete system access"
    echo "Some features may not work properly"
fi

# Create log directory
mkdir -p "$LOG_DIR"
chmod 755 "$LOG_DIR"

# Initialize log files
BOOT_LOG="${OUTPUT_BASE}_boot.log"
MEMORY_LOG="${OUTPUT_BASE}_memory.log"
PROCESS_LOG="${OUTPUT_BASE}_processes.log"
KERNEL_LOG="${OUTPUT_BASE}_kernel.log"
SYSTEM_LOG="${OUTPUT_BASE}_system.log"
ALERT_LOG="${OUTPUT_BASE}_alerts.log"
SUMMARY_LOG="${OUTPUT_BASE}_summary.log"

echo -e "${GREEN}[$(date)] Boot diagnostics started - Session: $SESSION_ID${NC}"
echo "[$(date)] Boot diagnostics started - Session: $SESSION_ID" >> "$BOOT_LOG"

# Function to log system boot state
capture_boot_state() {
    echo "=== BOOT STATE CAPTURE $(date) ===" >> "$BOOT_LOG"
    
    # System identification
    echo "--- System Information ---" >> "$BOOT_LOG"
    echo "Hostname: $(hostname)" >> "$BOOT_LOG"
    echo "Kernel: $(uname -a)" >> "$BOOT_LOG"
    echo "Boot time: $(who -b 2>/dev/null || echo "unknown")" >> "$BOOT_LOG"
    echo "Uptime: $(uptime)" >> "$BOOT_LOG"
    echo "Current time: $(date)" >> "$BOOT_LOG"
    echo "Timezone: $(timedatectl show --property=Timezone --value 2>/dev/null || echo "unknown")" >> "$BOOT_LOG"
    echo "" >> "$BOOT_LOG"
    
    # Hardware information
    echo "--- Hardware Information ---" >> "$BOOT_LOG"
    if [ -f /proc/cpuinfo ]; then
        echo "CPU: $(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)" >> "$BOOT_LOG"
        echo "CPU cores: $(nproc)" >> "$BOOT_LOG"
    fi
    
    if [ -f /proc/meminfo ]; then
        echo "Total memory: $(grep MemTotal /proc/meminfo | awk '{print $2 " " $3}')" >> "$BOOT_LOG"
    fi
    
    if command -v lscpu &> /dev/null; then
        echo "Architecture: $(lscpu | grep Architecture | cut -d: -f2 | xargs)" >> "$BOOT_LOG"
    fi
    echo "" >> "$BOOT_LOG"
    
    # Initial memory state
    echo "--- Initial Memory State ---" >> "$BOOT_LOG"
    free -h >> "$BOOT_LOG"
    echo "" >> "$BOOT_LOG"
    
    # Boot parameters
    echo "--- Boot Parameters ---" >> "$BOOT_LOG"
    if [ -f /proc/cmdline ]; then
        echo "Kernel command line: $(cat /proc/cmdline)" >> "$BOOT_LOG"
    fi
    echo "" >> "$BOOT_LOG"
    
    # Initial process state
    echo "--- Initial Process State ---" >> "$BOOT_LOG"
    echo "Total processes: $(ps aux | wc -l)" >> "$BOOT_LOG"
    echo "Running processes: $(ps aux | awk '$8 ~ /^R/ {count++} END {print count+0}')" >> "$BOOT_LOG"
    echo "Sleeping processes: $(ps aux | awk '$8 ~ /^S/ {count++} END {print count+0}')" >> "$BOOT_LOG"
    echo "" >> "$BOOT_LOG"
    
    # System services
    echo "--- System Services Status ---" >> "$BOOT_LOG"
    if command -v systemctl &> /dev/null; then
        echo "Failed services:" >> "$BOOT_LOG"
        systemctl --failed --no-legend >> "$BOOT_LOG" 2>/dev/null || echo "None" >> "$BOOT_LOG"
        echo "" >> "$BOOT_LOG"
        
        echo "Active services count: $(systemctl list-units --state=active --no-legend | wc -l)" >> "$BOOT_LOG"
    fi
    echo "" >> "$BOOT_LOG"
    
    echo "=========================================" >> "$BOOT_LOG"
}

# Function to capture kernel memory allocation
capture_kernel_memory() {
    echo "=== KERNEL MEMORY ANALYSIS $(date) ===" >> "$KERNEL_LOG"
    
    # Slab allocator information
    echo "--- Slab Allocator (Top 20) ---" >> "$KERNEL_LOG"
    if [ -f /proc/slabinfo ]; then
        head -1 /proc/slabinfo >> "$KERNEL_LOG"
        tail -n +2 /proc/slabinfo | sort -k3 -nr | head -20 >> "$KERNEL_LOG"
    else
        echo "Slab info not available" >> "$KERNEL_LOG"
    fi
    echo "" >> "$KERNEL_LOG"
    
    # Memory pressure indicators
    echo "--- Memory Pressure ---" >> "$KERNEL_LOG"
    if [ -f /proc/pressure/memory ]; then
        cat /proc/pressure/memory >> "$KERNEL_LOG"
    else
        echo "PSI not available" >> "$KERNEL_LOG"
    fi
    echo "" >> "$KERNEL_LOG"
    
    # Virtual memory statistics
    echo "--- Virtual Memory Statistics ---" >> "$KERNEL_LOG"
    if [ -f /proc/vmstat ]; then
        grep -E "(pgalloc|pgfree|pgfault|pgmajfault|pgrefill|pgsteal|pgscan|pgactivate|pgdeactivate|pgfault|pgmajfault|kswapd|oom_kill)" /proc/vmstat >> "$KERNEL_LOG"
    fi
    echo "" >> "$KERNEL_LOG"
    
    # OOM killer information
    echo "--- OOM Killer Activity ---" >> "$KERNEL_LOG"
    dmesg | grep -i "killed process\|out of memory\|oom" | tail -10 >> "$KERNEL_LOG" 2>/dev/null || echo "No recent OOM activity" >> "$KERNEL_LOG"
    echo "" >> "$KERNEL_LOG"
    
    # Memory cgroup information
    echo "--- Memory Cgroups ---" >> "$KERNEL_LOG"
    if [ -d /sys/fs/cgroup/memory ]; then
        echo "System memory usage:" >> "$KERNEL_LOG"
        find /sys/fs/cgroup/memory -name "memory.usage_in_bytes" -exec sh -c 'echo "$(dirname {}): $(cat {})"' \; 2>/dev/null | sort -k2 -nr | head -10 >> "$KERNEL_LOG"
    else
        echo "Memory cgroups not available or cgroups v2 in use" >> "$KERNEL_LOG"
    fi
    echo "" >> "$KERNEL_LOG"
    
    echo "=========================================" >> "$KERNEL_LOG"
}

# Function to monitor memory growth automatically
monitor_memory_growth() {
    local sample_count=0
    local max_samples=$((MONITOR_DURATION / SAMPLE_INTERVAL))
    
    echo "=== MEMORY GROWTH MONITORING $(date) ===" >> "$MEMORY_LOG"
    echo "Monitoring duration: $MONITOR_DURATION seconds" >> "$MEMORY_LOG"
    echo "Sample interval: $SAMPLE_INTERVAL seconds" >> "$MEMORY_LOG"
    echo "Maximum samples: $max_samples" >> "$MEMORY_LOG"
    echo "" >> "$MEMORY_LOG"
    
    # Create header
    echo "TIMESTAMP,TOTAL_KB,USED_KB,FREE_KB,AVAILABLE_KB,BUFFERS_KB,CACHED_KB,USAGE_PERCENT,TOP_PROCESS,TOP_PROCESS_MEM" >> "$MEMORY_LOG"
    
    while [ $sample_count -lt $max_samples ]; do
        timestamp=$(date +"%Y-%m-%d %H:%M:%S")
        
        # Get memory information
        mem_info=$(free | awk 'FNR==2{print $2","$3","$4","$7","$6","$6}')  # total,used,free,available,buffers,cached
        usage_percent=$(free | awk 'FNR==2{printf "%.1f", $3/($3+$4)*100}')
        
        # Get top memory consumer
        top_process=$(ps aux --sort=-%mem | awk 'NR==2{print $11","$6}')
        
        echo "$timestamp,$mem_info,$usage_percent,$top_process" >> "$MEMORY_LOG"
        
        # Check for memory alerts
        current_usage=$(free | awk 'FNR==2{printf "%.0f", $3/($3+$4)*100}')
        if [ "$current_usage" -gt "$ALERT_THRESHOLD" ]; then
            echo "$(date): ALERT - Memory usage at ${current_usage}%" >> "$ALERT_LOG"
            
            # Capture detailed snapshot for high memory usage
            echo "=== HIGH MEMORY USAGE SNAPSHOT $(date) ===" >> "$ALERT_LOG"
            free -h >> "$ALERT_LOG"
            echo "--- Top 10 Memory Consumers ---" >> "$ALERT_LOG"
            ps aux --sort=-%mem | head -11 >> "$ALERT_LOG"
            echo "" >> "$ALERT_LOG"
        fi
        
        sample_count=$((sample_count + 1))
        
        # Progress indicator (every 10 samples)
        if [ $((sample_count % 10)) -eq 0 ]; then
            echo -e "${BLUE}[$(date)] Memory monitoring: $sample_count/$max_samples samples${NC}"
        fi
        
        # Wait for next sample
        sleep $SAMPLE_INTERVAL
    done
    
    echo "=== MONITORING COMPLETED $(date) ===" >> "$MEMORY_LOG"
}

# Function to capture continuous process information
monitor_processes() {
    echo "=== PROCESS MONITORING $(date) ===" >> "$PROCESS_LOG"
    
    local sample_count=0
    local max_samples=$((MONITOR_DURATION / (SAMPLE_INTERVAL * 5)))  # Sample processes every 5 minutes
    
    while [ $sample_count -lt $max_samples ]; do
        echo "--- Process Snapshot $(date) ---" >> "$PROCESS_LOG"
        
        # Process count statistics
        echo "Total processes: $(ps aux | wc -l)" >> "$PROCESS_LOG"
        echo "Running: $(ps aux | awk '$8 ~ /^R/ {count++} END {print count+0}')" >> "$PROCESS_LOG"
        echo "Sleeping: $(ps aux | awk '$8 ~ /^S/ {count++} END {print count+0}')" >> "$PROCESS_LOG"
        echo "Zombie: $(ps aux | awk '$8 ~ /^Z/ {count++} END {print count+0}')" >> "$PROCESS_LOG"
        echo "" >> "$PROCESS_LOG"
        
        # Top memory consumers
        echo "Top 15 memory consumers:" >> "$PROCESS_LOG"
        ps aux --sort=-%mem | head -16 >> "$PROCESS_LOG"
        echo "" >> "$PROCESS_LOG"
        
        # Check for zombie processes
        zombie_count=$(ps aux | awk '$8 ~ /^Z/ {count++} END {print count+0}')
        if [ "$zombie_count" -gt 0 ]; then
            echo "$(date): ALERT - $zombie_count zombie processes detected" >> "$ALERT_LOG"
            ps aux | awk '$8 ~ /^Z/ {print}' >> "$ALERT_LOG"
            echo "" >> "$ALERT_LOG"
        fi
        
        sample_count=$((sample_count + 1))
        sleep $((SAMPLE_INTERVAL * 5))
    done
}

# Function to monitor system events
monitor_system_events() {
    echo "=== SYSTEM EVENT MONITORING $(date) ===" >> "$SYSTEM_LOG"
    
    # Monitor kernel messages
    echo "--- Initial Kernel Messages (last 50) ---" >> "$SYSTEM_LOG"
    dmesg | tail -50 >> "$SYSTEM_LOG"
    echo "" >> "$SYSTEM_LOG"
    
    # Monitor system logs in background
    if command -v journalctl &> /dev/null; then
        echo "--- System Journal Monitoring ---" >> "$SYSTEM_LOG"
        journalctl --since="$(date)" -f --no-pager -n 0 >> "$SYSTEM_LOG" &
        JOURNAL_PID=$!
        
        # Stop journal monitoring after duration
        (sleep $MONITOR_DURATION; kill $JOURNAL_PID 2>/dev/null) &
    fi
}

# Function to generate summary report
generate_summary() {
    echo "=== BOOT DIAGNOSTICS SUMMARY $(date) ===" >> "$SUMMARY_LOG"
    
    # System overview
    echo "--- Session Information ---" >> "$SUMMARY_LOG"
    echo "Session ID: $SESSION_ID" >> "$SUMMARY_LOG"
    echo "Monitoring duration: $((MONITOR_DURATION / 60)) minutes" >> "$SUMMARY_LOG"
    echo "Boot time: $(who -b 2>/dev/null || echo "unknown")" >> "$SUMMARY_LOG"
    echo "Analysis time: $(date)" >> "$SUMMARY_LOG"
    echo "" >> "$SUMMARY_LOG"
    
    # Memory analysis
    echo "--- Memory Analysis Summary ---" >> "$SUMMARY_LOG"
    
    # Initial vs final memory usage
    initial_memory=$(head -2 "$MEMORY_LOG" | tail -1 | cut -d, -f6)
    final_memory=$(tail -1 "$MEMORY_LOG" | cut -d, -f6)
    
    if [ -n "$initial_memory" ] && [ -n "$final_memory" ] && [ "$initial_memory" != "USAGE_PERCENT" ]; then
        memory_growth=$(awk "BEGIN {printf \"%.1f\", $final_memory - $initial_memory}")
        echo "Initial memory usage: ${initial_memory}%" >> "$SUMMARY_LOG"
        echo "Final memory usage: ${final_memory}%" >> "$SUMMARY_LOG"
        echo "Memory growth: ${memory_growth}%" >> "$SUMMARY_LOG"
    else
        echo "Memory trend analysis: Insufficient data" >> "$SUMMARY_LOG"
    fi
    echo "" >> "$SUMMARY_LOG"
    
    # Alert summary
    echo "--- Alert Summary ---" >> "$SUMMARY_LOG"
    if [ -f "$ALERT_LOG" ]; then
        alert_count=$(grep -c "ALERT" "$ALERT_LOG" 2>/dev/null || echo 0)
        echo "Total alerts generated: $alert_count" >> "$SUMMARY_LOG"
        
        if [ "$alert_count" -gt 0 ]; then
            echo "Alert details:" >> "$SUMMARY_LOG"
            grep "ALERT" "$ALERT_LOG" >> "$SUMMARY_LOG"
        fi
    else
        echo "No alerts generated" >> "$SUMMARY_LOG"
    fi
    echo "" >> "$SUMMARY_LOG"
    
    # Process analysis
    echo "--- Process Analysis Summary ---" >> "$SUMMARY_LOG"
    if [ -f "$PROCESS_LOG" ]; then
        echo "Process monitoring samples collected" >> "$SUMMARY_LOG"
        
        # Check for consistent high memory users
        echo "Most frequent top memory consumer:" >> "$SUMMARY_LOG"
        grep "Top 15 memory consumers:" "$PROCESS_LOG" -A 2 | grep -v "Top 15\|--" | awk '{print $11}' | sort | uniq -c | sort -nr | head -1 >> "$SUMMARY_LOG" 2>/dev/null || echo "Unable to determine" >> "$SUMMARY_LOG"
    fi
    echo "" >> "$SUMMARY_LOG"
    
    # Recommendations
    echo "--- Recommendations ---" >> "$SUMMARY_LOG"
    echo "1. Review memory growth patterns in: $MEMORY_LOG" >> "$SUMMARY_LOG"
    echo "2. Analyze process behavior in: $PROCESS_LOG" >> "$SUMMARY_LOG"
    echo "3. Check kernel memory allocation in: $KERNEL_LOG" >> "$SUMMARY_LOG"
    echo "4. Monitor system events in: $SYSTEM_LOG" >> "$SUMMARY_LOG"
    
    if [ -f "$ALERT_LOG" ] && [ -s "$ALERT_LOG" ]; then
        echo "5. Investigate alerts in: $ALERT_LOG" >> "$SUMMARY_LOG"
    fi
    echo "" >> "$SUMMARY_LOG"
    
    # File locations
    echo "--- Output Files ---" >> "$SUMMARY_LOG"
    echo "Boot state: $BOOT_LOG" >> "$SUMMARY_LOG"
    echo "Memory monitoring: $MEMORY_LOG" >> "$SUMMARY_LOG"
    echo "Process monitoring: $PROCESS_LOG" >> "$SUMMARY_LOG"
    echo "Kernel analysis: $KERNEL_LOG" >> "$SUMMARY_LOG"
    echo "System events: $SYSTEM_LOG" >> "$SUMMARY_LOG"
    echo "Alerts: $ALERT_LOG" >> "$SUMMARY_LOG"
    echo "This summary: $SUMMARY_LOG" >> "$SUMMARY_LOG"
    
    echo "=========================================" >> "$SUMMARY_LOG"
}

# Function to setup systemd service
setup_systemd_service() {
    cat > /etc/systemd/system/boot-diagnostics.service << 'EOF'
[Unit]
Description=Boot Memory Diagnostics
After=multi-user.target
Wants=multi-user.target

[Service]
Type=forking
ExecStart=/home/delorenj/docker/trunk-main/scripts/boot_diagnostics.sh
User=root
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable boot-diagnostics.service
    
    echo "Systemd service installed. The diagnostics will run automatically on next boot."
    echo "To run manually: sudo systemctl start boot-diagnostics.service"
    echo "To check status: sudo systemctl status boot-diagnostics.service"
    echo "To disable: sudo systemctl disable boot-diagnostics.service"
}

# Check if we're being asked to install as a service
if [ "${1:-}" = "--install-service" ]; then
    if [ "$EUID" -ne 0 ]; then
        echo "Installing systemd service requires root privileges"
        exit 1
    fi
    setup_systemd_service
    exit 0
fi

# Main execution starts here
echo -e "${YELLOW}[$(date)] Capturing initial boot state...${NC}"
capture_boot_state

echo -e "${YELLOW}[$(date)] Analyzing kernel memory allocation...${NC}"
capture_kernel_memory

echo -e "${YELLOW}[$(date)] Starting background monitoring...${NC}"

# Start background monitoring processes
monitor_memory_growth &
MEMORY_PID=$!

monitor_processes &
PROCESS_PID=$!

monitor_system_events &

# Wait for monitoring to complete
echo -e "${BLUE}[$(date)] Monitoring in progress... (Duration: $((MONITOR_DURATION / 60)) minutes)${NC}"
wait $MEMORY_PID
wait $PROCESS_PID

echo -e "${YELLOW}[$(date)] Generating summary report...${NC}"
generate_summary

echo -e "${GREEN}[$(date)] Boot diagnostics completed!${NC}"
echo -e "${GREEN}Session ID: $SESSION_ID${NC}"
echo -e "${GREEN}Summary: $SUMMARY_LOG${NC}"
echo -e "${GREEN}All logs saved to: $LOG_DIR${NC}"

# Display summary
echo -e "\n${YELLOW}=== DIAGNOSTICS SUMMARY ===${NC}"
if [ -f "$SUMMARY_LOG" ]; then
    tail -30 "$SUMMARY_LOG"
else
    echo "Summary file not generated"
fi

# Show installation instructions
if [ "$EUID" -eq 0 ] && [ ! -f "/etc/systemd/system/boot-diagnostics.service" ]; then
    echo -e "\n${BLUE}To run diagnostics automatically on boot, run:${NC}"
    echo -e "${BLUE}sudo $0 --install-service${NC}"
fi