#!/bin/bash
# Main entry point for Docker Hub multi-architecture build functionality
# This script integrates with the existing claude.sh command structure

set -e  # Exit on any error

# The directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

# Source the logger if available
if [[ -f "${SCRIPT_DIR}/dockerhub-logger.sh" ]]; then
    source "${SCRIPT_DIR}/dockerhub-logger.sh"
else
    # Fallback logging functions if logger script is not available
    log_info() { echo "[INFO] $1"; }
    log_error() { echo "[ERROR] $1"; }
    log_warn() { echo "[WARN] $1"; }
    log_debug() { echo "[DEBUG] $1"; }
    log_fatal() { echo "[FATAL] $1"; }
fi

# Display the help message
show_help() {
    echo "Claude Desktop Docker - Docker Hub Commands"
    echo ""
    echo "Usage: ./claude.sh dockerhub COMMAND [options]"
    echo ""
    echo "Commands:"
    echo "  build             Build multi-architecture Docker images"
    echo "  check             Check environment for Docker Hub builds"
    echo "  push              Build and push images to Docker Hub"
    echo "  menu              Launch interactive menu system"
    echo "  help              Show this help message"
    echo ""
    echo "For more information on a specific command, run:"
    echo "  ./claude.sh dockerhub COMMAND --help"
    echo ""
    echo "Examples:"
    echo "  ./claude.sh dockerhub build --platforms linux/amd64,linux/arm64"
    echo "  ./claude.sh dockerhub check --verbose"
    echo "  ./claude.sh dockerhub push --version 0.14.10"
    echo ""
}

# Check if COMMAND is provided
if [[ $# -eq 0 ]]; then
    show_help
    exit 1
fi

# Parse the COMMAND
COMMAND="$1"
shift

# Make scripts executable
chmod +x "${SCRIPT_DIR}/build-dockerhub-multiarch.sh" 2>/dev/null || true
chmod +x "${SCRIPT_DIR}/check-dockerhub-env.sh" 2>/dev/null || true
chmod +x "${SCRIPT_DIR}/dockerhub-logger.sh" 2>/dev/null || true
chmod +x "${SCRIPT_DIR}/menu.sh" 2>/dev/null || true

# Execute the appropriate script based on COMMAND
case "$COMMAND" in
    build)
        log_info "Building multi-architecture Docker images"
        "${SCRIPT_DIR}/build-dockerhub-multiarch.sh" --verbose-build "$@"
        ;;
    check)
        log_info "Checking environment for Docker Hub builds"
        "${SCRIPT_DIR}/check-dockerhub-env.sh" "$@"
        ;;
    push)
        log_info "Building and pushing images to Docker Hub"
        # Add --push flag to ensure images are pushed
        "${SCRIPT_DIR}/build-dockerhub-multiarch.sh" --verbose-build --push "$@"
        ;;
    menu)
        log_info "Launching interactive menu system"
        "${SCRIPT_DIR}/menu.sh"
        ;;
    help)
        show_help
        ;;
    *)
        log_error "Unknown command: $COMMAND"
        show_help
        exit 1
        ;;
esac
