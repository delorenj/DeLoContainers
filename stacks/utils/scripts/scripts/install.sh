#!/bin/bash

# Sample installer script
echo "Installing DeLoNET configuration..."

# Install core dependencies
sudo apt-get update
sudo apt-get install -y curl wget git zsh

# Install mise
curl https://mise.run | sh

# Configure mise
mise use node@lts
mise use python@latest

echo "DeLoNET base configuration installed successfully!"