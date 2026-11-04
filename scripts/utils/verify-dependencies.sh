#!/bin/bash
# Verifies, inside the container, that Claude Desktop and the desktop/VNC
# stack it runs on are present.

ok=0
check() {  # check <label> <command...>
    local label="$1"; shift
    if out=$("$@" 2>/dev/null); then
        echo "✅ $label${out:+: $out}"
    else
        echo "❌ $label: missing"
        ok=1
    fi
}

echo "=== Claude Desktop ==="
check "claude-desktop package" dpkg-query -W -f='${Version}' claude-desktop
check "launcher wrapper" sh -c 'test -x /usr/local/bin/claude-desktop && echo /usr/local/bin/claude-desktop'
check "app binary" sh -c 'test -x /usr/lib/claude-desktop/claude-desktop && echo /usr/lib/claude-desktop/claude-desktop'

echo
echo "=== Desktop / VNC stack ==="
for cmd in Xvnc vncserver websockify startxfce4 openbox dbus-daemon wmctrl xwininfo autocutsel; do
    check "$cmd" command -v "$cmd"
done

echo
echo "=== MCP tooling ==="
check "node" node --version
check "npx" command -v npx
check "git" command -v git
check "mcp-server-git" python3 -c 'import mcp_server_git; print("installed")'

echo
echo "=== System Info ==="
echo "Distribution: $(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d \")"
echo "Architecture: $(uname -m)"
echo "Memory: $(free -h | awk '/Mem/ {print $2}')"
echo "Disk space: $(df -h / | tail -1 | awk '{print $4}') available"

if [ "$ok" -ne 0 ]; then
    echo
    echo "Some components are missing. Rebuild the image: ./claude.sh build --clean"
fi
exit "$ok"
