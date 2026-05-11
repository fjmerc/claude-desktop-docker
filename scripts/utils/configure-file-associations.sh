#!/bin/bash
# Script to configure file associations in XFCE/Thunar

echo "Configuring file associations for text files..."

# Create necessary directories
mkdir -p /root/.config/xfce4/helpers
mkdir -p /root/.local/share/applications

# Create default text editor helper configuration
cat > /root/.config/xfce4/helpers/mousepad.desktop << EOF
[Desktop Entry]
Version=1.0
Type=X-XFCE-Helper
Name=Mousepad
StartupNotify=true
X-XFCE-Binaries=mousepad;nano;vim;vi;
X-XFCE-Category=TextEditor
X-XFCE-Commands=%B;%B %f;
X-XFCE-CommandsWithParameter=%B %s;%B %f;
EOF

# Set mousepad as the default editor
echo "mousepad" > /root/.config/xfce4/helpers/custom-TerminalEmulator.desktop

# Create MIME type associations for text files
cat > /root/.config/mimeapps.list << EOF
[Default Applications]
text/plain=mousepad.desktop
application/xml=mousepad.desktop
application/json=mousepad.desktop
text/x-python=mousepad.desktop
text/markdown=mousepad.desktop
text/x-csrc=mousepad.desktop
text/html=mousepad.desktop
application/x-shellscript=mousepad.desktop
text/x-script.python=mousepad.desktop
EOF

# Install mousepad if not already installed
if ! command -v mousepad &> /dev/null; then
    echo "Installing Mousepad text editor..."
    apt-get update
    apt-get install -y mousepad
    apt-get clean
    rm -rf /var/lib/apt/lists/*
fi

# Create a simple file opener script as fallback
cat > /usr/local/bin/xdg-open-text << EOF
#!/bin/bash
# Simple text file opener script

FILE="\$1"

# Try opening with various available editors in order of preference
if command -v mousepad &> /dev/null; then
    mousepad "\$FILE" &
elif command -v nano &> /dev/null; then
    xfce4-terminal -e "nano '\$FILE'" &
elif command -v vim &> /dev/null; then
    xfce4-terminal -e "vim '\$FILE'" &
else
    echo "No suitable text editor found."
fi
EOF
chmod +x /usr/local/bin/xdg-open-text

# Create a wrapper for xdg-open to handle text files
cat > /usr/local/bin/xdg-open << EOF
#!/bin/bash
# Wrapper for xdg-open to better handle text files

FILE="\$1"

# Check if file exists
if [ ! -f "\$FILE" ]; then
    echo "File not found: \$FILE"
    exit 1
fi

# Check if it's likely a text file
if file --mime "\$FILE" | grep -q "text/" || [[ "\$FILE" == *.txt ]] || [[ "\$FILE" == *.md ]] || 
   [[ "\$FILE" == *.py ]] || [[ "\$FILE" == *.js ]] || [[ "\$FILE" == *.html ]] || 
   [[ "\$FILE" == *.json ]] || [[ "\$FILE" == *.xml ]] || [[ "\$FILE" == *.sh ]]; then
    /usr/local/bin/xdg-open-text "\$FILE"
else
    # Log the attempt
    echo "Attempted to open: \$FILE" >> /tmp/xdg-open.log
fi
EOF
chmod +x /usr/local/bin/xdg-open

echo "File associations configured. Text files should now open correctly in the file manager."
