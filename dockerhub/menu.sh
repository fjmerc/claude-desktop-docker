#!/bin/bash
# Interactive menu for Claude Desktop Docker Hub operations
# This script provides a user-friendly interface to the Docker Hub build system

set -e  # Exit on any error

# The directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Source the logger if available
if [[ -f "${SCRIPT_DIR}/dockerhub-logger.sh" ]]; then
    source "${SCRIPT_DIR}/dockerhub-logger.sh"
else
    # Fallback logging functions if logger script is not available
    log_info() { echo -e "\033[32m[INFO] $1\033[0m"; }
    log_error() { echo -e "\033[31m[ERROR] $1\033[0m"; }
    log_warn() { echo -e "\033[33m[WARN] $1\033[0m"; }
fi

# Make sure all scripts are executable
chmod +x "${SCRIPT_DIR}"/*.sh 2>/dev/null || true

# Default configuration
DEFAULT_DOCKER_REPO="fjmerc/claude-desktop"
DEFAULT_VERSION="0.14.10"

# User configuration (can be overridden)
DOCKER_REPO="${DEFAULT_DOCKER_REPO}"
VERSION="${DEFAULT_VERSION}"

# Function to set custom repository
set_custom_repository() {
    read -p "Enter Docker repository (e.g., username/repo-name): " repo
    if [[ -n "$repo" ]]; then
        DOCKER_REPO="$repo"
        log_info "Repository set to: $DOCKER_REPO"
    else
        log_warn "Repository not changed, using: $DOCKER_REPO"
    fi
}

# Function to set custom version
set_custom_version() {
    read -p "Enter version (e.g., 1.0.0): " ver
    if [[ -n "$ver" ]]; then
        VERSION="$ver"
        log_info "Version set to: $VERSION"
    else
        log_warn "Version not changed, using: $VERSION"
    fi
}

# Function to show current configuration
show_current_config() {
    echo ""
    echo "Current Configuration:"
    echo "- Repository: $DOCKER_REPO"
    echo "- Version: $VERSION"
    echo ""
}

# Function to display the main menu
show_main_menu() {
    clear
    echo "=============================================="
    echo "    CLAUDE DESKTOP DOCKER HUB MENU SYSTEM    "
    echo "=============================================="
    echo ""
    echo "Please select an operation:"
    echo ""
    echo "1) Environment Check"
    echo "2) Build Operations"
    echo "3) Testing Operations"
    echo "4) Docker Hub Operations"
    echo "5) Help & Documentation"
    echo ""
    echo "q) Quit"
    echo ""
    echo "=============================================="
    echo -n "Enter your choice [1-5 or q]: "
}

# Function to display the environment check menu
show_environment_menu() {
    clear
    echo "=============================================="
    echo "    ENVIRONMENT CHECK OPERATIONS    "
    echo "=============================================="
    echo ""
    echo "Please select an operation:"
    echo ""
    echo "1) Basic environment check"
    echo "2) Detailed environment check (verbose)"
    echo "3) Fix environment issues automatically"
    echo ""
    echo "b) Back to main menu"
    echo "q) Quit"
    echo ""
    echo "=============================================="
    echo -n "Enter your choice [1-3, b or q]: "
}

# Function to display the build operations menu
show_build_menu() {
    clear
    echo "=============================================="
    echo "    BUILD OPERATIONS    "
    echo "=============================================="
    echo ""
    show_current_config
    echo "Please select an operation:"
    echo ""
    echo "1) Build for AMD64 architecture"
    echo "2) Build for ARM64 architecture"
    echo "3) Build for both architectures"
    echo "4) Build with no cache (clean build)"
    echo "5) Build and load into local Docker (single arch only)"
    echo "6) Set custom repository"
    echo "7) Set custom version"
    echo ""
    echo "b) Back to main menu"
    echo "q) Quit"
    echo ""
    echo "=============================================="
    echo -n "Enter your choice [1-7, b or q]: "
}

# Function to display the testing operations menu
show_testing_menu() {
    clear
    echo "=============================================="
    echo "    TESTING OPERATIONS    "
    echo "=============================================="
    echo ""
    show_current_config
    echo "Please select an operation:"
    echo ""
    echo "1) Test latest image"
    echo "2) Test specific version"
    echo "3) Test with clean environment"
    echo "4) Test in foreground mode"
    echo "5) Set custom repository"
    echo "6) Set custom version"
    echo ""
    echo "b) Back to main menu"
    echo "q) Quit"
    echo ""
    echo "=============================================="
    echo -n "Enter your choice [1-6, b or q]: "
}

# Function to display the Docker Hub operations menu
show_dockerhub_menu() {
    clear
    echo "=============================================="
    echo "    DOCKER HUB OPERATIONS    "
    echo "=============================================="
    echo ""
    show_current_config
    echo "Please select an operation:"
    echo ""
    echo "1) Push to Docker Hub (AMD64 only)"
    echo "2) Push to Docker Hub (ARM64 only)"
    echo "3) Push to Docker Hub (both architectures)"
    echo "4) Set custom version and push"
    echo "5) Set custom repository"
    echo "6) Set custom version"
    echo "7) Reset to default configuration"
    echo ""
    echo "b) Back to main menu"
    echo "q) Quit"
    echo ""
    echo "=============================================="
    echo -n "Enter your choice [1-7, b or q]: "
}

# Function to display the help menu
show_help_menu() {
    clear
    echo "=============================================="
    echo "    HELP & DOCUMENTATION    "
    echo "=============================================="
    echo ""
    echo "Please select a topic:"
    echo ""
    echo "1) Show command-line options"
    echo "2) View README"
    echo "3) View Docker Hub documentation"
    echo "4) Show GitHub workflow example"
    echo ""
    echo "b) Back to main menu"
    echo "q) Quit"
    echo ""
    echo "=============================================="
    echo -n "Enter your choice [1-4, b or q]: "
}

# Function to handle environment check operations
handle_environment_check() {
    local choice=$1
    
    case $choice in
        1)
            log_info "Running basic environment check..."
            "${SCRIPT_DIR}/check-dockerhub-env.sh"
            ;;
        2)
            log_info "Running detailed environment check..."
            "${SCRIPT_DIR}/check-dockerhub-env.sh" --verbose
            ;;
        3)
            log_info "Fixing environment issues..."
            "${SCRIPT_DIR}/check-dockerhub-env.sh" --fix --verbose
            ;;
        *)
            log_error "Invalid choice: $choice"
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
}

# Function to handle build operations
handle_build_operations() {
    local choice=$1
    
    case $choice in
        1)
            log_info "Building for AMD64 architecture..."
            "${PROJECT_DIR}/claude.sh" dockerhub build --platforms linux/amd64 --repo "${DOCKER_REPO}" --version "${VERSION}"
            ;;
        2)
            log_info "Building for ARM64 architecture..."
            "${PROJECT_DIR}/claude.sh" dockerhub build --platforms linux/arm64 --repo "${DOCKER_REPO}" --version "${VERSION}"
            ;;
        3)
            log_info "Building for both architectures..."
            "${PROJECT_DIR}/claude.sh" dockerhub build --platforms linux/amd64,linux/arm64 --repo "${DOCKER_REPO}" --version "${VERSION}"
            ;;
        4)
            log_info "Building with no cache (clean build)..."
            "${PROJECT_DIR}/claude.sh" dockerhub build --no-cache --repo "${DOCKER_REPO}" --version "${VERSION}"
            ;;
        5)
            log_info "Building and loading into local Docker..."
            read -p "Enter architecture (amd64 or arm64): " arch
            if [[ "$arch" == "amd64" || "$arch" == "arm64" ]]; then
                "${PROJECT_DIR}/claude.sh" dockerhub build --platforms linux/$arch --load --repo "${DOCKER_REPO}" --version "${VERSION}"
            else
                log_error "Invalid architecture: $arch. Must be amd64 or arm64."
            fi
            ;;
        *)
            log_error "Invalid choice: $choice"
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
}

# Function to handle testing operations
handle_testing_operations() {
    local choice=$1
    
    case $choice in
        1)
            log_info "Testing latest image..."
            "${SCRIPT_DIR}/test-dockerhub-image.sh" --repo "${DOCKER_REPO}"
            ;;
        2)
            log_info "Testing specific version..."
            read -p "Enter version to test: " test_version
            "${SCRIPT_DIR}/test-dockerhub-image.sh" --repo "${DOCKER_REPO}" --tag "${test_version:-$VERSION}"
            ;;
        3)
            log_info "Testing with clean environment..."
            "${SCRIPT_DIR}/test-dockerhub-image.sh" --repo "${DOCKER_REPO}" --clean
            ;;
        4)
            log_info "Testing in foreground mode..."
            "${SCRIPT_DIR}/test-dockerhub-image.sh" --repo "${DOCKER_REPO}" --foreground
            ;;
        *)
            log_error "Invalid choice: $choice"
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
}

# Function to handle Docker Hub operations
handle_dockerhub_operations() {
    local choice=$1
    
    case $choice in
        1)
            log_info "Pushing to Docker Hub (AMD64 only)..."
            "${PROJECT_DIR}/claude.sh" dockerhub push --platforms linux/amd64 --repo "${DOCKER_REPO}" --version "${VERSION}"
            ;;
        2)
            log_info "Pushing to Docker Hub (ARM64 only)..."
            "${PROJECT_DIR}/claude.sh" dockerhub push --platforms linux/arm64 --repo "${DOCKER_REPO}" --version "${VERSION}"
            ;;
        3)
            log_info "Pushing to Docker Hub (both architectures)..."
            "${PROJECT_DIR}/claude.sh" dockerhub push --platforms linux/amd64,linux/arm64 --repo "${DOCKER_REPO}" --version "${VERSION}"
            ;;
        4)
            log_info "Setting custom version and pushing..."
            set_custom_version
            "${PROJECT_DIR}/claude.sh" dockerhub push --repo "${DOCKER_REPO}" --version "${VERSION}"
            ;;
        5)
            log_info "Setting custom repository..."
            set_custom_repository
            ;;
        6)
            log_info "Setting custom version..."
            set_custom_version
            ;;
        7)
            log_info "Resetting to default configuration..."
            DOCKER_REPO="${DEFAULT_DOCKER_REPO}"
            VERSION="${DEFAULT_VERSION}"
            log_info "Configuration reset to defaults"
            ;;
        *)
            log_error "Invalid choice: $choice"
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
}

# Function to handle help operations
handle_help_operations() {
    local choice=$1
    
    case $choice in
        1)
            log_info "Showing command-line options..."
            "${PROJECT_DIR}/claude.sh" dockerhub help
            ;;
        2)
            log_info "Viewing README..."
            if command -v less &> /dev/null; then
                less "${SCRIPT_DIR}/README.md"
            else
                cat "${SCRIPT_DIR}/README.md"
            fi
            ;;
        3)
            log_info "Viewing Docker Hub documentation..."
            if command -v less &> /dev/null; then
                less "${SCRIPT_DIR}/DOCKERHUB.md"
            else
                cat "${SCRIPT_DIR}/DOCKERHUB.md"
            fi
            ;;
        4)
            log_info "Showing GitHub workflow example..."
            if command -v less &> /dev/null; then
                less "${SCRIPT_DIR}/github-workflow-example.yml"
            else
                cat "${SCRIPT_DIR}/github-workflow-example.yml"
            fi
            ;;
        *)
            log_error "Invalid choice: $choice"
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
}

# Main menu loop
while true; do
    show_main_menu
    read -r choice
    
    case $choice in
        1)
            while true; do
                show_environment_menu
                read -r subchoice
                
                case $subchoice in
                    [1-3]) handle_environment_check "$subchoice" ;;
                    b|B) break ;;
                    q|Q) exit 0 ;;
                    *) log_error "Invalid choice: $subchoice" ;;
                esac
            done
            ;;
        2)
            while true; do
                show_build_menu
                read -r subchoice
                
                case $subchoice in
                    [1-5]) handle_build_operations "$subchoice" ;;
                    6) set_custom_repository ;;
                    7) set_custom_version ;;
                    b|B) break ;;
                    q|Q) exit 0 ;;
                    *) log_error "Invalid choice: $subchoice" ;;
                esac
            done
            ;;
        3)
            while true; do
                show_testing_menu
                read -r subchoice
                
                case $subchoice in
                    [1-4]) handle_testing_operations "$subchoice" ;;
                    5) set_custom_repository ;;
                    6) set_custom_version ;;
                    b|B) break ;;
                    q|Q) exit 0 ;;
                    *) log_error "Invalid choice: $subchoice" ;;
                esac
            done
            ;;
        4)
            while true; do
                show_dockerhub_menu
                read -r subchoice
                
                case $subchoice in
                    [1-7]) handle_dockerhub_operations "$subchoice" ;;
                    b|B) break ;;
                    q|Q) exit 0 ;;
                    *) log_error "Invalid choice: $subchoice" ;;
                esac
            done
            ;;
        5)
            while true; do
                show_help_menu
                read -r subchoice
                
                case $subchoice in
                    [1-4]) handle_help_operations "$subchoice" ;;
                    b|B) break ;;
                    q|Q) exit 0 ;;
                    *) log_error "Invalid choice: $subchoice" ;;
                esac
            done
            ;;
        q|Q)
            echo "Exiting..."
            exit 0
            ;;
        *)
            log_error "Invalid choice: $choice"
            read -p "Press Enter to continue..."
            ;;
    esac
done
