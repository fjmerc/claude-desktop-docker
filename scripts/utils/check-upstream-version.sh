#!/bin/bash
# Compares the pinned CLAUDE_VERSION (claude-desktop.pin) against the newest
# release in Anthropic's official Claude Desktop APT repository.
#
# Usage: check-upstream-version.sh [expected-version]
#   With no argument, reads CLAUDE_VERSION from claude-desktop.pin. Exits 1
#   if upstream differs from it.
#
#        check-upstream-version.sh --upstream-only
#   Prints the upstream version and exits 0 without comparing (used by the
#   auto-bump workflow, which needs the value rather than a pass/fail).
#
#        check-upstream-version.sh --sha256 <amd64|arm64> <version>
#   Prints the SHA256 the repo's Packages index lists for that .deb.
#
# Every mode first checks that the feed is alive. The repo's signed Release
# file carries a Date that Anthropic refreshes when they re-sign (weekly so
# far). If it is older than MAX_FEED_AGE_DAYS, the feed has probably moved,
# and comparing against it would report "up to date" forever — which is
# exactly how the old Windows feed hid a year of releases. Fail loudly instead.
set -euo pipefail

APT_BASE="https://downloads.claude.ai/claude-desktop/apt/stable"
ARCHES="amd64 arm64"
MAX_FEED_AGE_DAYS="${MAX_FEED_AGE_DAYS:-21}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PIN_FILE="$PROJECT_DIR/claude-desktop.pin"

die() { echo "ERROR: $*" >&2; exit 2; }

check_feed_fresh() {
    local date_line released now age
    date_line=$(curl -fsSL "$APT_BASE/dists/stable/Release" | sed -n 's/^Date: //p')
    [ -n "$date_line" ] || die "could not read Date from $APT_BASE/dists/stable/Release"
    released=$(date -d "$date_line" +%s) || die "unparseable Release Date '$date_line'"
    now=$(date +%s)
    age=$(( (now - released) / 86400 ))
    if [ "$age" -gt "$MAX_FEED_AGE_DAYS" ]; then
        echo "ERROR: the Claude Desktop APT feed was last re-signed $age days ago ($date_line)." >&2
        echo "Anthropic may have moved it. Find the current feed before trusting any version check." >&2
        exit 1
    fi
}

# Print "<version> <sha256>" for every claude-desktop entry in one arch's index.
index_entries() {
    curl -fsSL "$APT_BASE/dists/stable/main/binary-$1/Packages" | awk '
        /^Package: / { p = $2 }
        /^Version: / { v = $2 }
        /^SHA256: /  { s = $2 }
        /^$/ { if (p == "claude-desktop" && v != "") print v, s; p = v = s = "" }
        END  { if (p == "claude-desktop" && v != "") print v, s }'
}

# Newest version published for EVERY arch. A release indexed for amd64 but
# not yet arm64 is not shippable as a multi-arch image, so it doesn't count.
upstream_version() {
    local arch common="" versions
    for arch in $ARCHES; do
        versions=$(index_entries "$arch" | cut -d' ' -f1 | sort -u)
        [ -n "$versions" ] || die "no claude-desktop entries in the $arch index"
        if [ -z "$common" ]; then
            common="$versions"
        else
            common=$(comm -12 <(echo "$common") <(echo "$versions"))
        fi
    done
    [ -n "$common" ] || die "no version is published for all of: $ARCHES"
    local latest
    latest=$(echo "$common" | sort -V | tail -1)
    # The index is external data that CI feeds into shell steps, branch names
    # and sed patterns. Refuse anything that isn't a plain X.Y.Z version.
    [[ "$latest" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "upstream version is not X.Y.Z: '$latest'"
    echo "$latest"
}

check_feed_fresh

case "${1:-}" in
    --upstream-only)
        upstream_version
        exit 0
        ;;
    --sha256)
        arch="${2:?usage: --sha256 <arch> <version>}"
        version="${3:?usage: --sha256 <arch> <version>}"
        sha=$(index_entries "$arch" | awk -v v="$version" '$1 == v { print $2 }' | tail -1)
        [ -n "$sha" ] || die "no $arch entry for version $version in the index"
        [[ "$sha" =~ ^[0-9a-f]{64}$ ]] || die "$arch SHA256 in the index is not 64 hex chars: '$sha'"
        echo "$sha"
        exit 0
        ;;
esac

EXPECTED="${1:-}"
if [ -z "$EXPECTED" ]; then
    # shellcheck source=/dev/null
    EXPECTED=$(. "$PIN_FILE" && echo "${CLAUDE_VERSION:-}")
fi
[ -n "$EXPECTED" ] || die "could not determine pinned CLAUDE_VERSION from $PIN_FILE"

UPSTREAM=$(upstream_version)
echo "pinned:   $EXPECTED"
echo "upstream: $UPSTREAM"

if [ "$UPSTREAM" != "$EXPECTED" ]; then
    echo "ERROR: upstream Claude Desktop is $UPSTREAM but this repo pins $EXPECTED." >&2
    echo "A build would still ship the pinned $EXPECTED, not the current $UPSTREAM release." >&2
    echo "Bump via scripts/utils/bump-claude-version.sh <version> <sha256-amd64> <sha256-arm64>, test, then re-tag." >&2
    exit 1
fi

echo "OK: pinned version matches upstream"
