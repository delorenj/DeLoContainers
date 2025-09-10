#!/bin/bash

# Memory Pattern Detection Script
# Detects patterns in memory usage that correlate with "doing nothing" scenarios

set -euo pipefail

LOG_DIR="/home/delorenj/docker/trunk-main/scripts/log-analysis/reports"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
REPORT_FILE="$LOG_DIR/memory_patterns_$TIMESTAMP.txt"

mkdir -p "$LOG_DIR"

echo "Memory Pattern Detection Analysis - $(date)" > "$REPORT_FILE"
echo "=================================================" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Function to check background processes
check_background_processes() {
    echo "BACKGROUND PROCESS ANALYSIS" >> "$REPORT_FILE"
    echo "----------------------------------------" >> "$REPORT_FILE"
    
    {
        echo "Processes consuming most memory:"
        ps aux --sort=-%mem | head -20
        echo ""
        
        echo "Processes with high CPU but low user activity (potential memory leaks):"
        ps aux --sort=-%cpu | head -10
        echo ""
        
        echo "Long-running processes (potential memory leak candidates):"
        ps -eo pid,ppid,cmd,etime,%mem,%cpu --sort=-etime | head -15
        echo ""
    } >> "$REPORT_FILE"
}

# Function to analyze system services
analyze_system_services() {
    echo "SYSTEM SERVICE ANALYSIS" >> "$REPORT_FILE"
    echo "----------------------------------------" >> "$REPORT_FILE"
    
    {
        echo "Memory usage by systemd services:"
        systemctl --type=service --state=running | while read service; do
            if [[ $service =~ \.service ]]; then
                service_name=$(echo "$service" | awk '{print $1}')
                systemctl show "$service_name" --property=MemoryCurrent 2>/dev/null
            fi
        done | grep -v "MemoryCurrent=0" | sort -k2 -nr | head -10 || echo "Unable to get service memory usage"
        echo ""
        
        echo "Services with restart issues:"
        systemctl list-units --failed --no-pager
        echo ""
    } >> "$REPORT_FILE"
}

# Function to check for memory fragmentation
check_memory_fragmentation() {
    echo "MEMORY FRAGMENTATION ANALYSIS" >> "$REPORT_FILE"
    echo "----------------------------------------" >> "$REPORT_FILE"
    
    {
        echo "Current memory layout:"
        cat /proc/meminfo | grep -E "(MemTotal|MemFree|MemAvailable|Buffers|Cached|Slab|PageTables|VmallocUsed)"
        echo ""
        
        echo "Memory fragmentation indicators:"
        if [ -f /proc/buddyinfo ]; then
            echo "Buddy info (free page blocks):"
            cat /proc/buddyinfo
        else
            echo "Buddy info not available"
        fi
        echo ""
        
        if [ -f /proc/pagetypeinfo ]; then
            echo "Page type info:"
            head -20 /proc/pagetypeinfo
        else
            echo "Page type info not available"
        fi
        echo ""
    } >> "$REPORT_FILE"
}

# Function to check for kernel memory leaks
check_kernel_memory() {
    echo "KERNEL MEMORY ANALYSIS" >> "$REPORT_FILE"
    echo "----------------------------------------" >> "$REPORT_FILE"
    
    {
        echo "Kernel slab usage (potential kernel memory leaks):"
        if [ -f /proc/slabinfo ]; then
            cat /proc/slabinfo | head -20
        else
            echo "Slab info not available (requires root)"
        fi
        echo ""
        
        echo "Kernel memory usage:"
        grep -E "(Slab|SReclaimable|SUnreclaim|KernelStack|PageTables)" /proc/meminfo
        echo ""
    } >> "$REPORT_FILE"
}

