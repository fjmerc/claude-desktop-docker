#!/bin/bash
# Multi-architecture build script for Claude Desktop Docker
# This script builds and pushes Docker images for multiple architectures

set -e  # Exit on any error

# Source the logger
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
source "${SCRIPT_DIR}/dockerhub-logger.sh"

# Default options
VERSION="0.9.2"
PLATFORMS="linux/amd64,linux/arm64"
DOCKER_REPO="fjmerc/claude-desktop"
PUSH=false
LOAD=false
CACHE=true
BUILDX_DRIVER="docker-container"
BUILDX_PLATFORM_FLAGS=""
BUILDX_BUILDER="claude-desktop-builder"
NODE_VERSION="22.x"
PROGRESS="auto"
CLEAN=false
DRY_RUN=false
VERBOSE_BUILD=false

# Display help
show_help() {
    echo "Claude Desktop Docker - Multi-Architecture Build Script"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --version VER       Set version for the build (default: $VERSION)"
    echo "  --platforms PLAT    Comma-separated list of platforms (default: $PLATFORMS)"
    echo "  --repo REPO         Docker Hub repository (default: $DOCKER_REPO)"
    echo "  --push              Push images to Docker Hub"
    echo "  --load              Load image into local Docker (single platform only)"
    echo "  --no-cache          Disable build cache"
    echo "  --driver DRIVER     Buildx driver (default: $BUILDX_DRIVER)"
    echo "  --node-version VER  Node.js version (default: $NODE_VERSION)"
    echo "  --progress TYPE     Build progress type (auto, plain, tty) (default: $PROGRESS)"
    echo "  --clean             Clean up builder and context before building"
    echo "  --dry-run           Print commands without executing them"
    echo "  --verbose-build     Show detailed build logs in real-time"
    echo "  --log-level LEVEL   Set log level (DEBUG, INFO, WARN, ERROR, FATAL)"
    echo "  --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --version 0.9.2 --platforms linux/amd64,linux/arm64 --push"
    echo "  $0 --platforms linux/amd64 --load --no-cache"
    echo ""
}

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --version) VERSION="$2"; shift ;;
        --platforms) PLATFORMS="$2"; shift ;;
        --repo) DOCKER_REPO="$2"; shift ;;
        --push) PUSH=true ;;
        --load) LOAD=true ;;
        --no-cache) CACHE=false ;;
        --driver) BUILDX_DRIVER="$2"; shift ;;
        --node-version) NODE_VERSION="$2"; shift ;;
        --progress) PROGRESS="$2"; shift ;;
        --clean) CLEAN=true ;;
        --dry-run) DRY_RUN=true ;;
        --verbose-build) VERBOSE_BUILD=true ;;
        --log-level) export DOCKERHUB_LOG_LEVEL="$2"; shift ;;
        --help) show_help; exit 0 ;;
        *) echo "Unknown parameter: $1"; show_help; exit 1 ;;
    esac
    shift
done

# Validate options
if [[ "$LOAD" == "true" && "$PUSH" == "true" ]]; then
    log_error "Cannot use both --load and --push options together"
    exit 1
fi

if [[ "$LOAD" == "true" && "$PLATFORMS" == *","* ]]; then
    log_error "Cannot use --load with multiple platforms. Use a single platform or --push instead."
    exit 1
fi

# Set up build start time for duration calculation
BUILD_START_TIME=$(date +%s)

# Log build start
log_build_start "$VERSION" "$PLATFORMS"

# Function to check if a command exists
check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "Required command not found: $1"
        return 1
    fi
    return 0
}

