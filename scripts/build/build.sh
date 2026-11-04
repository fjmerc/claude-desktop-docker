#!/bin/bash
# Build script for Claude Desktop Docker (local dev image).
#
# Claude Desktop is installed into the image at build time from Anthropic's
# official .deb (version pinned in claude-desktop.pin), and the container's
# startup.sh launches it — so "build" is just: build the image, start it.

set -e  # Exit on any error

# Compose v1/v2 compat: define a docker-compose shell function only if the
# standalone v1 binary isn't present, forwarding to the `docker compose` plugin.
command -v docker-compose >/dev/null 2>&1 || docker-compose() { docker compose "$@"; }

# Default options
NO_CACHE=false
CLEAN_BUILD=false
RUN_AFTER_BUILD=true
CHECK_DEPS=true

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
    echo "  --help             Show this help message"
    echo ""
}

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --no-cache) NO_CACHE=true ;;
        --clean) CLEAN_BUILD=true ;;
        --no-run) RUN_AFTER_BUILD=false ;;
        --no-deps-check) CHECK_DEPS=false ;;
        --help) show_help; exit 0 ;;
        *) echo "Unknown parameter: $1"; show_help; exit 1 ;;
    esac
    shift
done

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
cd "$PROJECT_DIR"

if [ "$CLEAN_BUILD" = true ]; then
    echo "=== Performing clean build ==="
    echo "Stopping and removing existing container..."
    docker-compose down
    docker-compose rm -f
fi

echo "=== Building Docker image (Claude Desktop $(. ./claude-desktop.pin && echo "$CLAUDE_VERSION")) ==="
if [ "$NO_CACHE" = true ]; then
    docker-compose build --no-cache
else
    docker-compose build
fi

if [ "$RUN_AFTER_BUILD" = true ]; then
    echo "=== Starting container ==="
    export USER=root
    docker-compose up -d

    echo "Waiting for container to initialize..."
    sleep 5

    if ! docker ps | grep -q claude-desktop; then
        echo "❌ Error: Container failed to start. Check logs with ./claude.sh logs"
        exit 1
    fi

    if [ "$CHECK_DEPS" = true ]; then
        echo "=== Verifying dependencies ==="
        docker exec claude-desktop /bin/bash -c "bash /scripts/utils/verify-dependencies.sh"
    fi

    echo "=============================================="
    echo "✅ Setup complete! Claude Desktop starts automatically with the container."
    echo "Access it via:"
    echo "1. Web browser at http://localhost:6080/"
    echo "2. VNC client at localhost:5901"
    echo "The VNC password is printed in ./claude.sh logs on first boot (or set VNC_PASSWORD)."
    echo "=============================================="
else
    echo "=== Docker image built successfully ==="
    echo "To start the container, run: ./claude.sh start"
fi