# Function to detect idle-time memory growth patterns
detect_idle_patterns() {
    echo "IDLE-TIME MEMORY GROWTH PATTERN DETECTION" >> "$REPORT_FILE"
    echo "----------------------------------------" >> "$REPORT_FILE"
    
    {
        echo "Checking for processes that grow during idle time:"
        echo "Current time: $(date)"
        echo "System uptime: $(uptime)"
        echo ""
        
        echo "Processes with unusual memory growth patterns:"
        # Check for processes that might be accumulating memory over time
        ps aux --sort=-%mem | awk 'NR>1 {if($6>100000) print $2, $11, $6"KB", $3"%CPU", $4"%MEM"}' | head -10
        echo ""
        
        echo "Checking for memory-mapped files:"
        lsof +L1 2>/dev/null | wc -l | xargs echo "Open files with link count of 1 (potential memory leaks):"
        echo ""
        
        echo "Processes with many open file descriptors:"
        for pid in $(ps -eo pid --no-headers | head -20); do
            if [ -d "/proc/$pid/fd" ]; then
                fd_count=$(ls /proc/$pid/fd 2>/dev/null | wc -l)
                if [ "$fd_count" -gt 100 ]; then
                    cmd=$(ps -p "$pid" -o comm= 2>/dev/null || echo "unknown")
                    echo "PID $pid ($cmd): $fd_count file descriptors"
                fi
            fi
        done
        echo ""
    } >> "$REPORT_FILE"
}

# Function to check Docker-specific memory patterns
check_docker_memory_patterns() {
    echo "DOCKER MEMORY PATTERN ANALYSIS" >> "$REPORT_FILE"
    echo "----------------------------------------" >> "$REPORT_FILE"
    
    {
        echo "Docker daemon memory usage:"
        ps aux | grep dockerd | grep -v grep || echo "Docker daemon not found in process list"
        echo ""
        
        echo "Container memory efficiency:"
        docker system df -v 2>/dev/null | grep -A 10 "CONTAINER" || echo "Docker system info not available"
        echo ""
        
        echo "Containers with potential memory leaks (high restart count):"
        docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.RestartCount}}\t{{.Image}}" | awk 'NR==1 || $3>5' || echo "No containers with high restart count"
        echo ""
        
        echo "Container processes consuming most memory:"
        docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}\t{{.MemPerc}}" 2>/dev/null | sort -k3 -nr | head -10 || echo "Docker stats not available"
        echo ""
    } >> "$REPORT_FILE"
}

# Function to check for tmpfs usage
check_tmpfs_usage() {
    echo "TMPFS AND MEMORY FILESYSTEM ANALYSIS" >> "$REPORT_FILE"
    echo "----------------------------------------" >> "$REPORT_FILE"
    
    {
        echo "tmpfs mounts and their usage:"
        df -h | grep tmpfs || echo "No tmpfs mounts found"
        echo ""
        
        echo "Shared memory usage:"
        df -h | grep shm || echo "No shared memory mounts found"
        echo ""
        
        echo "/tmp directory usage (if tmpfs):"
        du -sh /tmp/* 2>/dev/null | sort -hr | head -10 || echo "Cannot analyze /tmp usage"
        echo ""
    } >> "$REPORT_FILE"
}

# Run all analysis functions
echo "Running memory pattern detection analysis..."

check_background_processes
analyze_system_services
check_memory_fragmentation
check_kernel_memory
detect_idle_patterns
check_docker_memory_patterns
check_tmpfs_usage

# Add summary and recommendations
echo "" >> "$REPORT_FILE"
echo "SUMMARY AND RECOMMENDATIONS" >> "$REPORT_FILE"
echo "==========================================" >> "$REPORT_FILE"
{
    echo "Analysis completed at: $(date)"
    echo ""
    echo "Key areas to investigate for 'doing nothing' memory growth:"
    echo "1. Background processes with growing memory usage"
    echo "2. Docker containers with restart loops"
    echo "3. System services with memory leaks"
    echo "4. Kernel memory (slab) growth"
    echo "5. Memory fragmentation patterns"
    echo ""
    echo "Next steps:"
    echo "- Monitor memory usage patterns over time"
    echo "- Identify processes that grow during idle periods"
    echo "- Check for memory leaks in long-running services"
    echo "- Analyze container restart patterns"
    echo ""
    echo "Current memory status:"
    free -h
} >> "$REPORT_FILE"

echo "Memory pattern analysis complete. Report saved to: $REPORT_FILE"
echo ""
echo "Key findings summary will be in the report file."