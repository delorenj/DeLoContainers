#!/bin/bash

# MetaMCP Memory Analyzer
# Specific analysis for the MetaMCP container which is consuming 70GB+ memory

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT_FILE="${SCRIPT_DIR}/metamcp-memory-analysis-$(date +%Y%m%d-%H%M%S).txt"

echo "🔍 MetaMCP Memory Analysis Report" | tee "$REPORT_FILE"
echo "Generated: $(date)" | tee -a "$REPORT_FILE"
echo "================================" | tee -a "$REPORT_FILE"

# Function to log with timestamp
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$REPORT_FILE"
}

# Check if metamcp container exists
if ! docker ps -a --format "{{.Names}}" | grep -q "^metamcp$"; then
    log_message "❌ MetaMCP container not found"
    exit 1
fi

log_message "🔍 Analyzing MetaMCP container memory usage..."

# 1. Current memory statistics
log_message "\n📊 CURRENT MEMORY STATISTICS"
{
    docker stats --no-stream metamcp
} | tee -a "$REPORT_FILE"

# 2. Container configuration analysis
log_message "\n⚙️  CONTAINER CONFIGURATION"
log_message "Image: $(docker inspect metamcp --format '{{.Config.Image}}')"
log_message "Created: $(docker inspect metamcp --format '{{.Created}}')"
log_message "Started: $(docker inspect metamcp --format '{{.State.StartedAt}}')"
log_message "Uptime: $(docker inspect metamcp --format '{{.State.Status}}')"
log_message "Restart Count: $(docker inspect metamcp --format '{{.RestartCount}}')"

# Memory limits
memory_limit=$(docker inspect metamcp --format '{{.HostConfig.Memory}}')
if [ "$memory_limit" = "0" ]; then
    log_message "🚨 CRITICAL: NO MEMORY LIMIT SET!"
    log_message "   This container can consume ALL available host memory"
else
    limit_gb=$((memory_limit / 1024 / 1024 / 1024))
    log_message "Memory Limit: ${limit_gb}GB"
fi

# 3. Process analysis inside container
log_message "\n🔬 PROCESS ANALYSIS INSIDE CONTAINER"
if docker exec metamcp ps aux 2>/dev/null; then
    log_message "Top memory-consuming processes inside container:"
    docker exec metamcp ps aux --sort=-%mem | head -10 2>/dev/null | tee -a "$REPORT_FILE"
else
    log_message "Cannot access process list (container may not support ps)"
fi

# 4. File system analysis
log_message "\n💾 FILESYSTEM ANALYSIS"
if docker exec metamcp df -h 2>/dev/null; then
    log_message "Disk usage inside container:"
    docker exec metamcp df -h 2>/dev/null | tee -a "$REPORT_FILE"
    
    log_message "\nLarge files and directories:"
    docker exec metamcp find / -type f -size +50M 2>/dev/null | head -10 | while read file; do
        if [ -n "$file" ]; then
            size=$(docker exec metamcp stat -c%s "$file" 2>/dev/null || echo "unknown")
            size_mb=$((size / 1024 / 1024))
            log_message "  Large file: $file (${size_mb}MB)"
        fi
    done
else
    log_message "Cannot access filesystem information"
fi

# 5. Log analysis for memory issues
log_message "\n📝 LOG ANALYSIS"
log_message "Recent logs (last 100 lines):"
{
    docker logs --tail 100 metamcp 2>&1
} | tee -a "$REPORT_FILE"

log_message "\nMemory-related errors:"
if docker logs metamcp 2>&1 | grep -i "memory\|oom\|killed\|out of memory\|leak\|heap" | tail -10; then
    log_message "🔥 MEMORY-RELATED ISSUES FOUND IN LOGS!"
else
    log_message "No obvious memory errors in logs"
fi

# 6. Environment variables analysis
log_message "\n🌍 ENVIRONMENT VARIABLES"
docker inspect metamcp --format '{{range .Config.Env}}{{println .}}{{end}}' | grep -E "MEMORY|MEM|HEAP|NODE|POSTGRES" | tee -a "$REPORT_FILE"

