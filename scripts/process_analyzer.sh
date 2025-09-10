#!/bin/bash

# Comprehensive Process Analysis Script
# Usage: ./process_analyzer.sh [output_file]

set -euo pipefail

# Configuration
OUTPUT_FILE=${1:-"/var/log/process-analysis-$(date +%Y%m%d_%H%M%S).log"}
TEMP_DIR="/tmp/process_analyzer_$$"
ANALYSIS_DURATION=300  # 5 minutes for growth pattern analysis

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Ensure output directory exists
sudo mkdir -p "$(dirname "$OUTPUT_FILE")"
sudo touch "$OUTPUT_FILE"
sudo chown $USER:$USER "$OUTPUT_FILE"

# Create temp directory
mkdir -p "$TEMP_DIR"

echo -e "${GREEN}[$(date)] Starting comprehensive process analysis...${NC}"
echo -e "${BLUE}Output file: ${OUTPUT_FILE}${NC}"

# Function to log header
log_header() {
    local title="$1"
    echo "================================================================================================" >> "$OUTPUT_FILE"
    echo "=== $title - $(date) ===" >> "$OUTPUT_FILE"
    echo "================================================================================================" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
}

# Function to identify top memory consumers
analyze_memory_consumers() {
    log_header "TOP MEMORY CONSUMERS ANALYSIS"
    
    echo "--- Top 25 Processes by RSS (Resident Set Size) ---" >> "$OUTPUT_FILE"
    ps aux --sort=-%mem | head -26 >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    
    echo "--- Top 25 Processes by VSZ (Virtual Size) ---" >> "$OUTPUT_FILE"
    ps aux --sort=-vsz | head -26 >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    
    echo "--- Memory Usage by User ---" >> "$OUTPUT_FILE"
    ps aux | awk 'NR>1 {user_mem[$1] += $6; user_count[$1]++} END {
        printf "%-15s %15s %15s %10s\n", "USER", "TOTAL_RSS_KB", "AVG_RSS_KB", "PROCESSES"
        for (user in user_mem) {
            printf "%-15s %15.0f %15.0f %10d\n", user, user_mem[user], user_mem[user]/user_count[user], user_count[user]
        }
    }' | sort -k2 -nr >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    
    echo "--- Detailed Memory Analysis for Top 10 Processes ---" >> "$OUTPUT_FILE"
    ps aux --sort=-%mem | awk 'NR>1 && NR<=11 {print $2}' | while read pid; do
        if [ -f "/proc/$pid/status" ]; then
            echo "Process ID: $pid" >> "$OUTPUT_FILE"
            grep -E "(Name|VmPeak|VmSize|VmLck|VmPin|VmHWM|VmRSS|RssAnon|RssFile|RssShmem|VmData|VmStk|VmExe|VmLib|VmPTE|VmSwap)" "/proc/$pid/status" 2>/dev/null >> "$OUTPUT_FILE" || echo "  Process no longer exists" >> "$OUTPUT_FILE"
            echo "" >> "$OUTPUT_FILE"
        fi
    done
    
    echo "--- Memory Mapping Details for Top 5 Processes ---" >> "$OUTPUT_FILE"
    ps aux --sort=-%mem | awk 'NR>1 && NR<=6 {print $2}' | while read pid; do
        if [ -f "/proc/$pid/smaps" ]; then
            echo "Process ID: $pid ($(cat /proc/$pid/comm 2>/dev/null || echo unknown))" >> "$OUTPUT_FILE"
            
            # Summarize memory regions
            awk '
                /^[0-9a-f]+-[0-9a-f]+ / { region_count++ }
                /^Size:/ { total_size += $2 }
                /^Rss:/ { total_rss += $2 }
                /^Pss:/ { total_pss += $2 }
                /^Shared_Clean:/ { shared_clean += $2 }
                /^Shared_Dirty:/ { shared_dirty += $2 }
                /^Private_Clean:/ { private_clean += $2 }
                /^Private_Dirty:/ { private_dirty += $2 }
                /^Swap:/ { total_swap += $2 }
                END {
                    printf "  Memory Regions: %d\n", region_count
                    printf "  Total Size: %d kB\n", total_size
                    printf "  Total RSS: %d kB\n", total_rss
                    printf "  Total PSS: %d kB\n", total_pss
                    printf "  Shared Clean: %d kB\n", shared_clean
                    printf "  Shared Dirty: %d kB\n", shared_dirty
                    printf "  Private Clean: %d kB\n", private_clean
                    printf "  Private Dirty: %d kB\n", private_dirty
                    printf "  Swap: %d kB\n", total_swap
                }
            ' "/proc/$pid/smaps" >> "$OUTPUT_FILE" 2>/dev/null || echo "  Unable to analyze memory maps" >> "$OUTPUT_FILE"
            echo "" >> "$OUTPUT_FILE"
        fi
    done
}

