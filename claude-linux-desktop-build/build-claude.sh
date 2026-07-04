#!/bin/bash
#
# Main build script for Claude Desktop on Linux
# This script coordinates the modular build process
#
# Usage: ./build-claude.sh

# Set strict mode
set -euo pipefail

# Base directory for all the scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
CLAUDE_VERSION="0.14.10"
CLAUDE_URL="https://storage.googleapis.com/osprey-downloads-c02f6a0d-347c-492b-a752-3e0651722e97/nest-win-x64/Claude-Setup-x64.exe"
# Pinned hash of the upstream installer for v0.14.10 (last-modified 2025-10-29).
# build-module.sh verifies this before extraction. To bump CLAUDE_VERSION,
# update the URL if needed, run a build with CLAUDE_SHA256= unset to print
# the new hash, and replace this constant.
CLAUDE_SHA256="4a7fe5bcc95f29dedbfeeb45bc2c6b916343253ba0e0e392038968f5857c6aa9"

# Allow overriding build directory via environment variable
BUILD_ROOT="${BUILD_ROOT:-$HOME/.cache/claude-desktop-build}"
CLAUDE_DIR="${BUILD_ROOT}/claude-desktop-builder"
WORK_DIR="${CLAUDE_DIR}/build"
OUTPUT_DIR="${CLAUDE_DIR}/output"
DOWNLOAD_DIR="${CLAUDE_DIR}/downloads"

# Final application directory in user's home
APP_INSTALL_DIR="${APP_INSTALL_DIR:-$HOME/claude-app}"


# Create build directories
mkdir -p "$BUILD_ROOT"
mkdir -p "$APP_INSTALL_DIR"

# Exit codes
EXIT_DEPENDENCY_ERROR=1
EXIT_DOWNLOAD_ERROR=2
EXIT_EXTRACTION_ERROR=3
EXIT_BUILD_ERROR=4
EXIT_FILE_NOT_FOUND=5

# Source the utilities and components
source "${SCRIPT_DIR}/utils.sh"
source "${SCRIPT_DIR}/dependencies.sh"
source "${SCRIPT_DIR}/build-module.sh"
source "${SCRIPT_DIR}/packaging.sh"

# Main execution
main() {
    log_info "Building Claude Desktop v$CLAUDE_VERSION for Linux..."
    log_build_path
    
    # Create build directory
    mkdir -p "$CLAUDE_DIR"
    
    # Check dependencies
    check_dependencies
    
    # Create clean build environment
    log_info "Setting up build environment..."
    rm -rf "$OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR"
    mkdir -p "$DOWNLOAD_DIR"
    
    # Track start time
    BUILD_START_TIME=$(date +%s)
    
    log_info "Step 1/7: Setting up native module..."
    setup_patchy_cnb
    
    log_info "Step 2/7: Downloading and extracting Claude Desktop..."
    download_and_extract
    
    log_info "Step 3/7: Processing icons..."
    process_icons
    
    log_info "Step 4/7: Processing application files..."
    process_asar
    
    log_info "Step 5/7: Creating desktop entry..."
    create_desktop_entry
    
    log_info "Step 6/7: Creating launcher script..."
    create_launcher
    
    log_info "Step 7/7: Creating installation package..."
    create_package
    
    # Calculate build time
    BUILD_END_TIME=$(date +%s)
    BUILD_DURATION=$((BUILD_END_TIME - BUILD_START_TIME))
    BUILD_MINUTES=$((BUILD_DURATION / 60))
    BUILD_SECONDS=$((BUILD_DURATION % 60))
    
    # Display installation instructions
    create_install_instructions
    
    log_info "Build completed successfully in ${BUILD_MINUTES}m ${BUILD_SECONDS}s!"
    log_info "All build files are contained in: $CLAUDE_DIR"
    log_info "Package: ${CLAUDE_DIR}/claude-desktop-linux-v${CLAUDE_VERSION}.tar.gz"
}

# Export variables for other scripts
export CLAUDE_VERSION CLAUDE_URL CLAUDE_SHA256
export CLAUDE_DIR WORK_DIR OUTPUT_DIR DOWNLOAD_DIR APP_INSTALL_DIR
export EXIT_DEPENDENCY_ERROR EXIT_DOWNLOAD_ERROR EXIT_EXTRACTION_ERROR EXIT_BUILD_ERROR EXIT_FILE_NOT_FOUND

# Run the script
main "$@"
