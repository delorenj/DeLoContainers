#!/bin/bash

# Configuration
VPN_SERVICE="gluetun"
COMPOSE_FILE="/home/delorenj/docker/docker-compose.yml"
LOG_FILE="/home/delorenj/docker/logs/vpn.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Function to check VPN status
check_status() {
    echo "🔍 Checking VPN status..."
    
    # Check if VPN container is running
    if ! docker compose -f "$COMPOSE_FILE" ps "$VPN_SERVICE" | grep -q "running"; then
        echo -e "${RED}❌ VPN container is not running${NC}"
        return 1
    fi
    
    # Get current IP and location
    echo "📍 Connection Details:"
    docker compose -f "$COMPOSE_FILE" exec "$VPN_SERVICE" curl -s https://ipinfo.io/json | \
        jq -r '"Location: \(.city), \(.country)\nIP: \(.ip)\nHostname: \(.hostname)\nOrg: \(.org)"'
    
    # Check port forwarding status
    echo -e "\n🔌 Port Forwarding:"
    local ports=(49152 49153 49154 49155 49156)
    for port in "${ports[@]}"; do
        if docker compose -f "$COMPOSE_FILE" exec "$VPN_SERVICE" nc -zv localhost "$port" 2>/dev/null; then
            echo -e "${GREEN}✅ Port $port is open${NC}"
        else
            echo -e "${RED}❌ Port $port is closed${NC}"
        fi
    done
    
    # Check DNS resolution
    echo -e "\n🌐 DNS Resolution:"
    docker compose -f "$COMPOSE_FILE" exec "$VPN_SERVICE" dig +short google.com
}

# Function to restart VPN connection
restart_vpn() {
    echo "🔄 Restarting VPN connection..."
    
    # Stop dependent services
    echo "Stopping dependent services..."
    docker compose -f "$COMPOSE_FILE" stop qbittorrent prowlarr
    
    # Restart VPN container
    docker compose -f "$COMPOSE_FILE" restart "$VPN_SERVICE"
    
    # Wait for VPN to establish connection
    echo "Waiting for VPN connection..."
    sleep 10
    
    # Start dependent services
    echo "Starting dependent services..."
    docker compose -f "$COMPOSE_FILE" start qbittorrent prowlarr
    
    # Check status
    check_status
}

# Function to view VPN logs
view_logs() {
    echo "📋 VPN Logs:"
    docker compose -f "$COMPOSE_FILE" logs --tail=100 -f "$VPN_SERVICE"
}

# Function to test torrent connectivity
test_connection() {
    echo "🔄 Testing torrent connectivity..."
    
    # Check if qBittorrent is accessible
    echo "Testing qBittorrent Web UI..."
    if curl -s http://localhost:8090/api/v2/app/version > /dev/null; then
        echo -e "${GREEN}✅ qBittorrent Web UI is accessible${NC}"
    else
        echo -e "${RED}❌ qBittorrent Web UI is not accessible${NC}"
    fi
    
    # Test port forwarding
    echo -e "\nTesting port forwarding..."
    port=$(docker compose -f "$COMPOSE_FILE" exec qbittorrent qbittorrent-nox --version 2>/dev/null | grep "Listening on" | awk '{print $NF}')
    if [ -n "$port" ]; then
        echo -e "${GREEN}✅ qBittorrent is listening on port $port${NC}"
    else
        echo -e "${RED}❌ No listening port detected${NC}"
    fi
    
    # Test DHT
    echo -e "\nTesting DHT status..."
    if docker compose -f "$COMPOSE_FILE" exec qbittorrent curl -s http://localhost:8090/api/v2/transfer/info | jq -r '.dht_nodes' | grep -q "[1-9]"; then
        echo -e "${GREEN}✅ DHT is active${NC}"
    else
        echo -e "${RED}❌ DHT is not active${NC}"
    fi
}

# Function to show configuration
show_config() {
    echo "📋 VPN Configuration:"
    docker compose -f "$COMPOSE_FILE" exec "$VPN_SERVICE" env | grep -E "VPN_|FIREWALL_"
}

# Main execution
case "$1" in
    "status")
        check_status
        ;;
    "restart")
        restart_vpn
        ;;
    "logs")
        view_logs
        ;;
    "test")
        test_connection
        ;;
    "config")
        show_config
        ;;
    *)
        echo "Usage: $0 <command>"
        echo "Commands:"
        echo "  status  - Check VPN status and connectivity"
        echo "  restart - Restart VPN connection"
        echo "  logs    - View VPN logs"
        echo "  test    - Test torrent connectivity"
        echo "  config  - Show VPN configuration"
        exit 1
        ;;
esac

# Log command execution
echo "[$(date)] Command executed: $1" >> "$LOG_FILE"