# Function to analyze memory growth patterns
analyze_memory_growth() {
    log_header "MEMORY GROWTH PATTERN ANALYSIS"
    
    echo "--- Analyzing memory growth over $ANALYSIS_DURATION seconds ---" >> "$OUTPUT_FILE"
    echo "Starting memory growth analysis at $(date)" >> "$OUTPUT_FILE"
    
    # Take initial snapshot
    ps aux --sort=-%mem | head -11 | awk 'NR>1 {print $2, $6, $11}' > "$TEMP_DIR/initial_memory.txt"
    
    # Wait and take second snapshot
    sleep $ANALYSIS_DURATION
    
    ps aux --sort=-%mem | head -11 | awk 'NR>1 {print $2, $6, $11}' > "$TEMP_DIR/final_memory.txt"
    
    echo "--- Memory Growth Analysis Results ---" >> "$OUTPUT_FILE"
    echo "Analysis completed at $(date)" >> "$OUTPUT_FILE"
    printf "%-8s %-12s %-12s %-12s %-15s %s\n" "PID" "INITIAL_KB" "FINAL_KB" "GROWTH_KB" "GROWTH_%" "COMMAND" >> "$OUTPUT_FILE"
    
    # Compare snapshots
    while read pid final_mem cmd; do
        initial_mem=$(grep "^$pid " "$TEMP_DIR/initial_memory.txt" 2>/dev/null | awk '{print $2}' || echo "0")
        if [ "$initial_mem" != "0" ]; then
            growth_kb=$((final_mem - initial_mem))
            if [ "$initial_mem" -gt 0 ]; then
                growth_percent=$(awk "BEGIN {printf \"%.2f\", ($final_mem - $initial_mem) * 100 / $initial_mem}")
            else
                growth_percent="N/A"
            fi
            printf "%-8s %-12s %-12s %-12s %-15s %s\n" "$pid" "$initial_mem" "$final_mem" "$growth_kb" "$growth_percent" "$cmd" >> "$OUTPUT_FILE"
        else
            printf "%-8s %-12s %-12s %-12s %-15s %s\n" "$pid" "NEW" "$final_mem" "$final_mem" "NEW" "$cmd" >> "$OUTPUT_FILE"
        fi
    done < "$TEMP_DIR/final_memory.txt"
    
    echo "" >> "$OUTPUT_FILE"
    
    # Check for new processes
    echo "--- New Processes (not in initial scan) ---" >> "$OUTPUT_FILE"
    comm -13 <(awk '{print $1}' "$TEMP_DIR/initial_memory.txt" | sort) <(awk '{print $1}' "$TEMP_DIR/final_memory.txt" | sort) > "$TEMP_DIR/new_processes.txt"
    
    if [ -s "$TEMP_DIR/new_processes.txt" ]; then
        while read pid; do
            if [ -f "/proc/$pid/stat" ]; then
                echo "PID $pid: $(cat /proc/$pid/comm 2>/dev/null || echo unknown)" >> "$OUTPUT_FILE"
            fi
        done < "$TEMP_DIR/new_processes.txt"
    else
        echo "No new processes detected" >> "$OUTPUT_FILE"
    fi
    echo "" >> "$OUTPUT_FILE"
}

