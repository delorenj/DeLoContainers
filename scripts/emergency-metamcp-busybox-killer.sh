#!/bin/bash

# Emergency MetaMCP Process Control - BusyBox Compatible
# Designed for Alpine/BusyBox environment with limited command set

CONTAINER_NAME="metamcp"
MAX_PROCESSES=15
EMERGENCY_MODE=${1:-false}

echo "🚨 EMERGENCY MetaMCP BusyBox Process Control"
echo "Container: $CONTAINER_NAME"
echo "Max processes: $MAX_PROCESSES"
echo "Emergency mode: $EMERGENCY_MODE"

# Function to count processes
count_processes() {
    docker exec $CONTAINER_NAME sh -c 'ps aux | grep -E "(npm|node)" | grep -v grep | wc -l' 2>/dev/null || echo 0
}

# Function to get process list with basic info
get_processes() {
    docker exec $CONTAINER_NAME sh -c 'ps aux | grep -E "(npm|node)" | grep -v grep | awk "{print \$2, \$11, \$12, \$13}"' 2>/dev/null
}

# Function to kill processes by pattern (BusyBox compatible)
kill_by_pattern() {
    local pattern="$1"
    local description="$2"
    
    echo "Killing processes matching: $pattern ($description)"
    
    # Get PIDs matching pattern and kill them
    docker exec $CONTAINER_NAME sh -c "
        ps aux | grep '$pattern' | grep -v grep | awk '{print \$2}' | while read pid; do
            if [ -n \"\$pid\" ] && [ \"\$pid\" -gt 1 ]; then
                echo \"Killing PID: \$pid\"
                kill \$pid 2>/dev/null || kill -9 \$pid 2>/dev/null
            fi
        done
    "
}

# Function to kill oldest processes (BusyBox compatible)
kill_oldest() {
    local count_to_keep="$1"
    
    echo "Keeping only $count_to_keep newest processes..."
    
    docker exec $CONTAINER_NAME sh -c "
        ps aux | grep -E '(npm|node)' | grep -v grep | 
        sort -k9 | 
        awk 'NR > $count_to_keep {print \$2}' |
        while read pid; do
            if [ -n \"\$pid\" ] && [ \"\$pid\" -gt 1 ]; then
                echo \"Killing old PID: \$pid\"
                kill \$pid 2>/dev/null || kill -9 \$pid 2>/dev/null
            fi
        done
    "
}

# Function to kill duplicate npm exec processes
kill_npm_exec_duplicates() {
    echo "Killing duplicate npm exec processes..."
    
    # Kill npm exec processes but keep first of each type
    docker exec $CONTAINER_NAME sh -c '
        # Create temp file to track seen commands
        temp_file="/tmp/seen_commands"
        : > "$temp_file"
        
        ps aux | grep "npm exec" | grep -v grep | while read line; do
            pid=$(echo "$line" | awk "{print \$2}")
            cmd=$(echo "$line" | awk "{print \$11, \$12}")
            
            # Check if we have seen this command before
            if grep -q "$cmd" "$temp_file" 2>/dev/null; then
                echo "Killing duplicate: $cmd (PID: $pid)"
                kill $pid 2>/dev/null || kill -9 $pid 2>/dev/null
            else
                echo "$cmd" >> "$temp_file"
                echo "Keeping: $cmd (PID: $pid)"
            fi
        done
        
        rm -f "$temp_file"
    '
}

# Function to emergency container restart
emergency_restart() {
    echo "🚨 EMERGENCY: Restarting container..."
    docker restart $CONTAINER_NAME
    sleep 10
    echo "Container restart completed"
}

# Main execution
current_count=$(count_processes)
echo "Current process count: $current_count"

if [ "$current_count" -gt "$MAX_PROCESSES" ]; then
    echo "⚠️  Process count exceeds limit: $current_count > $MAX_PROCESSES"
    
    if [ "$EMERGENCY_MODE" = "true" ]; then
        echo "🚨 EMERGENCY MODE: Killing all npm/node processes..."
        kill_by_pattern "npm" "all npm processes"
        kill_by_pattern "node.*mcp" "all MCP node processes"
        sleep 5
        
        # If still too many, restart container
        current_count=$(count_processes)
        if [ "$current_count" -gt "$MAX_PROCESSES" ]; then
            emergency_restart
        fi
    else
        echo "🔧 STANDARD MODE: Selective cleanup..."
        
        # Step 1: Kill duplicate npm exec processes
        kill_npm_exec_duplicates
        sleep 2
        
        # Step 2: Check count and kill oldest if needed
        current_count=$(count_processes)
        if [ "$current_count" -gt "$MAX_PROCESSES" ]; then
            echo "Still $current_count processes, killing oldest..."
            kill_oldest $MAX_PROCESSES
            sleep 2
        fi
        
        # Step 3: If still too many, kill all npm exec
        current_count=$(count_processes)
        if [ "$current_count" -gt "$MAX_PROCESSES" ]; then
            echo "Still $current_count processes, killing all npm exec..."
            kill_by_pattern "npm exec" "all npm exec processes"
            sleep 2
        fi
        
        # Step 4: Last resort - emergency restart
        current_count=$(count_processes)
        if [ "$current_count" -gt "$MAX_PROCESSES" ]; then
            echo "🚨 Last resort: Emergency restart..."
            emergency_restart
        fi
    fi
    
    # Final status check
    sleep 5
    final_count=$(count_processes)
    echo "✅ Final process count: $final_count"
    
    if [ "$final_count" -le "$MAX_PROCESSES" ]; then
        echo "✅ SUCCESS: Process count under control"
    else
        echo "❌ FAILED: Process count still high ($final_count)"
        echo "Manual intervention required"
    fi
else
    echo "✅ Process count OK: $current_count/$MAX_PROCESSES"
fi

# Show current process state
echo ""
echo "Current processes:"
get_processes | head -10