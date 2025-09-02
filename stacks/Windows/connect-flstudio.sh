#!/bin/bash
# FreeRDP connection script for FL Studio Windows container
# Usage: ./connect-flstudio.sh [username] [password]

USERNAME="${1:-Docker}"
PASSWORD="${2:-admin}"
HOST="localhost"
PORT="13389"

# Check if FreeRDP is installed
if ! command -v xfreerdp &> /dev/null; then
    echo "FreeRDP not found. Installing..."
    sudo apt install -y freerdp2-x11
fi

echo "Connecting to Windows FL Studio container..."
echo "Username: $USERNAME"
echo "Host: $HOST:$PORT"

# Connect with audio support (USB devices are already passed through at Docker level)
xfreerdp \
    /v:$HOST:$PORT \
    /u:$USERNAME \
    /p:$PASSWORD \
    /sound:sys:alsa \
    /microphone:sys:alsa \
    /gfx:rfx \
    /network:auto \
    /compression \
    /cert:ignore \
    /dynamic-resolution \
    /size:1920x1080