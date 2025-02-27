#!/bin/bash

# Configuration
TRAEFIK_DIR="/home/delorenj/docker/stacks/proxy/traefik"
DYNAMIC_DIR="$TRAEFIK_DIR/config/dynamic"
CONFIG_FILE="$TRAEFIK_DIR/config/traefik.yml"
ACTION=$1
DOMAIN=$2

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Function to validate configuration files
validate_config() {
    echo "🔍 Validating Traefik configuration..."
    
    # Check main configuration
    if ! docker run --rm -v "$TRAEFIK_DIR/config:/etc/traefik" traefik traefik validate /etc/traefik/traefik.yml; then
        echo -e "${RED}❌ Main configuration validation failed${NC}"
        return 1
    fi
    
    # Check dynamic configurations
    for file in "$DYNAMIC_DIR"/*.yml; do
        if ! docker run --rm -v "$file:/config.yml" traefik traefik validate /config.yml; then
            echo -e "${RED}❌ Dynamic configuration validation failed: $(basename "$file")${NC}"
            return 1
        fi
    done
    
    echo -e "${GREEN}✅ All configurations validated successfully${NC}"
    return 0
}

# Function to show current configuration
show_config() {
    echo "📋 Current Traefik Configuration:"
    echo "================================="
    
    # Show main configuration
    echo -e "${YELLOW}Main Configuration:${NC}"
    cat "$CONFIG_FILE"
    
    # Show dynamic configurations
    echo -e "\n${YELLOW}Dynamic Configurations:${NC}"
    for file in "$DYNAMIC_DIR"/*.yml; do
        echo -e "\n--- $(basename "$file") ---"
        cat "$file"
    done
    
    # Show current routes
    echo -e "\n${YELLOW}Active Routes:${NC}"
    curl -s http://localhost:8080/api/http/routers | jq -r '.[] | "• \(.rule) -> \(.service)"'
}

# Function to add a new domain configuration
add_domain() {
    local domain=$1
    local config_file="$DYNAMIC_DIR/$domain.yml"
    
    echo "🌐 Adding configuration for $domain..."
    
    # Create dynamic configuration
    cat > "$config_file" << EOF
http:
  routers:
    ${domain//./-}:
      rule: "Host(\`$domain\`)"
      service: ${domain//./-}
      entryPoints:
        - websecure
      tls:
        certResolver: letsencrypt
  
  services:
    ${domain//./-}:
      loadBalancer:
        servers:
          - url: "http://localhost:8080"  # Default port, update as needed
EOF
    
    echo -e "${GREEN}✅ Configuration created for $domain${NC}"
    echo "Don't forget to update the service URL in $config_file"
}

# Function to remove a domain configuration
remove_domain() {
    local domain=$1
    local config_file="$DYNAMIC_DIR/$domain.yml"
    
    if [ -f "$config_file" ]; then
        rm "$config_file"
        echo -e "${GREEN}✅ Removed configuration for $domain${NC}"
    else
        echo -e "${RED}❌ No configuration found for $domain${NC}"
    fi
}

# Function to apply configuration changes
apply_config() {
    echo "🔄 Applying configuration changes..."
    
    # Validate configuration first
    if ! validate_config; then
        echo -e "${RED}❌ Configuration validation failed. Aborting.${NC}"
        return 1
    fi
    
    # Reload Traefik
    docker compose -f "$TRAEFIK_DIR/compose.yml" restart traefik
    
    # Wait for Traefik to start
    sleep 5
    
    # Check if Traefik is running
    if ! curl -s -f http://localhost:8080/ping > /dev/null; then
        echo -e "${RED}❌ Traefik failed to start properly${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ Configuration applied successfully${NC}"
    return 0
}

# Function to monitor Traefik logs
monitor_logs() {
    echo "📊 Monitoring Traefik logs..."
    docker compose -f "$TRAEFIK_DIR/compose.yml" logs -f traefik
}

# Function to check SSL certificates
check_certs() {
    echo "🔒 Checking SSL certificates..."
    
    # Get all domains from configurations
    local domains=$(grep -h "Host(" "$DYNAMIC_DIR"/*.yml | sed -E 's/.*Host\(`([^`]+)`\).*/\1/')
    
    for domain in $domains; do
        echo -e "\n${YELLOW}Checking $domain${NC}"
        expiry=$(openssl s_client -connect "$domain:443" -servername "$domain" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null | grep "notAfter")
        if [ -n "$expiry" ]; then
            echo -e "${GREEN}✅ Certificate valid: $expiry${NC}"
        else
            echo -e "${RED}❌ Unable to get certificate information${NC}"
        fi
    done
}

# Main execution
case $ACTION in
    "validate")
        validate_config
        ;;
    "show")
        show_config
        ;;
    "add")
        if [ -z "$DOMAIN" ]; then
            echo "Usage: $0 add <domain>"
            exit 1
        fi
        add_domain "$DOMAIN"
        ;;
    "remove")
        if [ -z "$DOMAIN" ]; then
            echo "Usage: $0 remove <domain>"
            exit 1
        fi
        remove_domain "$DOMAIN"
        ;;
    "apply")
        apply_config
        ;;
    "logs")
        monitor_logs
        ;;
    "certs")
        check_certs
        ;;
    *)
        echo "Usage: $0 <command> [domain]"
        echo "Commands:"
        echo "  validate - Validate configuration files"
        echo "  show    - Show current configuration"
        echo "  add     - Add new domain configuration"
        echo "  remove  - Remove domain configuration"
        echo "  apply   - Apply configuration changes"
        echo "  logs    - Monitor Traefik logs"
        echo "  certs   - Check SSL certificates"
        exit 1
        ;;
esac