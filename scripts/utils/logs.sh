#!/bin/bash
# Consolidated logs script for Claude Desktop Docker

set -e  # Exit on any error

# Compose v1/v2 compat: define a docker-compose shell function only if the
# standalone v1 binary isn't present, forwarding to the `docker compose` plugin.
command -v docker-compose >/dev/null 2>&1 || docker-compose() { docker compose "$@"; }

# Default options
FOLLOW=true
TAIL="all"

# Display help
show_help() {
    echo "Claude Desktop Docker - Logs Script"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --no-follow      Don't follow logs (show and exit)"
    echo "  --tail=LINES     Number of lines to show (default: all)"
    echo "  --help           Show this help message"
    echo ""
}

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --no-follow) FOLLOW=false ;;
        --tail=*) TAIL="${1#*=}" ;;
        --help) show_help; exit 0 ;;
        *) echo "Unknown parameter: $1"; show_help; exit 1 ;;
    esac
    shift
done

# The directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Change to project directory
cd "$PROJECT_DIR"

# Check if container exists
if ! docker ps -a | grep -q claude-desktop; then
    echo "❌ Error: Container does not exist. Please build it first with:"
    echo "./claude.sh build"
    exit 1
fi

# View logs
echo "=== Claude Desktop Docker Container Logs ==="
echo "Displaying logs for container 'claude-desktop'"
echo ""

if [ "$FOLLOW" = true ]; then
    if [ "$TAIL" = "all" ]; then
        docker-compose logs -f
    else
        docker-compose logs -f --tail="$TAIL"
    fi
else
    if [ "$TAIL" = "all" ]; then
        docker-compose logs
    else
        docker-compose logs --tail="$TAIL"
    fi
fi
