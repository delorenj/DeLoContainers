#!/bin/bash

# port-checker.sh
# Finds port mappings in Docker Compose files, detects collisions,
# and suggests non-colliding alternatives

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Port Checker: Finding and resolving port conflicts${NC}"
echo "-----------------------------------------------"

# Use a temporary file to store port mappings
PORT_MAP_FILE=$(mktemp)
trap "rm -f $PORT_MAP_FILE ${PORT_MAP_FILE}.sorted" EXIT

# Function to check if a port is in use
is_port_used() {
  grep -q "^$1:" "$PORT_MAP_FILE"
}

# Function to get service using a port
get_port_service() {
  grep "^$1:" "$PORT_MAP_FILE" | cut -d':' -f2-
}

# Function to add a port to the map
add_port() {
  echo "$1:$2" >> "$PORT_MAP_FILE"
}

# Function to find a non-colliding port
find_non_colliding_port() {
  local port=$1
  local original_port=$port
  local attempts=0
  
  while is_port_used "$port"; do
    # Port exists in map, try a new one
    local random_change=$((RANDOM % 9 + 1))
    port=$((port + random_change))
    
    # Avoid well-known ports
    if [[ $port -lt 1024 ]]; then
      port=$((port + 1024))
    fi
    
    # Prevent infinite loops
    ((attempts++))
    if [[ $attempts -gt 20 ]]; then
      port=$((original_port + 10000 + RANDOM % 1000))
      break
    fi
  done
  
  echo $port
}

# Function to update config files with new port
update_config_files() {
  local compose_dir=$(dirname "$1")
  local old_port=$2
  local new_port=$3
  local service_name=$4
  
  echo -e "${YELLOW}Updating references to port $old_port → $new_port in $compose_dir${NC}"
  
  # Find all potential config files
  find "$compose_dir" -type f -name "*.yml" -o -name "*.yaml" -o -name "*.env" -o -name "*.conf" -o -name "*.json" | grep -v "node_modules" | while read config_file; do
    # Skip the compose file we already processed
    if [[ "$config_file" == "$1" ]]; then
      continue
    fi
    
    # Check if file contains the old port
    if grep -q "$old_port" "$config_file"; then
      echo "  Found port reference in: $config_file"
      echo "    ⚠️  Would replace port $old_port with $new_port (script only identifying files for now)"
    fi
  done
}

# Find all compose files
find /Users/jaraddelorenzo/docker -name "compose.yml" -o -name "compose.yaml" -o -name "docker-compose.yml" -o -name "docker-compose.yaml" | grep -v "node_modules" | while read compose_file; do
  echo -e "${BLUE}Checking $compose_file...${NC}"
  
  # Extract port mappings
  # Look for patterns like: "8080:80" or '8080:80' or 8080:80
  grep -oE '[0-9]+:[0-9]+(/tcp|/udp)?' "$compose_file" 2>/dev/null | sort -u | while read mapping; do
    # Extract host and container ports
    host_port=$(echo "$mapping" | cut -d':' -f1)
    container_port=$(echo "$mapping" | cut -d':' -f2 | cut -d'/' -f1)
    
    # Try to determine the service name
    service_name=$(grep -B15 -A3 "$mapping" "$compose_file" | grep -oE '^  [a-zA-Z0-9_-]+:' | tail -1 | tr -d ' :' || echo "unknown")
    if [[ -z "$service_name" || "$service_name" == "ports" ]]; then
      service_name="unknown"
    fi
    
    echo "  Found port mapping: $host_port:$container_port (Service: $service_name)"
    
    # Check if this port is already used
    if is_port_used "$host_port"; then
      # Collision detected
      existing_service=$(get_port_service "$host_port")
      echo -e "${RED}  ⚠️  Collision detected: Port $host_port already used by $existing_service${NC}"
      
      # Find a non-colliding alternative
      new_port=$(find_non_colliding_port "$host_port")
      echo -e "${GREEN}  ✓ Suggested alternative: $new_port:$container_port${NC}"
      
      # Update references to this port in config files
      update_config_files "$compose_file" "$host_port" "$new_port" "$service_name"
      
      # Add the new port to our map
      add_port "$new_port" "$service_name ($compose_file → $container_port)"
    else
      # No collision, add to map
      add_port "$host_port" "$service_name ($compose_file → $container_port)"
    fi
  done
  
  echo ""  # Add a blank line between files
done

# Output port usage summary
echo -e "${BLUE}Port Usage Summary:${NC}"
echo "-------------------"

# Sort the port file
sort -n "$PORT_MAP_FILE" > "${PORT_MAP_FILE}.sorted"

# Display sorted ports
while IFS=: read -r port service; do
  echo -e "${GREEN}$port${NC}: $service"
done < "${PORT_MAP_FILE}.sorted"

echo -e "\n${BLUE}Script completed.${NC}"
echo "This script currently only identifies potential port conflicts and suggests alternatives."
echo "To automatically update port references, edit the script to uncomment the actual replacement logic."