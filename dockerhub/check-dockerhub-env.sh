#!/bin/bash
# Environment checker for Docker Hub builds
# This script verifies that all prerequisites for Docker Hub builds are met

set -e  # Exit on any error

# Source the logger
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
source "${SCRIPT_DIR}/dockerhub-logger.sh"

# Default options
VERBOSE=false
FIX_ISSUES=false
REQUIRED_PACKAGES=(
    "docker"
    "curl"
    "jq"
)

# Display help
show_help() {
    echo "Claude Desktop Docker - Docker Hub Environment Checker"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --verbose           Show detailed output"
    echo "  --fix               Attempt to fix issues automatically"
    echo "  --log-level LEVEL   Set log level (DEBUG, INFO, WARN, ERROR, FATAL)"
    echo "  --help              Show this help message"
    echo ""
}

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --verbose) VERBOSE=true ;;
        --fix) FIX_ISSUES=true ;;
        --log-level) export DOCKERHUB_LOG_LEVEL="$2"; shift ;;
        --help) show_help; exit 0 ;;
        *) echo "Unknown parameter: $1"; show_help; exit 1 ;;
    esac
    shift
done

# Log start
log_info "=== Docker Hub Environment Check ==="
log_info "Checking system prerequisites for Docker Hub builds"

# Function to check if a command exists
check_command() {
    local cmd="$1"
    local package="$2"
    local fix_cmd="$3"
    
    if command -v "$cmd" &> /dev/null; then
        if [[ "$VERBOSE" == "true" ]]; then
            log_info "✅ $cmd is installed: $(command -v "$cmd")"
            if [[ "$cmd" == "docker" ]]; then
                log_info "   Docker version: $(docker --version)"
            fi
        else
            log_info "✅ $cmd is installed"
        fi
        return 0
    else
        log_error "❌ $cmd is not installed"
        if [[ -n "$package" && "$FIX_ISSUES" == "true" ]]; then
            log_info "Attempting to install $package..."
            if [[ -n "$fix_cmd" ]]; then
                log_exec "$fix_cmd"
                if command -v "$cmd" &> /dev/null; then
                    log_info "✅ Successfully installed $cmd"
                    return 0
                else
                    log_error "❌ Failed to install $cmd"
                    return 1
                fi
            else
                log_warn "No installation command provided for $package"
                return 1
            fi
        fi
        return 1
    fi
}

# Function to check Docker Buildx
check_buildx() {
    if docker buildx version &> /dev/null; then
        if [[ "$VERBOSE" == "true" ]]; then
            log_info "✅ Docker Buildx is installed: $(docker buildx version)"
        else
            log_info "✅ Docker Buildx is installed"
        fi
        
        # Check available platforms
        local available_platforms=$(docker buildx inspect --bootstrap 2>/dev/null | grep "Platforms:" | cut -d':' -f2 | tr -d '[:space:]' || echo "")
        if [[ -n "$available_platforms" ]]; then
            log_info "   Available platforms: $available_platforms"
            
            # Check for amd64 and arm64
            local has_amd64=false
            local has_arm64=false
            
            if [[ "$available_platforms" == *"linux/amd64"* ]]; then
                has_amd64=true
            fi
            
            if [[ "$available_platforms" == *"linux/arm64"* ]]; then
                has_arm64=true
            fi
            
            if [[ "$has_amd64" == "true" && "$has_arm64" == "true" ]]; then
                log_info "✅ Both amd64 and arm64 platforms are supported"
            else
                if [[ "$has_amd64" == "false" ]]; then
                    log_warn "⚠️ linux/amd64 platform is not supported"
                fi
                if [[ "$has_arm64" == "false" ]]; then
                    log_warn "⚠️ linux/arm64 platform is not supported"
                fi
                
                if [[ "$FIX_ISSUES" == "true" ]]; then
                    log_info "Attempting to set up QEMU for multi-architecture support..."
                    log_exec "docker run --privileged --rm tonistiigi/binfmt --install all"
                    
                    # Check again
                    available_platforms=$(docker buildx inspect --bootstrap 2>/dev/null | grep "Platforms:" | cut -d':' -f2 | tr -d '[:space:]' || echo "")
                    log_info "   Updated available platforms: $available_platforms"
                fi
            fi
        else
            log_warn "⚠️ Could not determine available platforms"
        fi
        
        return 0
    else
        log_error "❌ Docker Buildx is not installed"
        
        if [[ "$FIX_ISSUES" == "true" ]]; then
            log_info "Attempting to enable Docker Buildx..."
            
            # For Docker 19.03 or newer, buildx should be available as a plugin
            if docker info 2>/dev/null | grep -q "buildx: true"; then
                log_info "Buildx plugin is available but not initialized"
                log_exec "docker buildx create --name claude-desktop-builder --use"
                
                if docker buildx version &> /dev/null; then
                    log_info "✅ Successfully enabled Docker Buildx"
                    return 0
                else
                    log_error "❌ Failed to enable Docker Buildx"
                    return 1
                fi
            else
                log_error "Buildx plugin not available. Please install Docker 19.03+ or install buildx manually."
                return 1
            fi
        fi
        
        return 1
    fi
}

