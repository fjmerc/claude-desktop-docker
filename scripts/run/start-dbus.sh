#!/bin/bash

# Start the D-Bus session daemon
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    eval $(dbus-launch --sh-syntax)
    echo "D-Bus session started at $DBUS_SESSION_BUS_ADDRESS"
fi

# Start the default command or the command specified
exec "$@"
