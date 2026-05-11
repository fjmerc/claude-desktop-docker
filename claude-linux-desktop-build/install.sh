#!/bin/bash
# Install script for Claude Desktop
# Run this after successfully building Claude Desktop

CLAUDE_VERSION="0.9.2"

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    ARCH_SUFFIX="-arm64"
else
    ARCH_SUFFIX="-x86_64"
fi

# Look in multiple possible locations
POSSIBLE_PATHS=(
    "$(pwd)/claude-desktop-linux${ARCH_SUFFIX}-v${CLAUDE_VERSION}.tar.gz" 
    "$(pwd)/claude-desktop-builder/claude-desktop-linux${ARCH_SUFFIX}-v${CLAUDE_VERSION}.tar.gz"
    "$HOME/.cache/claude-desktop-build/claude-desktop-builder/claude-desktop-linux${ARCH_SUFFIX}-v${CLAUDE_VERSION}.tar.gz"
)

PACKAGE_PATH=""
for path in "${POSSIBLE_PATHS[@]}"; do
    if [ -f "$path" ]; then
        PACKAGE_PATH="$path"
        break
    fi
done

if [ -z "$PACKAGE_PATH" ]; then
    echo "Error: Package not found at any of these locations:"
    for path in "${POSSIBLE_PATHS[@]}"; do
        echo "  - $path"
    done
    echo "Please run the build script first."
    exit 1
fi

# Offer installation options
echo "Claude Desktop installation options (auto-selecting user installation):"
echo "✓ User installation (recommended for single user)"
#echo "2) System-wide installation (requires sudo)"
echo "Selected option 1 automatically"
OPTION=1

case "$OPTION" in
    1)
        echo "Installing for current user..."
        # Create all necessary directories
        mkdir -p ~/.local/bin ~/.local/share/applications ~/.local/share/icons ~/.local/claude-desktop
        
        # Extract package
        echo "📦 Extracting package..."
        tar -xzf "$PACKAGE_PATH" -C ~/.local
        
        # Move files from output to claude-desktop directory
        if [ -d ~/.local/output ]; then
            echo "📂 Moving files to claude-desktop directory..."
            cp -r ~/.local/output/* ~/.local/claude-desktop/
            rm -rf ~/.local/output
            
            echo "🔗 Creating symlink to executable..."
            ln -sf ~/.local/claude-desktop/bin/claude-desktop ~/.local/bin/claude-desktop
            
            echo "📄 Installing desktop entry and icons..."
            # Copy desktop file if it exists
            if [ -f ~/.local/claude-desktop/share/applications/claude-desktop.desktop ]; then
                cp -f ~/.local/claude-desktop/share/applications/claude-desktop.desktop ~/.local/share/applications/
            else
                echo "⚠️  Warning: Desktop file not found in package"
            fi
            
            # Copy icons if they exist
            if [ -d ~/.local/claude-desktop/share/icons ]; then
                cp -rf ~/.local/claude-desktop/share/icons/* ~/.local/share/icons/
            else
                echo "⚠️  Warning: Icons directory not found in package"
            fi
        else
            echo "Error: claude-desktop directory not found after extraction"
            echo "Contents of package:"
            tar -tvf "$PACKAGE_PATH"
        fi
        update-desktop-database ~/.local/share/applications || echo "Warning: update-desktop-database command not found. Desktop entry may not be immediately recognized."
        
        # Setup protocol handler
        xdg-mime default claude-desktop.desktop x-scheme-handler/claude || echo "Warning: xdg-mime command not found. Protocol handler not set up."
        
        echo "Installation complete!"
        echo "You can now run Claude Desktop by typing 'claude-desktop' or from your application launcher."
        ;;
    2)
        echo "Installing system-wide..."
        sudo tar -xzf "$PACKAGE_PATH" -C /opt
        sudo ln -sf /opt/claude-desktop/bin/claude-desktop /usr/local/bin/claude-desktop
        sudo cp /opt/claude-desktop/share/applications/claude-desktop.desktop /usr/share/applications/
        sudo cp -r /opt/claude-desktop/share/icons/* /usr/share/icons/
        sudo update-desktop-database /usr/share/applications || echo "Warning: update-desktop-database command not found. Desktop entry may not be immediately recognized."
        
        # Setup protocol handler
        xdg-mime default claude-desktop.desktop x-scheme-handler/claude || echo "Warning: xdg-mime command not found. Protocol handler not set up."
        
        echo "Installation complete!"
        echo "You can now run Claude Desktop by typing 'claude-desktop' or from your application launcher."
        ;;
    *)
        echo "Invalid option. Installation aborted."
        exit 1
        ;;
esac
