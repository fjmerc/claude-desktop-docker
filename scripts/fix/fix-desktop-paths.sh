#!/bin/bash
# Script to fix desktop entry and icon paths

set -e  # Exit on any error

# Create necessary directories
mkdir -p /root/.local/share/applications
mkdir -p /root/.local/share/icons

# Copy files from the correct location to ~/.local paths
if [ -d "/root/claude-app/share/applications" ]; then
    echo "Copying desktop entry from /root/claude-app/share/applications to ~/.local/share/applications"
    cp -v /root/claude-app/share/applications/* /root/.local/share/applications/ || true
fi

if [ -d "/root/claude-app/share/icons" ]; then
    echo "Copying icons from /root/claude-app/share/icons to ~/.local/share/icons"
    cp -rv /root/claude-app/share/icons/* /root/.local/share/icons/ || true
fi

# If files are in alternative locations, try those as well
if [ -d "/root/.cache/claude-desktop-build/claude-desktop-builder/output/share/applications" ]; then
    echo "Copying desktop entry from build output to ~/.local/share/applications"
    cp -v /root/.cache/claude-desktop-build/claude-desktop-builder/output/share/applications/* /root/.local/share/applications/ || true
fi

if [ -d "/root/.cache/claude-desktop-build/claude-desktop-builder/output/share/icons" ]; then
    echo "Copying icons from build output to ~/.local/share/icons"
    cp -rv /root/.cache/claude-desktop-build/claude-desktop-builder/output/share/icons/* /root/.local/share/icons/ || true
fi

echo "✅ Desktop entry and icon paths fixed"