# Function to check Docker and Buildx
check_docker_buildx() {
    # Check Docker
    if ! check_command docker; then
        log_fatal "Docker is required but not installed"
        exit 1
    fi
    
    # Check Docker Buildx
    if ! docker buildx version &> /dev/null; then
        log_error "Docker Buildx not available"
        log_info "Attempting to install Docker Buildx..."
        
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[DRY RUN] Would install Docker Buildx"
        else
            # Try to enable buildx
            docker_version=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "unknown")
            log_info "Docker version: $docker_version"
            
            # For Docker 19.03 or newer, buildx should be available as a plugin
            if docker info 2>/dev/null | grep -q "buildx: true"; then
                log_info "Buildx plugin is available but not initialized"
            else
                log_error "Buildx plugin not available. Please install Docker 19.03+ or install buildx manually."
                exit 1
            fi
        fi
    else
        log_info "Docker Buildx is available: $(docker buildx version)"
    fi
    
    return 0
}

# Function to set up buildx builder
setup_buildx_builder() {
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would set up buildx builder: $BUILDX_BUILDER"
        return 0
    fi
    
    # Check if the builder already exists
    if docker buildx inspect "$BUILDX_BUILDER" &> /dev/null; then
        if [[ "$CLEAN" == "true" ]]; then
            log_info "Removing existing builder: $BUILDX_BUILDER"
            docker buildx rm "$BUILDX_BUILDER"
        else
            log_info "Using existing builder: $BUILDX_BUILDER"
            docker buildx use "$BUILDX_BUILDER"
            return 0
        fi
    fi
    
    # Create a new builder
    log_info "Creating new buildx builder: $BUILDX_BUILDER"
    docker buildx create --name "$BUILDX_BUILDER" --driver "$BUILDX_DRIVER" --use
    
    # Bootstrap the builder
    log_info "Bootstrapping buildx builder"
    docker buildx inspect --bootstrap
    
    # List available platforms
    available_platforms=$(docker buildx inspect --bootstrap | grep "Platforms:" | cut -d':' -f2 | tr -d '[:space:]')
    log_info "Available platforms: $available_platforms"
    
    # Check if requested platforms are supported
    IFS=',' read -ra REQUESTED_PLATFORMS <<< "$PLATFORMS"
    for platform in "${REQUESTED_PLATFORMS[@]}"; do
        if [[ "$available_platforms" != *"$platform"* ]]; then
            log_warn "Platform $platform might not be supported by the current builder"
        fi
    done
    
    return 0
}

# Function to prepare build arguments
prepare_build_args() {
    BUILD_ARGS=(
        "--file" "${SCRIPT_DIR}/Dockerfile.dockerhub"
        "--build-arg" "VERSION=${VERSION}"
        "--build-arg" "NODE_VERSION=${NODE_VERSION}"
        "--progress" "${PROGRESS}"
    )
    
    # Add platform-specific flags
    if [[ -n "$PLATFORMS" ]]; then
        BUILD_ARGS+=("--platform" "$PLATFORMS")
    fi
    
    # Add cache flags
    if [[ "$CACHE" == "false" ]]; then
        BUILD_ARGS+=("--no-cache")
    fi
    
    # Add tags
    BUILD_ARGS+=("-t" "${DOCKER_REPO}:${VERSION}")
    BUILD_ARGS+=("-t" "${DOCKER_REPO}:latest")
    
    # Add output flags
    if [[ "$PUSH" == "true" ]]; then
        BUILD_ARGS+=("--push")
    elif [[ "$LOAD" == "true" ]]; then
        BUILD_ARGS+=("--load")
    else
        # Default to just building without pushing or loading
        BUILD_ARGS+=("--output" "type=image,push=false")
    fi
    
    log_debug "Build arguments: ${BUILD_ARGS[*]}"
    return 0
}

