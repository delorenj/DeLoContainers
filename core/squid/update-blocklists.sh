#!/bin/bash

SQUID_PATH="/etc/squid"
TEMP_DIR="/tmp/blocklists"

mkdir -p $TEMP_DIR

# Download lists
curl -s "https://urlhaus.abuse.ch/downloads/text/" > $TEMP_DIR/malware.txt
curl -s "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts" > $TEMP_DIR/combined.txt

# Process lists
cat $TEMP_DIR/malware.txt | grep -v '^#' | awk '{print $1}' > $SQUID_PATH/malware_domains.txt
cat $TEMP_DIR/combined.txt | grep '^0\.0\.0\.0' | awk '{print $2}' | grep -i 'adult\|porn\|xxx' > $SQUID_PATH/adult_sites.txt

# Clean up
rm -rf $TEMP_DIR

# Reload Squid
systemctl reload squid