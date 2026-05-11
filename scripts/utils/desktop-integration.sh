#!/bin/bash
# Slim desktop integration for Claude Desktop (run once, post-build).
#
# We deliberately don't re-extract the tarball into ~/.local/claude-desktop/
# the way the upstream install.sh does — that's a ~150MB duplicate of files
# that already live at /root/claude-app/. Instead, just register the launcher
# with XDG so it shows up in the XFCE Applications menu and as a clickable
# Desktop icon. Costs about 10 KB.
#
# Idempotent — safe to run on every container build / start.

set -euo pipefail

APP_DIR="${APP_INSTALL_DIR:-/root/claude-app}"
LAUNCHER="$APP_DIR/bin/claude-desktop"

if [ ! -x "$LAUNCHER" ]; then
    echo "desktop-integration: $LAUNCHER not found or not executable; skipping" >&2
    exit 0
fi

# 1. PATH access
ln -sf "$LAUNCHER" /usr/local/bin/claude-desktop

# 2. Icons
mkdir -p /root/.local/share/icons
if [ -d "$APP_DIR/share/icons" ]; then
    cp -rf "$APP_DIR/share/icons/." /root/.local/share/icons/ 2>/dev/null || true
fi

# 3. .desktop file. The launcher script auto-detects root and adds
# --no-sandbox, so we don't need to pass it here. (If we did, a non-root
# install reusing this .desktop would lose its sandbox.)
mkdir -p /root/.local/share/applications /root/Desktop
cat > /root/.local/share/applications/claude-desktop.desktop <<EOF
[Desktop Entry]
Name=Claude
Comment=Claude AI Assistant
Exec=$LAUNCHER %u
Icon=claude
Type=Application
Terminal=false
Categories=Office;Utility;Network;
Keywords=AI;Assistant;Claude;Chat;
MimeType=x-scheme-handler/claude;
StartupWMClass=Claude
StartupNotify=true
EOF
chmod +x /root/.local/share/applications/claude-desktop.desktop

# 4. Desktop shortcut (XFCE shows .desktop files placed in ~/Desktop)
cp -f /root/.local/share/applications/claude-desktop.desktop /root/Desktop/
chmod +x /root/Desktop/claude-desktop.desktop

# 5. Refresh XDG database (best-effort)
update-desktop-database /root/.local/share/applications 2>/dev/null || true

echo "desktop-integration: registered Claude launcher + Applications-menu entry + Desktop icon"
