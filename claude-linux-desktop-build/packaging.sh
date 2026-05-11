#!/bin/bash
#
# Packaging functions for Claude Desktop build - simplified version

# Process and repackage app.asar
process_asar() {
    log_info "Processing app.asar..."
    cd "$WORK_DIR"
    
    # Create output directories
    mkdir -p "$OUTPUT_DIR/lib/claude-desktop"
    
    # Copy app.asar and app.asar.unpacked
    cp "lib/net45/resources/app.asar" "$OUTPUT_DIR/lib/claude-desktop/" || {
        log_error "Failed to copy app.asar"
        exit $EXIT_FILE_NOT_FOUND
    }
    
    if [ -d "lib/net45/resources/app.asar.unpacked" ]; then
        cp -r "lib/net45/resources/app.asar.unpacked" "$OUTPUT_DIR/lib/claude-desktop/" || {
            log_error "Failed to copy app.asar.unpacked"
            exit $EXIT_FILE_NOT_FOUND
        }
    else
        mkdir -p "$OUTPUT_DIR/lib/claude-desktop/app.asar.unpacked"
    fi
    
    # Extract asar file for modification
    cd "$OUTPUT_DIR/lib/claude-desktop"
    asar extract app.asar app.asar.contents || {
        log_error "Failed to extract app.asar"
        exit $EXIT_EXTRACTION_ERROR
    }
    
    # Create directories if they don't exist
    mkdir -p "app.asar.contents/node_modules/claude-native"
    mkdir -p "app.asar.unpacked/node_modules/claude-native"
    
    # Detect system architecture and choose appropriate binding
    ARCH=$(uname -m)
    if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
        log_info "ARM64 architecture detected, using arm64 native binding"
        BINDING_FILE="patchy-cnb.linux-arm64-gnu.node"
        
        # Check if ARM64 binding exists
        if [ ! -f "$WORK_DIR/patchy-cnb/$BINDING_FILE" ]; then
            log_warning "ARM64 binding not found, falling back to x64 binding"
            BINDING_FILE="patchy-cnb.linux-x64-gnu.node"
        fi
    else
        log_info "x86_64 architecture detected, using x64 native binding"
        BINDING_FILE="patchy-cnb.linux-x64-gnu.node"
    fi
    
    # Replace native bindings
    cp "$WORK_DIR/patchy-cnb/$BINDING_FILE" \
        "app.asar.contents/node_modules/claude-native/claude-native-binding.node" || {
        log_error "Failed to copy native binding to app.asar.contents"
        exit $EXIT_FILE_NOT_FOUND
    }
    
    cp "$WORK_DIR/patchy-cnb/$BINDING_FILE" \
        "app.asar.unpacked/node_modules/claude-native/claude-native-binding.node" || {
        log_error "Failed to copy native binding to app.asar.unpacked"
        exit $EXIT_FILE_NOT_FOUND
    }
    
    # Copy Tray icons if they exist
    mkdir -p app.asar.contents/resources
    if ls "$WORK_DIR/lib/net45/resources/Tray"* >/dev/null 2>&1; then
        cp "$WORK_DIR/lib/net45/resources/Tray"* app.asar.contents/resources/ || {
            log_warning "Failed to copy tray icons, creating placeholder"
            touch app.asar.contents/resources/TrayIconDefault.png
        }
    else
        log_warning "Tray icons not found, creating placeholder"
        touch app.asar.contents/resources/TrayIconDefault.png
    fi

    # Copy i18n files
    mkdir -p app.asar.contents/resources/i18n
    if [ -d "$WORK_DIR/lib/net45/resources/i18n" ]; then
        cp "$WORK_DIR/lib/net45/resources/i18n/"*.json app.asar.contents/resources/i18n/ || {
            log_warning "Failed to copy i18n files"
        }
    else
        log_warning "i18n directory not found, creating from Windows resources"
        # Copy language files from Windows resources to i18n directory
        for lang_file in "$WORK_DIR/lib/net45/resources/"*-*.json; do
            if [ -f "$lang_file" ]; then
                base_name=$(basename "$lang_file")
                cp "$lang_file" "app.asar.contents/resources/i18n/$base_name" || {
                    log_warning "Failed to copy language file: $base_name"
                }
            fi
        done
    fi
    
    # Repackage app.asar
    asar pack app.asar.contents app.asar || {
        log_error "Failed to repackage app.asar"
        exit $EXIT_EXTRACTION_ERROR
    }
    
    log_info "Successfully processed app.asar"
}

# Create desktop entry
create_desktop_entry() {
    log_info "Creating desktop entry..."
    mkdir -p "$OUTPUT_DIR/share/applications"
    
    cat > "$OUTPUT_DIR/share/applications/claude-desktop.desktop" << EOF
[Desktop Entry]
Name=Claude
Comment=Claude AI Assistant
Exec=claude-desktop %u
Icon=claude
Type=Application
Terminal=false
Categories=Office;Utility;AI;
Keywords=AI;Assistant;Claude;Chat;
MimeType=x-scheme-handler/claude
StartupWMClass=Claude
StartupNotify=true
EOF
    
    log_info "Desktop entry created successfully"
}

