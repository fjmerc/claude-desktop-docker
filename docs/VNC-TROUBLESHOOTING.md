# VNC Server Troubleshooting for Claude Desktop Docker

This document provides information about common VNC server issues and their solutions for the Claude Desktop Docker implementation.

## Common Issues

### 0. Unrecognized Option Error

**Symptoms:**
```
Unrecognized option: no
```

**Solution:**
This occurs with TightVNC 1.3.10 because it doesn't understand the `-localhost no` syntax. After examining the TightVNC help text, we can see that `-localhost` is a standalone flag meaning "only allow connections from localhost" - it doesn't accept a value like "no".

The correct solution is:

1. Remove `localhost=no` from the VNC config file (~/.vnc/config)
2. Remove the `-localhost no` parameter from the vncserver command
3. By default, TightVNC accepts remote connections, so we don't need any special parameters

**Correct command syntax:**
```bash
vncserver :1 -geometry 1280x800 -depth 24 -name "Claude Desktop VNC"
```

**Note:** If you wanted to restrict to localhost only, you would add the `-localhost` flag without any value.

### 1. Missing `.Xauthority` File

**Symptoms:**
```
xauth: file /root/.Xauthority does not exist
```

**Solution:**
The `.Xauthority` file is needed for X11 authentication. It can be created with:

```bash
touch $HOME/.Xauthority
chmod 600 $HOME/.Xauthority
xauth generate $DISPLAY . trusted
```

This has been added to the startup scripts in the latest version.

### 2. Font Path Issues

**Symptoms:**
```
Couldn't start Xtightvnc; trying default font path.
Please set correct fontPath in the vncserver script.
```

**Solution:**
Install the required font packages:

```bash
apt-get update && apt-get install -y xfonts-base xfonts-75dpi xfonts-100dpi
```

These packages are now included in the Dockerfile and startup script.

### 3. VNC Server Won't Start

**Symptoms:**
```
Couldn't start Xtightvnc process.
```

**Solution:**
Ensure DISPLAY is properly set and VNC server is started with correct parameters:

```bash
export DISPLAY=:1
vncserver $DISPLAY -localhost no -geometry 1280x800 -depth 24
```

## Applied Fixes

The following fixes have been implemented in the latest version:

1. Added missing font packages in the Dockerfile
2. Created the `.Xauthority` file in startup and xstartup scripts
3. Enhanced VNC server startup with explicit parameters
4. Added fallback to xterm if XFCE is not available
5. Created a `fix-vnc-issues.sh` script to apply all changes

## Verification

To verify that VNC is working correctly:

1. Run `docker logs claude-desktop` and confirm no errors
2. Check if VNC process is running with `docker exec claude-desktop ps aux | grep Xvnc`
3. Try connecting with a VNC client to localhost:5901 (password: claude_desktop)
4. Open a web browser and go to http://localhost:6080/

## Manual Recovery

If you're still experiencing issues, you can manually fix them by running:

```bash
./scripts/fix-vnc-issues.sh
```

This script will:
- Rebuild the Docker image with the fixes
- Restart the container
- Verify VNC server is running correctly

## Checking Container Status

```bash
# View container logs
docker logs claude-desktop

# Check running processes inside container
docker exec claude-desktop ps aux

# Access container shell
docker exec -it claude-desktop bash
```
