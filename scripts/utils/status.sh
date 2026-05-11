#!/bin/bash
# Consolidated status script for Claude Desktop Docker
# Provides detailed status information about the container and Claude Desktop

set -e  # Exit on any error

# Display help
show_help() {
    echo "Claude Desktop Docker - Status Script"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --help           Show this help message"
    echo ""
}

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
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

# Source utils.sh for helper functions
source "$SCRIPT_DIR/utils.sh"

# Display container status
get_container_status

# If container is running, show more detailed information
if is_container_running; then
    echo ""
    echo "=== Container Details ==="
    docker inspect claude-desktop --format "Created: {{.Created}}
Image: {{.Config.Image}}
Ports: {{range \$p, \$conf := .NetworkSettings.Ports}}{{if \$conf}}{{range \$i, \$mapping := \$conf}}{{if eq \$i 0}}{{if eq \$p \"5901/tcp\"}}VNC: :{{\$mapping.HostPort}}{{else if eq \$p \"6080/tcp\"}}noVNC: :{{\$mapping.HostPort}}{{else}}{{\$p}} -> {{\$mapping.HostPort}}{{end}}{{end}}{{end}}
{{end}}{{end}}"

    # Check for Claude Desktop
    if is_claude_desktop_built; then
        echo ""
        echo "=== Claude Desktop ==="
        docker exec claude-desktop bash -c "
            if [ -f /root/claude-app/bin/claude-desktop ]; then
                echo 'Installation path: /root/claude-app/bin/claude-desktop'
                if [ -f /root/claude-app/bin/version.txt ]; then
                    echo -n 'Version: '
                    cat /root/claude-app/bin/version.txt
                elif [ -f /root/claude-app/version.txt ]; then
                    echo -n 'Version: '
                    cat /root/claude-app/version.txt
                else
                    echo 'Version: 0.9.2 (Assumed)'
                fi
                echo ''
                echo 'To run Claude Desktop:'
                echo '1. Access the VNC interface at localhost:5901 or http://localhost:6080/'
                echo '2. In the container, run: /root/claude-app/bin/claude-desktop'
            fi
        "
    fi

    # Display VNC server status
    echo ""
    echo "=== VNC Server Status ==="
    docker exec claude-desktop bash -c "
        if pgrep -x Xvnc > /dev/null; then
            echo 'VNC server is running'
            echo 'Process info:'
            ps aux | grep Xvnc | grep -v grep
        else
            echo 'VNC server is not running'
            echo 'To fix VNC issues, run: ./claude.sh fix-vnc'
        fi
    "

    # Display disk space information
    echo ""
    echo "=== Disk Space Usage ==="
    docker exec claude-desktop bash -c "df -h / | tail -1 | awk '{print \"Container root: \"\$2\" total, \"\$4\" available (\"\$5\" used)\"}'"
    docker exec claude-desktop bash -c "du -sh /root/claude-app 2>/dev/null || echo 'Claude app directory: Not found or empty'"
    
    if is_claude_desktop_built; then
        docker exec claude-desktop bash -c "du -sh /root/.cache/claude-desktop-build 2>/dev/null || echo 'Build cache: Not found'"
    fi
fi

echo ""
echo "=== Helpful Commands ==="
echo "Start container:     ./claude.sh start"
echo "Stop container:      ./claude.sh stop"
echo "Fix VNC issues:      ./claude.sh fix-vnc"
echo "View logs:           ./claude.sh logs"
echo "Access shell:        ./claude.sh shell"
