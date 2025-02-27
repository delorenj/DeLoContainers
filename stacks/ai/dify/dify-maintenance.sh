#!/bin/bash

# Dify Maintenance Script
# Usage: ./dify-maintenance.sh [command]

# Set color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Define commands
case "$1" in
    status)
        echo -e "${GREEN}Checking Dify service status...${NC}"
        docker-compose ps
        ;;
    logs)
        if [ -z "$2" ]; then
            echo -e "${GREEN}Showing logs for all services...${NC}"
            docker-compose logs -f
        else
            echo -e "${GREEN}Showing logs for $2 service...${NC}"
            docker-compose logs -f "$2"
        fi
        ;;
    restart)
        if [ -z "$2" ]; then
            echo -e "${YELLOW}Restarting all Dify services...${NC}"
            docker-compose restart
        else
            echo -e "${YELLOW}Restarting $2 service...${NC}"
            docker-compose restart "$2"
        fi
        ;;
    backup)
        echo -e "${GREEN}Creating backup of Dify data...${NC}"
        BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
        BACKUP_DIR="/home/delorenj/docker/backups/dify"
        mkdir -p $BACKUP_DIR
        
        echo -e "${YELLOW}Backing up configuration files...${NC}"
        cp .env $BACKUP_DIR/.env.$BACKUP_DATE
        cp docker-compose.yml $BACKUP_DIR/docker-compose.yml.$BACKUP_DATE
        
        echo -e "${YELLOW}Backing up data directory...${NC}"
        tar -czf $BACKUP_DIR/dify-data-$BACKUP_DATE.tar.gz ./data
        
        echo -e "${GREEN}Backup completed: $BACKUP_DIR/dify-data-$BACKUP_DATE.tar.gz${NC}"
        ;;
    update)
        echo -e "${YELLOW}Updating Dify to the latest version...${NC}"
        echo -e "${YELLOW}Pulling latest images...${NC}"
        docker-compose pull
        
        echo -e "${YELLOW}Restarting services with new images...${NC}"
        docker-compose down
        docker-compose up -d
        
        echo -e "${GREEN}Update completed!${NC}"
        ;;
    reset)
        echo -e "${RED}WARNING: This will reset your Dify installation!${NC}"
        read -p "Are you sure you want to continue? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Stopping services...${NC}"
            docker-compose down
            
            echo -e "${YELLOW}Creating backup before reset...${NC}"
            BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
            BACKUP_DIR="/home/delorenj/docker/backups/dify"
            mkdir -p $BACKUP_DIR
            tar -czf $BACKUP_DIR/dify-data-before-reset-$BACKUP_DATE.tar.gz ./data
            
            echo -e "${RED}Removing data directories...${NC}"
            sudo rm -rf ./data/postgres-data
            sudo rm -rf ./data/redis-data
            sudo rm -rf ./data/weaviate-data
            sudo rm -rf ./data/storage
            
            echo -e "${YELLOW}Recreating data directories...${NC}"
            mkdir -p ./data/postgres-data
            mkdir -p ./data/redis-data
            mkdir -p ./data/weaviate-data
            mkdir -p ./data/storage
            
            echo -e "${GREEN}Dify has been reset. Starting services again...${NC}"
            docker-compose up -d
        else
            echo -e "${GREEN}Reset cancelled.${NC}"
        fi
        ;;
    *)
        echo -e "Dify Maintenance Script"
        echo -e "Usage: $0 [command]"
        echo -e "\nCommands:"
        echo -e "  ${GREEN}status${NC}            - Show status of all Dify services"
        echo -e "  ${GREEN}logs${NC} [service]     - Show logs (optionally for a specific service)"
        echo -e "  ${GREEN}restart${NC} [service]  - Restart all services or a specific service"
        echo -e "  ${GREEN}backup${NC}            - Create a backup of Dify data and config"
        echo -e "  ${GREEN}update${NC}            - Update to the latest version of Dify"
        echo -e "  ${GREEN}reset${NC}             - Reset Dify installation (CAUTION: Deletes all data)"
        ;;
esac
