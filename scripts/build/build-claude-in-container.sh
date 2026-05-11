#!/bin/bash
# Script to build Claude Desktop inside the container
# Called by other scripts to perform the internal build process

set -e

echo "=== Building Claude Desktop inside the container ==="

# Navigate to the scripts directory
cd /root/claude-linux-desktop-build

# Run the build script with home directory installation
export APP_INSTALL_DIR=/root/claude-app
./build-claude.sh

# Make sure the application is installed
# Backup original script
cp install.sh install.sh.original

# Create a completely new install script that uses APP_INSTALL_DIR
cat > install.sh << EOF
#!/bin/bash
# Modified install script for Claude Desktop

CLAUDE_VERSION="0.9.2"
INSTALL_DIR="$APP_INSTALL_DIR"

# Detect architecture
ARCH=\$(uname -m)
if [ "\$ARCH" = "aarch64" ] || [ "\$ARCH" = "arm64" ]; then
    ARCH_SUFFIX="-arm64"
else
    ARCH_SUFFIX="-x86_64"
fi

# Look in multiple possible locations
POSSIBLE_PATHS=(
    "\$(pwd)/claude-desktop-linux\${ARCH_SUFFIX}-v\${CLAUDE_VERSION}.tar.gz" 
    "\$(pwd)/claude-desktop-builder/claude-desktop-linux\${ARCH_SUFFIX}-v\${CLAUDE_VERSION}.tar.gz"
    "\$HOME/.cache/claude-desktop-build/claude-desktop-builder/claude-desktop-linux\${ARCH_SUFFIX}-v\${CLAUDE_VERSION}.tar.gz"
)

PACKAGE_PATH=""
for path in "\${POSSIBLE_PATHS[@]}"; do
    if [ -f "\$path" ]; then
        PACKAGE_PATH="\$path"
        break
    fi
done

if [ -z "\$PACKAGE_PATH" ]; then
    echo "Error: Package not found at any of these locations:"
    for path in "\${POSSIBLE_PATHS[@]}"; do
        echo "  - \$path"
    done
    echo "Please run the build script first."
    exit 1
fi

echo "Installing Claude Desktop from package: \$PACKAGE_PATH"
echo "Installing to: \$INSTALL_DIR"

# Create installation directory
mkdir -p "\$INSTALL_DIR"
tar -xzf "\$PACKAGE_PATH" -C "\$INSTALL_DIR"

# Create symlink to executable
mkdir -p "\$INSTALL_DIR/bin"
ln -sf "\$INSTALL_DIR/claude-desktop/bin/claude-desktop" "\$INSTALL_DIR/bin/claude-desktop"

# Register desktop file
mkdir -p "\$INSTALL_DIR/share/applications"
if [ -f "\$INSTALL_DIR/claude-desktop/share/applications/claude-desktop.desktop" ]; then
    cp "\$INSTALL_DIR/claude-desktop/share/applications/claude-desktop.desktop" "\$INSTALL_DIR/share/applications/"
else
    echo "Warning: Desktop file not found in extracted package"
fi

# Copy icons
mkdir -p "\$INSTALL_DIR/share/icons"
if [ -d "\$INSTALL_DIR/claude-desktop/share/icons" ]; then
    cp -r "\$INSTALL_DIR/claude-desktop/share/icons/"* "\$INSTALL_DIR/share/icons/" 2>/dev/null || echo "Warning: No icons found"
else
    echo "Warning: Icons directory not found in extracted package"
fi

# Update desktop database if available
if command -v update-desktop-database &> /dev/null; then
    update-desktop-database "\$INSTALL_DIR/share/applications" || true
fi

# Setup protocol handler if available
if command -v xdg-mime &> /dev/null; then
    xdg-mime default claude-desktop.desktop x-scheme-handler/claude || true
fi

echo "Installation complete!"
echo "Claude Desktop installed to: \$INSTALL_DIR"
echo "You can run it from \$INSTALL_DIR/bin/claude-desktop"
EOF

# Make the modified script executable
chmod +x install.sh

# Run the modified install script
./install.sh

# Restore original script
mv install.sh.original install.sh

echo "✅ Build completed. Claude Desktop installed at /root/claude-app"
