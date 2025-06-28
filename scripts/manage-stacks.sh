#!/bin/bash
# Docker Stack Management Script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_ROOT="/home/delorenj/docker"
MONITOR_SCRIPT="$SCRIPT_DIR/stack-monitor.py"
SERVICE_FILE="$SCRIPT_DIR/docker-stack-monitor.service"

show_help() {
    echo "Docker Stack Management"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  status      - Show current status of all stacks"
    echo "  check       - Run a single monitoring check"
    echo "  start       - Start the monitoring service"
    echo "  stop        - Stop the monitoring service"
    echo "  restart     - Restart the monitoring service"
    echo "  install     - Install the monitoring service"
    echo "  uninstall   - Remove the monitoring service"
    echo "  logs        - Show service logs"
    echo "  config      - Edit the stack configuration"
    echo "  enable      - Enable a stack in config"
    echo "  disable     - Disable a stack in config"
    echo ""
}

install_service() {
    echo "Installing Docker Stack Monitor service..."
    
    # Make scripts executable
    chmod +x "$MONITOR_SCRIPT"
    chmod +x "$0"
    
    # Install systemd service
    sudo cp "$SERVICE_FILE" /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable docker-stack-monitor
    
    echo "Service installed successfully!"
    echo "Use 'manage-stacks.sh start' to start monitoring"
}

uninstall_service() {
    echo "Uninstalling Docker Stack Monitor service..."
    
    sudo systemctl stop docker-stack-monitor 2>/dev/null || true
    sudo systemctl disable docker-stack-monitor 2>/dev/null || true
    sudo rm -f /etc/systemd/system/docker-stack-monitor.service
    sudo systemctl daemon-reload
    
    echo "Service uninstalled successfully!"
}

case "$1" in
    status)
        python3 "$MONITOR_SCRIPT" status
        ;;
    check)
        python3 "$MONITOR_SCRIPT" check
        ;;
    start)
        sudo systemctl start docker-stack-monitor
        echo "Stack monitor started"
        ;;
    stop)
        sudo systemctl stop docker-stack-monitor
        echo "Stack monitor stopped"
        ;;
    restart)
        sudo systemctl restart docker-stack-monitor
        echo "Stack monitor restarted"
        ;;
    install)
        install_service
        ;;
    uninstall)
        uninstall_service
        ;;
    logs)
        sudo journalctl -u docker-stack-monitor -f
        ;;
    config)
        ${EDITOR:-nano} "$DOCKER_ROOT/stack-config.yml"
        ;;
    enable)
        if [ -z "$2" ]; then
            echo "Usage: $0 enable <stack-path>"
            echo "Example: $0 enable core/traefik/compose.yml"
            exit 1
        fi
        echo "Enabling stack: $2"
        # This would need a more sophisticated YAML editor
        echo "Please edit the config file manually for now: $DOCKER_ROOT/stack-config.yml"
        ;;
    disable)
        if [ -z "$2" ]; then
            echo "Usage: $0 disable <stack-path>"
            echo "Example: $0 disable core/traefik/compose.yml"
            exit 1
        fi
        echo "Disabling stack: $2"
        echo "Please edit the config file manually for now: $DOCKER_ROOT/stack-config.yml"
        ;;
    *)
        show_help
        ;;
esac
