#!/bin/bash

echo "=== Environment Variables ==="
echo "USER=$USER"
echo "HOME=$HOME"
echo "DISPLAY=$DISPLAY"
echo

echo "=== VNC Files ==="
ls -la /root/.vnc/
echo

echo "=== VNC Configuration ==="
cat /root/.vnc/config
echo

echo "=== VNC Server Status ==="
vncserver -list

echo "Checking if noVNC is running..."
ps aux | grep novnc

echo "Checking if Claude Desktop is installed..."
if v=$(dpkg-query -W -f='${Version}' claude-desktop 2>/dev/null); then
  echo "Claude Desktop $v is installed (/usr/lib/claude-desktop)"
else
  echo "Claude Desktop is not installed in this image"
fi

echo
echo "=== Dependency Check ==="
bash /scripts/verify-dependencies.sh

echo
echo "=== Network Ports ==="
netstat -tulpn | grep -E '5901|6080'
