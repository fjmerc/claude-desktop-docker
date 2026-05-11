# Script Organization Reference

This document explains the organization of scripts in the Claude Desktop Docker project and the relationships between them.

## Directory Structure

The scripts are organized into functional categories:

```
scripts/
├── build/           # Scripts related to building the Docker image and Claude Desktop
├── fix/             # Scripts that fix various issues in the container
├── run/             # Scripts for managing the container lifecycle
├── utils/           # Utility scripts and common functions
└── main.sh          # Main entry point for all commands
```

## Main Entry Point

- `claude.sh`: Simple wrapper that calls `scripts/main.sh` with all arguments
- `scripts/main.sh`: Routes commands to the appropriate scripts in the categorized directories

## Build Scripts

Scripts in `scripts/build/`:

- `build.sh`: Performs a complete build of both Docker container and Claude Desktop
- `build-claude-in-container.sh`: Script to build Claude Desktop inside the container
- `distribute.sh`: Creates a distributable archive of the entire setup

## Run Scripts

Scripts in `scripts/run/`:

- `run.sh`: Manages container lifecycle (start, stop, restart)
- `setup.sh`: Performs initial setup for permissions and environment verification
- `startup.sh`: Container initialization script that starts VNC server and Claude Desktop
- `start-claude.sh`: Specifically starts Claude Desktop in an already running container

## Fix Scripts

Scripts in `scripts/fix/`:

- `fix-dbus.sh`: Fixes dbus-launch issues in the container
- `fix-desktop-paths.sh`: Fixes desktop entry and icon paths
- `fix-electron-sandbox.sh`: Fixes Electron sandbox restrictions
- `fix-install-prompts.sh`: Modifies install script to run non-interactively
- `fix-paths.sh`: Fixes paths for Claude Desktop installation
- `fix-vnc.sh`: Resolves VNC connection issues
- `fix-vnc-issues.sh`: Additional VNC troubleshooting
- `make-scripts-executable.sh`: Compatibility script that redirects to the utils version

## Utility Scripts

Scripts in `scripts/utils/`:

- `install-remaining-deps.sh`: Installs remaining dependencies after container build
- `logs.sh`: Views container logs
- `shell.sh`: Accesses container shell
- `status.sh`: Shows container and Claude Desktop status
- `utils.sh`: Contains common utility functions used by other scripts
- `verify-dependencies.sh`: Verifies that all required dependencies are installed
- `make-scripts-executable.sh`: Makes all scripts in the project executable
- `xstartup`: VNC server startup script
- `config`: VNC server configuration file
- `find-electron.sh`: Diagnostic tool to locate electron in the container

## Execution Flow

1. User calls `./claude.sh` with a command and options
2. `claude.sh` forwards to `scripts/main.sh`
3. `main.sh` routes to appropriate script in the categorized directories
4. Scripts execute with proper permissions

## Dependencies Between Scripts

- Most scripts source `utils.sh` to access common functions
- Build scripts call fix scripts to ensure proper setup
- All scripts that run commands in the container first check if the container is running

## Error Handling

- Most scripts use `set -e` to exit on any error
- Scripts provide clear error messages with suggestions for resolution
- Common error detection and handling routines are in `utils.sh`

## Extending the System

When adding new functionality:

1. Place the script in the appropriate category directory
2. Update `main.sh` if adding a new top-level command
3. Follow the same error handling and documentation patterns
4. Make the script executable with `chmod +x`

## Best Practices

1. Always use `set -e` for error detection
2. Get project directory paths using `dirname` and `BASH_SOURCE`
3. Source `utils.sh` for common functions
4. Display clear help messages with `--help` option
5. Use prefixes for echo statements (✅, ❌, ⚠️) for clarity
6. Ensure proper error handling and reporting
