#!/bin/bash

# Setup script for opencode systemd service
echo "Setting up opencode systemd service..."

# Copy service file
sudo cp /home/delorenj/docker/core/traefik/opencode.service /etc/systemd/system/

# Reload systemd
sudo systemctl daemon-reload

# Enable service to start on boot
sudo systemctl enable opencode.service

# Start the service
sudo systemctl start opencode.service

# Check status
sudo systemctl status opencode.service

echo "OpenCode service setup complete!"