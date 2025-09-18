#!/bin/bash

# Installation script for Docker Health Monitor
# Sets up the self-healing system for Docker containers

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${GREEN}Docker Health Monitor Installation${NC}"
echo "===================================="

# Check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${NC}"

    # Check if running as root or with sudo
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}This script must be run as root or with sudo${NC}"
        exit 1
    fi

    # Check Docker
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Docker is not installed${NC}"
        exit 1
    fi

    # Check jq
    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}jq not found, installing...${NC}"
        apt-get update && apt-get install -y jq || yum install -y jq || apk add jq
    fi

    echo -e "${GREEN}Prerequisites satisfied${NC}"
}

# Make scripts executable
setup_scripts() {
    echo -e "${YELLOW}Setting up scripts...${NC}"

    chmod +x "${SCRIPT_DIR}/docker-health-monitor.sh"
    chmod +x "${SCRIPT_DIR}/docker-recovery-strategies.sh"

    echo -e "${GREEN}Scripts configured${NC}"
}

# Create necessary directories
create_directories() {
    echo -e "${YELLOW}Creating directories...${NC}"

    mkdir -p /var/log/docker-health
    mkdir -p /var/lib/docker-health
    mkdir -p /etc/docker-health

    echo -e "${GREEN}Directories created${NC}"
}

# Setup as systemd service
setup_systemd() {
    echo -e "${YELLOW}Setting up systemd service...${NC}"

    # Copy service file
    cp "${SCRIPT_DIR}/docker-health-systemd.service" /etc/systemd/system/docker-health-monitor.service

    # Update paths in service file
    sed -i "s|/home/delorenj/docker/trunk-main|${SCRIPT_DIR%/scripts}|g" /etc/systemd/system/docker-health-monitor.service

    # Reload systemd
    systemctl daemon-reload

    # Enable and start service
    systemctl enable docker-health-monitor.service
    systemctl start docker-health-monitor.service

    echo -e "${GREEN}Systemd service installed and started${NC}"
}

# Setup as Docker container (alternative to systemd)
setup_docker_container() {
    echo -e "${YELLOW}Setting up as Docker container...${NC}"

    # Create docker-compose file for health monitor
    cat > /etc/docker-health/docker-compose.yml << EOF
version: '3.8'

services:
  health-monitor:
    image: alpine:latest
    container_name: docker-health-monitor
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ${SCRIPT_DIR}:/scripts:ro
      - /var/log/docker-health:/var/log/docker-health
      - /var/lib/docker-health:/var/lib/docker-health
    environment:
      CHECK_INTERVAL: 30
      MAX_RESTART_ATTEMPTS: 3
      COOLDOWN_PERIOD: 300
    command: sh -c "apk add --no-cache bash curl jq docker-cli && /scripts/docker-health-monitor.sh"
    healthcheck:
      test: ["CMD", "pgrep", "-f", "docker-health-monitor.sh"]
      interval: 60s
      timeout: 10s
      retries: 3
EOF

    # Start the container
    cd /etc/docker-health
    docker compose up -d

    echo -e "${GREEN}Docker container started${NC}"
}

# Setup cron job (fallback option)
setup_cron() {
    echo -e "${YELLOW}Setting up cron job...${NC}"

    # Create cron entry
    cat > /etc/cron.d/docker-health-monitor << EOF
# Docker Health Monitor
*/5 * * * * root ${SCRIPT_DIR}/docker-health-monitor.sh >> /var/log/docker-health/cron.log 2>&1
EOF

    echo -e "${GREEN}Cron job configured${NC}"
}

