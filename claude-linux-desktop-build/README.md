# Claude Desktop for Linux Build Scripts

This is a modular build system for creating a Linux version of Claude Desktop.

## Files

- `build-claude.sh` - Main script that coordinates the build process
- `utils.sh` - Utility functions used throughout the build process
- `dependencies.sh` - Dependency checking and installation
- `build-module.sh` - Native module building and extraction functions
- `packaging.sh` - Packaging and installation scripts
- `rust-code.rs` - Rust code for the native module
- `make-executable.sh` - Helper script to make all scripts executable

## Usage

1. Make the scripts executable:
   ```bash
   cd claude-desktop-scripts
   chmod +x make-executable.sh
   ./make-executable.sh
   ```

2. Run the build script:
   ```bash
   # Build in default location ($HOME/.cache/claude-desktop-build)
   ./build-claude.sh

   # Or specify a custom build directory
   BUILD_ROOT=/path/to/build/dir ./build-claude.sh
   ```

3. Follow the installation instructions provided after the build completes.

## Directory Structure

The build system uses two main directories:

1. **Build Directory** - Where temporary and build files are stored, which persists across reboots:
   ```
   $HOME/.cache/claude-desktop-build/
   ├── claude-desktop-builder/
   │   ├── build/           # Build files
   │   ├── downloads/       # Downloaded installers
   │   └── output/          # Final build output
   ```

2. **Application Directory** - Where the final application is installed:
   ```
   $HOME/claude-app/
   ├── bin/                # Executable files
   ├── lib/                # Libraries and application files
   └── share/              # Desktop entries and icons
   ```

You can override these locations by setting environment variables:

```bash
# Custom build directory
BUILD_ROOT=~/claude-builds ./build-claude.sh

# Custom application installation directory
APP_INSTALL_DIR=~/Applications/Claude ./build-claude.sh
```

## Requirements

- Node.js 14+ and npm
- Rust and Cargo
- Electron
- p7zip
- ImageMagick
- icoutils

The script will check for these dependencies and provide instructions if any are missing.

## Repository Organization

The repository contains only the build scripts and source files:

```
claude-desktop-scripts/
├── build-claude.sh      # Main build script
├── build-module.sh      # Native module handling
├── dependencies.sh      # Dependency checking
├── packaging.sh        # Packaging functions
├── utils.sh           # Utility functions
├── rust-code.rs       # Native module source
└── make-executable.sh  # Helper script
```

Build artifacts are kept separate from the source code to maintain a clean repository.

## Architecture

The build process has been split into modular components:

1. **Dependency Checking**: Verifies all required tools are installed
2. **Native Module Building**: Creates Linux-compatible native bindings
3. **Extraction**: Downloads and extracts the Windows Claude Desktop installer
4. **Asset Processing**: Processes icons and resources
5. **App Packaging**: Modifies and repackages the app.asar file
6. **Launcher Creation**: Creates the desktop entry and launcher script
7. **Distribution**: Creates the final installable package

## Customization

- Update the `CLAUDE_VERSION` and `CLAUDE_URL` variables in build-claude.sh to build different versions
- Modify the Rust code in rust-code.rs if needed

## Troubleshooting

If you encounter any issues during the build process:

1. Check the error messages for specific problems
2. Verify all dependencies are installed correctly
3. Ensure you have sufficient disk space
4. Look for issues with file permissions

## License

This script is provided for personal use only, subject to Anthropic's terms of service.
