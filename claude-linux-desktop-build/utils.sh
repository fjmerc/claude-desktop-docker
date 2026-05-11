#!/bin/bash
#
# Utility functions for Claude Desktop build scripts

# Logging functions
log_info() {
    echo -e "\033[0;32m[INFO]\033[0m $1"
}

log_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1" >&2
}

log_warning() {
    echo -e "\033[0;33m[WARNING]\033[0m $1"
}

log_build_path() {
    echo -e "\033[0;34m[PATH]\033[0m Build files will be stored in: $BUILD_ROOT"
    echo -e "\033[0;34m[PATH]\033[0m These files will persist across system reboots"
    echo -e "\033[0;34m[PATH]\033[0m Application will be installed to: $APP_INSTALL_DIR"
}

# Error handling
handle_error() {
    local exit_code=${2:-1}
    log_error "An error occurred on line $1"
    exit $exit_code
}

# Verify file exists
verify_file_exists() {
    if [ ! -f "$1" ]; then
        log_error "Required file not found: $1"
        return 1
    fi
    return 0
}

# Verify directory exists
verify_dir_exists() {
    if [ ! -d "$1" ]; then
        log_error "Required directory not found: $1"
        return 1
    fi
    return 0
}

# Detect package manager and set appropriate commands/packages
detect_package_manager() {
    if command -v dnf >/dev/null 2>&1; then
        log_info "DNF-based system detected"
        PKG_MANAGER="dnf"
        PKG_INSTALL="sudo dnf install -y"
        PACKAGES="$DNF_PACKAGES"
    elif command -v apt-get >/dev/null 2>&1; then
        log_info "Debian-based system detected"
        PKG_MANAGER="apt"
        PKG_INSTALL="sudo apt-get install -y"
        PACKAGES="$DEBIAN_PACKAGES"
    else
        log_error "Unsupported package manager. This script supports dnf and apt (Debian/Ubuntu)"
        exit 1
    fi
}

# Check for the correct ImageMagick command
check_image_command() {
    if command -v magick >/dev/null 2>&1; then
        IMAGE_CMD="magick"
        return 0
    elif command -v convert >/dev/null 2>&1; then
        IMAGE_CMD="convert"
        return 0
    else
        IMAGE_CMD=""
        return 1
    fi
}

# Set trap for error handling
trap 'handle_error $LINENO' ERR

# Export variables for other scripts
export -f log_info log_error log_warning log_build_path handle_error
export -f verify_file_exists verify_dir_exists
export -f detect_package_manager check_image_command
