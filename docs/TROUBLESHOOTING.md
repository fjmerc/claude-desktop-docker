# Troubleshooting Claude Desktop in Docker

This document provides solutions for common issues that may occur when running Claude Desktop in a Docker container.

## Issue: Installation Requires User Input

**Symptoms:**
- Build process stops with a prompt asking to select installation type (user or system-wide)
- Installation fails with "Invalid option. Installation aborted"

**Solution:**
The `fix-install-prompts.sh` script automatically selects the user installation option without requiring interaction. This should be applied as part of the build process. If issues persist, you can manually run:

```bash
docker exec claude-desktop bash /scripts/fix-install-prompts.sh
docker exec claude-desktop bash -c "cd /root/claude-desktop-scripts && ./install.sh"
```

## Issue: D-Bus Connection Errors

**Symptoms:**
- "Unable to contact settings server" error
- "Failed to execute child process 'dbus-launch'" message

**Solution:**
The `fix-dbus.sh` script installs and configures D-Bus for the container environment. If the issue persists, you can manually run:

```bash
docker exec claude-desktop bash /scripts/fix-dbus.sh
docker exec claude-desktop bash -c "export $(dbus-launch)"
```

## Issue: Desktop Entry and Icon Errors

**Symptoms:**
- "Cannot stat '~/.local/claude-desktop/share/applications/claude-desktop.desktop'" error
- Missing icons in the application launcher

**Solution:**
The `fix-desktop-paths.sh` script copies desktop entries and icons to the expected locations. If the issue persists, you can manually run:

```bash
docker exec claude-desktop bash /scripts/fix-desktop-paths.sh
```

## Issue: Electron Sandbox Errors

**Symptoms:**
- "Running as root without --no-sandbox is not supported" error
- Electron application fails to launch
- SIGTRAP signal mentioned in error messages

**Solution:**
The `fix-electron-sandbox.sh` script modifies the Claude Desktop launcher to include the `--no-sandbox` flag. If the issue persists, you can manually run:

```bash
docker exec claude-desktop bash /scripts/fix-electron-sandbox.sh
docker exec claude-desktop bash /scripts/launch-claude.sh
```

## Issue: VNC Connection Problems

**Symptoms:**
- Cannot connect to the VNC server
- Connection refused errors

**Solution:**
The `fix-vnc.sh` script resolves common VNC connection issues. Run:

```bash
./claude.sh fix-vnc
```

## Manual Container Access

For advanced troubleshooting, you can access the container's shell:

```bash
./claude.sh shell
```

Once inside, you can:
- Check log files: `ls -la /root/.local/share/Claude/logs/`
- Verify installation: `ls -la /root/claude-app/`
- Test launching manually: `cd /root/claude-app/bin && ./claude-desktop --no-sandbox`

## Rebuilding from Scratch

If you want to start completely fresh:

```bash
./claude.sh stop
docker-compose down -v  # Removes containers and volumes
./claude.sh build --clean
```

## Getting Help

If none of these solutions resolve your issue, please:
1. Collect logs: `./claude.sh logs > claude-logs.txt`
2. Run diagnostic info: `docker exec claude-desktop bash /scripts/diagnostic-info.sh > diagnostic-info.txt`
3. Submit these files along with a description of your issue
