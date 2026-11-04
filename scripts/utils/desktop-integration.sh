#!/bin/bash
# Desktop integration for Claude Desktop (run once at image build time).
#
# The official .deb already registers its own Applications-menu entry and
# icons under /usr/share; install-claude-desktop.sh repoints that entry's
# Exec at the root-aware wrapper. All that's left is a clickable icon on the
# XFCE desktop, which shows .desktop files placed in ~/Desktop.
#
# Idempotent — safe to re-run.

set -euo pipefail

ENTRY=/usr/share/applications/com.anthropic.Claude.desktop

if [ ! -f "$ENTRY" ]; then
    echo "desktop-integration: $ENTRY not found (is claude-desktop installed?); skipping" >&2
    exit 0
fi

mkdir -p /root/Desktop
cp -f "$ENTRY" /root/Desktop/claude-desktop.desktop
chmod +x /root/Desktop/claude-desktop.desktop

# Entries left behind by the old converted build would show a second,
# broken "Claude" in the menu.
rm -f /root/.local/share/applications/claude-desktop.desktop

update-desktop-database /usr/share/applications 2>/dev/null || true

echo "desktop-integration: Claude menu entry (from the .deb) + Desktop icon ready"