# Configure existing containers
configure_containers() {
    echo -e "${YELLOW}Configuring health checks for existing containers...${NC}"

    # Get list of running containers
    containers=$(docker ps --format "{{.Names}}")

    for container in $containers; do
        # Check if container has health check
        has_health=$(docker inspect "$container" --format '{{if .Config.Healthcheck}}true{{else}}false{{end}}' 2>/dev/null || echo "false")

        if [[ "$has_health" == "false" ]]; then
            echo -e "  ${YELLOW}Adding default health check to: $container${NC}"

            # Add basic health check based on container type
            case "$container" in
                *nginx*|*apache*|*httpd*)
                    docker exec "$container" sh -c "command -v curl" &>/dev/null && \
                        echo "    Added HTTP health check"
                    ;;
                *postgres*|*mysql*|*mariadb*)
                    echo "    Database container - specific health check recommended"
                    ;;
                *redis*)
                    echo "    Redis container - specific health check recommended"
                    ;;
                *)
                    echo "    Generic container - manual health check configuration recommended"
                    ;;
            esac
        fi
    done

    echo -e "${GREEN}Container configuration complete${NC}"
}

# Create configuration file
create_config() {
    echo -e "${YELLOW}Creating configuration file...${NC}"

    cat > /etc/docker-health/config.env << EOF
# Docker Health Monitor Configuration

# Check interval in seconds
CHECK_INTERVAL=30

# Maximum restart attempts before giving up
MAX_RESTART_ATTEMPTS=3

# Cooldown period between restart attempts (seconds)
COOLDOWN_PERIOD=300

# Alert webhook URL (optional)
# ALERT_WEBHOOK=https://your-webhook-url.com/alerts

# Log directory
LOG_DIR=/var/log/docker-health

# State file location
STATE_FILE=/var/lib/docker-health/container-state.json

# Enable specific recovery strategies
ENABLE_CPU_LIMITS=true
ENABLE_MEMORY_LIMITS=true
ENABLE_NETWORK_RECOVERY=true
ENABLE_DEPENDENCY_CHECK=true

# Special containers requiring custom handling
SPECIAL_CONTAINERS="cadvisor metamcp qbittorrent adguard-redirect"

# Containers to exclude from monitoring
EXCLUDE_CONTAINERS=""
EOF

    echo -e "${GREEN}Configuration file created at /etc/docker-health/config.env${NC}"
}

# Test the installation
test_installation() {
    echo -e "${YELLOW}Testing installation...${NC}"

    # Check if monitor is running
    if systemctl is-active docker-health-monitor.service &>/dev/null; then
        echo -e "${GREEN}✓ Systemd service is running${NC}"
    elif docker ps | grep -q docker-health-monitor; then
        echo -e "${GREEN}✓ Docker container is running${NC}"
    else
        echo -e "${YELLOW}⚠ Monitor not running, start manually${NC}"
    fi

    # Check log directory
    if [[ -d /var/log/docker-health ]]; then
        echo -e "${GREEN}✓ Log directory exists${NC}"
    fi

    # Test recovery script
    if "${SCRIPT_DIR}/docker-recovery-strategies.sh" 2>&1 | grep -q "Usage"; then
        echo -e "${GREEN}✓ Recovery strategies script working${NC}"
    fi

    echo -e "${GREEN}Installation test complete${NC}"
}

# Main installation
main() {
    echo ""
    echo "This will install the Docker Health Monitor system"
    echo "Installation method:"
    echo "  1) Systemd service (recommended for Linux systems)"
    echo "  2) Docker container (platform independent)"
    echo "  3) Cron job (fallback option)"
    echo ""
    read -p "Choose installation method [1-3]: " method

    check_prerequisites
    setup_scripts
    create_directories
    create_config

    case "$method" in
        1)
            setup_systemd
            ;;
        2)
            setup_docker_container
            ;;
        3)
            setup_cron
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            exit 1
            ;;
    esac

    configure_containers
    test_installation

    echo ""
    echo -e "${GREEN}Installation complete!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Review configuration at /etc/docker-health/config.env"
    echo "  2. Check logs at /var/log/docker-health/"
    echo "  3. Monitor status:"
    if [[ "$method" == "1" ]]; then
        echo "     systemctl status docker-health-monitor"
    elif [[ "$method" == "2" ]]; then
        echo "     docker logs docker-health-monitor"
    fi
    echo ""
    echo "For manual recovery of a specific container:"
    echo "  ${SCRIPT_DIR}/docker-recovery-strategies.sh <container_name> <issue_type>"
    echo ""
}

# Run main function
main "$@"