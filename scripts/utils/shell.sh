#!/bin/bash
# Consolidated shell script for Claude Desktop Docker

set -e  # Exit on any error

# Default options
COMMAND=""

# Display help
show_help() {
    echo "Claude Desktop Docker - Shell Script"
    echo ""
    echo "Usage: $0 [options] [command]"
    echo ""
    echo "Options:"
    echo "  --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0               Open an interactive shell inside the container"
    echo "  $0 \"ls -la\"      Run a command inside the container and display results"
    echo ""
}

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --help) show_help; exit 0 ;;
        *)
            if [ -z "$COMMAND" ]; then
                COMMAND="$1"
            else
                COMMAND="$COMMAND $1"
            fi
            ;;
    esac
    shift
done

# The directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Change to project directory
cd "$PROJECT_DIR"

# Check if container is running
if ! docker ps | grep -q claude-desktop; then
    echo "❌ Error: Container is not running. Please start it first with:"
    echo "./claude.sh start"
    exit 1
fi

# Access shell or run command
if [ -z "$COMMAND" ]; then
    # Interactive shell
    echo "=== Accessing interactive shell in Claude Desktop Docker container ==="
    echo "Type 'exit' to return to your host system"
    echo ""
    docker exec -it claude-desktop bash
else
    # Run command
    echo "=== Executing command in Claude Desktop Docker container ==="
    echo "Command: $COMMAND"
    echo ""
    docker exec -it claude-desktop bash -c "$COMMAND"
fi
