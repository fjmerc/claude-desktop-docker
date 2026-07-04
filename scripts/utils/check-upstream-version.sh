#!/bin/bash
# Compares the pinned CLAUDE_VERSION against the newest full release in
# Anthropic's Squirrel RELEASES manifest. The installer URL in
# build-claude.sh is unversioned (always the latest .exe), so a mismatch
# means a build would ship a different version than its label/tag claims.
#
# Usage: check-upstream-version.sh [expected-version]
#   With no argument, reads CLAUDE_VERSION from build-claude.sh.
set -euo pipefail

RELEASES_URL="https://storage.googleapis.com/osprey-downloads-c02f6a0d-347c-492b-a752-3e0651722e97/nest-win-x64/RELEASES"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

EXPECTED="${1:-}"
if [ -z "$EXPECTED" ]; then
    EXPECTED=$(sed -nE 's/^CLAUDE_VERSION="([0-9.]+)"/\1/p' \
        "$PROJECT_DIR/claude-linux-desktop-build/build-claude.sh")
fi
if [ -z "$EXPECTED" ]; then
    echo "ERROR: could not determine pinned CLAUDE_VERSION" >&2
    exit 2
fi

UPSTREAM=$(curl -fsSL "$RELEASES_URL" | grep -- '-full.nupkg' | tail -1 \
    | sed -E 's/.*AnthropicClaude-([0-9.]+)-full\.nupkg.*/\1/')
if [ -z "$UPSTREAM" ]; then
    echo "ERROR: could not parse upstream version from RELEASES manifest" >&2
    exit 2
fi

echo "pinned:   $EXPECTED"
echo "upstream: $UPSTREAM"

if [ "$UPSTREAM" != "$EXPECTED" ]; then
    echo "ERROR: upstream Claude Desktop is $UPSTREAM but this repo pins $EXPECTED." >&2
    echo "The installer download is unversioned, so a build now would ship $UPSTREAM labeled as $EXPECTED." >&2
    echo "Bump CLAUDE_VERSION in claude-linux-desktop-build/build-claude.sh, test, then re-tag." >&2
    exit 1
fi

echo "OK: pinned version matches upstream"
