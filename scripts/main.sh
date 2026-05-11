#!/bin/bash
# Main entry point script for Claude Desktop Docker
# This script provides a unified command interface for all operations

set -e  # Exit on any error

# Display the main help message
show_help() {
    echo "Claude Desktop Docker - Main Command Interface"
    echo ""
    echo "Usage: $0 COMMAND [options]"
    echo ""
    echo "Commands:"
    echo "  setup             Initial setup and permission configuration"
    echo "  build             Build Docker container and Claude Desktop"
    echo "  start             Start the container"
    echo "  stop              Stop the container"
    echo "  restart           Restart the container"
    echo "  start-claude      Start Claude Desktop in an already running container"
    echo "  login-reset       Wipe Claude session state and restart (fresh login screen)"
    echo "  find-electron     Find the electron binary in the container (for troubleshooting)"
    echo "  shell             Access container shell"
    echo "  logs              View container logs"
    echo "  status            Show container and Claude Desktop status"
    echo "  fix-vnc           Fix VNC connection issues"
    echo "  distribute        Create shareable distribution archive"
    echo "  dockerhub         Docker Hub multi-architecture build commands"
    echo "  help              Show this help message"
    echo ""
    echo "For more information on a specific command, run:"
    echo "  $0 COMMAND --help"
}

# Get the main directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Check if COMMAND is provided
if [ $# -eq 0 ]; then
    show_help
    exit 1
fi

# Parse the COMMAND
COMMAND="$1"
shift

# Execute the appropriate script based on COMMAND
case "$COMMAND" in
    setup)
        "$SCRIPT_DIR/run/setup.sh" "$@"
        ;;
    build)
        "$SCRIPT_DIR/build/build.sh" "$@"
        ;;
    start)
        "$SCRIPT_DIR/run/run.sh" start "$@"
        ;;
    stop)
        "$SCRIPT_DIR/run/run.sh" stop "$@"
        ;;
    restart)
        "$SCRIPT_DIR/run/run.sh" restart "$@"
        ;;
    start-claude)
        chmod +x "$SCRIPT_DIR/run/start-claude.sh"
        "$SCRIPT_DIR/run/start-claude.sh" "$@"
        ;;
    login-reset)
        "$SCRIPT_DIR/run/login-reset.sh" "$@"
        ;;
    find-electron)
        chmod +x "$SCRIPT_DIR/utils/find-electron.sh"
        docker exec claude-desktop /bin/bash -c "/scripts/utils/find-electron.sh"
        ;;
    shell)
        "$SCRIPT_DIR/utils/shell.sh" "$@"
        ;;
    logs)
        "$SCRIPT_DIR/utils/logs.sh" "$@"
        ;;
    status)
        "$SCRIPT_DIR/utils/status.sh" "$@"
        ;;
    fix-vnc)
        "$SCRIPT_DIR/fix/fix-vnc.sh" "$@"
        ;;
    distribute)
        "$SCRIPT_DIR/build/distribute.sh" "$@"
        ;;
    dockerhub)
        chmod +x "$PROJECT_DIR/dockerhub/dockerhub-main.sh"
        "$PROJECT_DIR/dockerhub/dockerhub-main.sh" "$@"
        ;;
    help)
        show_help
        ;;
    *)
        echo "Unknown command: $COMMAND"
        show_help
        exit 1
        ;;
esac
