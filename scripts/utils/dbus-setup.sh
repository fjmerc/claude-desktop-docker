#!/bin/bash
# Set up a minimal D-Bus environment to reduce errors

# Create a session D-Bus if it doesn't exist
if [ ! -f /tmp/dbus-session.info ]; then
  # Start a session dbus and save the environment variables
  dbus-launch --sh-syntax > /tmp/dbus-session.info
  echo "D-Bus session initialized"
else
  echo "D-Bus session already initialized"
fi

# Export D-Bus session variables
if [ -f /tmp/dbus-session.info ]; then
  source /tmp/dbus-session.info
  echo "D-Bus environment variables loaded:"
  echo "DBUS_SESSION_BUS_ADDRESS=$DBUS_SESSION_BUS_ADDRESS"
  echo "DBUS_SESSION_BUS_PID=$DBUS_SESSION_BUS_PID"
fi

# Create XDG runtime directory if it doesn't exist
XDG_RUNTIME_DIR="/tmp/xdg-runtime-dir"
if [ ! -d "$XDG_RUNTIME_DIR" ]; then
  mkdir -p "$XDG_RUNTIME_DIR"
  chmod 700 "$XDG_RUNTIME_DIR"
  echo "XDG runtime directory created at $XDG_RUNTIME_DIR"
else
  echo "XDG runtime directory already exists"
fi

# Set essential XDG environment variables
export XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"

# Note: a smarter xdg-open wrapper is created by configure-file-associations.sh
# which runs earlier in startup.sh. Don't clobber it with a silent stub here.

echo "XDG environment setup complete"
