#!/bin/bash

# Comprehensive Memory Monitoring Script
# Usage: ./memory_monitor.sh [duration_minutes] [sample_interval_seconds]

set -euo pipefail

# Configuration
DURATION_MINUTES=${1:-60}
SAMPLE_INTERVAL=${2:-30}
LOG_DIR="/var/log/memory-monitor"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_BASE="$LOG_DIR/memory_monitor_$TIMESTAMP"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create log directory
sudo mkdir -p "$LOG_DIR"
sudo chown $USER:$USER "$LOG_DIR"

echo -e "${GREEN}[$(date)] Starting comprehensive memory monitoring...${NC}"
echo -e "${BLUE}Duration: ${DURATION_MINUTES} minutes${NC}"
echo -e "${BLUE}Sample interval: ${SAMPLE_INTERVAL} seconds${NC}"
echo -e "${BLUE}Log directory: ${LOG_DIR}${NC}"

# Initialize log files
MEMORY_LOG="${OUTPUT_BASE}_memory.log"
PROCESS_LOG="${OUTPUT_BASE}_processes.log"
DOCKER_LOG="${OUTPUT_BASE}_docker.log"
FRAGMENTATION_LOG="${OUTPUT_BASE}_fragmentation.log"
SWAP_LOG="${OUTPUT_BASE}_swap.log"
SUMMARY_LOG="${OUTPUT_BASE}_summary.log"

# Function to log system memory usage
log_system_memory() {
    echo "=== SYSTEM MEMORY $(date) ===" >> "$MEMORY_LOG"
    
    # Detailed memory info
    free -h >> "$MEMORY_LOG"
    echo "" >> "$MEMORY_LOG"
    
    # Memory info from /proc/meminfo
    echo "--- /proc/meminfo ---" >> "$MEMORY_LOG"
    grep -E "(MemTotal|MemFree|MemAvailable|Buffers|Cached|SwapTotal|SwapFree|Dirty|Writeback|Slab|SReclaimable|SUnreclaim|KReclaimable|PageTables|VmallocUsed|Percpu|HugePages)" /proc/meminfo >> "$MEMORY_LOG"
    echo "" >> "$MEMORY_LOG"
    
    # Memory pressure information
    echo "--- Memory Pressure ---" >> "$MEMORY_LOG"
    if [ -f /proc/pressure/memory ]; then
        cat /proc/pressure/memory >> "$MEMORY_LOG"
    else
        echo "PSI not available" >> "$MEMORY_LOG"
    fi
    echo "" >> "$MEMORY_LOG"
    
    # Virtual memory statistics
    echo "--- VM Stats ---" >> "$MEMORY_LOG"
    grep -E "(nr_free_pages|nr_inactive|nr_active|nr_dirty|nr_writeback|nr_slab|nr_mapped)" /proc/vmstat >> "$MEMORY_LOG"
    echo "===============================================" >> "$MEMORY_LOG"
    echo "" >> "$MEMORY_LOG"
}

# Function to log process-level memory usage
log_process_memory() {
    echo "=== PROCESS MEMORY $(date) ===" >> "$PROCESS_LOG"
    
    # Top memory consumers
    echo "--- Top 20 Memory Consumers (RSS) ---" >> "$PROCESS_LOG"
    ps aux --sort=-%mem | head -21 >> "$PROCESS_LOG"
    echo "" >> "$PROCESS_LOG"
    
    # Top memory consumers by VSZ
    echo "--- Top 20 Memory Consumers (VSZ) ---" >> "$PROCESS_LOG"
    ps aux --sort=-vsz | head -21 >> "$PROCESS_LOG"
    echo "" >> "$PROCESS_LOG"
    
    # Memory map summary for high consumers
    echo "--- Memory Maps for Top 5 Processes ---" >> "$PROCESS_LOG"
    ps aux --sort=-%mem | awk 'NR>1 && NR<=6 {print $2}' | while read pid; do
        if [ -f "/proc/$pid/smaps" ]; then
            echo "Process $pid:" >> "$PROCESS_LOG"
            grep -E "(Size|Rss|Pss|Shared|Private)" "/proc/$pid/smaps" | \
                awk '{sum[$1] += $2} END {for (i in sum) printf "  %s: %d kB\n", i, sum[i]}' >> "$PROCESS_LOG"
            echo "" >> "$PROCESS_LOG"
        fi
    done
    
    # Process count and zombie detection
    echo "--- Process Statistics ---" >> "$PROCESS_LOG"
    echo "Total processes: $(ps aux | wc -l)" >> "$PROCESS_LOG"
    echo "Zombie processes: $(ps aux | awk '$8 ~ /^Z/ {count++} END {print count+0}')" >> "$PROCESS_LOG"
    echo "Sleeping processes: $(ps aux | awk '$8 ~ /^S/ {count++} END {print count+0}')" >> "$PROCESS_LOG"
    echo "Running processes: $(ps aux | awk '$8 ~ /^R/ {count++} END {print count+0}')" >> "$PROCESS_LOG"
    echo "" >> "$PROCESS_LOG"
    
    # File descriptor usage
    echo "--- File Descriptor Usage ---" >> "$PROCESS_LOG"
    echo "System FD limit: $(cat /proc/sys/fs/file-max)" >> "$PROCESS_LOG"
    echo "Open FDs: $(cat /proc/sys/fs/file-nr | cut -f1)" >> "$PROCESS_LOG"
    echo "Top 10 FD consumers:" >> "$PROCESS_LOG"
    lsof 2>/dev/null | awk '{print $2}' | sort | uniq -c | sort -nr | head -10 >> "$PROCESS_LOG" 2>/dev/null || echo "lsof not available" >> "$PROCESS_LOG"
    
    echo "===============================================" >> "$PROCESS_LOG"
    echo "" >> "$PROCESS_LOG"
}

