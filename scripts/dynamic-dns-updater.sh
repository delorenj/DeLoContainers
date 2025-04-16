#!/usr/bin/env zsh

# Dynamic DNS Updater for Cloudflare
# Keeps your Cloudflare DNS records updated with your current home IP
# Add to crontab to run automatically (e.g., every hour)
# Requires: jq, curl, dig

# Configuration
CF_EMAIL="your-cloudflare-email@example.com"  # Replace with your email
CF_API_KEY="your-cloudflare-global-api-key"  # Replace with your Global API Key
CF_ZONE_ID="your-cloudflare-zone-id"         # Replace with your Zone ID for delo.sh
DOMAIN="delo.sh"
SUBDOMAINS=("traefik" "lms" "draw" "sync")  # Add all subdomains you need

# Get current public IP
CURRENT_IP=$(dig +short myip.opendns.com @resolver1.opendns.com)
if [ -z "$CURRENT_IP" ]; then
  echo "ERROR: Could not determine current IP address"
  exit 1
fi

echo "Current IP: $CURRENT_IP"

# Function to update a DNS record
update_record() {
  local name=$1
  local type="A"
  local proxied="false"  # Setting to false = Grey Cloud in Cloudflare
  
  # First, get the record ID
  record_info=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records?type=$type&name=$name.$DOMAIN" \
    -H "X-Auth-Email: $CF_EMAIL" \
    -H "X-Auth-Key: $CF_API_KEY" \
    -H "Content-Type: application/json")
  
  # Check if record exists
  record_exists=$(echo "$record_info" | jq -r '.result | length')
  
  if [ "$record_exists" -gt 0 ]; then
    # Get record ID
    record_id=$(echo "$record_info" | jq -r '.result[0].id')
    old_ip=$(echo "$record_info" | jq -r '.result[0].content')
    old_proxied=$(echo "$record_info" | jq -r '.result[0].proxied')
    
    # Update only if IP has changed or proxied setting is different
    if [ "$old_ip" != "$CURRENT_IP" ] || [ "$old_proxied" != "$proxied" ]; then
      echo "Updating $name.$DOMAIN from $old_ip to $CURRENT_IP (proxied: $proxied)"
      
      update_result=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$record_id" \
        -H "X-Auth-Email: $CF_EMAIL" \
        -H "X-Auth-Key: $CF_API_KEY" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"$type\",\"name\":\"$name.$DOMAIN\",\"content\":\"$CURRENT_IP\",\"ttl\":1,\"proxied\":$proxied}")
      
      success=$(echo "$update_result" | jq -r '.success')
      if [ "$success" = "true" ]; then
        echo "✅ Successfully updated $name.$DOMAIN"
      else
        error=$(echo "$update_result" | jq -r '.errors[0].message')
        echo "❌ Failed to update $name.$DOMAIN: $error"
      fi
    else
      echo "✓ No change needed for $name.$DOMAIN (IP: $old_ip, proxied: $old_proxied)"
    fi
  else
    # Create new record
    echo "Creating new record for $name.$DOMAIN with IP $CURRENT_IP"
    
    create_result=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records" \
      -H "X-Auth-Email: $CF_EMAIL" \
      -H "X-Auth-Key: $CF_API_KEY" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"$type\",\"name\":\"$name.$DOMAIN\",\"content\":\"$CURRENT_IP\",\"ttl\":1,\"proxied\":$proxied}")
    
    success=$(echo "$create_result" | jq -r '.success')
    if [ "$success" = "true" ]; then
      echo "✅ Successfully created $name.$DOMAIN"
    else
      error=$(echo "$create_result" | jq -r '.errors[0].message')
      echo "❌ Failed to create $name.$DOMAIN: $error"
    fi
  fi
}

# Update root domain
update_record "@"

# Update all subdomains
for subdomain in "${SUBDOMAINS[@]}"; do
  update_record "$subdomain"
done

echo "DNS update complete!"
echo "Note: It may take a few minutes for DNS changes to propagate"
