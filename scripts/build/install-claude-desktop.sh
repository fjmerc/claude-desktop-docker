#!/bin/bash
# Installs Anthropic's official Claude Desktop .deb at image build time.
#
# Usage: install-claude-desktop.sh <pin-file>
#
# Downloads the version pinned in claude-desktop.pin for this image's
# architecture, refuses it unless its SHA256 matches the pin, installs it with
# apt (which pulls in the package's declared runtime dependencies), then puts
# a root-aware wrapper at /usr/local/bin/claude-desktop. That directory comes
# before /usr/bin on PATH, so every launch path (startup.sh, kiosk autostart,
# menu entry, Desktop icon) goes through the wrapper.
set -euo pipefail

PIN_FILE="${1:?usage: install-claude-desktop.sh <pin-file>}"
# shellcheck source=/dev/null
. "$PIN_FILE"

APT_BASE="https://downloads.claude.ai/claude-desktop/apt/stable"
ARCH="$(dpkg --print-architecture)"
case "$ARCH" in
    amd64) SHA256="$CLAUDE_SHA256_AMD64" ;;
    arm64) SHA256="$CLAUDE_SHA256_ARM64" ;;
    *) echo "ERROR: Anthropic publishes no Claude Desktop .deb for '$ARCH'" >&2; exit 1 ;;
esac

DEB="claude-desktop_${CLAUDE_VERSION}_${ARCH}.deb"
URL="$APT_BASE/pool/main/c/claude-desktop/$DEB"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Downloading Claude Desktop $CLAUDE_VERSION ($ARCH)..."
# The repo's index can briefly run ahead of its CDN, so retry before failing.
curl -fsSL --retry 5 --retry-delay 15 --retry-all-errors -o "$TMP/$DEB" "$URL"

echo "Verifying SHA256..."
if ! echo "$SHA256  $TMP/$DEB" | sha256sum -c - >/dev/null; then
    echo "ERROR: SHA256 mismatch for $DEB" >&2
    echo "  expected: $SHA256" >&2
    echo "  actual:   $(sha256sum "$TMP/$DEB" | cut -d' ' -f1)" >&2
    exit 1
fi

apt-get update
apt-get install -y --no-install-recommends "$TMP/$DEB"
apt-get clean
rm -rf /var/lib/apt/lists/*

# Chromium cannot use its sandbox as root, which is how the container runs.
# Add --no-sandbox only in that case so a non-root user keeps the sandbox.
cat > /usr/local/bin/claude-desktop <<'EOF'
#!/bin/bash
flags=()
[ "$(id -u)" -eq 0 ] && flags+=(--no-sandbox)
exec /usr/bin/claude-desktop "${flags[@]}" "$@"
EOF
chmod 755 /usr/local/bin/claude-desktop

# The package's menu entry runs a bare "claude-desktop" (4.4212.0), which only
# reaches the wrapper while /usr/local/bin precedes /usr/bin on PATH. Pin it
# to the wrapper by absolute path, whichever form a future .deb uses.
for f in /usr/share/applications/com.anthropic.Claude.desktop; do
    [ -f "$f" ] && sed -i -E 's#^(Exec=)(/usr/bin/)?claude-desktop( |$)#\1/usr/local/bin/claude-desktop\3#' "$f"
done

echo "Installed Claude Desktop $(dpkg-query -W -f='${Version}' claude-desktop)"
