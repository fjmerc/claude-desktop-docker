#!/bin/bash
# Boots a built image and waits for VNC, the Claude process, and its window.
# Catches the "the build silently produced a broken image" failure mode
# before anything gets published.
#
# Usage: smoke-test-image.sh <image> [timeout-seconds]
set -euo pipefail

IMAGE="${1:?usage: smoke-test-image.sh <image> [timeout-seconds]}"
TIMEOUT="${2:-90}"
NAME="claude-smoke-$$"

cleanup() { docker rm -f "$NAME" >/dev/null 2>&1 || true; }
trap cleanup EXIT

docker run -d --name "$NAME" --privileged --shm-size 2g "$IMAGE"

# Pass = VNC port open, Claude main process alive, AND a top-level window
# titled "Claude" mapped on the X display. The window check catches an app
# that starts but never renders (wrong deps, crash before first paint).
# Uses bash /dev/tcp so we don't need nc/ncat installed in the image.
vnc_up='exec 3<>/dev/tcp/localhost/5901 2>/dev/null && exec 3<&-'
app_up="pgrep -f '^/usr/(bin|lib/claude-desktop)/claude-desktop' >/dev/null"
win_up="DISPLAY=:1 xwininfo -root -tree 2>/dev/null | grep -q '\"Claude\": ('"
for i in $(seq 1 "$TIMEOUT"); do
    if docker exec "$NAME" bash -c "$vnc_up && $app_up && $win_up" 2>/dev/null; then
        echo "smoke OK after ${i}s"
        exit 0
    fi
    sleep 1
done

yn() { docker exec "$NAME" bash -c "$1" >/dev/null 2>&1 && echo yes || echo no; }
echo "smoke FAILED — VNC up=$(yn "$vnc_up"), app=$(yn "$app_up"), window=$(yn "$win_up")" >&2
docker logs "$NAME" | tail -100
exit 1
