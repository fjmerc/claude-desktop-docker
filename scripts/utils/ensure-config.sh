#!/bin/bash
# This script ensures that Claude configuration directories exist and have proper permissions

# Create Claude config directory if it doesn't exist
mkdir -p /root/.config/Claude

# Set proper permissions
chmod 755 /root/.config
chmod 755 /root/.config/Claude

echo "Claude config directory verified at /root/.config/Claude"
