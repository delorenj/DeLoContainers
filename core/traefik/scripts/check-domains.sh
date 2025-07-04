#!/usr/bin/env zsh

echo "Checking if the domains resolve locally..."

echo "
Checking prowlarr.${DOMAIN}..."
nslookup prowlarr.${DOMAIN}

echo "
Checking movies.${DOMAIN}..."
nslookup movies.${DOMAIN}

echo "
Checking get.${DOMAIN}..."
nslookup get.${DOMAIN}

echo "
You may need to add these domains to your /etc/hosts file:"
echo "127.0.0.1 prowlarr.${DOMAIN} movies.${DOMAIN} get.${DOMAIN}"