# Function to log Docker container memory usage
log_docker_memory() {
    if ! command -v docker &> /dev/null; then
        echo "Docker not installed" >> "$DOCKER_LOG"
        return
    fi
    
    echo "=== DOCKER MEMORY $(date) ===" >> "$DOCKER_LOG"
    
    # Container memory stats
    echo "--- Container Memory Usage ---" >> "$DOCKER_LOG"
    docker stats --no-stream --format "table {{.Container}}\t{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}" >> "$DOCKER_LOG" 2>/dev/null || echo "No containers running" >> "$DOCKER_LOG"
    echo "" >> "$DOCKER_LOG"
    
    # Detailed container inspection for memory limits
    echo "--- Container Memory Limits ---" >> "$DOCKER_LOG"
    docker ps --format "{{.Names}}" 2>/dev/null | while read container; do
        if [ -n "$container" ]; then
            echo "Container: $container" >> "$DOCKER_LOG"
            docker inspect "$container" | jq -r '.[].HostConfig | "Memory: \(.Memory // "unlimited"), MemorySwap: \(.MemorySwap // "unlimited"), OomKillDisable: \(.OomKillDisable)"' >> "$DOCKER_LOG" 2>/dev/null || echo "  Unable to inspect $container" >> "$DOCKER_LOG"
        fi
    done
    echo "" >> "$DOCKER_LOG"
    
    # Docker system usage
    echo "--- Docker System Usage ---" >> "$DOCKER_LOG"
    docker system df >> "$DOCKER_LOG" 2>/dev/null || echo "Unable to get Docker system usage" >> "$DOCKER_LOG"
    
    echo "===============================================" >> "$DOCKER_LOG"
    echo "" >> "$DOCKER_LOG"
}

# Function to analyze memory fragmentation
log_memory_fragmentation() {
    echo "=== MEMORY FRAGMENTATION $(date) ===" >> "$FRAGMENTATION_LOG"
    
    # Buddy allocator info
    echo "--- Buddy Allocator Info ---" >> "$FRAGMENTATION_LOG"
    if [ -f /proc/buddyinfo ]; then
        cat /proc/buddyinfo >> "$FRAGMENTATION_LOG"
    else
        echo "Buddy info not available" >> "$FRAGMENTATION_LOG"
    fi
    echo "" >> "$FRAGMENTATION_LOG"
    
    # Slab allocator info
    echo "--- Slab Allocator Info (Top 20) ---" >> "$FRAGMENTATION_LOG"
    if [ -f /proc/slabinfo ]; then
        head -1 /proc/slabinfo >> "$FRAGMENTATION_LOG"
        tail -n +2 /proc/slabinfo | sort -k3 -nr | head -20 >> "$FRAGMENTATION_LOG"
    else
        echo "Slab info not available" >> "$FRAGMENTATION_LOG"
    fi
    echo "" >> "$FRAGMENTATION_LOG"
    
    # Zone info
    echo "--- Zone Information ---" >> "$FRAGMENTATION_LOG"
    if [ -f /proc/zoneinfo ]; then
        grep -E "(Node|zone|free|min|low|high)" /proc/zoneinfo >> "$FRAGMENTATION_LOG"
    else
        echo "Zone info not available" >> "$FRAGMENTATION_LOG"
    fi
    
    echo "===============================================" >> "$FRAGMENTATION_LOG"
    echo "" >> "$FRAGMENTATION_LOG"
}

