# Claude Desktop Docker Script Structure

This document explains the organization and purpose of the scripts for Claude Desktop Docker.

## Script Organization

```
claude-desktop-docker/
├── claude.sh                          # Master command script
├── cleanup.sh                         # Helper to clean up resources
├── docker-compose.yml                 # Container configuration
├── Dockerfile                         # Docker image definition
├── scripts/
│   ├── build/                         # Build scripts
│   │   ├── build.sh                   # Main build script  
│   │   ├── build-claude-in-container.sh # Build Claude in container
│   │   └── distribute.sh              # Create distribution package
│   ├── fix/                           # Fix scripts
│   │   ├── fix-dbus.sh                # Fix dbus issues
│   │   ├── fix-desktop-paths.sh       # Fix desktop entry paths
│   │   ├── fix-electron-sandbox.sh    # Fix electron sandbox issues
│   │   ├── fix-install-prompts.sh     # Fix interactive prompts
│   │   ├── fix-paths.sh               # Fix installation paths
│   │   ├── fix-vnc-issues.sh          # Fix VNC connection issues
│   │   ├── fix-vnc.sh                 # Main VNC fix script
│   │   └── make-scripts-executable.sh # Compatibility script for script execution
│   ├── main.sh                        # Main command dispatcher
│   ├── run/                           # Runtime scripts
│   │   ├── run.sh                     # Container lifecycle management
│   │   ├── setup.sh                   # Initial environment setup
│   │   ├── start-claude.sh            # Start Claude in running container
│   │   └── startup.sh                 # Container startup script
│   └── utils/                         # Utility scripts
│       ├── config                     # VNC configuration
│       ├── find-electron.sh           # Locate electron binary
│       ├── install-remaining-deps.sh  # Install dependencies
│       ├── logs.sh                    # View container logs
│       ├── make-scripts-executable.sh # Make scripts executable
│       ├── shell.sh                   # Access container shell
│       ├── status.sh                  # Check status
│       ├── utils.sh                   # Shared functions
│       ├── verify-dependencies.sh     # Check dependencies
│       └── xstartup                   # VNC startup script
└── docs/
    ├── SCRIPT-STRUCTURE.md            # This documentation
    └── ...                            # Other documentation
```

## Script Descriptions

### Master Script

- **claude.sh**: A convenience wrapper that calls the main.sh script with all the provided arguments. This allows for a simpler command interface at the project root level.

### Core Scripts

- **main.sh**: Command dispatcher that routes calls to the appropriate script based on the command argument.
- **scripts/run/setup.sh**: Sets up the environment by ensuring permissions are correct and verifying Docker is installed.
- **scripts/build/build.sh**: Builds the Docker container and the Claude Desktop application. Provides options for clean builds, dependency management, and more.
- **scripts/run/run.sh**: Manages container lifecycle with start, stop, and restart actions. Can optionally build Claude Desktop on start.
- **scripts/utils/shell.sh**: Provides shell access to the running container. Can also run individual commands.
- **scripts/utils/logs.sh**: Views and follows container logs with options for controlling output.
- **scripts/utils/status.sh**: Provides detailed status information about the container and Claude Desktop application.
- **scripts/fix/fix-vnc.sh**: Troubleshoots and fixes VNC connection issues with multiple fix strategies.
- **scripts/build/distribute.sh**: Creates a distributable archive of the Claude Desktop Docker setup.
- **scripts/utils/utils.sh**: Contains shared utility functions used by multiple scripts.
- **scripts/run/start-claude.sh**: Specifically starts Claude Desktop in an already running container.
- **scripts/utils/find-electron.sh**: Diagnostic tool to locate the electron binary in the container.

## Script Features

Most scripts support the following common features:

- **--help** flag to display usage information
- Parameterized options with sensible defaults
- Consistent error handling and reporting
- Path-independent operation (can be run from any directory)
- Status reporting during operation
- Cross-script compatibility

## Script Dependencies

The scripts have the following dependency structure:

1. **utils.sh** is used by most other scripts for common functions
2. **setup.sh** should be run before other scripts to ensure permissions
3. **build.sh** is required before using run.sh, shell.sh, logs.sh or fix-vnc.sh
4. **main.sh** depends on all other scripts for dispatching commands
5. **start-claude.sh** can be used to manually start Claude in a running container
6. **find-electron.sh** helps troubleshoot PATH issues with electron

## Common Commands

Here are some common commands you might use:

```bash
# Initial setup
./claude.sh setup

# Build container and Claude Desktop
./claude.sh build

# Start the container (and Claude Desktop if built)
./claude.sh start

# Stop the container
./claude.sh stop

# Restart the container
./claude.sh restart

# Start Claude Desktop manually
./claude.sh start-claude

# Find electron binary (for troubleshooting)
./claude.sh find-electron

# Access container shell
./claude.sh shell

# View container logs
./claude.sh logs

# Check status
./claude.sh status
```
