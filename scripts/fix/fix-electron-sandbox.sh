#!/bin/bash
# Script to fix Electron sandbox issue in Docker container

set -e  # Exit on any error

echo "=== Fixing Electron sandbox issue ==="

# Path to the application executable
EXECUTABLE="/root/claude-app/bin/claude-desktop"

if [ ! -f "$EXECUTABLE" ]; then
    echo "❌ Error: Claude Desktop executable not found at $EXECUTABLE"
    exit 1
fi

# Create a backup of the original executable
cp "$EXECUTABLE" "${EXECUTABLE}.bak"

# Read the content of the file
CONTENT=$(cat "$EXECUTABLE")

# Check if it's a shell script (as expected)
if [[ $CONTENT == \#\!* ]]; then
    echo "Modifying launcher script..."
    
    # If the script already contains --no-sandbox, don't modify it again
    if grep -q -- "--no-sandbox" "$EXECUTABLE"; then
        echo "✅ --no-sandbox flag already present in the launcher script"
    else
        # Find the electron command line and add --no-sandbox
        # This is a bit tricky without knowing the exact script structure
        # We'll use a common pattern for electron apps
        if grep -q "electron app.asar" "$EXECUTABLE"; then
            # Common pattern: electron app.asar
            sed -i 's/electron app.asar/electron --no-sandbox app.asar/g' "$EXECUTABLE"
            echo "✅ Added --no-sandbox flag to 'electron app.asar' command"
        elif grep -q "electron ." "$EXECUTABLE"; then
            # Another common pattern: electron .
            sed -i 's/electron \./electron --no-sandbox \./g' "$EXECUTABLE"
            echo "✅ Added --no-sandbox flag to 'electron .' command"
        elif grep -q "exec.*electron" "$EXECUTABLE"; then
            # Pattern with exec
            sed -i 's/exec.*electron/& --no-sandbox/g' "$EXECUTABLE"
            echo "✅ Added --no-sandbox flag to exec electron command"
        else
            # Create a wrapper script as a fallback solution
            echo "Creating a wrapper script..."
            mv "$EXECUTABLE" "${EXECUTABLE}.original"
            cat > "$EXECUTABLE" << 'EOF'
#!/bin/bash
# Wrapper script to add --no-sandbox flag to Electron

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
ORIGINAL_SCRIPT="${SCRIPT_DIR}/claude-desktop.original"

# Run the original script with the --no-sandbox flag added to electron
"$ORIGINAL_SCRIPT" --no-sandbox "$@"
EOF
            chmod +x "$EXECUTABLE"
            echo "✅ Created wrapper script to add --no-sandbox flag"
        fi
    fi
else
    echo "❌ Unexpected file format. Creating a wrapper script instead..."
    mv "$EXECUTABLE" "${EXECUTABLE}.bin"
    cat > "$EXECUTABLE" << 'EOF'
#!/bin/bash
# Wrapper script to add --no-sandbox flag to Electron binary

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
ORIGINAL_BIN="${SCRIPT_DIR}/claude-desktop.bin"

# Run the original binary with the --no-sandbox flag
"$ORIGINAL_BIN" --no-sandbox "$@"
EOF
    chmod +x "$EXECUTABLE"
    echo "✅ Created wrapper script to add --no-sandbox flag"
fi

echo "Checking the Claude Desktop launcher directory structure..."
find "/root/claude-app" -type f -name "electron" -o -name "*.asar" | grep -v "node_modules" || echo "No electron or asar files found directly"

# If app.asar is in a standard location, we might need to modify the main.js within it
ASAR_FILE="/root/claude-app/resources/app.asar"
if [ -f "$ASAR_FILE" ]; then
    echo "Found app.asar at $ASAR_FILE"
    
    # Create a directory for extraction
    EXTRACT_DIR="/tmp/app-extract"
    rm -rf "$EXTRACT_DIR"
    mkdir -p "$EXTRACT_DIR"
    
    # Extract the asar file
    echo "Extracting app.asar..."
    asar extract "$ASAR_FILE" "$EXTRACT_DIR"
    
    # Find and modify main.js files to add --no-sandbox
    echo "Looking for main process files to modify..."
    MODIFIED=0
    
    # Common main process filenames
    for FILE in "$EXTRACT_DIR/main.js" "$EXTRACT_DIR/electron-main.js" "$EXTRACT_DIR/src/main.js" "$EXTRACT_DIR/src/electron-main.js"; do
        if [ -f "$FILE" ]; then
            echo "Found potential main process file: $FILE"
            
            # Add --no-sandbox to app.commandLine.appendSwitch calls
            if grep -q "app.commandLine.appendSwitch" "$FILE"; then
                echo "Adding --no-sandbox to commandLine switches in $FILE"
                # Add after the imports but before the first function
                sed -i '/const.*require/a\
// Add no-sandbox switch for Docker environment\
const { app } = require("electron");\
if (app && app.commandLine) {\
  app.commandLine.appendSwitch("no-sandbox");\
}\
' "$FILE"
                MODIFIED=1
            fi
            
            # If the file contains BrowserWindow creation
            if grep -q "new BrowserWindow" "$FILE"; then
                echo "File contains BrowserWindow creation: $FILE"
                # Add sandbox: false to BrowserWindow options
                sed -i 's/new BrowserWindow({/new BrowserWindow({\n      sandbox: false,/g' "$FILE"
                MODIFIED=1
            fi
        fi
    done
    
    if [ $MODIFIED -eq 1 ]; then
        # Backup the original asar file
        cp "$ASAR_FILE" "${ASAR_FILE}.bak"
        
        # Repackage the asar file
        echo "Repackaging app.asar with modifications..."
        asar pack "$EXTRACT_DIR" "$ASAR_FILE"
        echo "✅ Modified app.asar to disable sandbox"
    else
        echo "⚠️ No suitable main process files found for modification"
    fi
    
    # Clean up
    rm -rf "$EXTRACT_DIR"
fi

echo "✅ Electron sandbox fix applied"
echo "Try launching Claude Desktop again"
