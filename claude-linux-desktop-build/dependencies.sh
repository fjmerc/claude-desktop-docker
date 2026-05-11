#!/bin/bash
#
# Dependency checking for Claude Desktop build

# Package definitions for different distributions
DNF_PACKAGES="p7zip p7zip-plugins nodejs npm rust cargo electron ImageMagick icoutils rsync"
DEBIAN_PACKAGES="p7zip-full nodejs npm cargo rustc electron imagemagick icoutils rsync"

# NPM packages needed
NPM_PACKAGES="asar @napi-rs/cli"

# Check for required dependencies
check_dependencies() {
    local deps=("7za" "npm" "node" "cargo" "rustc" "electron" "wrestool" "icotool" "rsync")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing+=("$dep")
        fi
    done
    
    # Check for either magick or convert
    if ! check_image_command; then
        missing+=("ImageMagick")
    else
        log_info "Using ImageMagick command: $IMAGE_CMD"
    fi

    # Check Node.js version
    if command -v node >/dev/null 2>&1; then
        NODE_VERSION=$(node --version | cut -d 'v' -f 2)
        NODE_MAJOR=$(echo "$NODE_VERSION" | cut -d '.' -f 1)
        NODE_MINOR=$(echo "$NODE_VERSION" | cut -d '.' -f 2)
        
        if [ "$NODE_MAJOR" -lt 14 ]; then
            log_error "Node.js version $NODE_VERSION is not compatible. Version 14 or higher is required."
            exit $EXIT_DEPENDENCY_ERROR
        elif [ "$NODE_MAJOR" -eq 14 ] && [ "$NODE_MINOR" -lt 17 ]; then
            log_warning "Node.js version $NODE_VERSION detected. Version 14.17 or higher is recommended for best compatibility."
        fi
    else
        log_error "Node.js is not installed or not in PATH"
        exit $EXIT_DEPENDENCY_ERROR
    fi

    if [ ${#missing[@]} -ne 0 ]; then
        detect_package_manager
        log_error "Missing required dependencies: ${missing[*]}"
        log_info "Please install them using:"
        echo "${PKG_INSTALL} ${PACKAGES}"
        exit $EXIT_DEPENDENCY_ERROR
    fi

    # Check for NPM packages
    log_info "Checking for required NPM packages..."
    for pkg in $NPM_PACKAGES; do
        if ! npm list -g "$pkg" >/dev/null 2>&1; then
            log_info "Installing $pkg globally..."
            npm install -g "$pkg" || {
                log_error "Failed to install $pkg. Please run: sudo npm install -g $pkg"
                exit $EXIT_DEPENDENCY_ERROR
            }
        fi
    done
    
    # Verify asar is properly installed and working
    if ! asar --version >/dev/null 2>&1; then
        log_error "The asar package is installed but not working properly"
        exit $EXIT_DEPENDENCY_ERROR
    fi
}

# Export variables for other scripts
export DNF_PACKAGES DEBIAN_PACKAGES NPM_PACKAGES
export -f check_dependencies
