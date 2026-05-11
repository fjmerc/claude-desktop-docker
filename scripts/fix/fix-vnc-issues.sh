#!/bin/bash
set -e

# Compose v1/v2 compat: define a docker-compose shell function only if the
# standalone v1 binary isn't present, forwarding to the `docker compose` plugin.
command -v docker-compose >/dev/null 2>&1 || docker-compose() { docker compose "$@"; }

# This script addresses the VNC server issues in the Claude Desktop Docker container

# Ensure we're in the right directory
cd "$(dirname "$0")/.."

echo "Applying fixes for VNC server issues..."

# Step 1: Make the script executable
chmod +x scripts/fix-vnc-issues.sh

# Step 2: Explain fixes being applied
echo "Applying the following fixes:"
echo "1. Adding X11 authentication with .Xauthority file"
echo "2. Adding font packages to resolve font path issues"
echo "3. Removing incompatible -localhost no parameter"
echo "4. Using config file for localhost setting"
echo ""

# Step 3: Rebuild the Docker image with our changes
echo "Rebuilding Docker image..."
docker-compose build

# Step 3: Stop any existing containers
echo "Stopping existing containers..."
docker-compose down || true

# Step 4: Start the container with the updated configuration
echo "Starting container with new configuration..."
docker-compose up -d

# Step 5: Wait for container to start up
echo "Waiting for container to start..."
sleep 5

# Step 6: Check if VNC server is running properly
echo "Checking VNC server status..."
docker exec claude-desktop bash -c "ps aux | grep Xvnc"

echo "Checking noVNC status..."
docker exec claude-desktop bash -c "ps aux | grep websockify"

echo "Checking logs for any remaining errors..."
docker logs claude-desktop | grep -i error

echo "=============================================="
echo "VNC setup check complete!"
echo "You should now be able to access the Claude Desktop via:"
echo "1. VNC client at localhost:5901 (password: claude_desktop)"
echo "2. Web browser at http://localhost:6080/"
echo "=============================================="
echo "If you still experience issues, check the logs with:"
echo "docker logs claude-desktop"
echo "=============================================="
