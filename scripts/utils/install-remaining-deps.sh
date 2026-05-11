#!/bin/bash
# Script to install remaining dependencies after container build

echo "=== Installing Remaining Dependencies ==="

# Check if wget is installed
if ! command -v wget &> /dev/null; then
    echo "wget not found, installing..."
    apt-get update && apt-get install -y wget
fi

# Install electron globally via npm if not already installed
if ! command -v electron &> /dev/null; then
    echo "Installing electron via npm..."
    npm install -g electron
fi

# Check for 7za and try alternative methods if missing
if ! command -v 7za &> /dev/null; then
    echo "7za not found, checking alternatives..."
    
    # Check if 7z is available
    if command -v 7z &> /dev/null; then
        echo "Creating 7za symlink to 7z..."
        ln -sf $(which 7z) /usr/local/bin/7za
    else
        echo "Installing p7zip-full again..."
        apt-get update && apt-get install -y p7zip-full
    fi
fi

# Check for wrestool and icotool from icoutils
if ! command -v wrestool &> /dev/null || ! command -v icotool &> /dev/null; then
    echo "icoutils not found, installing again..."
    apt-get update && apt-get install -y icoutils
fi

# Check for convert from ImageMagick
if ! command -v convert &> /dev/null; then
    echo "ImageMagick not found, installing again..."
    apt-get update && apt-get install -y imagemagick
fi

echo "=== Verifying Dependencies ==="
bash /scripts/utils/verify-dependencies.sh

echo "=== Installation Complete ==="
