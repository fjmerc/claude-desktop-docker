#!/bin/bash
# Bumps the pinned Claude Desktop version everywhere it appears in the repo.
#
# Usage: bump-claude-version.sh <new-version> <new-sha256>
#
# Reads the current CLAUDE_VERSION from build-claude.sh, re-pins
# CLAUDE_SHA256, then replaces the old version string in every tracked file
# that mentions it — except .github/, which CI's GITHUB_TOKEN is not allowed
# to modify (the workflows read the pin from build-claude.sh instead of
# hardcoding it, so they never need bumping).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_SH="$PROJECT_DIR/claude-linux-desktop-build/build-claude.sh"

NEW_VERSION="${1:-}"
NEW_SHA256="${2:-}"

if ! [[ "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "ERROR: <new-version> must look like X.Y.Z, got '$NEW_VERSION'" >&2
    echo "Usage: bump-claude-version.sh <new-version> <new-sha256>" >&2
    exit 2
fi
if ! [[ "$NEW_SHA256" =~ ^[0-9a-f]{64}$ ]]; then
    echo "ERROR: <new-sha256> must be 64 lowercase hex chars" >&2
    echo "Usage: bump-claude-version.sh <new-version> <new-sha256>" >&2
    exit 2
fi

OLD_VERSION=$(sed -nE 's/^CLAUDE_VERSION="([0-9.]+)"/\1/p' "$BUILD_SH")
if [ -z "$OLD_VERSION" ]; then
    echo "ERROR: could not read CLAUDE_VERSION from $BUILD_SH" >&2
    exit 2
fi

sed -i -E "s|^CLAUDE_SHA256=\"[0-9a-f]*\"|CLAUDE_SHA256=\"$NEW_SHA256\"|" "$BUILD_SH"

if [ "$OLD_VERSION" = "$NEW_VERSION" ]; then
    echo "version already $NEW_VERSION; only CLAUDE_SHA256 updated"
    exit 0
fi

cd "$PROJECT_DIR"
OLD_RE=${OLD_VERSION//./\\.}
git grep -lF "$OLD_VERSION" -- ':!.github' | while read -r f; do
    sed -i "s/$OLD_RE/$NEW_VERSION/g" "$f"
    echo "updated: $f"
done

echo "bumped $OLD_VERSION -> $NEW_VERSION (sha256 $NEW_SHA256)"
