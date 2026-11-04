#!/bin/bash
# Bumps the pinned Claude Desktop version everywhere it appears in the repo.
#
# Usage: bump-claude-version.sh <new-version> <sha256-amd64> <sha256-arm64>
#
# Rewrites claude-desktop.pin (version + both per-arch .deb hashes), then
# replaces the old version string in every other tracked file that mentions
# it (docs, examples) — except .github/, which CI's GITHUB_TOKEN is not
# allowed to modify (the workflows read the pin file instead of hardcoding
# the version, so they never need bumping).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PIN_FILE="$PROJECT_DIR/claude-desktop.pin"

usage() { echo "Usage: bump-claude-version.sh <new-version> <sha256-amd64> <sha256-arm64>" >&2; exit 2; }

NEW_VERSION="${1:-}"
NEW_AMD64="${2:-}"
NEW_ARM64="${3:-}"

[[ "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "ERROR: <new-version> must look like X.Y.Z, got '$NEW_VERSION'" >&2; usage; }
for h in "$NEW_AMD64" "$NEW_ARM64"; do
    [[ "$h" =~ ^[0-9a-f]{64}$ ]] || { echo "ERROR: each sha256 must be 64 lowercase hex chars, got '$h'" >&2; usage; }
done

# shellcheck source=/dev/null
OLD_VERSION=$(. "$PIN_FILE" && echo "${CLAUDE_VERSION:-}")
[ -n "$OLD_VERSION" ] || { echo "ERROR: could not read CLAUDE_VERSION from $PIN_FILE" >&2; exit 2; }

sed -i -E \
    -e "s|^CLAUDE_VERSION=\"[^\"]*\"|CLAUDE_VERSION=\"$NEW_VERSION\"|" \
    -e "s|^CLAUDE_SHA256_AMD64=\"[^\"]*\"|CLAUDE_SHA256_AMD64=\"$NEW_AMD64\"|" \
    -e "s|^CLAUDE_SHA256_ARM64=\"[^\"]*\"|CLAUDE_SHA256_ARM64=\"$NEW_ARM64\"|" \
    "$PIN_FILE"

if [ "$OLD_VERSION" = "$NEW_VERSION" ]; then
    echo "version already $NEW_VERSION; only the hashes were updated"
    exit 0
fi

cd "$PROJECT_DIR"
OLD_RE=${OLD_VERSION//./\\.}
git grep -lF "$OLD_VERSION" -- ':!.github' ':!claude-desktop.pin' | while read -r f; do
    sed -i "s/$OLD_RE/$NEW_VERSION/g" "$f"
    echo "updated: $f"
done

echo "bumped $OLD_VERSION -> $NEW_VERSION"
