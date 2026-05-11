#!/bin/bash
# Script to fix dbus-launch missing issue in Docker container

set -e  # Exit on any error

echo "=== Installing dbus and fixing configuration ==="

# Install dbus packages
apt-get update
apt-get install -y --no-install-recommends dbus dbus-x11

# Create a dbus launch script
mkdir -p /scripts/utils
cat > /scripts/utils/start-dbus.sh << 'EOF'
#!/bin/bash

# Start the D-Bus session daemon
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    eval $(dbus-launch --sh-syntax)
    echo "D-Bus session started at $DBUS_SESSION_BUS_ADDRESS"
fi

# Start the default command or the command specified
exec "$@"
EOF

# Make it executable
chmod +x /scripts/utils/start-dbus.sh

# Modify startup.sh to include dbus
STARTUP_SCRIPT="/startup.sh"
if [ -f "$STARTUP_SCRIPT" ]; then
    # Back up the original startup script
    cp "$STARTUP_SCRIPT" "${STARTUP_SCRIPT}.bak"
    
    # Find the line where VNC server is started
    VNC_LINE=$(grep -n "vncserver \$DISPLAY" "$STARTUP_SCRIPT" | cut -d: -f1)
    
    if [ -n "$VNC_LINE" ]; then
        # Insert dbus-launch before VNC server start
        sed -i "${VNC_LINE}i# Start D-Bus session daemon\nif [ -z \"\$DBUS_SESSION_BUS_ADDRESS\" ]; then\n  eval \$(dbus-launch --sh-syntax)\n  echo \"D-Bus session started at \$DBUS_SESSION_BUS_ADDRESS\"\nfi" "$STARTUP_SCRIPT"
        echo "✅ Modified startup script to include D-Bus initialization"
    else
        echo "❌ Could not find VNC server start line in startup script"
    fi
else
    echo "❌ Startup script not found at ${STARTUP_SCRIPT}"
fi

# Configure XFCE to use D-Bus
mkdir -p /root/.config/xfce4/xfconf/xfce-perchannel-xml/
cat > /root/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-session.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-session" version="1.0">
  <property name="general" type="empty">
    <property name="FailsafeSessionName" type="string" value="Failsafe"/>
    <property name="LockCommand" type="string" value=""/>
  </property>
  <property name="sessions" type="empty">
    <property name="Failsafe" type="empty">
      <property name="IsFailsafe" type="bool" value="true"/>
      <property name="Count" type="int" value="5"/>
      <property name="Client0_Command" type="array">
        <value type="string" value="xfwm4"/>
      </property>
      <property name="Client1_Command" type="array">
        <value type="string" value="xfsettingsd"/>
      </property>
      <property name="Client2_Command" type="array">
        <value type="string" value="xfce4-panel"/>
      </property>
      <property name="Client3_Command" type="array">
        <value type="string" value="Thunar"/>
        <value type="string" value="--daemon"/>
      </property>
      <property name="Client4_Command" type="array">
        <value type="string" value="xfdesktop"/>
      </property>
    </property>
  </property>
</channel>
EOF

echo "✅ XFCE configured to work with D-Bus"
echo "✅ D-Bus installation and configuration complete"
