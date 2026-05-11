# Dynamic Display Scaling for Claude Desktop in Docker

This document explains the dynamic display scaling feature implemented in the Claude Desktop Docker container.

## Overview

The Dynamic Display Scaling feature allows the Claude Desktop VNC display to automatically adjust to your browser or VNC client window size. This provides a better user experience by ensuring the application is always properly sized to your viewing window.

## Features

1. **Auto-scaling Interface**: Automatically scales the desktop to fit your browser window
2. **Resolution Options**: Selectable scaling modes (remote, local, or none)
3. **Persistent Settings**: Your scaling preferences are maintained across sessions
4. **Higher Base Resolution**: Default resolution increased to 1920x1080 for better clarity
5. **Dynamic Resize Support**: Handles window resizing events in real-time

## How It Works

The implementation uses several technologies working together:

1. **TightVNC Server Configuration**: The VNC server is configured with the `remote-resize=on` option to support client-initiated resize events
2. **noVNC Configuration**: The web interface is configured to support different scaling modes
3. **XFCE Desktop Settings**: Custom configuration for the XFCE desktop environment to better handle resolution changes
4. **Resolution Monitoring**: A background process monitors and adjusts the display settings

## Usage

When you connect to the Claude Desktop via the web interface (http://localhost:6080/), you'll be presented with a selection page offering different scaling options:

- **Auto-scaling Interface**: Automatically scales the desktop to fit your browser window. Best for most users.
- **Local Scaling**: Scales locally in the browser. Better for high-DPI displays.
- **Standard Interface**: No automatic scaling. Use this if you prefer to control scaling manually.

Select the option that works best for your setup.

## Technical Implementation

The dynamic scaling is implemented through several components:

1. **VNC Server Configuration**:
   - Default resolution set to 1920x1080
   - Remote resize capability enabled

2. **XFCE Display Configuration**:
   - Custom display settings to handle resolution changes
   - xrandr configuration for proper display handling

3. **noVNC Customizations**:
   - Modified UI settings to enable scaling by default
   - Custom landing page with scaling options
   - Parameter passing for scaling preferences

4. **Background Monitoring**:
   - Regular checks for resolution changes
   - Automatic display adjustment

## Troubleshooting

If you experience issues with the dynamic scaling:

1. **Screen appears blurry**: Try switching to "Local Scaling" mode for better handling of high-DPI displays
2. **Display doesn't resize**: Ensure you're using the latest version of your browser
3. **Black borders appear**: Try refreshing the page or selecting a different scaling option
4. **Keyboard input issues**: Some keyboard shortcuts may be intercepted by the browser; use the on-screen keyboard option in noVNC if needed

## Advanced Configuration

You can modify the default settings by editing the following files:

- `/scripts/utils/config`: VNC server configuration 
- `/scripts/utils/xstartup`: X11 startup configuration
- `/scripts/run/startup.sh`: Container startup script
- `/scripts/utils/customize-novnc.sh`: noVNC customization script

### Editing Configuration Files

The container comes with several text editors pre-installed:

- **nano**: A simple, user-friendly text editor
- **vim**: A more advanced text editor with powerful features

To edit files, open a terminal in the VNC session and use one of these editors:

```bash
# Example using nano (easier for beginners)
nano /path/to/file

# Example using vim (more powerful but has a learning curve)
vim /path/to/file
```

If these editors are not available, you can install them using:

```bash
/scripts/utils/install-tools.sh
```

## Contributing

If you develop additional scaling features or improvements, please submit a pull request with a clear description of your changes.
