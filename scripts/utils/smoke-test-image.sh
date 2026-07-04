#!/bin/bash
# Boots a built image and waits for VNC + an Electron process to come up.
# Catches the "Anthropic restructured their installer and the build silently
# produced a broken image" failure mode before anything gets published.
#
# Usage: smoke-test-image.sh <image> [timeout-seconds]
set -euo pipefail

IMAGE="${1:?usage: smoke-test-image.sh <image> [timeout-seconds]}"
TIMEOUT="${2:-60}"
NAME="claude-smoke-$$"

cleanup() { docker rm -f "$NAME" >/dev/null 2>&1 || true; }
trap cleanup EXIT

docker run -d --name "$NAME" --privileged --shm-size 2g "$IMAGE"

# Uses bash /dev/tcp so we don't need nc/ncat installed in the image.
check='exec 3<>/dev/tcp/localhost/5901 2>/dev/null && exec 3<&- && pgrep -f "electron.*app.asar" >/dev/null'
for i in $(seq 1 "$TIMEOUT"); do
    if docker exec "$NAME" bash -c "$check" 2>/dev/null; then
        echo "smoke OK after ${i}s"
        exit 0
    fi
    sleep 1
done

vnc=$(docker exec "$NAME" bash -c 'exec 3<>/dev/tcp/localhost/5901 2>/dev/null && exec 3<&- && echo yes || echo no')
elec=$(docker exec "$NAME" bash -c 'pgrep -f "electron.*app.asar" >/dev/null && echo yes || echo no')
echo "smoke FAILED — VNC up=$vnc, electron=$elec" >&2
docker logs "$NAME" | tail -100
exit 1
