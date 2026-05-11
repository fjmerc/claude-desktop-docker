#!/bin/bash
# Script to launch Claude Desktop with proper flags in Docker

set -e  # Exit on any error

CLAUDE_PATH="/root/claude-app/bin/claude-desktop"

if [ ! -f "$CLAUDE_PATH" ]; then
    echo "❌ Error: Claude Desktop executable not found at $CLAUDE_PATH"
    exit 1
fi

echo "=== Launching Claude Desktop with --no-sandbox ==="
cd "$(dirname "$CLAUDE_PATH")"
./claude-desktop --no-sandbox "$@"
