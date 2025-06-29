#!/bin/bash

# OpenCode Container Management Script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if systemd service exists and is running
check_systemd_service() {
    if systemctl is-active --quiet opencode.service 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Stop systemd service
stop_systemd_service() {
    log_info "Stopping systemd opencode service..."
    sudo systemctl stop opencode.service || true
    sudo systemctl disable opencode.service || true
    log_success "Systemd service stopped and disabled"
}

# Start container service
start_container() {
    log_info "Starting OpenCode container..."
    docker compose up -d --build
    log_success "OpenCode container started"
}

# Stop container service
stop_container() {
    log_info "Stopping OpenCode container..."
    docker compose down
    log_success "OpenCode container stopped"
}

# Generate API key
generate_api_key() {
    log_info "Generating API key..."
    if docker compose ps opencode | grep -q "Up"; then
        docker compose exec opencode /home/mcp/generate-apikey.sh "$@"
    else
        log_error "OpenCode container is not running. Start it first with: $0 start"
        exit 1
    fi
}

# Show status
show_status() {
    echo "OpenCode Service Status"
    echo "======================"
    echo ""
    
    # Check systemd service
    if check_systemd_service; then
        echo -e "Systemd Service: ${YELLOW}RUNNING${NC}"
        log_warning "Systemd service is still running. Consider migrating to container."
    else
        echo -e "Systemd Service: ${GREEN}STOPPED${NC}"
    fi
    
    # Check container
    if docker compose ps opencode | grep -q "Up"; then
        echo -e "Container Service: ${GREEN}RUNNING${NC}"
        echo ""
        docker compose ps opencode
    else
        echo -e "Container Service: ${RED}STOPPED${NC}"
    fi
    
    echo ""
    echo "Logs (last 10 lines):"
    echo "--------------------"
    docker compose logs --tail=10 opencode 2>/dev/null || echo "No container logs available"
}

# Migrate from systemd to container
migrate() {
    log_info "Starting migration from systemd to container..."
    
    if check_systemd_service; then
        log_info "Systemd service is running. Stopping it..."
        stop_systemd_service
    else
        log_info "Systemd service is not running."
    fi
    
    # Ensure .env file exists
    if [ ! -f .env ]; then
        log_info "Creating .env file from template..."
        cp .env.example .env
        log_warning "Please review and update .env file as needed"
    fi
    
    start_container
    
    log_success "Migration completed!"
    log_info "OpenCode is now running in a container"
    log_info "Generate an API key with: $0 generate-key"
}

# Show help
show_help() {
    echo "OpenCode Container Management"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  start              Start the OpenCode container"
    echo "  stop               Stop the OpenCode container"
    echo "  restart            Restart the OpenCode container"
    echo "  status             Show service status"
    echo "  logs               Show container logs"
    echo "  generate-key [key] Generate API key (optionally with custom key)"
    echo "  migrate            Migrate from systemd service to container"
    echo "  build              Rebuild the container image"
    echo "  shell              Open shell in running container"
    echo "  help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 migrate                    # Migrate from systemd to container"
    echo "  $0 generate-key               # Generate random API key"
    echo "  $0 generate-key mykey123      # Generate with specific key"
    echo "  $0 logs -f                    # Follow logs in real-time"
}

# Main command handling
case "${1:-help}" in
    start)
        start_container
        ;;
    stop)
        stop_container
        ;;
    restart)
        stop_container
        start_container
        ;;
    status)
        show_status
        ;;
    logs)
        shift
        docker compose logs "$@" opencode
        ;;
    generate-key)
        shift
        generate_api_key "$@"
        ;;
    migrate)
        migrate
        ;;
    build)
        log_info "Rebuilding OpenCode container..."
        docker compose build --no-cache
        log_success "Container rebuilt"
        ;;
    shell)
        if docker compose ps opencode | grep -q "Up"; then
            docker compose exec opencode /bin/zsh
        else
            log_error "OpenCode container is not running. Start it first with: $0 start"
            exit 1
        fi
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        log_error "Unknown command: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
