#!/bin/bash

# MetaMCP Status Monitor - Real-time dashboard
# Shows current status and trends for MetaMCP container

CONTAINER_NAME="metamcp"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Clear screen function
clear_screen() {
    clear
    echo -e "${BOLD}═══════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}                    METAMCP EMERGENCY STATUS MONITOR${NC}"
    echo -e "${BOLD}═══════════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Get container stats
get_stats() {
    local container_stats=$(docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.PIDs}}" "$CONTAINER_NAME" 2>/dev/null | tail -n1)
    
    if [ -n "$container_stats" ]; then
        echo "$container_stats" | awk '{print $2 "," $3 "," $4 "," $5}'
    else
        echo "0%,0B / 0B,0%,0"
    fi
}

# Get process count
get_process_count() {
    docker exec "$CONTAINER_NAME" ps aux 2>/dev/null | wc -l || echo "0"
}

# Get monitoring status
get_monitoring_status() {
    local nuclear_monitor=""
    local host_monitor=""
    local enforcer=""
    
    if pgrep -f "metamcp-nuclear-monitor" >/dev/null; then
        nuclear_monitor="✅ ACTIVE"
    else
        nuclear_monitor="❌ INACTIVE"
    fi
    
    if pgrep -f "metamcp-host-monitor" >/dev/null; then
        host_monitor="✅ ACTIVE"
    else
        host_monitor="❌ INACTIVE"
    fi
    
    if pgrep -f "metamcp-resource-enforcer" >/dev/null; then
        enforcer="✅ ACTIVE"
    else
        enforcer="❌ INACTIVE"
    fi
    
    echo "$nuclear_monitor,$host_monitor,$enforcer"
}

# Status color based on process count
get_status_color() {
    local count=$1
    if [ "$count" -lt 15 ]; then
        echo "$GREEN"
    elif [ "$count" -lt 30 ]; then
        echo "$YELLOW"  
    else
        echo "$RED"
    fi
}