# 7. Volume and mount analysis
log_message "\n📁 VOLUMES AND MOUNTS"
docker inspect metamcp --format '{{range .Mounts}}{{println .Source " -> " .Destination " (" .Type ")"}}{{end}}' | tee -a "$REPORT_FILE"

# 8. Network analysis
log_message "\n🌐 NETWORK CONNECTIONS"
if docker exec metamcp netstat -tuln 2>/dev/null | head -20; then
    log_message "Active network connections listed above"
else
    log_message "Cannot access network information"
fi

# 9. Claude Flow specific analysis
log_message "\n🤖 CLAUDE FLOW ANALYSIS"
log_message "Checking for Claude Flow processes and memory usage:"

# Check for claude-flow related processes
if docker exec metamcp ps aux 2>/dev/null | grep -i "claude\|flow\|mcp" | grep -v grep; then
    log_message "Claude Flow processes found (see above)"
else
    log_message "No obvious Claude Flow processes visible"
fi

# Check for MCP server logs
if docker logs metamcp 2>&1 | grep -i "\[claude-flow\]" | tail -10; then
    log_message "Claude Flow specific log entries found (see above)"
else
    log_message "No Claude Flow specific logs found"
fi

# 10. Memory leak indicators
log_message "\n🚨 MEMORY LEAK INDICATORS"

# Check uptime vs memory usage
uptime_hours=$(docker inspect metamcp --format '{{.State.StartedAt}}' | xargs -I {} date -d {} +%s | xargs -I {} echo $(( ($(date +%s) - {}) / 3600 )))
current_memory_gb=$(docker stats --no-stream --format "{{.MemUsage}}" metamcp | grep -o '^[0-9.]*')

if [ -n "$current_memory_gb" ] && [ -n "$uptime_hours" ]; then
    if [ "$(echo "$current_memory_gb > 10" | bc -l 2>/dev/null || echo 0)" = "1" ]; then
        log_message "🔴 CRITICAL MEMORY LEAK DETECTED:"
        log_message "  - Current memory usage: ${current_memory_gb}GB"
        log_message "  - Container uptime: ${uptime_hours} hours"
        log_message "  - This level of memory usage is abnormal for MetaMCP"
        
        if [ "$uptime_hours" -gt 24 ]; then
            log_message "  - Long-running container may have accumulated memory leaks"
        fi
    fi
fi

# 11. Recommendations
log_message "\n💡 RECOMMENDATIONS"

log_message "IMMEDIATE ACTIONS:"
log_message "1. 🔄 RESTART CONTAINER: docker restart metamcp"
log_message "   - This will clear any memory leaks"
log_message "   - Monitor memory usage after restart"

log_message "\n2. 🛡️  ADD MEMORY LIMITS to compose.yml:"
cat << 'EOF' | tee -a "$REPORT_FILE"
   deploy:
     resources:
       limits:
         memory: 4G
       reservations:
         memory: 2G
EOF

log_message "\n3. 🔍 MONITOR FOR PATTERNS:"
log_message "   - Run this script after restart to establish baseline"
log_message "   - Use container-memory-monitor.sh for ongoing monitoring"
log_message "   - Check if memory grows over time (indicates leak)"

log_message "\n4. 🐛 DEBUGGING STEPS:"
log_message "   - Check Claude Flow version for known memory issues"
log_message "   - Review MCP server configuration"
log_message "   - Consider running with fewer concurrent operations"

log_message "\n5. 🔧 CONFIGURATION OPTIMIZATIONS:"
log_message "   - Set NODE_OPTIONS='--max-old-space-size=2048' for Node.js apps"
log_message "   - Disable unnecessary features or reduce concurrency"
log_message "   - Regular container restarts via health checks"

log_message "\n📊 NEXT STEPS:"
log_message "1. Save this report for baseline comparison"
log_message "2. Restart the container: docker restart metamcp"
log_message "3. Run this script again in 1 hour to compare"
log_message "4. Implement memory limits and monitoring"

log_message "\n📄 Report saved to: $REPORT_FILE"
log_message "🔍 For real-time monitoring: scripts/docker-diagnostics/container-memory-monitor.sh"

# Make script executable
chmod +x "$0"