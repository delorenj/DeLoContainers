#!/usr/bin/env bash

# Script to list all services from compose.yml files with their running status
# For use with DeLoContainers project

echo -e "\033[1;32m📋 Services in DeLoContainers\033[0m"
echo -e "\033[1;32m=========================\033[0m"

# Get the list of running containers once for performance
running_containers=$(docker ps --format '{{.Names}}')

find stacks -type f -name "compose.yml" 2>/dev/null | sort | while read -r file; do
    # Extract directory path for display
    dir_path=$(dirname "$file")
    echo -e "\n\033[1;34m📁 $dir_path\033[0m"
    
    # Process the file using docker-compose config to get the normalized structure
    if ! service_output=$(docker-compose -f "$file" config --services 2>/dev/null); then
        # If docker-compose fails, try parsing the file directly
        if grep -q "services:" "$file"; then
            service_output=$(grep -A 100 "services:" "$file" | 
                            grep -v "services:" | 
                            grep "^  [a-zA-Z0-9_-]\+:" | 
                            sed 's/://' | 
                            sed 's/^[ \t]*//')
        else
            service_output=""
        fi
    fi
    
    if [ -n "$service_output" ]; then
        echo "$service_output" | sort | while read -r service; do
            # Check if this service has a container_name defined
            container_name=$(grep -A 20 "^  $service:" "$file" | 
                            grep -m 1 "container_name:" | 
                            sed 's/.*container_name: *//')
            
            # If no container_name defined, use the service name
            if [ -z "$container_name" ]; then
                container_name=$service
            fi
            
            # Check if this container is running
            if echo "$running_containers" | grep -q "^$container_name$"; then
                status="\033[1;32m✓\033[0m"
            else
                status="\033[1;31m✗\033[0m"
            fi
            
            # Extract Traefik Host label if it exists
            traefik_host=$(grep -A 50 "^  $service:" "$file" | 
                          grep -o "Host(\`[^)]*\`)" | 
                          head -1 | 
                          sed "s/Host(\`\(.*\)\`)/\1/")
            
            # Check if the host is reachable
            reachable=""
            if [ -n "$traefik_host" ]; then
                if curl -s --head --max-time 2 "https://$traefik_host" >/dev/null 2>&1; then
                    reachable="\033[1;32m✓\033[0m"
                else
                    reachable="\033[1;31m✗\033[0m"
                fi
                traefik_info=" 🌐 \033[1;35m$traefik_host\033[0m $reachable"
            else
                traefik_info=""
            fi
            
            if grep -q "container_name:" <<< $(grep -A 20 "^  $service:" "$file" 2>/dev/null); then
                echo -e "    $status \033[1;36m$service\033[0m → \033[1;33m$container_name\033[0m$traefik_info"
            else
                echo -e "    $status \033[1;36m$service\033[0m$traefik_info"
            fi
        done
    else
        echo -e "    \033[1;31mNo services found\033[0m"
    fi
done

echo -e "\n\033[1;32mLegend: \033[1;32m✓\033[0m Running  \033[1;31m✗\033[0m Not Running  🌐 Web Address\033[0m"
