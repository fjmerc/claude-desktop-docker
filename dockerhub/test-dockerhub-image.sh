#!/bin/bash
# Test script for Docker Hub images
# This script pulls and runs the Docker Hub image locally for testing

set -e  # Exit on any error

# Compose v1/v2 compat: define a docker-compose shell function only if the
# standalone v1 binary isn't present, forwarding to the `docker compose` plugin.
command -v docker-compose >/dev/null 2>&1 || docker-compose() { docker compose "$@"; }

# Source the logger
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
source "${SCRIPT_DIR}/dockerhub-logger.sh"

# Default options
DOCKER_REPO="fjmerc/claude-desktop"
IMAGE_TAG="latest"
PULL=true
CLEAN=false
DETACH=true

# Display help
show_help() {
    echo "Claude Desktop Docker - Docker Hub Image Test Script"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --repo REPO        Docker repository (default: $DOCKER_REPO)"
    echo "  --tag TAG          Image tag to test (default: $IMAGE_TAG)"
    echo "  --no-pull          Don't pull the image before testing"
    echo "  --clean            Remove existing containers before testing"
    echo "  --foreground       Run in foreground (don't detach)"
    echo "  --log-level LEVEL  Set log level (DEBUG, INFO, WARN, ERROR, FATAL)"
    echo "  --help             Show this help message"
    echo ""
}

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --repo) DOCKER_REPO="$2"; shift ;;
        --tag) IMAGE_TAG="$2"; shift ;;
        --no-pull) PULL=false ;;
        --clean) CLEAN=true ;;
        --foreground) DETACH=false ;;
        --log-level) export DOCKERHUB_LOG_LEVEL="$2"; shift ;;
        --help) show_help; exit 0 ;;
        *) echo "Unknown parameter: $1"; show_help; exit 1 ;;
    esac
    shift
done

# Log start
log_info "=== Docker Hub Image Test ==="
log_info "Testing image: ${DOCKER_REPO}:${IMAGE_TAG}"

# Function to check if a container exists
container_exists() {
    docker ps -a --format '{{.Names}}' | grep -q "^claude-desktop$"
    return $?
}

# Function to check if a container is running
container_running() {
    docker ps --format '{{.Names}}' | grep -q "^claude-desktop$"
    return $?
}

# Clean up if requested
if [[ "$CLEAN" == "true" ]]; then
    log_info "Cleaning up existing containers..."
    
    if container_running; then
        log_info "Stopping running container..."
        docker stop claude-desktop
    fi
    
    if container_exists; then
        log_info "Removing existing container..."
        docker rm claude-desktop
    fi
fi

# Pull the image if requested
if [[ "$PULL" == "true" ]]; then
    log_info "Pulling image: ${DOCKER_REPO}:${IMAGE_TAG}"
    docker pull "${DOCKER_REPO}:${IMAGE_TAG}"
fi

# Check if container already exists
if container_exists; then
    if container_running; then
        log_info "Container is already running"
        log_info "Access it via:"
        log_info "- VNC: localhost:5901 (password: claude_desktop)"
        log_info "- Web: http://localhost:6080/"
        exit 0
    else
        log_info "Starting existing container..."
        docker start claude-desktop
    fi
else
    log_info "Creating and starting container..."
    
    # Use docker-compose.dockerhub.yml
    COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.dockerhub.yml"
    
    if [[ ! -f "$COMPOSE_FILE" ]]; then
        log_error "Compose file not found: $COMPOSE_FILE"
        exit 1
    fi
    
    # Set the environment variables for docker-compose
    export CLAUDE_DESKTOP_REPO="$DOCKER_REPO"
    export CLAUDE_DESKTOP_IMAGE_TAG="$IMAGE_TAG"
    
    # Start the container
    if [[ "$DETACH" == "true" ]]; then
        docker-compose -f "$COMPOSE_FILE" up -d
    else
        docker-compose -f "$COMPOSE_FILE" up
    fi
fi

# Wait for container to be healthy
if [[ "$DETACH" == "true" ]]; then
    log_info "Waiting for container to be ready..."
    
    # Wait for VNC port to be available
    for i in {1..30}; do
        if nc -z localhost 5901 &>/dev/null; then
            log_info "VNC port is available"
            break
        fi
        
        if [[ $i -eq 30 ]]; then
            log_warn "Timed out waiting for VNC port"
        fi
        
        sleep 1
    done
    
    # Wait for web port to be available
    for i in {1..30}; do
        if nc -z localhost 6080 &>/dev/null; then
            log_info "Web port is available"
            break
        fi
        
        if [[ $i -eq 30 ]]; then
            log_warn "Timed out waiting for web port"
        fi
        
        sleep 1
    done
    
    # Check container health
    health_status=$(docker inspect --format='{{.State.Health.Status}}' claude-desktop 2>/dev/null || echo "unknown")
    log_info "Container health status: $health_status"
    
    # Print access information
    log_info "=============================================="
    log_info "Container is running!"
    log_info "Access Claude Desktop via:"
    log_info "- VNC client at localhost:5901 (password: claude_desktop)"
    log_info "- Web browser at http://localhost:6080/"
    log_info "=============================================="
    
    # Print logs
    log_info "Container logs:"
    docker logs claude-desktop --tail 20
fi
