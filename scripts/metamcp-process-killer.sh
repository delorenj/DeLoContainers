#!/bin/bash

# MetaMCP Emergency Process Control Script
# Kills duplicate processes to prevent memory explosion

CONTAINER_NAME="metamcp"
MAX_PROCESSES=15
CHECK_INTERVAL=30

echo "Starting MetaMCP process monitor..."
echo "Max processes allowed: $MAX_PROCESSES"

while true; do
    # Count npm/node processes in container
    PROCESS_COUNT=$(docker exec $CONTAINER_NAME ps aux 2>/dev/null | grep -E "(npm|node)" | wc -l)
    
    if [ "$PROCESS_COUNT" -gt "$MAX_PROCESSES" ]; then
        echo "⚠️  ALERT: $PROCESS_COUNT processes found (max: $MAX_PROCESSES)"
        
        # Kill duplicate npm exec processes (keep only first of each type)
        docker exec $CONTAINER_NAME sh -c '
            # Kill duplicate npm exec processes, keeping first instance
            ps aux | grep "npm exec" | grep -v grep | 
            awk "{print \$2, \$11, \$12}" | 
            sort -k2,3 | 
            uniq -f1 --all-repeated=separate | 
            while read pid cmd args; do 
                echo "Killing duplicate: $cmd $args (PID: $pid)"
                kill $pid 2>/dev/null
            done
        '
        
        # If still too many, kill oldest processes
        NEW_COUNT=$(docker exec $CONTAINER_NAME ps aux 2>/dev/null | grep -E "(npm|node)" | wc -l)
        if [ "$NEW_COUNT" -gt "$MAX_PROCESSES" ]; then
            echo "Still $NEW_COUNT processes, killing oldest..."
            docker exec $CONTAINER_NAME sh -c '
                ps aux | grep -E "(npm|node)" | grep -v grep | 
                sort -k9 | tail -n +16 | 
                awk "{print \$2}" | 
                xargs -r kill 2>/dev/null
            '
        fi
        
        echo "✅ Process cleanup completed"
    else
        echo "✅ Process count OK: $PROCESS_COUNT/$MAX_PROCESSES"
    fi
    
    sleep $CHECK_INTERVAL
done