# Create launcher script
create_launcher() {
    log_info "Creating launcher script..."
    mkdir -p "$OUTPUT_DIR/bin"
    
    cat > "$OUTPUT_DIR/bin/claude-desktop" << 'EOF'
#!/bin/bash

# Find the real location of this script
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

# Calculate the app directory based on installation structure
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Verify app.asar exists
if [[ ! -f "$APP_DIR/lib/claude-desktop/app.asar" ]]; then
  echo "Error: Could not find Claude Desktop application files."
  echo "Expected location: $APP_DIR/lib/claude-desktop/app.asar"
  exit 1
fi

# Set display if not set
if [ -z "$DISPLAY" ]; then
  export DISPLAY=:0
fi

# Electron refuses to start without --no-sandbox when running as root
# (e.g. inside the Docker container). Auto-detect so users on a normal
# Linux desktop keep the sandbox; only the root case forces --no-sandbox.
ELECTRON_FLAGS=()
if [ "$EUID" -eq 0 ]; then
  ELECTRON_FLAGS+=(--no-sandbox)
fi

# Launch application with error handling
if ! electron "${ELECTRON_FLAGS[@]}" "$APP_DIR/lib/claude-desktop/app.asar" "$@"; then
  echo "Error: Failed to launch Electron application."
  echo "Please ensure X server is running and DISPLAY is set correctly."
  echo "Current DISPLAY=$DISPLAY"
  exit 1
fi
EOF

    chmod +x "$OUTPUT_DIR/bin/claude-desktop"
    log_info "Launcher script created successfully"
}

# Create installation package
create_package() {
    log_info "Creating installation package..."
    
    # Detect system architecture for package naming
    ARCH=$(uname -m)
    if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
        ARCH_SUFFIX="-arm64"
        ARCH_NAME="ARM64 (aarch64)"
    else
        ARCH_SUFFIX="-x86_64"
        ARCH_NAME="x86_64"
    fi
    
    # Define the package path with architecture
    PACKAGE_NAME="claude-desktop-linux${ARCH_SUFFIX}-v${CLAUDE_VERSION}.tar.gz"
    PACKAGE_PATH="${CLAUDE_DIR}/${PACKAGE_NAME}"
    
    # Create a simple README
    cat > "$OUTPUT_DIR/README.md" << EOF
# Claude Desktop for Linux
Version: ${CLAUDE_VERSION}
EOF
    
    # Create the package
    cd "$OUTPUT_DIR/.."
    tar -czf "$PACKAGE_PATH" "$(basename "$OUTPUT_DIR")"
    
    # Install to user's home directory
    log_info "Installing to ${APP_INSTALL_DIR}..."
    mkdir -p "$APP_INSTALL_DIR"
    
    # Copy files to the application directory
    rsync -a "$OUTPUT_DIR/" "$APP_INSTALL_DIR/"
    
    # Create symbolic link to the binary in ~/bin if it exists
    if [ -d "$HOME/bin" ]; then
        log_info "Creating symbolic link in ~/bin..."
        ln -sf "$APP_INSTALL_DIR/bin/claude-desktop" "$HOME/bin/claude-desktop"
    fi
    
    # Set permissions
    chmod +x "$APP_INSTALL_DIR/bin/claude-desktop"
    
    log_info "Package created: $PACKAGE_PATH"
    log_info "Application installed to: $APP_INSTALL_DIR (${ARCH_NAME})"
}

# Create installation instructions
create_install_instructions() {
    # ARCH_NAME is already defined in create_package()
    
    log_info "Build complete! Claude Desktop is available in: $OUTPUT_DIR"
    echo -e "\n=== Claude Desktop for Linux v${CLAUDE_VERSION} ==="
    echo "Architecture: $ARCH_NAME"
    echo "Application installed in: ${APP_INSTALL_DIR}"
    echo "To run: ${APP_INSTALL_DIR}/bin/claude-desktop"
    echo "Package: ${CLAUDE_DIR}/claude-desktop-linux${ARCH_SUFFIX}-v${CLAUDE_VERSION}.tar.gz"
    echo "Build directory: ${BUILD_ROOT} (will persist across reboots)"
    
    # Check if ~/bin is in PATH
    if [ -d "$HOME/bin" ] && echo $PATH | grep -q "$HOME/bin"; then
        echo "You can also run 'claude-desktop' directly"
    else
        echo "Tip: Add '$APP_INSTALL_DIR/bin' to your PATH for easier access"
    fi
}

# Export functions for the main script
export -f process_asar create_desktop_entry create_launcher create_package create_install_instructions
