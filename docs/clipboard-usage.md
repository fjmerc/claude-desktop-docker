# Clipboard Usage in Claude Desktop Docker

This document explains how to use clipboard functionality with the Claude Desktop Docker container.

## Overview

The clipboard functionality has been improved to allow copying and pasting between your host system and the Claude Desktop application running in the Docker container.

## How to Use

### When using noVNC (web browser interface):

1. **First-time setup**:
   - When you first try to copy or paste, your browser will request clipboard permission
   - Click "Allow" when prompted to enable clipboard access
   - This is a browser security requirement and cannot be bypassed

2. **Copying text from host to Claude Desktop**:
   - Copy text on your host machine as normal (Ctrl+C)
   - Click inside the noVNC window
   - Click the clipboard button in the noVNC control panel (left side)
   - Paste your text into the clipboard dialog
   - Click "Send to server"
   - Now paste inside Claude Desktop (Ctrl+V)

3. **Copying text from Claude Desktop to host**:
   - Copy text in Claude Desktop (Ctrl+C)
   - The clipboard contents should automatically appear in the noVNC clipboard dialog
   - You can now paste on your host machine (Ctrl+V)

### When using a native VNC client:

If clipboard functionality is critical to your workflow, consider using a native VNC client instead of noVNC:

1. Connect to `localhost:5901` with a VNC client like TigerVNC, RealVNC, or Remmina
2. Use password: `claude_desktop`
3. Clipboard should work more seamlessly without browser restrictions

## Troubleshooting

If clipboard functionality isn't working:

1. **Browser issues**:
   - Make sure you've allowed clipboard access when prompted
   - Try clicking in the noVNC window before clipboard operations
   - Some browsers are more restrictive than others (Firefox often works better than Chrome)

2. **VNC server issues**:
   - Check if `vncconfig` is running in the container
   - Verify `autocutsel` is running with: `ps aux | grep autocutsel`

3. **Alternative method**:
   - Use the clipboard dialog in the noVNC control panel as a manual copy/paste buffer

## Known Limitations

- Browser security restrictions may still cause issues with clipboard access
- One-way clipboard transfers may work when two-way doesn't
- Large clipboard contents may be truncated

For persistent clipboard issues, consider using a native VNC client instead of the noVNC web interface.
