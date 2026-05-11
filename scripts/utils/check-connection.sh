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
if [ -d "/root/claude-app" ]; then
  echo "Claude Desktop is installed at /root/claude-app"
  ls -la /root/claude-app
else
  echo "Claude Desktop is not installed yet"
fi

echo
echo "=== Dependency Check ==="
bash /scripts/verify-dependencies.sh

echo
echo "=== Network Ports ==="
netstat -tulpn | grep -E '5901|6080'
