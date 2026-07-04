# Claude Desktop in Docker

Run Anthropic's **Claude Desktop** (the native Electron app) on Linux, headless,
inside a Docker container. The Windows installer is repacked into a Linux
Electron app at build time; the app runs under XFCE on a virtual display
served over **VNC** and a **noVNC** web interface, so you can connect from
any browser on any device — laptop, phone, work machine — to the same
persistent Claude session.

Why? Anthropic ships Claude Desktop only for Windows and macOS. There is no
official Linux build. And the desktop app exposes the local **MCP server**
ecosystem in a way the web app at claude.ai doesn't. Running it in Docker
lets you keep one Claude that lives on your server, sees your files via MCP,
and follows you across devices.

## Quick start

### Run the prebuilt image from Docker Hub (fastest)

```bash
docker run -d --name claude-desktop \
  --privileged --shm-size=2g \
  -p 5901:5901 -p 6080:6080 \
  -v claude-config:/root/.config/Claude \
  fjmerc/claude-desktop:latest
```

Multi-arch (`linux/amd64`, `linux/arm64`). Then open `http://localhost:6080/` and check `docker logs claude-desktop` for the auto-generated VNC password.

### Build from source

```bash
git clone https://github.com/fjmerc/claude-desktop-docker.git
cd claude-desktop-docker

./claude.sh setup          # one-time: chmod and verify Docker is installed
./claude.sh build          # build image and Claude Desktop, ~10–15 min cold
```

When the container starts for the first time, watch `docker logs` for the
generated VNC password:

```
======================================================================
  No VNC password configured. Generated one for this volume:

      <16-char-password>

  Save it. To set your own, stop the container, set VNC_PASSWORD
  in .env (or docker-compose.override.yml), and start again.
======================================================================
```

Then open:

```
http://localhost:6080/
```

Sign in with your Anthropic account using the email-code flow (no browser
required for OAuth — the desktop app handles email verification in-window).

## Managing a source build

These commands assume you cloned the repo and ran `./claude.sh build` above. If
you ran the prebuilt image with `docker run` instead, use plain `docker`
commands (`docker start claude-desktop`, `docker stop claude-desktop`,
`docker exec -it claude-desktop bash`, `docker logs -f claude-desktop`).

```bash
./claude.sh start           # docker-compose up -d (auto-launches Claude if built)
./claude.sh stop
./claude.sh restart
./claude.sh shell           # exec bash in container
./claude.sh logs            # tail container logs
./claude.sh status          # container + Claude Desktop health
./claude.sh login-reset     # wipe Claude session state and restart
./claude.sh fix-vnc         # multi-strategy VNC repair
./claude.sh distribute      # create a shareable tarball

# Multi-arch publish
./claude.sh dockerhub check --verbose
./claude.sh dockerhub build --platforms linux/amd64,linux/arm64
./claude.sh dockerhub push --version 0.14.10
```

## Configuration via .env / docker-compose.override.yml

The repo ships `.env.example` and `docker-compose.override.yml.example`.
Copy whichever fits and edit:

```bash
cp .env.example .env                                       # or
cp docker-compose.override.yml.example docker-compose.override.yml
```

Both are gitignored. Variables you'll likely set:

| Variable | What | Default |
|---|---|---|
| `VNC_PASSWORD` | Pin a password instead of the auto-generated random one | empty (random) |
| `VNC_PORT` | Host port mapped to container's 5901 | `5901` |
| `NOVNC_PORT` | Host port mapped to container's 6080 | `6080` |
| `KIOSK_MODE` | `true` = minimal openbox + Claude only (no XFCE panel/desktop). `Ctrl+Alt+C` relaunches Claude if you close it (`Super+C` also works from native VNC clients; browsers' host OS usually swallows Super-key combos). | unset (full XFCE) |
| `CLAUDE_AUTO_RESTART` | `0`/`false` disables the watchdog that relaunches Claude whenever it exits (quit, crash, in-app update). Gives up after 5 crash-loop exits. No effect in kiosk mode. | on |

Note: clicking the window's X hides Claude to the tray rather than quitting it,
so the watchdog (correctly) does nothing. To bring the window back without
restarting anything:

```bash
docker exec -d -e DISPLAY=:1 -e ELECTRON_DISABLE_SANDBOX=1 -e ELECTRON_NO_ASAR=1 \
    claude-desktop /root/claude-app/bin/claude-desktop --no-sandbox
```

Electron's single-instance lock hands the invocation to the running app, which
re-shows its window. The same command also works after a full quit if the
watchdog is disabled or has given up.

Bind mounts (only via the override file) for the most common personal-data
patterns: a host directory exposed to Claude (mounted at `/data` inside the
container in the shipped example — you can pick any in-container path), and
the `claude_desktop_config.json` MCP-server config file. See
`docker-compose.override.yml.example` for the exact syntax.

The default is full XFCE — better for MCP power users who want a terminal
and file manager handy. Kiosk mode is the cleaner "single app on screen"
look at the cost of in-container tooling. Switch with `KIOSK_MODE=true` in
`.env`, then `./claude.sh stop && ./claude.sh start` (a plain `restart`
won't pick up env changes).

## Connecting Claude to your local files via MCP

The reason most people run this project is to give Claude Desktop access to
the local filesystem (notes, code, knowledge bases) through an **MCP**
filesystem server. The pattern:

1. Bind-mount a host directory to a path inside the container (the shipped
   override example uses `/data`, but the in-container path is your choice)
   by uncommenting the matching line in `docker-compose.override.yml`.

2. Configure an MCP filesystem server in
   `/root/.config/Claude/claude_desktop_config.json`. Either edit it
   inside the container (`./claude.sh shell`, then your editor) or
   bind-mount the file from the host so you can use your own tools.
   The in-container path on the last line of `args` must match whatever
   you chose in step 1. Example:

   ```json
   {
     "mcpServers": {
       "host-files": {
         "command": "npx",
         "args": ["-y", "@modelcontextprotocol/server-filesystem", "/data"]
       }
     }
   }
   ```

   The key `"host-files"` is just the name Claude shows for this server —
   pick whatever you like. (Don't use `"memory"`, which collides with the
   official `@modelcontextprotocol/server-memory` package, a different
   thing.)

3. Restart Claude (close and reopen the window inside the container, or
   `./claude.sh restart`).

Claude will now have read/write access to that host directory through the
filesystem MCP server. Same pattern works for any of the
[community MCP servers](https://github.com/modelcontextprotocol/servers).

## Architecture

Two parallel Docker images, kept in sync:

- **Local-dev** — `Dockerfile` + `docker-compose.yml`. Bind-mounts `scripts/`
  and the `claude-linux-desktop-build/` directory. Fat: keeps rustup/build
  deps at runtime so you can rebuild Claude in place via `./claude.sh build`.
  Used during development.

- **Published** — `dockerhub/Dockerfile.dockerhub` +
  `dockerhub/docker-compose.dockerhub.yml`. **Multi-stage**: builder stage
  compiles Claude, runtime stage drops ~1.2 GB of build deps and ships only
  what's needed to run the app. Multi-arch (linux/amd64, linux/arm64) via CI.

The `claude-linux-desktop-build/` directory does the actual `.exe` → Linux
conversion: downloads `Claude-Setup-x64.exe`, extracts via 7z, repacks the
asar, and builds a native Rust replacement for the `claude-native` Windows
binding via napi-rs.

For more detail on the codebase layout, see
[CLAUDE.md](CLAUDE.md). For multi-arch publishing, see
[dockerhub/README.md](dockerhub/README.md).

## Persistent volumes

| Volume | Container path | Holds |
|---|---|---|
| `app` | `/root/claude-app` | The built Electron app |
| `cache` | `/root/.cache` | Build cache (rust artifacts, node_modules, etc.) |
| `config` | `/root/.config/Claude` | Login state, MCP config, conversation history |
| `home` | `/root/home` | Misc user data |
| `vnc` | `/root/.vnc` | VNC password file, xstartup |

Login persists across restarts and image rebuilds. To wipe and start fresh:
`./claude.sh login-reset`.

## Verified working

- Backspace, arrow keys, Delete, F-keys, all standard nav (TigerVNC has
  working XKB; the previous TightVNC had broken keymaps).
- Clipboard between host and container (autocutsel + xclip + noVNC's
  clipboard panel).
- Window auto-maximizes on launch.
- Claude shows up in the XFCE Applications menu and as a desktop icon.
- Container survives `docker restart` (cleans stale `/tmp/.X*-lock` and
  `/tmp/dbus-session.info`).
- `docker stop` cleanly forwards SIGTERM to the Claude process.

## Known limitations

- **Software rendering only.** Electron logs `GLX is not present` warnings —
  expected and harmless inside a VNC virtual display. Performance is fine
  for chat/UI; not for video.
- **No browser inside the container.** Claude links that rely on
  `xdg-open` to spawn a browser won't open anything. The
  email-code login flow is fully in-app and unaffected.
- **VNC traffic is unencrypted.** Fine on a trusted LAN; if exposing
  publicly, put a reverse proxy with TLS + auth in front of port 6080.

## Troubleshooting

- **Login stuck on a stale verification-code screen?** `./claude.sh login-reset`.
- **Container keeps restarting?** `./claude.sh logs` — most likely a stale
  X lock from `docker restart`. The startup script wipes them; if it's
  failing earlier, the logs will say.
- **Backspace or arrows don't work?** Should not happen on TigerVNC; if it
  does, check `docker exec claude-desktop setxkbmap -query` (should report
  `layout: us`).
- See also `docs/TROUBLESHOOTING.md` and `docs/VNC-TROUBLESHOOTING.md`.