# Function to log swap usage patterns
log_swap_usage() {
    echo "=== SWAP USAGE $(date) ===" >> "$SWAP_LOG"
    
    # Overall swap usage
    echo "--- Swap Summary ---" >> "$SWAP_LOG"
    swapon --show >> "$SWAP_LOG" 2>/dev/null || echo "No swap configured" >> "$SWAP_LOG"
    echo "" >> "$SWAP_LOG"
    
    # Per-process swap usage
    echo "--- Top 20 Swap Consumers ---" >> "$SWAP_LOG"
    if [ -d /proc ]; then
        {
            echo "PID SWAP_KB COMMAND"
            for pid in /proc/[0-9]*; do
                if [ -f "$pid/smaps" ]; then
                    pid_num=$(basename "$pid")
                    swap_kb=$(grep "^Swap:" "$pid/smaps" 2>/dev/null | awk '{sum += $2} END {print sum+0}')
                    if [ "$swap_kb" -gt 0 ]; then
                        command=$(cat "$pid/comm" 2>/dev/null || echo "unknown")
                        echo "$pid_num $swap_kb $command"
                    fi
                fi
            done
        } | sort -k2 -nr | head -20 >> "$SWAP_LOG"
    fi
    echo "" >> "$SWAP_LOG"
    
    # Swap I/O stats
    echo "--- Swap I/O Statistics ---" >> "$SWAP_LOG"
    grep -E "(swap|pswp)" /proc/vmstat >> "$SWAP_LOG"
    
    echo "===============================================" >> "$SWAP_LOG"
    echo "" >> "$SWAP_LOG"
}

# Function to generate summary
generate_summary() {
    echo "=== MEMORY MONITORING SUMMARY $(date) ===" >> "$SUMMARY_LOG"
    
    # System overview
    echo "--- System Overview ---" >> "$SUMMARY_LOG"
    echo "Hostname: $(hostname)" >> "$SUMMARY_LOG"
    echo "Kernel: $(uname -r)" >> "$SUMMARY_LOG"
    echo "Uptime: $(uptime)" >> "$SUMMARY_LOG"
    echo "Load Average: $(cat /proc/loadavg)" >> "$SUMMARY_LOG"
    echo "" >> "$SUMMARY_LOG"
    
    # Memory summary
    echo "--- Memory Summary ---" >> "$SUMMARY_LOG"
    free -h | grep -E "(Mem|Swap)" >> "$SUMMARY_LOG"
    echo "" >> "$SUMMARY_LOG"
    
    # Top memory consumers
    echo "--- Top 10 Memory Consumers ---" >> "$SUMMARY_LOG"
    ps aux --sort=-%mem | head -11 >> "$SUMMARY_LOG"
    echo "" >> "$SUMMARY_LOG"
    
    # Docker summary if available
    if command -v docker &> /dev/null && docker ps -q | grep -q .; then
        echo "--- Docker Summary ---" >> "$SUMMARY_LOG"
        docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}" >> "$SUMMARY_LOG"
        echo "" >> "$SUMMARY_LOG"
    fi
    
    # Alerts and warnings
    echo "--- Alerts ---" >> "$SUMMARY_LOG"
    
    # Check for high memory usage
    mem_percent=$(free | awk 'FNR==2{printf "%.0f", $3/($3+$4)*100}')
    if [ "$mem_percent" -gt 80 ]; then
        echo "WARNING: Memory usage is ${mem_percent}%" >> "$SUMMARY_LOG"
    fi
    
    # Check for swap usage
    swap_used=$(free | awk 'FNR==3{print $3}')
    if [ "$swap_used" -gt 0 ]; then
        echo "WARNING: Swap is being used ($(free -h | awk 'FNR==3{print $3}'))" >> "$SUMMARY_LOG"
    fi
    
    # Check for zombie processes
    zombie_count=$(ps aux | awk '$8 ~ /^Z/ {count++} END {print count+0}')
    if [ "$zombie_count" -gt 0 ]; then
        echo "WARNING: $zombie_count zombie processes detected" >> "$SUMMARY_LOG"
    fi
    
    echo "===============================================" >> "$SUMMARY_LOG"
    echo "" >> "$SUMMARY_LOG"
}

# Main monitoring loop
echo -e "${YELLOW}[$(date)] Initializing monitoring logs...${NC}"

# Initial baseline capture
log_system_memory
log_process_memory
log_docker_memory
log_memory_fragmentation
log_swap_usage
generate_summary

echo -e "${GREEN}[$(date)] Baseline captured. Starting continuous monitoring...${NC}"

# Calculate total samples
total_samples=$((DURATION_MINUTES * 60 / SAMPLE_INTERVAL))
current_sample=0

while [ $current_sample -lt $total_samples ]; do
    sleep $SAMPLE_INTERVAL
    current_sample=$((current_sample + 1))
    
    echo -e "${BLUE}[$(date)] Sample $current_sample/$total_samples${NC}"
    
    # Log all metrics
    log_system_memory
    log_process_memory
    log_docker_memory
    log_memory_fragmentation
    log_swap_usage
    
    # Generate summary every 10 samples
    if [ $((current_sample % 10)) -eq 0 ]; then
        generate_summary
        echo -e "${YELLOW}[$(date)] Summary updated (sample $current_sample)${NC}"
    fi
done

# Final summary
generate_summary

echo -e "${GREEN}[$(date)] Memory monitoring completed!${NC}"
echo -e "${GREEN}Log files saved to: ${OUTPUT_BASE}_*.log${NC}"
echo -e "${GREEN}Summary available at: ${SUMMARY_LOG}${NC}"

# Display final summary
echo -e "\n${YELLOW}=== FINAL SUMMARY ===${NC}"
tail -20 "$SUMMARY_LOG"