# Main monitoring loop
main() {
    local update_interval=${1:-5}
    
    echo "Starting MetaMCP status monitor (update every ${update_interval}s)"
    echo "Press Ctrl+C to exit"
    echo ""
    
    while true; do
        clear_screen
        
        # Get current data
        local stats=$(get_stats)
        local cpu=$(echo "$stats" | cut -d',' -f1)
        local memory=$(echo "$stats" | cut -d',' -f2)
        local memory_pct=$(echo "$stats" | cut -d',' -f3)
        local docker_pids=$(echo "$stats" | cut -d',' -f4)
        
        local process_count=$(get_process_count)
        local monitoring_status=$(get_monitoring_status)
        local nuclear_status=$(echo "$monitoring_status" | cut -d',' -f1)
        local host_status=$(echo "$monitoring_status" | cut -d',' -f2)
        local enforcer_status=$(echo "$monitoring_status" | cut -d',' -f3)
        
        # Determine overall status
        local status_color=$(get_status_color "$process_count")
        local status_text=""
        
        if [ "$process_count" -lt 15 ]; then
            status_text="${GREEN}✅ NORMAL${NC}"
        elif [ "$process_count" -lt 30 ]; then
            status_text="${YELLOW}⚠️  WARNING${NC}"
        elif [ "$process_count" -lt 50 ]; then
            status_text="${RED}🔥 CRITICAL${NC}"
        else
            status_text="${RED}☢️  NUCLEAR${NC}"
        fi
        
        # Display status
        echo -e "${BOLD}Current Status:${NC} $status_text"
        echo -e "${BOLD}Timestamp:${NC} $(date)"
        echo ""
        
        echo -e "${BOLD}📊 RESOURCE USAGE${NC}"
        echo "┌─────────────────────────────────────────────────────────────────┐"
        echo -e "│ ${BOLD}Metric${NC}           │ ${BOLD}Current${NC}     │ ${BOLD}Limit${NC}      │ ${BOLD}Status${NC}     │"
        echo "├─────────────────────────────────────────────────────────────────┤"
        
        # Process count row
        local proc_status=""
        if [ "$process_count" -lt 15 ]; then
            proc_status="${GREEN}NORMAL${NC}"
        elif [ "$process_count" -lt 30 ]; then
            proc_status="${YELLOW}WARNING${NC}"
        else
            proc_status="${RED}CRITICAL${NC}"
        fi
        printf "│ %-15s │ %-10s │ %-10s │ %-10s │\n" "Processes" "$process_count" "15" "$proc_status"
        
        # Memory row
        local mem_status=""
        local mem_val=$(echo "$memory_pct" | sed 's/%//')
        if (( $(echo "$mem_val < 75" | bc -l) )); then
            mem_status="${GREEN}NORMAL${NC}"
        elif (( $(echo "$mem_val < 90" | bc -l) )); then
            mem_status="${YELLOW}WARNING${NC}"
        else
            mem_status="${RED}CRITICAL${NC}"
        fi
        printf "│ %-15s │ %-10s │ %-10s │ %-10s │\n" "Memory" "$memory" "4GB" "$mem_status"
        
        # CPU row
        local cpu_status=""
        local cpu_val=$(echo "$cpu" | sed 's/%//')
        if (( $(echo "$cpu_val < 80" | bc -l) )); then
            cpu_status="${GREEN}NORMAL${NC}"
        else
            cpu_status="${YELLOW}HIGH${NC}"
        fi
        printf "│ %-15s │ %-10s │ %-10s │ %-10s │\n" "CPU" "$cpu" "200%" "$cpu_status"
        
        echo "└─────────────────────────────────────────────────────────────────┘"
        echo ""
        
        echo -e "${BOLD}🛡️  MONITORING SYSTEMS${NC}"
        echo "┌─────────────────────────────────────────────────────────────────┐"
        echo -e "│ ${BOLD}Monitor${NC}          │ ${BOLD}Status${NC}     │ ${BOLD}Function${NC}                   │"
        echo "├─────────────────────────────────────────────────────────────────┤"
        printf "│ %-15s │ %-10s │ %-25s │\n" "Nuclear" "$nuclear_status" "Aggressive cleanup"
        printf "│ %-15s │ %-10s │ %-25s │\n" "Host" "$host_status" "Container restart"  
        printf "│ %-15s │ %-10s │ %-25s │\n" "Resource" "$enforcer_status" "Resource enforcement"
        echo "└─────────────────────────────────────────────────────────────────┘"
        echo ""
        
        # Container health
        local container_health=$(docker ps --format "table {{.Status}}" --filter "name=$CONTAINER_NAME" | tail -n1)
        echo -e "${BOLD}🐳 CONTAINER STATUS${NC}"
        echo "Status: $container_health"
        echo ""
        
        # Recent activity
        echo -e "${BOLD}📋 RECENT ACTIVITY${NC}"
        if [ -f "/tmp/metamcp-nuclear-monitor.log" ]; then
            echo "Nuclear Monitor:"
            tail -n 3 /tmp/metamcp-nuclear-monitor.log | sed 's/^/  /'
        fi
        
        if [ -f "/tmp/metamcp-host-monitor.log" ]; then
            echo "Host Monitor:"  
            tail -n 2 /tmp/metamcp-host-monitor.log | sed 's/^/  /'
        fi
        
        echo ""
        echo -e "${BOLD}Controls:${NC} [Ctrl+C] Exit | [Enter] Refresh Now"
        echo "Auto-refresh in ${update_interval} seconds..."
        
        # Wait for update interval or user input
        read -t "$update_interval" -n 1 && continue
    done
}

# Handle arguments
case "${1:-monitor}" in
    "monitor"|"")
        main 5
        ;;
    "fast")
        main 2
        ;;
    "slow") 
        main 10
        ;;
    "once")
        main 999999
        ;;
    *)
        echo "Usage: $0 {monitor|fast|slow|once}"
        echo "  monitor - Standard 5s updates (default)"
        echo "  fast    - Fast 2s updates"  
        echo "  slow    - Slow 10s updates"
        echo "  once    - Single status check"
        exit 1
        ;;
esac