# Function to detect zombie processes
analyze_zombie_processes() {
    log_header "ZOMBIE PROCESS ANALYSIS"
    
    zombie_count=$(ps aux | awk '$8 ~ /^Z/ {count++} END {print count+0}')
    echo "Total zombie processes: $zombie_count" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    
    if [ "$zombie_count" -gt 0 ]; then
        echo "--- Zombie Process Details ---" >> "$OUTPUT_FILE"
        ps aux | awk '$8 ~ /^Z/ {print "PID:", $2, "PPID:", $3, "Command:", $11}' >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
        
        echo "--- Parent Processes of Zombies ---" >> "$OUTPUT_FILE"
        ps aux | awk '$8 ~ /^Z/ {print $3}' | sort | uniq | while read ppid; do
            if [ -f "/proc/$ppid/stat" ]; then
                echo "Parent PID $ppid: $(cat /proc/$ppid/comm 2>/dev/null || echo unknown)" >> "$OUTPUT_FILE"
                ps aux | awk -v ppid="$ppid" '$2 == ppid {print "  Full command:", $0}' >> "$OUTPUT_FILE"
            fi
        done
    else
        echo "No zombie processes found" >> "$OUTPUT_FILE"
    fi
    echo "" >> "$OUTPUT_FILE"
}

