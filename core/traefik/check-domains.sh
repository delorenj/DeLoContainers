#!/usr/bin/env zsh

echo "Checking if the domains resolve locally..."

echo "
Checking prowlarr.delo.sh..."
nslookup prowlarr.delo.sh

echo "
Checking movies.delo.sh..."
nslookup movies.delo.sh

echo "
Checking get.delo.sh..."
nslookup get.delo.sh

echo "
You may need to add these domains to your /etc/hosts file:"
echo "127.0.0.1 prowlarr.delo.sh movies.delo.sh get.delo.sh"