# Function to check Docker Hub credentials
check_docker_hub_credentials() {
    if docker info 2>/dev/null | grep -q "Username:"; then
        log_info "✅ Docker Hub credentials are configured"
        
        if [[ "$VERBOSE" == "true" ]]; then
            local username=$(docker info 2>/dev/null | grep "Username:" | cut -d':' -f2 | tr -d '[:space:]')
            log_info "   Docker Hub username: $username"
        fi
        
        return 0
    else
        log_warn "⚠️ Docker Hub credentials are not configured"
        log_info "   You will need to run 'docker login' before pushing images to Docker Hub"
        
        if [[ "$FIX_ISSUES" == "true" ]]; then
            log_info "Please enter your Docker Hub credentials:"
            log_exec "docker login"
            
            if docker info 2>/dev/null | grep -q "Username:"; then
                log_info "✅ Successfully logged in to Docker Hub"
                return 0
            else
                log_warn "⚠️ Failed to log in to Docker Hub"
                return 1
            fi
        fi
        
        return 1
    fi
}

# Function to check system resources
check_system_resources() {
    log_info "=== System Resources ==="
    
    # Check CPU
    local cpu_cores=$(nproc)
    log_info "CPU cores: $cpu_cores"
    if [[ $cpu_cores -lt 2 ]]; then
        log_warn "⚠️ Low CPU core count. Multi-architecture builds may be slow."
    fi
    
    # Check memory
    local mem_total=$(free -m | awk '/^Mem:/{print $2}')
    log_info "Memory: ${mem_total}MB"
    if [[ $mem_total -lt 4000 ]]; then
        log_warn "⚠️ Low memory. Multi-architecture builds may fail or be very slow."
        log_info "   Recommended: At least 4GB of RAM"
    fi
    
    # Check disk space
    local disk_free=$(df -h / | awk 'NR==2 {print $4}')
    local disk_free_bytes=$(df / | awk 'NR==2 {print $4}')
    log_info "Free disk space: $disk_free"
    if [[ $disk_free_bytes -lt 10000000 ]]; then  # Less than 10GB
        log_warn "⚠️ Low disk space. Multi-architecture builds require significant space."
        log_info "   Recommended: At least 10GB of free space"
    fi
    
    return 0
}

# Function to check Docker configuration
check_docker_config() {
    log_info "=== Docker Configuration ==="
    
    # Check if Docker daemon is running
    if systemctl is-active --quiet docker 2>/dev/null || pgrep -f docker > /dev/null; then
        log_info "✅ Docker daemon is running"
    else
        log_error "❌ Docker daemon is not running"
        
        if [[ "$FIX_ISSUES" == "true" ]]; then
            log_info "Attempting to start Docker daemon..."
            if systemctl start docker 2>/dev/null; then
                log_info "✅ Successfully started Docker daemon"
            else
                log_error "❌ Failed to start Docker daemon"
                return 1
            fi
        else
            return 1
        fi
    fi
    
    # Check Docker storage driver
    local storage_driver=$(docker info 2>/dev/null | grep "Storage Driver:" | cut -d':' -f2 | tr -d '[:space:]')
    log_info "Storage driver: $storage_driver"
    
    # Check experimental features
    if docker info 2>/dev/null | grep -q "Experimental: true"; then
        log_info "✅ Docker experimental features are enabled"
    else
        log_warn "⚠️ Docker experimental features are not enabled"
        log_info "   Some multi-architecture features may require experimental mode"
        
        if [[ "$FIX_ISSUES" == "true" ]]; then
            log_info "Attempting to enable Docker experimental features..."
            
            # Create or update daemon.json
            local daemon_json="/etc/docker/daemon.json"
            if [[ -f "$daemon_json" ]]; then
                # Update existing file
                log_exec "sudo cp $daemon_json ${daemon_json}.bak"
                log_exec "sudo jq '. + {\"experimental\": true}' ${daemon_json}.bak | sudo tee $daemon_json > /dev/null"
            else
                # Create new file
                log_exec "echo '{\"experimental\": true}' | sudo tee $daemon_json > /dev/null"
            fi
            
            # Restart Docker daemon
            log_exec "sudo systemctl restart docker"
            
            # Check again
            if docker info 2>/dev/null | grep -q "Experimental: true"; then
                log_info "✅ Successfully enabled Docker experimental features"
            else
                log_warn "⚠️ Failed to enable Docker experimental features"
            fi
        fi
    fi
    
    return 0
}

# Main function
main() {
    local all_checks_passed=true
    
    # Check required packages
    log_info "=== Required Packages ==="
    for package in "${REQUIRED_PACKAGES[@]}"; do
        if ! check_command "$package" "$package" "apt-get update && apt-get install -y $package"; then
            all_checks_passed=false
        fi
    done
    
    # Check Docker Buildx
    log_info "=== Docker Buildx ==="
    if ! check_buildx; then
        all_checks_passed=false
    fi
    
    # Check Docker Hub credentials
    log_info "=== Docker Hub Credentials ==="
    check_docker_hub_credentials
    
    # Check system resources
    check_system_resources
    
    # Check Docker configuration
    check_docker_config
    
    # Summary
    echo ""
    if [[ "$all_checks_passed" == "true" ]]; then
        log_info "=============================================="
        log_info "✅ All essential checks passed!"
        log_info "Your system is ready for Docker Hub multi-architecture builds."
        log_info "=============================================="
        return 0
    else
        log_warn "=============================================="
        log_warn "⚠️ Some checks failed."
        log_warn "Please address the issues above before proceeding with Docker Hub builds."
        log_warn "Run with --fix to attempt automatic fixes."
        log_warn "=============================================="
        return 1
    fi
}

# Run the main function
main
