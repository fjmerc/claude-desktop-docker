#!/bin/bash
set -e

# Forward SIGTERM/SIGINT to background children (Claude Desktop, noVNC, VNC)
# so `docker stop` doesn't fall through to a 10s SIGKILL with no chance to flush.
CLAUDE_PID=""
shutdown() {
    [ -n "$CLAUDE_PID" ] && kill -TERM "$CLAUDE_PID" 2>/dev/null || true
    vncserver -kill :1 >/dev/null 2>&1 || true
    exit 0
}
trap shutdown TERM INT

# Make sure necessary environment variables are set
export USER=${USER:-root}
export HOME=${HOME:-/root}

# Set PATH to include all necessary directories
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin:/root/.npm-global/bin:$PATH

# Make sure ~/.vnc directory exists
mkdir -p ~/.vnc /scripts /scripts/utils

# VNC password setup. Priority:
#   1. $VNC_PASSWORD env var (if set, always wins — regenerate the passwd file)
#   2. existing /root/.vnc/passwd in the named volume from a previous boot
#   3. random 16-char password, generated and printed to docker logs
if [ -n "${VNC_PASSWORD:-}" ]; then
    echo "$VNC_PASSWORD" | vncpasswd -f > /root/.vnc/passwd
    chmod 600 /root/.vnc/passwd
    echo "VNC password set from VNC_PASSWORD env var"
elif [ ! -s /root/.vnc/passwd ]; then
    GENERATED_VNC_PASSWORD=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16)
    echo "$GENERATED_VNC_PASSWORD" | vncpasswd -f > /root/.vnc/passwd
    chmod 600 /root/.vnc/passwd
    echo "==================================================================="
    echo "  No VNC password configured. Generated one for this volume:"
    echo
    echo "      $GENERATED_VNC_PASSWORD"
    echo
    echo "  Save it. To set your own, stop the container, set VNC_PASSWORD"
    echo "  in .env (or docker-compose.override.yml), and start again."
    echo "==================================================================="
else
    echo "Reusing existing VNC password from /root/.vnc/passwd"
fi

# Create a default .Xauthority file if it doesn't exist
if [ ! -f $HOME/.Xauthority ]; then
    touch $HOME/.Xauthority
    xauth generate $DISPLAY . trusted
fi

# If scripts directory structure needs setup, create symlinks
if [ ! -f /scripts/utils/verify-dependencies.sh ] && [ -f /startup.sh ]; then
  echo "Creating compatibility symlinks..."
  ln -sf /startup.sh /scripts/
  ln -sf /root/.vnc/xstartup /scripts/utils/
  ln -sf /root/.vnc/config /scripts/utils/
  
  # For backward compatibility
  ln -sf /scripts/utils/xstartup /scripts/
  ln -sf /scripts/utils/config /scripts/
fi

echo "Environment variables:"
echo "USER=$USER"
echo "HOME=$HOME"
echo "DISPLAY=$DISPLAY"

echo "Starting VNC server..."

# Kill existing VNC sessions if any
vncserver -kill :1 >/dev/null 2>&1 || true

# Clean stale state from a previous container instance. `docker restart`
# preserves /tmp inside the container, so previous-instance X lock files,
# X11 sockets, and a stale dbus-session.info would all point at sockets
# whose owning processes are gone. `docker-compose up` recreates the
# container and avoids this; `docker restart` does not.
rm -f /tmp/.X*-lock /tmp/.X11-unix/X* /tmp/dbus-session.info 2>/dev/null || true
rm -rf /tmp/dbus-* 2>/dev/null || true

# Pick the X session based on KIOSK_MODE. Default = full XFCE.
# Truthy values: true / 1 / yes (case-insensitive).
case "${KIOSK_MODE:-}" in
  [Tt]rue|1|[Yy]es|[Oo]n)
    if [ -f /scripts/utils/xstartup-kiosk ]; then
      cp -f /scripts/utils/xstartup-kiosk /root/.vnc/xstartup
      echo "KIOSK_MODE: openbox + Claude (no XFCE panel/desktop)"
    else
      echo "KIOSK_MODE requested but /scripts/utils/xstartup-kiosk missing — falling back to XFCE"
      cp -f /scripts/utils/xstartup /root/.vnc/xstartup
    fi
    ;;
  *)
    cp -f /scripts/utils/xstartup /root/.vnc/xstartup
    ;;
esac
chmod +x /root/.vnc/xstartup
# Start VNC server with correct parameters
export DISPLAY=:1

# Ensure Claude config directory exists
mkdir -p /root/.config/Claude

# TigerVNC vncserver flags. We dropped TightVNC because its compiled-in
# keymap uses non-standard X keycodes (BackSpace at 64, etc.), which
# Chromium-based Electron apps misinterpret — Backspace, arrow keys, and
# others would not work inside Claude. TigerVNC has working XKB and a
# standard keymap. Note the flag differences: TightVNC's -name, -desktop,
# -alwaysshared aren't accepted by tigervncserver. -localhost no is
# required for direct host:5901 connections via Docker's port mapping.
vncserver $DISPLAY -geometry 1920x1080 -depth 24 -rfbport 5901 -SecurityTypes VncAuth -localhost no

# Start noVNC with scaling options enabled
# Explicit subshell so `&` unambiguously backgrounds the entire OR-chain.
if [ -f /usr/share/novnc/utils/launch.sh ]; then
  ( /usr/share/novnc/utils/launch.sh --vnc localhost:5901 --listen 6080 --scale remote || \
    /usr/share/novnc/utils/launch.sh --vnc localhost:5901 --listen 6080 ) &
