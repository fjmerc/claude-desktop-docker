#!/bin/bash
# Run script for Claude Desktop Docker: start, stop, restart the container.
#
# Claude Desktop ships inside the image and the container's startup.sh
# launches it (and relaunches it if it exits), so there is nothing to build
# or launch from here.

set -e  # Exit on any error

# Compose v1/v2 compat: define a docker-compose shell function only if the
# standalone v1 binary isn't present, forwarding to the `docker compose` plugin.
command -v docker-compose >/dev/null 2>&1 || docker-compose() { docker compose "$@"; }

ACTION="start"

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
    echo "  --help    Show this help message"
    echo ""
}

while [[ "$#" -gt 0 ]]; do
    case $1 in
        start|stop|restart) ACTION="$1" ;;
        --build-claude|--force-rebuild)
            echo "Note: $1 is no longer needed — Claude Desktop is installed in the image."
            echo "      To update it, rebuild the image: ./claude.sh build" ;;
        --help) show_help; exit 0 ;;
        *) echo "Unknown parameter: $1"; show_help; exit 1 ;;
    esac
    shift
done

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
cd "$PROJECT_DIR"

start_container() {
    export USER=root
    docker-compose up -d

    echo "Waiting for container to initialize..."
    sleep 5

    if ! docker ps | grep -q claude-desktop; then
        echo "❌ Error: Container failed to start. Check logs with ./claude.sh logs"
        exit 1
    fi

    echo "=============================================="
    echo "✅ Container $1! Claude Desktop starts automatically."
    echo "Access it via:"
    echo "1. Web browser at http://localhost:6080/"
    echo "2. VNC client at localhost:5901"
    echo "=============================================="
}

case "$ACTION" in
    start)
        echo "=== Starting container ==="
        start_container started
        ;;
    stop)
        echo "=== Stopping container ==="
        docker-compose down
        echo "✅ Container stopped."
        ;;
    restart)
        echo "=== Restarting container ==="
        docker-compose down
        start_container restarted
        ;;
esac
