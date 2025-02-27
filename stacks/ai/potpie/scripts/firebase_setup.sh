#!/bin/bash
# Firebase Setup Helper for PotPie
# This script helps manage Firebase configurations for PotPie

set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if we're in the PotPie directory
if [ ! -f "app/main.py" ]; then
  echo -e "${RED}Error: This script must be run from the PotPie root directory${NC}"
  exit 1
fi

# Functions
show_help() {
  echo -e "${BLUE}Firebase Setup Helper for PotPie${NC}"
  echo ""
  echo "Usage: ./scripts/firebase_setup.sh [command]"
  echo ""
  echo "Commands:"
  echo "  check      - Check Firebase configuration status"
  echo "  dev        - Set development mode (skip Firebase auth)"
  echo "  prod       - Set production mode (requires Firebase auth)"
  echo "  help       - Show this help message"
  echo ""
}

check_firebase_config() {
  echo -e "${BLUE}Checking Firebase configuration...${NC}"
  
  # Check for service account file
  if [ -f "firebase_service_account.json" ]; then
    echo -e "${GREEN}✓ Firebase service account file found${NC}"
  else
    echo -e "${YELLOW}⚠ Firebase service account file not found${NC}"
    echo "  To use PotPie in production mode, you need this file."
    echo "  See docs/FIREBASE_SETUP.md for instructions."
  fi
  
  # Check environment mode
  if grep -q "isDevelopmentMode=enabled" .env; then
    echo -e "${YELLOW}⚠ Running in DEVELOPMENT mode (Firebase auth bypassed)${NC}"
  else
    echo -e "${GREEN}✓ Running in PRODUCTION mode${NC}"
    
    # Additional checks for production mode
    if ! grep -q "ENV=production" .env; then
      echo -e "${RED}✗ ENV variable not set to 'production' in .env file${NC}"
    fi
  fi
  
  echo ""
  echo -e "${BLUE}Firebase Features Status:${NC}"
  if [ -f "firebase_service_account.json" ] && ! grep -q "isDevelopmentMode=enabled" .env; then
    echo -e "${GREEN}✓ User Authentication enabled${NC}"
    echo -e "${GREEN}✓ User Management enabled${NC}"
    echo -e "${GREEN}✓ Data Persistence enabled${NC}"
  else
    echo -e "${YELLOW}⚠ Using dummy user (development mode)${NC}"
    echo -e "${YELLOW}⚠ Limited user management${NC}"
    echo -e "${YELLOW}⚠ Data persistence limited to local database${NC}"
  fi
}

set_dev_mode() {
  echo -e "${BLUE}Setting development mode...${NC}"
  
  # Backup .env file
  cp .env .env.backup
  
  # Update .env file
  sed -i 's/isDevelopmentMode=disabled/isDevelopmentMode=enabled/g' .env
  if ! grep -q "isDevelopmentMode=" .env; then
    echo "isDevelopmentMode=enabled" >> .env
  fi
  
  # Set development environment
  sed -i 's/ENV=production/ENV=development/g' .env
  if ! grep -q "ENV=" .env; then
    echo "ENV=development" >> .env
  fi
  
  echo -e "${GREEN}Development mode enabled. Firebase auth will be bypassed.${NC}"
  echo "A backup of your previous .env has been saved as .env.backup"
}

set_prod_mode() {
  echo -e "${BLUE}Setting production mode...${NC}"
  
  if [ ! -f "firebase_service_account.json" ]; then
    echo -e "${RED}Error: Firebase service account file not found${NC}"
    echo "Please place your firebase_service_account.json file in the PotPie root directory first."
    echo "See docs/FIREBASE_SETUP.md for instructions."
    exit 1
  fi
  
  # Backup .env file
  cp .env .env.backup
  
  # Update .env file
  sed -i 's/isDevelopmentMode=enabled/isDevelopmentMode=disabled/g' .env
  if ! grep -q "isDevelopmentMode=" .env; then
    echo "isDevelopmentMode=disabled" >> .env
  fi
  
  # Set production environment
  sed -i 's/ENV=development/ENV=production/g' .env
  if ! grep -q "ENV=" .env; then
    echo "ENV=production" >> .env
  fi
  
  echo -e "${GREEN}Production mode enabled. Firebase auth will be used.${NC}"
  echo "A backup of your previous .env has been saved as .env.backup"
}

# Main logic
case "$1" in
  check)
    check_firebase_config
    ;;
  dev)
    set_dev_mode
    ;;
  prod)
    set_prod_mode
    ;;
  help|*)
    show_help
    ;;
esac

exit 0
