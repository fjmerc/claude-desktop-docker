#!/bin/bash
# Consolidated VNC fix script for Claude Desktop Docker
# This script handles various VNC connection issues

set -e  # Exit on any error

# Compose v1/v2 compat: define a docker-compose shell function only if the
# standalone v1 binary isn't present, forwarding to the `docker compose` plugin.
command -v docker-compose >/dev/null 2>&1 || docker-compose() { docker compose "$@"; }

# Default options
FIX_TYPE="auto"

# Display help
show_help() {
    echo "Claude Desktop Docker - VNC Fix Script"
    echo ""
    echo "Usage: $0 [options] [fix-type]"
    echo ""
    echo "Fix Types:"
    echo "  auto     Automatically detect and apply the appropriate fix (default)"
    echo "  config   Fix VNC configuration files"
    echo "  direct   Directly reconfigure and restart VNC server inside container"
    echo "  restart  Simply restart the container with working VNC configuration"
    echo ""
    echo "Options:"
    echo "  --help   Show this help message"
    echo ""
}

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        auto|config|direct|restart) FIX_TYPE="$1" ;;
        --help) show_help; exit 0 ;;
        *) echo "Unknown parameter: $1"; show_help; exit 1 ;;
    esac
    shift
done

# The directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Change to project directory
cd "$PROJECT_DIR"

# Auto-detect the issue
if [ "$FIX_TYPE" = "auto" ]; then
    echo "=== Auto-detecting VNC issues ==="
    
    # Check if the container is running
    if ! docker ps | grep -q claude-desktop; then
        echo "Container is not running. Will apply 'restart' fix."
        FIX_TYPE="restart"
    else
        # Check if VNC server is running
        if ! docker exec claude-desktop pgrep -x Xvnc > /dev/null; then
            echo "VNC server not running. Will apply 'direct' fix."
            FIX_TYPE="direct"
        else
            # Check if config has localhost=no which can cause issues
            if docker exec claude-desktop bash -c "grep -q 'localhost=no' /root/.vnc/config 2>/dev/null"; then
                echo "Detected problematic VNC configuration. Will apply 'config' fix."
                FIX_TYPE="config"
            else
                # Default to restart fix if no specific issue detected
                echo "No specific issue detected. Will apply 'restart' fix."
                FIX_TYPE="restart"
            fi
        fi
    fi
    
    echo "Selected fix type: $FIX_TYPE"
    echo ""
fi

# Apply the selected fix
case "$FIX_TYPE" in
    config)
        echo "=== Applying VNC configuration fix ==="
        
        # Update the scripts directory
        echo "Checking configuration files..."
        
        # Fix config file if it exists
        CONFIG_FILE="${PROJECT_DIR}/scripts/utils/config"
        if [ -f "$CONFIG_FILE" ]; then
            if grep -q "localhost=no" "$CONFIG_FILE"; then
                echo "Fixing config file to remove localhost=no..."
                sed -i 's/localhost=no/# Note: Don'\''t use localhost=no here, it will be misinterpreted/' "$CONFIG_FILE"
            fi
        fi
        
        # Fix startup script if it exists
        STARTUP_FILE="${PROJECT_DIR}/scripts/run/startup.sh"
        if [ -f "$STARTUP_FILE" ]; then
            if grep -q "vncserver \$DISPLAY -localhost no" "$STARTUP_FILE"; then
                echo "Fixing startup script to remove -localhost no parameter..."
                sed -i 's/vncserver \$DISPLAY -localhost no/vncserver \$DISPLAY/' "$STARTUP_FILE"
            fi
        fi
        
        echo "Configuration files updated."
        echo "Restarting container with fixed configuration..."
        docker-compose stop || true
        docker-compose up -d
        
        echo "Waiting for container to start..."
        sleep 5
        ;;
        
    direct)
        echo "=== Applying direct VNC server fix ==="
        
        # Stop any existing VNC sessions in the container
        echo "Stopping existing VNC sessions..."
        docker exec claude-desktop bash -c "vncserver -kill :1 || true"
        
        # Update config files directly inside the container
        echo "Updating VNC configuration files inside the container..."
        docker exec claude-desktop bash -c "
            mkdir -p /root/.vnc
            echo '# VNC server configuration' > /root/.vnc/config
            echo 'geometry=1280x800' >> /root/.vnc/config
            echo 'depth=24' >> /root/.vnc/config
            echo 'name=Claude Desktop VNC' >> /root/.vnc/config
            
            # Ensure xstartup is properly configured
            cat > /root/.vnc/xstartup << 'EOF'
#!/bin/bash
export DISPLAY=:1
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

# Make sure .Xauthority exists and has proper permissions
touch \$HOME/.Xauthority
chmod 600 \$HOME/.Xauthority

# Load X resources if available
[ -r \$HOME/.Xresources ] && xrdb \$HOME/.Xresources

# Start XFCE desktop environment
if command -v startxfce4 >/dev/null; then
  startxfce4 &
else
  echo \"XFCE not found, starting xterm\"
  xterm &
fi
EOF
            
            # Make the script executable
            chmod +x /root/.vnc/xstartup
        "
        
        # Manually start the VNC server with correct parameters
        echo "Starting VNC server with correct parameters..."
        docker exec claude-desktop bash -c "vncserver :1 -geometry 1280x800 -depth 24 -name 'Claude Desktop VNC'"
        
        echo "Waiting for VNC server to start..."
        sleep 3
        
        # Verify that the VNC server is running
        echo "Checking VNC server status..."
        docker exec claude-desktop bash -c "ps aux | grep Xvnc"
        ;;
        
    restart)
        echo "=== Applying restart fix ==="
        
        # Stop the container
        echo "Stopping container..."
        docker-compose stop || true
        
        # Start the container with the right environment
        echo "Starting container with correct environment..."
        export USER=root
        docker-compose up -d
        
        echo "Waiting for container to start..."
        sleep 5
        ;;
esac

echo "=============================================="
echo "✅ VNC fix applied!"
echo "You should now be able to access the Claude Desktop via:"
echo "1. VNC client at localhost:5901 (password: claude_desktop)"
echo "2. Web browser at http://localhost:6080/"
echo "=============================================="
