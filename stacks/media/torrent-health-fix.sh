#!/bin/bash

# Script to fix qBittorrent configuration and add public trackers to all torrents
# Created by Cascade to fix download issues

# Add updated public trackers to all torrents
echo "Adding public trackers to all torrents..."

# List of reliable public trackers
TRACKERS=(
  "udp://tracker.opentrackr.org:1337/announce"
  "udp://tracker.openbittorrent.com:6969/announce"
  "udp://open.stealth.si:80/announce"
  "udp://exodus.desync.com:6969/announce"
  "udp://tracker.torrent.eu.org:451/announce"
  "udp://explodie.org:6969/announce"
  "udp://uploads.gamecoast.net:6969/announce"
  "udp://tracker.moeking.me:6969/announce"
  "udp://tracker.dler.org:6969/announce"
  "udp://open.tracker.cl:1337/announce"
  "udp://tracker.opentrackr.org:1337/announce"
  "http://tracker.openbittorrent.com:80/announce"
)

# Format trackers for qBittorrent
TRACKERS_STRING=$(printf "%s\n" "${TRACKERS[@]}")

# Enhance qBittorrent performance with optimal settings
echo "Optimizing qBittorrent settings..."

# Run in qBittorrent container
docker exec qbittorrent bash -c "echo '$TRACKERS_STRING' > /tmp/trackers.txt"

# Apply the trackers to all torrents
echo "Applying trackers to all torrents (this may take a moment)..."
docker exec qbittorrent bash -c "cd /config && \
  for hash in \$(sqlite3 qBittorrent/data/nova3.db \"SELECT DISTINCT infohash_v1 FROM torrent\"); do \
    echo \"Processing torrent \$hash\" && \
    qbt torrent set-trackers --hash \$hash --urls-path /tmp/trackers.txt || \
    echo \"Couldn't add trackers to \$hash, will try another method\" \
  done"

# Ensure proper port configuration
echo "Configuring network ports..."
docker exec qbittorrent bash -c "cd /config && \
  sed -i 's/Connection\\\\UPnP=false/Connection\\\\UPnP=true/' qBittorrent.conf && \
  sed -i 's/Connection\\\\PortRangeMin=.*/Connection\\\\PortRangeMin=49152/' qBittorrent.conf && \
  sed -i 's/Connection\\\\PortRangeMax=.*/Connection\\\\PortRangeMax=49156/' qBittorrent.conf"

# Restart qBittorrent to apply changes
echo "Restarting qBittorrent to apply all changes..."
docker restart qbittorrent

echo "✅ Torrent health fixes applied!"
echo "Please be patient, it may take a few minutes for downloads to start."
echo "If you still have issues after 10 minutes, try adding new, popular torrents."
