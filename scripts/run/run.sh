#!/bin/bash
# Consolidated run script for Claude Desktop Docker
# This script handles starting, stopping, and restarting the container

set -e  # Exit on any error

# Compose v1/v2 compat: define a docker-compose shell function only if the
# standalone v1 binary isn't present, forwarding to the `docker compose` plugin.
command -v docker-compose >/dev/null 2>&1 || docker-compose() { docker compose "$@"; }

# Default options
ACTION="start"
BUILD_CLAUDE=false
FORCE_REBUILD=false

# Display help
show_help() {
    echo "Claude Desktop Docker - Run Script"
    echo ""
    echo "Usage: $0 [options] [action]"
    echo ""
    echo "Actions:"
    echo "  start     Start the container (default)"
    echo "  stop      Stop the container"
    echo "  restart   Restart the container"
    echo ""
    echo "Options:"
    echo "  --build-claude    Build Claude Desktop after starting"
    echo "  --force-rebuild   Force rebuild of Claude Desktop even if it exists"
    echo "  --help            Show this help message"
    echo ""
}

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        start|stop|restart) ACTION="$1" ;;
        --build-claude) BUILD_CLAUDE=true ;;
        --force-rebuild) FORCE_REBUILD=true; BUILD_CLAUDE=true ;;
        --help) show_help; exit 0 ;;
        *) echo "Unknown parameter: $1"; show_help; exit 1 ;;
    esac
    shift
done

# The directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
SCRIPTS_DIR="$(dirname "$SCRIPT_DIR")"

# Change to project directory
cd "$PROJECT_DIR"

# Handle different actions
case "$ACTION" in
    start)
        echo "=== Starting container ==="
        export USER=root
        docker-compose up -d
        
        echo "Waiting for container to initialize..."
        sleep 5
        
        # Check if container is running
        if ! docker ps | grep -q claude-desktop; then
            echo "❌ Error: Container failed to start. Check logs with ./claude.sh logs"
            exit 1
        fi
        
        # Ensure directory structure for volumes
        echo "=== Ensuring directory structure for volumes ==="
        docker exec claude-desktop /bin/bash -c "mkdir -p /root/claude-app /root/.cache /root/.config/Claude"
        
        if [ "$BUILD_CLAUDE" = true ]; then
            echo "=== Building Claude Desktop ==="
            if [ "$FORCE_REBUILD" = true ]; then
                docker exec claude-desktop /bin/bash -c "rm -rf /root/claude-app/* || true"
            fi
            docker exec claude-desktop /bin/bash -c "cd /root/claude-linux-desktop-build && chmod +x build-claude.sh && export APP_INSTALL_DIR=/root/claude-app && ./build-claude.sh"
        else
            # Check if Claude Desktop is already built
            if docker exec claude-desktop /bin/bash -c "[ -f /root/claude-app/bin/claude-desktop ]"; then
                echo "✅ Claude Desktop is already built. Starting it..."
                
                # Copy the find-electron.sh script to the container
                docker cp "$SCRIPT_DIR/../utils/find-electron.sh" claude-desktop:/scripts/utils/
                
                # Make it executable
                docker exec claude-desktop chmod +x /scripts/utils/find-electron.sh
                
                # Set proper paths and start the application
                docker exec -d claude-desktop /bin/bash -c "export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin:/root/.npm-global/bin && export DISPLAY=:1 && cd /root/claude-app/bin && ./claude-desktop --no-sandbox"
            else
                echo "⚠️ Claude Desktop is not built yet. Run with --build-claude option to build it."
            fi
        fi
        
        echo "=============================================="
        echo "✅ Container started!"
        echo "Access the Claude Desktop via:"
        echo "1. VNC client at localhost:5901 (password: claude_desktop)"
        echo "2. Web browser at http://localhost:6080/"
        echo "=============================================="
        ;;
        
    stop)
        echo "=== Stopping container ==="
        docker-compose down
        echo "✅ Container stopped."
        ;;
        
    restart)
        echo "=== Restarting container ==="
        docker-compose down
        export USER=root
        docker-compose up -d
        
        echo "Waiting for container to initialize..."
        sleep 5
        
        # Check if container is running
        if ! docker ps | grep -q claude-desktop; then
            echo "❌ Error: Container failed to restart. Check logs with ./claude.sh logs"
            exit 1
        fi
        
        # Ensure directory structure for volumes
        echo "=== Ensuring directory structure for volumes ==="
        docker exec claude-desktop /bin/bash -c "mkdir -p /root/claude-app /root/.cache /root/.config/Claude"
        
        # Check if Claude Desktop is already built and start it automatically
        if docker exec claude-desktop /bin/bash -c "[ -f /root/claude-app/bin/claude-desktop ]"; then
            echo "✅ Claude Desktop is already built. Starting it..."
            
            # Copy the find-electron.sh script to the container
            docker cp "$SCRIPT_DIR/../utils/find-electron.sh" claude-desktop:/scripts/utils/
            
            # Make it executable
            docker exec claude-desktop chmod +x /scripts/utils/find-electron.sh
            
            # Set proper paths and start the application
            docker exec -d claude-desktop /bin/bash -c "export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin:/root/.npm-global/bin && export DISPLAY=:1 && cd /root/claude-app/bin && ./claude-desktop --no-sandbox"
        else
            echo "⚠️ Claude Desktop is not built yet. Run with --build-claude option to build it."
        fi
        
        echo "=============================================="
        echo "✅ Container restarted!"
        echo "Access the Claude Desktop via:"
        echo "1. VNC client at localhost:5901 (password: claude_desktop)"
        echo "2. Web browser at http://localhost:6080/"
        echo "=============================================="
        ;;
esac
