#!/bin/bash
# Script to make all .sh files executable

set -e  # Exit on any error

echo "=== Making all scripts executable ==="

# The directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Find all .sh files and make them executable
find "$PROJECT_DIR" -name "*.sh" -type f -exec chmod +x {} \;

# Make other special files executable
if [ -f "$SCRIPT_DIR/xstartup" ]; then
    chmod +x "$SCRIPT_DIR/xstartup"
fi

echo "✅ All scripts are now executable"
