#!/bin/bash
# Consolidated distribution script for Claude Desktop Docker
# This script creates a distributable archive of the entire setup

set -e  # Exit on any error

# Default options
VERSION="0.14.10"  # Match with Claude Desktop version
INCLUDE_BUILD=false

# Display help
show_help() {
    echo "Claude Desktop Docker - Distribution Script"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --version VER      Set version for the archive (default: $VERSION)"
    echo "  --include-build    Include built Claude Desktop files in archive"
    echo "  --help             Show this help message"
    echo ""
}

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --version) VERSION="$2"; shift ;;
        --include-build) INCLUDE_BUILD=true ;;
        --help) show_help; exit 0 ;;
        *) echo "Unknown parameter: $1"; show_help; exit 1 ;;
    esac
    shift
done

# The directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Change to project directory
cd "$PROJECT_DIR"

# Set archive name
ARCHIVE_NAME="claude-desktop-docker-$VERSION.tar.gz"

echo "Creating distribution archive: $ARCHIVE_NAME"
echo "This will include all necessary files for running Claude Desktop in Docker."

# Set exclude patterns
EXCLUDE_PATTERNS=(
    ".git"
    "node_modules"
    ".cache"
    "$ARCHIVE_NAME"
    "archive"  # Exclude the archive directory
)

# Add claude-app to exclude patterns if not including build
if [ "$INCLUDE_BUILD" = false ]; then
    EXCLUDE_PATTERNS+=("claude-app")
fi

# Build the exclude parameters
EXCLUDE_PARAMS=""
for pattern in "${EXCLUDE_PATTERNS[@]}"; do
    EXCLUDE_PARAMS="$EXCLUDE_PARAMS --exclude='$pattern'"
done

# Create the archive
eval "tar -czf $ARCHIVE_NAME $EXCLUDE_PARAMS ."

echo "=============================================="
echo "✅ Archive created: $ARCHIVE_NAME"
echo ""
echo "Distribution instructions:"
echo "1. Share this archive with others"
echo "2. They should extract it with: tar -xzf $ARCHIVE_NAME"
echo "3. Then run: cd claude-desktop-docker && ./claude.sh setup"
echo "4. Finally run: ./claude.sh build"
echo "=============================================="
