#!/bin/bash
# Consolidated build script for Claude Desktop Docker
# This script handles building both the Docker container and Claude Desktop

set -e  # Exit on any error

# Compose v1/v2 compat: define a docker-compose shell function only if the
# standalone v1 binary isn't present, forwarding to the `docker compose` plugin.
command -v docker-compose >/dev/null 2>&1 || docker-compose() { docker compose "$@"; }

# Default options
NO_CACHE=false
CLEAN_BUILD=false
RUN_AFTER_BUILD=true
CHECK_DEPS=true
INSTALL_DEPS=true
INSTALL_DIR="/root/claude-app"

# Display help
show_help() {
    echo "Claude Desktop Docker - Build Script"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --no-cache         Build Docker image without using cache"
    echo "  --clean            Clean build (remove container and rebuild from scratch)"
    echo "  --no-run           Don't start the container after building"
    echo "  --no-deps-check    Skip dependency verification"
    echo "  --no-deps-install  Skip installation of additional dependencies"
    echo "  --install-dir DIR  Custom installation directory (default: $INSTALL_DIR)"
    echo "  --help             Show this help message"
    echo ""
}

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --no-cache) NO_CACHE=true ;;
        --clean) CLEAN_BUILD=true ;;
        --no-run) RUN_AFTER_BUILD=false ;;
        --no-deps-check) CHECK_DEPS=false ;;
        --no-deps-install) INSTALL_DEPS=false ;;
        --install-dir) INSTALL_DIR="$2"; shift ;;
        --help) show_help; exit 0 ;;
        *) echo "Unknown parameter: $1"; show_help; exit 1 ;;
    esac
    shift
done

# The directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
UTILS_DIR="$PROJECT_DIR/scripts/utils"

# Change to project directory
cd "$PROJECT_DIR"

# Clean build if requested
if [ "$CLEAN_BUILD" = true ]; then
    echo "=== Performing clean build ==="
    echo "Stopping and removing existing container..."
    docker-compose down
    docker-compose rm -f
fi

# Build the Docker image
echo "=== Building Docker image ==="
if [ "$NO_CACHE" = true ]; then
    docker-compose build --no-cache
else
    docker-compose build
fi

# Start the container if required
if [ "$RUN_AFTER_BUILD" = true ]; then
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
    
    # Install dependencies if needed
    if [ "$INSTALL_DEPS" = true ]; then
        echo "=== Installing additional dependencies ==="
        docker exec claude-desktop /bin/bash -c "bash /scripts/utils/install-remaining-deps.sh"
    fi
    
    # Verify dependencies if needed
    if [ "$CHECK_DEPS" = true ]; then
        echo "=== Verifying dependencies ==="
        docker exec claude-desktop /bin/bash -c "bash /scripts/utils/verify-dependencies.sh"
    fi
    
    # Ensure directory structure for volumes
    echo "=== Ensuring directory structure for volumes ==="
    docker exec claude-desktop /bin/bash -c "mkdir -p /root/claude-app /root/.cache /root/.config/Claude"
    
    # Build Claude Desktop
    # Note: build-claude.sh's create_package() already rsyncs the built app to
    # $APP_INSTALL_DIR. We intentionally do NOT call install.sh, which would
    # extract a second copy to ~/.local/claude-desktop (~150MB of duplication
    # ignoring APP_INSTALL_DIR). XFCE menu integration is forfeited; Claude
    # Desktop is launched directly by startup.sh.
    echo "=== Building Claude Desktop ==="
    docker exec claude-desktop /bin/bash -c "cd /root/claude-linux-desktop-build && chmod +x build-claude.sh && export APP_INSTALL_DIR=$INSTALL_DIR && ./build-claude.sh"

    # Slim desktop integration: registers Claude in the XFCE Applications menu
    # and on the Desktop, and symlinks the launcher onto PATH. Avoids the
    # full install.sh re-extract (which duplicated ~150MB into ~/.local).
    echo "=== Registering Claude in XFCE Applications menu and Desktop ==="
    docker exec claude-desktop /bin/bash -c "APP_INSTALL_DIR=$INSTALL_DIR /scripts/utils/desktop-integration.sh"

    # Make scripts executable
    echo "=== Making scripts executable ==="
    docker exec claude-desktop bash /scripts/utils/make-scripts-executable.sh
    
    # Copy the find-electron.sh script to the container
    echo "=== Copying find-electron.sh to the container ==="
    docker cp "$UTILS_DIR/find-electron.sh" claude-desktop:/scripts/utils/
    
    # Make it executable
    docker exec claude-desktop chmod +x /scripts/utils/find-electron.sh
    
    # Explicitly start Claude Desktop
    echo "=== Starting Claude Desktop ==="
    docker exec -d claude-desktop /bin/bash -c "export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin:/root/.npm-global/bin && export DISPLAY=:1 && cd /root/claude-app/bin && ./claude-desktop --no-sandbox"
    
    echo "=============================================="
    echo "✅ Setup complete!"
    echo "Access the Claude Desktop via:"
    echo "1. VNC client at localhost:5901 (password: claude_desktop)"
    echo "2. Web browser at http://localhost:6080/"
    echo "=============================================="
else
    echo "=== Docker image built successfully ==="
    echo "To start the container and build Claude Desktop, run:"
    echo "./claude.sh start"
fi
