#!/bin/bash
# Wipe Claude Desktop's session state in the persisted config volume so the
# app boots into the email-entry login screen. Useful when:
#   - You're switching accounts.
#   - The login flow is stuck on a stale verification-code screen.
#   - The persisted state is corrupted.
#
# Doesn't touch the build cache, app binary, or MCP server config — just the
# Cookies / Local Storage / Session Storage / IndexedDB that hold session
# tokens.

set -e

show_help() {
    echo "Claude Desktop Docker - Login Reset"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --no-restart    Wipe session state but don't restart the container"
    echo "  --help          Show this help message"
    echo ""
    echo "Removes Cookies, Local/Session Storage, and IndexedDB from"
    echo "/root/.config/Claude/ so Claude Desktop boots fresh on next launch."
}

NO_RESTART=false
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --no-restart) NO_RESTART=true ;;
        --help) show_help; exit 0 ;;
        *) echo "Unknown parameter: $1"; show_help; exit 1 ;;
    esac
    shift
done

if ! docker ps -a --format '{{.Names}}' | grep -qx claude-desktop; then
    echo "Error: claude-desktop container does not exist."
    echo "Run './claude.sh build' first."
    exit 1
fi

echo "=== Wiping Claude Desktop session state ==="
docker exec claude-desktop bash -c '
    rm -rf "/root/.config/Claude/Cookies" \
           "/root/.config/Claude/Cookies-journal" \
           "/root/.config/Claude/Local Storage" \
           "/root/.config/Claude/Session Storage" \
           "/root/.config/Claude/IndexedDB" \
           "/root/.config/Claude/SingletonCookie" \
           "/root/.config/Claude/SingletonLock" \
           "/root/.config/Claude/SingletonSocket" 2>/dev/null
    echo "session state removed"
' || {
    echo "Note: container was not running; state still wiped from the volume."
    docker run --rm -v claude-desktop-docker_config:/v alpine sh -c '
        rm -rf "/v/Cookies" "/v/Cookies-journal" "/v/Local Storage" \
               "/v/Session Storage" "/v/IndexedDB" \
               "/v/SingletonCookie" "/v/SingletonLock" "/v/SingletonSocket"
    '
}

if [ "$NO_RESTART" = false ]; then
    echo "=== Restarting container ==="
    docker restart claude-desktop >/dev/null
    echo "Done. Connect to noVNC and you'll land on the email-entry screen."
else
    echo "Done. Restart the container (or close Claude inside it) to see the fresh login screen."
fi
