#!/bin/bash
# Utility functions for Claude Desktop Docker scripts

# Get the root project directory
get_project_dir() {
    local script_path="$1"
    local script_dir="$( cd "$( dirname "$script_path" )" &> /dev/null && pwd )"
    echo "$(dirname "$(dirname "$script_dir")")"
}

# Check if Docker is available
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo "❌ Error: Docker is not installed. Please install Docker before continuing."
        return 1
    fi
    
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        echo "❌ Error: Docker Compose is not installed. Please install Docker Compose before continuing."
        return 1
    fi
    
    if ! docker info &> /dev/null; then
        echo "❌ Error: You don't have permission to use Docker."
        echo "Please make sure your user is in the docker group or run with sudo."
        return 1
    fi
    
    return 0
}

# Check if container is running
is_container_running() {
    docker ps | grep -q claude-desktop
    return $?
}

# Check if Claude Desktop is built
is_claude_desktop_built() {
    docker exec claude-desktop bash -c "[ -f /root/claude-app/bin/claude-desktop ]"
    return $?
}

# Get container status information
get_container_status() {
    echo "=== Claude Desktop Docker Container Status ==="
    
    if is_container_running; then
        echo "✅ Container: Running"
        docker exec claude-desktop bash -c "if [ -f /root/claude-app/bin/claude-desktop ]; then echo '✅ Claude Desktop: Built'; else echo '❌ Claude Desktop: Not built'; fi"
        
        # Check VNC server
        if docker exec claude-desktop pgrep -x Xvnc > /dev/null; then
            echo "✅ VNC Server: Running"
        else
            echo "❌ VNC Server: Not running"
        fi
        
        # Show container info
        echo ""
        echo "Container ID: $(docker ps -q -f name=claude-desktop)"
        echo "VNC Access: localhost:5901 (password: claude_desktop)"
        echo "Web Access: http://localhost:6080/"
    else
        echo "❌ Container: Not running"
    fi
}

# Display help for all scripts
show_all_commands() {
    echo "Claude Desktop Docker - Available Commands"
    echo ""
    echo "Setup and Building:"
    echo "  ./claude.sh setup                Initial setup for permissions"
    echo "  ./claude.sh build                Build Docker container and Claude Desktop"
    echo ""
    echo "Container Management:"
    echo "  ./claude.sh start                Start container"
    echo "  ./claude.sh stop                 Stop container"
    echo "  ./claude.sh restart              Restart container"
    echo "  ./claude.sh logs                 View container logs"
    echo "  ./claude.sh shell                Access container shell"
    echo ""
    echo "Troubleshooting:"
    echo "  ./claude.sh fix-vnc              Fix VNC connection issues"
    echo "  ./claude.sh status               Check container status"
    echo ""
    echo "Distribution:"
    echo "  ./claude.sh distribute           Create shareable archive"
    echo ""
    echo "For more information on a specific command, run:"
    echo "  ./claude.sh [command] --help"
}
