#!/bin/bash

# Bolt.DIY Stack Management Script

STACK_DIR="/home/delorenj/docker/stacks/ai/bolt-diy"
SOURCE_DIR="/home/delorenj/code/agentic-coders/bolt.diy"

cd "$STACK_DIR"

case "$1" in
    start)
        echo "Starting Bolt.DIY stack..."
        docker compose up -d
        ;;
    stop)
        echo "Stopping Bolt.DIY stack..."
        docker compose down
        ;;
    restart)
        echo "Restarting Bolt.DIY stack..."
        docker compose down
        docker compose up -d
        ;;
    rebuild)
        echo "Rebuilding Bolt.DIY from source..."
        docker compose down
        docker compose build --no-cache
        docker compose up -d
        ;;
    logs)
        echo "Showing Bolt.DIY logs..."
        docker compose logs -f bolt-diy
        ;;
    status)
        echo "Bolt.DIY stack status:"
        docker compose ps
        ;;
    update)
        echo "Updating Bolt.DIY source code..."
        cd "$SOURCE_DIR"
        git pull
        cd "$STACK_DIR"
        docker compose build --no-cache
        docker compose up -d
        ;;
    shell)
        echo "Opening shell in Bolt.DIY container..."
        docker compose exec bolt-diy /bin/bash
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|rebuild|logs|status|update|shell}"
        echo ""
        echo "Commands:"
        echo "  start   - Start the Bolt.DIY stack"
        echo "  stop    - Stop the Bolt.DIY stack"
        echo "  restart - Restart the Bolt.DIY stack"
        echo "  rebuild - Rebuild and restart from source"
        echo "  logs    - Show container logs"
        echo "  status  - Show container status"
        echo "  update  - Pull latest code and rebuild"
        echo "  shell   - Open shell in container"
        exit 1
        ;;
esac
