#!/bin/bash

# Script to update qBittorrent configuration to fix port issues
CONFIG_FILE="/home/delorenj/docker/stacks/media/qbittorrent/qBittorrent.conf"

if [ -f "$CONFIG_FILE" ]; then
    # Make a backup
    cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"
    
    # Update listening port settings
    sed -i 's/^Session\\Port=.*/Session\\Port=6881/' "$CONFIG_FILE"
    sed -i 's/^Session\\PortRangeMin=.*/Session\\PortRangeMin=6881/' "$CONFIG_FILE"
    sed -i 's/^Session\\PortRangeMax=.*/Session\\PortRangeMax=6885/' "$CONFIG_FILE"
    
    # Ensure "use different port on each startup" is disabled
    sed -i 's/^Session\\PortRandom=.*/Session\\PortRandom=false/' "$CONFIG_FILE"
    
    # Ensure qBittorrent listens on all interfaces
    sed -i 's/^Session\\Interface=.*/Session\\Interface=tun0/' "$CONFIG_FILE"
    sed -i 's/^Session\\InterfaceName=.*/Session\\InterfaceName=tun0/' "$CONFIG_FILE"
    
    # Ensure UPnP/NAT-PMP is disabled (handled by gluetun)
    sed -i 's/^Bittorrent\\UPnP=.*/Bittorrent\\UPnP=false/' "$CONFIG_FILE"
    sed -i 's/^Bittorrent\\NATPMP=.*/Bittorrent\\NATPMP=false/' "$CONFIG_FILE"
    
    echo "Configuration updated successfully"
else
    echo "Configuration file not found at $CONFIG_FILE"
fi