elif [ -f /usr/share/novnc/utils/novnc_proxy ]; then
  ( /usr/share/novnc/utils/novnc_proxy --vnc localhost:5901 --listen 6080 --scale remote || \
    /usr/share/novnc/utils/novnc_proxy --vnc localhost:5901 --listen 6080 ) &
else
  # Create temporary web configuration for noVNC scaling
  NOVNC_DIR=/usr/share/novnc
  mkdir -p /tmp/novnc_config
  if [ -f $NOVNC_DIR/app/ui.js ]; then
    # Copy and modify UI.js to enable scaling by default
    cp $NOVNC_DIR/app/ui.js /tmp/novnc_config/
    sed -i 's/UI.initSetting("resize", "off");/UI.initSetting("resize", "remote");/g' /tmp/novnc_config/ui.js
    # Start websockify with our modified config
    websockify --web=$NOVNC_DIR --web-path=/tmp/novnc_config/=/usr/share/novnc/app/ 6080 localhost:5901 &
  else
    # Fallback to standard configuration
    websockify --web=/usr/share/novnc 6080 localhost:5901 &
  fi
fi

# Allow noVNC to start up
sleep 3

# Run noVNC customization script to enable scaling by default
if [ -f /scripts/utils/customize-novnc.sh ]; then
  chmod +x /scripts/utils/customize-novnc.sh
  /scripts/utils/customize-novnc.sh
  
  # Create a symlink from the standard noVNC index to our custom page
  if [ -d /usr/share/novnc ]; then
    # If custom page exists, update the default redirect
    if [ -f /tmp/novnc-custom/resize.html ]; then
      # Copy our custom page to the noVNC directory
      cp /tmp/novnc-custom/resize.html /usr/share/novnc/
      # Update index.html to redirect to our scaling page if it's standard
      if grep -q 'window.location = "vnc.html"' /usr/share/novnc/index.html; then
        sed -i 's|window.location = "vnc.html"|window.location = "resize.html"|' /usr/share/novnc/index.html
      fi
    fi
  fi
fi

# Configure file associations for the file manager
if [ -f /scripts/utils/configure-file-associations.sh ]; then
  chmod +x /scripts/utils/configure-file-associations.sh
  /scripts/utils/configure-file-associations.sh
fi

# Ensure Claude configuration directory exists
if [ -f /scripts/utils/ensure-config.sh ]; then
  chmod +x /scripts/utils/ensure-config.sh
  /scripts/utils/ensure-config.sh
fi

echo "========================================================"
echo "VNC server started on port 5901"
echo "noVNC web interface available at: http://localhost:6080/"
echo "========================================================"

# Wait for XFCE to fully initialize
sleep 5

# Check if Claude Desktop is installed
if [ -d "/root/claude-app" ] && [ -x "/root/claude-app/bin/claude-desktop" ]; then
  echo "Starting Claude Desktop..."
  
  # Add electron directories to path if not already included
  which electron >/dev/null 2>&1 || {
    echo "electron not in PATH, adding npm directories"
    export PATH=/root/.npm-global/bin:/usr/local/lib/node_modules/electron/dist:$PATH
  }
  
  echo "Updated PATH: $PATH"
  
  # Set up D-Bus and XDG environment variables if not already done
  if [ -f /scripts/utils/dbus-setup.sh ]; then
    source /scripts/utils/dbus-setup.sh
  fi
  
  # Ensure permissions are correct
  chmod +x /root/claude-app/bin/claude-desktop
  
  # Fix for any xdg-open related errors
  export ELECTRON_DISABLE_SANDBOX=1
  export ELECTRON_NO_ASAR=1
  export ELECTRON_NO_ATTACH_CONSOLE=1
  
  # Change to the claude-app bin directory
  cd /root/claude-app/bin
  
  # Attempt to start Claude Desktop. Sleep before probing so the fork has time
  # to actually exec/exit; the previous immediate ps check was a no-op race.
  echo "Launching claude-desktop application..."
  ./claude-desktop --no-sandbox &
  CLAUDE_PID=$!
  sleep 2

  # Maximize the Claude window once it appears. Electron's first-run window is
  # small and not centered well in 1920x1080; users expect full-screen on a
  # VNC/noVNC display. Background loop, exits as soon as it succeeds or after
  # ~30s of waiting (whichever comes first).
  ( for i in $(seq 1 30); do
      if DISPLAY=:1 wmctrl -l 2>/dev/null | awk '{print $4}' | grep -qx Claude; then
        DISPLAY=:1 wmctrl -r Claude -b add,maximized_vert,maximized_horz 2>/dev/null && break
      fi
      sleep 1
    done ) &

  if ps -p $CLAUDE_PID > /dev/null; then
    echo "Claude Desktop started with PID $CLAUDE_PID"
  else
    echo "Failed to start Claude Desktop with bin/claude-desktop, trying alternative method..."
    # Alternative startup method
    cd /root/claude-app
    if [ -f "electron" ]; then
      ./electron --no-sandbox . &
      CLAUDE_PID=$!
      echo "Started Claude Desktop with ./electron (PID $CLAUDE_PID)"
    else
      electron --no-sandbox . &
      CLAUDE_PID=$!
      echo "Started Claude Desktop with electron command (PID $CLAUDE_PID)"
    fi
  fi
else
  echo "WARNING: Claude Desktop not found or not executable."
  echo "Please build it first by running ./claude.sh build --build-claude"
fi

echo "Container is now running."
echo "Use VNC client or web browser to access the desktop."

# Wait (not tail) so the trap fires promptly on docker stop and forwards
# SIGTERM to Claude Desktop / VNC server before SIGKILL hits.
wait
