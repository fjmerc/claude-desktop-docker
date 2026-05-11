#!/bin/bash
# Helper script to find electron in the container

# Set output to verbose for debugging
set -x

echo "Checking for electron binary..."
which electron || echo "electron not found in PATH"

echo "Checking npm global path..."
npm root -g

echo "Looking for electron in npm directories..."
find $(npm root -g) -name electron -type f -executable 2>/dev/null

echo "Looking for electron in /usr/local..."
find /usr/local -name electron -type f -executable 2>/dev/null

echo "Checking for locally installed electron package..."
[ -d "/root/claude-app/node_modules/electron" ] && find /root/claude-app/node_modules/electron -name electron -type f -executable 2>/dev/null

echo "Current PATH:"
echo $PATH