# Function to execute the build
execute_build() {
    # Prepare context directory (parent of this script)
    CONTEXT_DIR="$(dirname "$SCRIPT_DIR")"
    
    log_info "Building Claude Desktop Docker for platforms: $PLATFORMS"
    log_info "Build context: $CONTEXT_DIR"
    
    # Prepare build command
    BUILD_CMD="docker buildx build ${BUILD_ARGS[*]} \"$CONTEXT_DIR\""
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would execute: $BUILD_CMD"
        return 0
    fi
    
    # Execute the build with logging
    log_info "Starting build process..."
    
    if [[ "$VERBOSE_BUILD" == "true" ]]; then
        # Execute directly to show real-time output
        log_info "Showing detailed build logs in real-time..."
        
        # Create a temporary file for capturing output
        TEMP_LOG_FILE=$(mktemp)
        
        # Run the command and tee output to both terminal and temp file
        if ! eval "$BUILD_CMD" 2>&1 | tee "$TEMP_LOG_FILE"; then
            # Append the output to the log file
            cat "$TEMP_LOG_FILE" >> "$LOG_FILE"
            rm "$TEMP_LOG_FILE"
            
            log_error "Build failed"
            BUILD_END_TIME=$(date +%s)
            BUILD_DURATION=$((BUILD_END_TIME - BUILD_START_TIME))
            log_build_completion "failure" "$(format_duration $BUILD_DURATION)" "Build command failed"
            exit 1
        fi
        
        # Append the output to the log file
        cat "$TEMP_LOG_FILE" >> "$LOG_FILE"
        rm "$TEMP_LOG_FILE"
    else
        # Use log_exec to capture output
        if ! log_exec "$BUILD_CMD"; then
            log_error "Build failed"
            BUILD_END_TIME=$(date +%s)
            BUILD_DURATION=$((BUILD_END_TIME - BUILD_START_TIME))
            log_build_completion "failure" "$(format_duration $BUILD_DURATION)" "Build command failed"
            exit 1
        fi
    fi
    
    log_info "Build completed successfully"
    return 0
}

# Function to format duration in human-readable format
format_duration() {
    local seconds=$1
    local minutes=$((seconds / 60))
    local hours=$((minutes / 60))
    local days=$((hours / 24))
    local rem_hours=$((hours - days * 24))
    local rem_minutes=$((minutes - hours * 60))
    local rem_seconds=$((seconds - minutes * 60))
    
    if [[ $days -gt 0 ]]; then
        echo "${days}d ${rem_hours}h ${rem_minutes}m ${rem_seconds}s"
    elif [[ $hours -gt 0 ]]; then
        echo "${hours}h ${rem_minutes}m ${rem_seconds}s"
    elif [[ $minutes -gt 0 ]]; then
        echo "${minutes}m ${rem_seconds}s"
    else
        echo "${seconds}s"
    fi
}

# Main execution
main() {
    # Check requirements
    check_docker_buildx
    
    # Set up buildx builder
    setup_buildx_builder
    
    # Prepare build arguments
    prepare_build_args
    
    # Execute the build
    execute_build
    
    # Calculate build duration
    BUILD_END_TIME=$(date +%s)
    BUILD_DURATION=$((BUILD_END_TIME - BUILD_START_TIME))
    
    # Log completion
    if [[ "$PUSH" == "true" ]]; then
        log_info "Images pushed to Docker Hub: ${DOCKER_REPO}:${VERSION} and ${DOCKER_REPO}:latest"
    elif [[ "$LOAD" == "true" ]]; then
        log_info "Image loaded into local Docker: ${DOCKER_REPO}:${VERSION} and ${DOCKER_REPO}:latest"
    else
        log_info "Images built but not pushed or loaded"
    fi
    
    log_build_completion "success" "$(format_duration $BUILD_DURATION)"
    
    # Print summary
    echo ""
    echo "=============================================="
    echo "Build Summary:"
    echo "- Version: $VERSION"
    echo "- Platforms: $PLATFORMS"
    echo "- Repository: $DOCKER_REPO"
    echo "- Duration: $(format_duration $BUILD_DURATION)"
    if [[ "$PUSH" == "true" ]]; then
        echo "- Images pushed to Docker Hub"
    elif [[ "$LOAD" == "true" ]]; then
        echo "- Image loaded into local Docker"
    else
        echo "- Images built but not pushed or loaded"
    fi
    echo "=============================================="
    
    return 0
}

# Run the main function
main
