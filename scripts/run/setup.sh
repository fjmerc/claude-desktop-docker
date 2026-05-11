#!/bin/bash
# Consolidated setup script that prepares the environment
# for building and running Claude Desktop in Docker

set -e  # Exit on any error

echo "=== Claude Desktop Docker - Initial Setup ==="

# The directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Make all scripts executable
echo "Setting executable permissions on all scripts..."
find "$PROJECT_DIR" -name "*.sh" -type f -exec chmod +x {} \;

# Make sure xstartup is executable if it exists
if [ -f "$PROJECT_DIR/scripts/xstartup" ]; then
    chmod +x "$PROJECT_DIR/scripts/xstartup"
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Error: Docker is not installed. Please install Docker before continuing."
    exit 1
fi

# Check if Docker Compose is installed (v1 standalone or v2 plugin)
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "❌ Error: Docker Compose is not installed. Please install Docker Compose before continuing."
    exit 1
fi

# Verify if user has docker permissions
if ! docker info &> /dev/null; then
    echo "❌ Error: You don't have permission to use Docker."
    echo "Please make sure your user is in the docker group or run with sudo."
    exit 1
fi

echo "✅ Docker environment verified successfully."
echo "✅ All scripts now have executable permissions."
echo ""
echo "Initial setup complete. You can now build Claude Desktop with:"
echo "./claude.sh build"
echo ""
echo "For additional options, run:"
echo "./claude.sh build --help"
