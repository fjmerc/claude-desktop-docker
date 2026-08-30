#!/bin/bash
# Compares the pinned CLAUDE_VERSION against the newest full release in
# Anthropic's Squirrel RELEASES manifest. The download URL in build-claude.sh
# is a versioned nupkg, so a mismatch means the pin is outdated — a build
# would ship an older Claude than upstream's current release.
#
# Usage: check-upstream-version.sh [expected-version]
#   With no argument, reads CLAUDE_VERSION from build-claude.sh.
#
#        check-upstream-version.sh --upstream-only
#   Prints the upstream version and exits 0 without comparing (used by the
#   auto-bump workflow, which needs the value rather than a pass/fail).
set -euo pipefail

RELEASES_URL="https://storage.googleapis.com/osprey-downloads-c02f6a0d-347c-492b-a752-3e0651722e97/nest-win-x64/RELEASES"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

UPSTREAM_ONLY=0
if [ "${1:-}" = "--upstream-only" ]; then
    UPSTREAM_ONLY=1
    shift
fi

EXPECTED="${1:-}"
if [ "$UPSTREAM_ONLY" -eq 0 ]; then
    if [ -z "$EXPECTED" ]; then
        EXPECTED=$(sed -nE 's/^CLAUDE_VERSION="([0-9.]+)"/\1/p' \
            "$PROJECT_DIR/claude-linux-desktop-build/build-claude.sh")
    fi
    if [ -z "$EXPECTED" ]; then
        echo "ERROR: could not determine pinned CLAUDE_VERSION" >&2
        exit 2
    fi
fi

UPSTREAM=$(curl -fsSL "$RELEASES_URL" | grep -- '-full.nupkg' | tail -1 \
    | sed -E 's/.*AnthropicClaude-([0-9.]+)-full\.nupkg.*/\1/')
if [ -z "$UPSTREAM" ]; then
    echo "ERROR: could not parse upstream version from RELEASES manifest" >&2
    exit 2
fi

if [ "$UPSTREAM_ONLY" -eq 1 ]; then
    echo "$UPSTREAM"
    exit 0
fi

echo "pinned:   $EXPECTED"
echo "upstream: $UPSTREAM"

if [ "$UPSTREAM" != "$EXPECTED" ]; then
    echo "ERROR: upstream Claude Desktop is $UPSTREAM but this repo pins $EXPECTED." >&2
    echo "A build would still ship the pinned $EXPECTED, not the current $UPSTREAM release." >&2
    echo "Bump via scripts/utils/bump-claude-version.sh <version> <sha256>, test, then re-tag." >&2
    exit 1
fi

echo "OK: pinned version matches upstream"
