# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project does

Runs Anthropic's Claude **Desktop** inside a headless Ubuntu 22.04 container, using Anthropic's **official Linux build** (the `claude-desktop` `.deb` from `https://downloads.claude.ai/claude-desktop/apt/stable`, amd64 + arm64). The image installs it at build time and exposes the GUI over VNC (`:5901`) and noVNC (`http://localhost:6080/`); the VNC password comes from the `VNC_PASSWORD` env var, or is randomly generated and printed to the container logs on first boot. This is unrelated to the Claude Code CLI or the Anthropic API — do not propose API/SDK refactors.

## Two parallel build paths — keep them in sync

There are two Dockerfiles with overlapping but distinct purposes. Changes to install steps, scripts copied into the image, or environment variables almost always need to be made in both:

1. **Local dev:** root `Dockerfile` + `docker-compose.yml`. Bind-mounts `scripts/` from the host so you can iterate on scripts without rebuilding.
2. **Docker Hub publish:** `dockerhub/Dockerfile.dockerhub` + `dockerhub/docker-compose.dockerhub.yml`. `COPY`s scripts in so the published image is self-contained. Multi-arch (linux/amd64, linux/arm64) via Buildx.

Both install Claude Desktop identically via `scripts/build/install-claude-desktop.sh claude-desktop.pin`: download the pinned `.deb` for the image arch, verify its SHA256, `apt-get install` it, and write the root-aware wrapper `/usr/local/bin/claude-desktop` (adds `--no-sandbox` only when running as root, then execs `/usr/bin/claude-desktop`). It also repoints the package's menu entry at the wrapper.

The CI workflow `.github/workflows/dockerhub.yml` triggers on `v*` tags or manual dispatch and pushes to `fjmerc/claude-desktop` on Docker Hub; the version always comes from `claude-desktop.pin` and a tag/input that disagrees with it fails the run (keep it that way — auto-bump PRs must never need to edit workflow files, which `GITHUB_TOKEN` cannot push). The interactive `dockerhub/menu.sh`, `test-dockerhub-image.sh`, and `build-dockerhub-multiarch.sh` all default to the same repo.

Version bumps are automated end-to-end: `.github/workflows/upstream-version-check.yml` (weekly) detects upstream drift against the APT repo's `Packages` index (newest version published for **both** arches), downloads both `.deb`s and checks them against the index's SHA256, rewrites the pin and every hardcoded version via `scripts/utils/bump-claude-version.sh`, smoke-tests a candidate amd64 image (`scripts/utils/smoke-test-image.sh`, shared with the publish workflow), and opens an `auto-bump/claude-<version>` PR. Merging that PR is the human gate: `.github/workflows/publish-on-bump-merge.yml` then tags `v<version>` and dispatches the Docker Hub publish.

## The version pin

`claude-desktop.pin` (repo root, shell-sourceable) is the single source of truth: `CLAUDE_VERSION`, `CLAUDE_SHA256_AMD64`, `CLAUDE_SHA256_ARM64`. Workflows read it with `. ./claude-desktop.pin`. Bump it only with `scripts/utils/bump-claude-version.sh <version> <sha256-amd64> <sha256-arm64>` so the three values move together.

History: until 2026-11 this repo converted the **Windows** installer into a Linux Electron app (vendored `claude-linux-desktop-build/`: nupkg download, asar repack, Rust napi stub for `claude-native`). That was retired when Anthropic shipped an official Linux `.deb`; the converter's history lives in git and in the standalone Gitea repo `fray/claude-linux-desktop-build`. Don't reintroduce it.

## Command dispatch architecture

User-facing entry point is `./claude.sh COMMAND [args]` (a thin wrapper that execs `scripts/main.sh`). `scripts/main.sh` is a `case` dispatcher that routes to one of four script categories:

- `scripts/build/` — image build (`build.sh`), the shared `install-claude-desktop.sh`, distribution archive
- `scripts/run/` — container lifecycle (`run.sh start|stop|restart`), `startup.sh` (the container's `CMD`), `setup.sh`
- `scripts/utils/` — shell, logs, status, dep verification, upstream check/bump, smoke test, plus the VNC `xstartup`/`config` files
- `scripts/fix/` — targeted repair scripts (dbus, VNC)

The `dockerhub` subcommand is a parallel dispatcher (`dockerhub/dockerhub-main.sh`) for the multi-arch flow with its own `build`/`check`/`push`/`menu` subcommands. Don't merge the two dispatchers — they have different working directories and config defaults.

## Common commands

```bash
# First-time on a host: ensure permissions, then build image + Claude Desktop, then start
./claude.sh setup
./claude.sh build                  # builds the image (installs the pinned Claude Desktop) and starts it
./claude.sh build --no-cache       # rebuild image from scratch
./claude.sh build --clean          # docker-compose down + rm before building

./claude.sh start                  # docker-compose up -d; startup.sh launches Claude
./claude.sh start-claude           # re-launch/re-show Claude in a running container
./claude.sh restart
./claude.sh stop

./claude.sh shell                  # exec bash in container
./claude.sh logs                   # docker-compose logs -f
./claude.sh status                 # container + Claude Desktop health
./claude.sh fix-vnc                # multi-strategy VNC repair
./claude.sh distribute             # create shareable tarball

# Multi-arch publish (separate dispatcher)
./claude.sh dockerhub check --verbose
./claude.sh dockerhub build --platforms linux/amd64,linux/arm64
./claude.sh dockerhub push         # tag version comes from claude-desktop.pin
./claude.sh dockerhub menu         # interactive
```

There is no test suite, linter, or package manager in this repo — it is shell scripts and Dockerfiles. "Verification" means `scripts/utils/smoke-test-image.sh <image>` (boots an image; passes only when VNC is up, the Claude process is alive, and a "Claude" X window is mapped — CI runs it before every publish), `verify-dependencies.sh` (inside the container), and `check-dockerhub-env.sh` (Buildx/QEMU on the host).

## Runtime layout inside the container

- `/startup.sh` is the `CMD`. It starts `vncserver :1 -geometry 1920x1080`, launches `novnc_proxy` (or falls back to `websockify`), then runs `/usr/local/bin/claude-desktop` under a watchdog that relaunches the app whenever it exits (disable with `CLAUDE_AUTO_RESTART=0`; skipped in kiosk mode, which relaunches via `Ctrl+Alt+C` (or `Super+C`; note "space" bound with modifiers never fires on the Xvnc XKB setup, and browsers' host OS eats Super combos); gives up after 5 rapid crash-loop exits). Required env: `DISPLAY=:1`.
- Process match used by startup.sh, the HEALTHCHECK, status and the smoke test: `pgrep -f '^/usr/(bin|lib/claude-desktop)/claude-desktop'` (main process runs as `/usr/bin/claude-desktop`, Chromium children as `/usr/lib/claude-desktop/claude-desktop --type=...`).
- Named volumes persist across rebuilds: `config` → `/root/.config/Claude` (login state/prefs), `cache` → `/root/.cache`, `home` → `/root/home`, `vnc` → `/root/.vnc`. The app itself is **not** in a volume (it lives in the image under `/usr/lib/claude-desktop`) — never put it back in one: Docker seeds a named volume from the image only on first creation, so the old `app` volume silently pinned every user to their first-pulled app version.
- `docker-compose.yml` also bind-mounts `/home/fray/Documents/memory/` → `/root/memory` (host-specific path; will not exist on other developers' machines — strip or parameterize before publishing).
- `privileged: true` and `shm_size: 2gb` are required for Electron/X11 to work; don't remove them casually.

## When editing scripts

- Most scripts derive `PROJECT_DIR` from `$BASH_SOURCE`, so they work from any CWD. Preserve that pattern.
- Scripts copied into the image at build time live at `/scripts/{build,run,utils,fix}/`. The local-dev compose file *also* bind-mounts `./scripts:/scripts`, so on a dev machine your host edits take effect immediately — but on a published image they don't, because nothing is mounted. Test changes that affect runtime behavior in **both** modes.
- The Dockerfile creates compatibility symlinks (e.g., `/scripts/xstartup` → `/scripts/utils/xstartup`) for older script paths. Don't break these without grepping for callers.
- `cleanup.sh` at the repo root is a one-shot historical refactor script that moved files into `scripts/{build,run,utils,fix}` subdirs. It references hardcoded paths and should not be re-run.

## Things that look like bugs but aren't

- `docker-compose.yml` is in `.gitignore` — but it *is* tracked. The ignore entry is there so users editing it locally (e.g., changing the `/home/fray/...` bind mount) don't accidentally commit personal paths. Use `git update-index --skip-worktree` semantics mentally; don't "fix" the gitignore.
- VNC server runs as root. This is intentional for a single-user dev container; do not propose hardening unless asked.
- `check-upstream-version.sh` fails not only on version drift but also when the APT repo's `Release` file `Date` is older than `MAX_FEED_AGE_DAYS` (21). Anthropic re-signs it weekly; a stale date means the feed has probably moved. This exists because the old Windows feed (a GCS bucket) froze in Oct 2025 while the version check kept passing for a year. Don't remove it to make CI green — find the new feed.
- The Linux `.deb` can lag the Windows/macOS releases (on 2026-11-03 Linux was at 4.4212.0 while Windows was at 4.16336.0; Linux caught up the next day). A gap is upstream cadence, not a bug in the check.
