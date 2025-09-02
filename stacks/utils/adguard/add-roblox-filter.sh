#!/bin/bash
# Add Roblox filter to AdGuard Home via API

# Get the AdGuard Home admin password from environment or prompt
ADMIN_PASS=${ADMIN_PASSWORD:-admin}

# Add the custom filter
curl -X POST "http://localhost:8080/control/filtering/add_url" \
  -H "Content-Type: application/json" \
  -u "admin:$ADMIN_PASS" \
  -d '{
    "url": "file:///opt/adguardhome/work/data/filters/9999.txt",
    "name": "Roblox Block List",
    "whitelist": false
  }'
