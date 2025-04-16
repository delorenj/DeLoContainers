#!/usr/bin/env zsh

# DeLoHome Management Script
# For managing the Home Assistant-based smart home stack

# Set directory
SCRIPT_DIR=$(dirname "$0")
cd $SCRIPT_DIR

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print styled messages
print_status() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_header() {
  echo -e "\n${GREEN}=== $1 ===${NC}\n"
}

# Function to check if Docker is running
check_docker() {
  if ! docker info >/dev/null 2>&1; then
    print_error "Docker is not running or you don't have permission to use it."
    print_status "Please start Docker or add your user to the docker group with:"
    print_status "sudo usermod -aG docker $USER"
    exit 1
  fi
}

# Check if Zigbee adapter is connected
check_zigbee_adapter() {
  if [[ $(ls /dev/ttyACM* 2>/dev/null | wc -l) -gt 0 ]]; then
    local adapters=$(ls /dev/ttyACM*)
    print_success "Found potential Zigbee adapters: $adapters"
    
    # Uncomment the device lines in docker-compose.yml if needed
    if grep -q "#   - /dev/ttyACM0:/dev/ttyACM0" compose.yml; then
      print_status "Uncomment the device mapping in compose.yml and restart to use the adapter."
    fi
  else
    print_warning "No Zigbee adapters detected. If you have one, ensure it's properly connected."
  fi
}

# Start the stack
start() {
  print_header "Starting DeLoHome Stack"
  check_docker
  
  print_status "Starting all services..."
  docker compose up -d
  
  if [ $? -eq 0 ]; then
    print_success "DeLoHome stack started successfully!"
    print_status "Home Assistant UI available at: http://localhost:8123"
    print_status "Node-RED available at: http://localhost:1880"
    print_status "Grafana available at: http://localhost:3000"
    print_status "InfluxDB available at: http://localhost:8086"
    print_status "Zigbee2MQTT available at: http://localhost:8080"
    
    check_zigbee_adapter
  else
    print_error "Failed to start DeLoHome stack."
  fi
}

# Stop the stack
stop() {
  print_header "Stopping DeLoHome Stack"
  check_docker
  
  print_status "Stopping all services..."
  docker compose down
  
  if [ $? -eq 0 ]; then
    print_success "DeLoHome stack stopped successfully!"
  else
    print_error "Failed to stop DeLoHome stack."
  fi
}

# Restart the stack
restart() {
  print_header "Restarting DeLoHome Stack"
  check_docker
  
  print_status "Restarting all services..."
  docker compose restart
  
  if [ $? -eq 0 ]; then
    print_success "DeLoHome stack restarted successfully!"
  else
    print_error "Failed to restart DeLoHome stack."
  fi
}

# Update the stack
update() {
  print_header "Updating DeLoHome Stack"
  check_docker
  
  print_status "Pulling latest images..."
  docker compose pull
  
  print_status "Restarting services with new images..."
  docker compose up -d
  
  if [ $? -eq 0 ]; then
    print_success "DeLoHome stack updated successfully!"
  else
    print_error "Failed to update DeLoHome stack."
  fi
}

# View logs
logs() {
  print_header "Viewing DeLoHome Logs"
  check_docker
  
  if [ -z "$2" ]; then
    print_status "Showing logs for all services (press Ctrl+C to exit)..."
    docker compose logs -f --tail=100
  else
    print_status "Showing logs for $2 (press Ctrl+C to exit)..."
    docker compose logs -f --tail=100 "$2"
  fi
}

# Show stack status
status() {
  print_header "DeLoHome Stack Status"
  check_docker
  
  print_status "Container status:"
  docker compose ps
}

# Backup configuration
backup() {
  print_header "Backing Up DeLoHome Configuration"
  local backup_dir="/home/delorenj/code/DeLoDocs/HomeAssistant/backups"
  local backup_file="delohome_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
  
  print_status "Creating backup directory if it doesn't exist..."
  mkdir -p $backup_dir
  
  print_status "Creating backup archive..."
  tar -czf "$backup_dir/$backup_file" -C "$(dirname "$SCRIPT_DIR")" "$(basename "$SCRIPT_DIR")"
  
  if [ $? -eq 0 ]; then
    print_success "Backup created successfully at: $backup_dir/$backup_file"
  else
    print_error "Failed to create backup."
  fi
}

# Check ports
check_ports() {
  print_header "Checking Required Ports"
  local ports=(8123 1883 9001 1880 3000 8086 8080)
  local all_free=true
  
  for port in "${ports[@]}"; do
    if nc -z localhost $port 2>/dev/null; then
      print_warning "Port $port is already in use."
      all_free=false
    else
      print_success "Port $port is available."
    fi
  done
  
  if [ "$all_free" = true ]; then
    print_success "All required ports are available."
  else
    print_warning "Some required ports are already in use. You may need to modify port mappings in compose.yml."
  fi
}

# Show help
show_help() {
  print_header "DeLoHome Management Script"
  echo "Usage: $0 [command]"
  echo ""
  echo "Commands:"
  echo "  start         Start the DeLoHome stack"
  echo "  stop          Stop the DeLoHome stack"
  echo "  restart       Restart the DeLoHome stack"
  echo "  update        Update images and restart the stack"
  echo "  logs [service] View logs (optionally for a specific service)"
  echo "  status        Check the status of all services"
  echo "  backup        Create a backup of the entire configuration"
  echo "  check-ports   Check if required ports are available"
  echo "  help          Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0 start"
  echo "  $0 logs homeassistant"
}

# Main command handling
case "$1" in
  start)
    start
    ;;
  stop)
    stop
    ;;
  restart)
    restart
    ;;
  update)
    update
    ;;
  logs)
    logs "$@"
    ;;
  status)
    status
    ;;
  backup)
    backup
    ;;
  check-ports)
    check_ports
    ;;
  help|"")
    show_help
    ;;
  *)
    print_error "Unknown command: $1"
    show_help
    exit 1
    ;;
esac

exit 0