# Function to analyze file descriptor leaks
analyze_file_descriptors() {
    log_header "FILE DESCRIPTOR LEAK ANALYSIS"
    
    echo "--- System File Descriptor Limits and Usage ---" >> "$OUTPUT_FILE"
    echo "System-wide FD limit: $(cat /proc/sys/fs/file-max)" >> "$OUTPUT_FILE"
    current_fds=$(cat /proc/sys/fs/file-nr | cut -f1)
    echo "Currently open FDs: $current_fds" >> "$OUTPUT_FILE"
    echo "FD usage percentage: $(awk "BEGIN {printf \"%.2f%%\", $current_fds * 100 / $(cat /proc/sys/fs/file-max)}")" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    
    echo "--- Top 20 Processes by File Descriptor Usage ---" >> "$OUTPUT_FILE"
    printf "%-8s %-15s %-8s %s\n" "PID" "COMMAND" "FD_COUNT" "STATUS" >> "$OUTPUT_FILE"
    
    for pid in /proc/[0-9]*; do
        if [ -d "$pid/fd" ]; then
            pid_num=$(basename "$pid")
            fd_count=$(ls "$pid/fd" 2>/dev/null | wc -l)
            if [ "$fd_count" -gt 10 ]; then  # Only show processes with >10 FDs
                command=$(cat "$pid/comm" 2>/dev/null || echo "unknown")
                status=$(awk '/^State:/ {print $2}' "$pid/status" 2>/dev/null || echo "unknown")
                printf "%-8s %-15s %-8s %s\n" "$pid_num" "$command" "$fd_count" "$status"
            fi
        fi
    done | sort -k3 -nr | head -20 >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    
    echo "--- File Descriptor Types for Top 5 FD Consumers ---" >> "$OUTPUT_FILE"
    for pid in /proc/[0-9]*; do
        if [ -d "$pid/fd" ]; then
            pid_num=$(basename "$pid")
            fd_count=$(ls "$pid/fd" 2>/dev/null | wc -l)
            echo "$pid_num $fd_count"
        fi
    done | sort -k2 -nr | head -5 | while read pid fd_count; do
        if [ -d "/proc/$pid/fd" ]; then
            echo "Process $pid ($(cat /proc/$pid/comm 2>/dev/null || echo unknown)) - $fd_count FDs:" >> "$OUTPUT_FILE"
            
            # Categorize file descriptors
            ls -la "/proc/$pid/fd" 2>/dev/null | awk '
                NR>1 {
                    if ($NF ~ /socket:/) sockets++
                    else if ($NF ~ /pipe:/) pipes++
                    else if ($NF ~ /\/dev\//) devices++
                    else if ($NF ~ /\/proc\//) proc_files++
                    else if ($NF ~ /\/tmp\//) temp_files++
                    else if ($NF ~ /\.log$|\/log\//) log_files++
                    else regular_files++
                }
                END {
                    printf "  Sockets: %d\n", sockets+0
                    printf "  Pipes: %d\n", pipes+0
                    printf "  Devices: %d\n", devices+0
                    printf "  Proc files: %d\n", proc_files+0
                    printf "  Temp files: %d\n", temp_files+0
                    printf "  Log files: %d\n", log_files+0
                    printf "  Regular files: %d\n", regular_files+0
                }
            ' >> "$OUTPUT_FILE"
            echo "" >> "$OUTPUT_FILE"
        fi
    done
}

# Function to analyze shared memory usage
analyze_shared_memory() {
    log_header "SHARED MEMORY ANALYSIS"
    
    echo "--- System V Shared Memory Segments ---" >> "$OUTPUT_FILE"
    if command -v ipcs &> /dev/null; then
        echo "Shared Memory Segments:" >> "$OUTPUT_FILE"
        ipcs -m >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
        
        echo "Shared Memory Summary:" >> "$OUTPUT_FILE"
        ipcs -m -u >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
        
        echo "Message Queues:" >> "$OUTPUT_FILE"
        ipcs -q >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
        
        echo "Semaphore Arrays:" >> "$OUTPUT_FILE"
        ipcs -s >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
    else
        echo "ipcs command not available" >> "$OUTPUT_FILE"
    fi
    
    echo "--- POSIX Shared Memory (/dev/shm) ---" >> "$OUTPUT_FILE"
    if [ -d "/dev/shm" ]; then
        echo "Total /dev/shm usage:" >> "$OUTPUT_FILE"
        du -sh /dev/shm 2>/dev/null >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
        
        echo "Files in /dev/shm:" >> "$OUTPUT_FILE"
        ls -lah /dev/shm 2>/dev/null >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
    else
        echo "/dev/shm not available" >> "$OUTPUT_FILE"
    fi
    
    echo "--- Process Shared Memory Usage ---" >> "$OUTPUT_FILE"
    printf "%-8s %-15s %-12s %-12s %s\n" "PID" "COMMAND" "SHARED_KB" "PRIVATE_KB" "RATIO" >> "$OUTPUT_FILE"
    
    for pid in /proc/[0-9]*; do
        if [ -f "$pid/smaps" ]; then
            pid_num=$(basename "$pid")
            command=$(cat "$pid/comm" 2>/dev/null || echo "unknown")
            
            # Calculate shared vs private memory
            shared_kb=$(awk '/^Shared_/ {sum += $2} END {print sum+0}' "$pid/smaps" 2>/dev/null)
            private_kb=$(awk '/^Private_/ {sum += $2} END {print sum+0}' "$pid/smaps" 2>/dev/null)
            
            if [ "$shared_kb" -gt 1024 ] || [ "$private_kb" -gt 1024 ]; then  # Only show significant memory users
                if [ "$private_kb" -gt 0 ]; then
                    ratio=$(awk "BEGIN {printf \"%.2f\", $shared_kb / $private_kb}")
                else
                    ratio="inf"
                fi
                printf "%-8s %-15s %-12s %-12s %s\n" "$pid_num" "$command" "$shared_kb" "$private_kb" "$ratio"
            fi
        fi
    done | sort -k3 -nr | head -20 >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
}

# Function to generate alerts and recommendations
generate_alerts() {
    log_header "ALERTS AND RECOMMENDATIONS"
    
    echo "--- System Health Alerts ---" >> "$OUTPUT_FILE"
    
    # Memory usage alerts
    mem_percent=$(free | awk 'FNR==2{printf "%.0f", $3/($3+$4)*100}')
    if [ "$mem_percent" -gt 90 ]; then
        echo "CRITICAL: Memory usage is ${mem_percent}% - immediate action required" >> "$OUTPUT_FILE"
    elif [ "$mem_percent" -gt 80 ]; then
        echo "WARNING: Memory usage is ${mem_percent}% - monitor closely" >> "$OUTPUT_FILE"
    fi
    
    # Swap usage alerts
    swap_used=$(free | awk 'FNR==3{print $3}')
    if [ "$swap_used" -gt 1048576 ]; then  # > 1GB
        echo "WARNING: Heavy swap usage detected ($(free -h | awk 'FNR==3{print $3}'))" >> "$OUTPUT_FILE"
    elif [ "$swap_used" -gt 0 ]; then
        echo "INFO: Some swap usage detected ($(free -h | awk 'FNR==3{print $3}'))" >> "$OUTPUT_FILE"
    fi
    
    # Process count alerts
    process_count=$(ps aux | wc -l)
    if [ "$process_count" -gt 1000 ]; then
        echo "WARNING: High process count ($process_count processes)" >> "$OUTPUT_FILE"
    fi
    
    # Zombie process alerts
    zombie_count=$(ps aux | awk '$8 ~ /^Z/ {count++} END {print count+0}')
    if [ "$zombie_count" -gt 0 ]; then
        echo "WARNING: $zombie_count zombie processes detected" >> "$OUTPUT_FILE"
    fi
    
    # File descriptor alerts
    current_fds=$(cat /proc/sys/fs/file-nr | cut -f1)
    max_fds=$(cat /proc/sys/fs/file-max)
    fd_percent=$(awk "BEGIN {printf \"%.0f\", $current_fds * 100 / $max_fds}")
    if [ "$fd_percent" -gt 80 ]; then
        echo "WARNING: File descriptor usage is ${fd_percent}%" >> "$OUTPUT_FILE"
    fi
    
    echo "" >> "$OUTPUT_FILE"
    
    echo "--- Recommendations ---" >> "$OUTPUT_FILE"
    echo "1. Monitor processes with highest memory growth rates" >> "$OUTPUT_FILE"
    echo "2. Investigate processes with excessive file descriptor usage" >> "$OUTPUT_FILE"
    echo "3. Check for memory leaks in long-running processes" >> "$OUTPUT_FILE"
    echo "4. Review shared memory usage for optimization opportunities" >> "$OUTPUT_FILE"
    echo "5. Set up continuous monitoring to track trends over time" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
}

# Main execution
echo -e "${YELLOW}[$(date)] Running memory consumers analysis...${NC}"
analyze_memory_consumers

echo -e "${YELLOW}[$(date)] Running memory growth pattern analysis (this will take $(($ANALYSIS_DURATION / 60)) minutes)...${NC}"
analyze_memory_growth

echo -e "${YELLOW}[$(date)] Running zombie process analysis...${NC}"
analyze_zombie_processes

echo -e "${YELLOW}[$(date)] Running file descriptor analysis...${NC}"
analyze_file_descriptors

echo -e "${YELLOW}[$(date)] Running shared memory analysis...${NC}"
analyze_shared_memory

echo -e "${YELLOW}[$(date)] Generating alerts and recommendations...${NC}"
generate_alerts

# Cleanup
rm -rf "$TEMP_DIR"

echo -e "${GREEN}[$(date)] Process analysis completed!${NC}"
echo -e "${GREEN}Analysis results saved to: ${OUTPUT_FILE}${NC}"
echo -e "${GREEN}File size: $(du -h "$OUTPUT_FILE" | cut -f1)${NC}"

# Display critical alerts
echo -e "\n${YELLOW}=== CRITICAL ALERTS ===${NC}"
grep -E "CRITICAL|WARNING" "$OUTPUT_FILE" || echo "No critical alerts found"