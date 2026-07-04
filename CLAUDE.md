# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project does

Runs Anthropic's Claude **Desktop** (the Electron app, distributed as a Windows `.exe`) inside a headless Ubuntu 22.04 container. The container repackages the Windows build into a Linux Electron app at runtime and exposes the GUI over VNC (`:5901`) and noVNC (`http://localhost:6080/`); the VNC password comes from the `VNC_PASSWORD` env var, or is randomly generated and printed to the container logs on first boot. This is unrelated to the Claude Code CLI or the Anthropic API — do not propose API/SDK refactors.

## Two parallel build paths — keep them in sync

There are two Dockerfiles with overlapping but distinct purposes. Changes to install steps, scripts copied into the image, or environment variables almost always need to be made in both:

1. **Local dev:** root `Dockerfile` + `docker-compose.yml`. Bind-mounts `scripts/` and `claude-linux-desktop-build/` from the host so you can iterate without rebuilding. Claude Desktop is **built at runtime** inside the running container by `./claude.sh build`.
2. **Docker Hub publish:** `dockerhub/Dockerfile.dockerhub` + `dockerhub/docker-compose.dockerhub.yml`. `COPY`s scripts in and runs `build-claude.sh` + `install.sh` **at image build time** so the published image is self-contained. Multi-arch (linux/amd64, linux/arm64) via Buildx.

The CI workflow `.github/workflows/dockerhub.yml` triggers on `v*` tags or manual dispatch and pushes to `fjmerc/claude-desktop` on Docker Hub; when no version is given it reads the `CLAUDE_VERSION` pin from `build-claude.sh` (keep it that way — auto-bump PRs must never need to edit workflow files, which `GITHUB_TOKEN` cannot push). The interactive `dockerhub/menu.sh`, `test-dockerhub-image.sh`, and `build-dockerhub-multiarch.sh` all default to the same repo.

Version bumps are automated end-to-end: `.github/workflows/upstream-version-check.yml` (weekly) detects upstream drift, computes the new installer SHA256, rewrites every hardcoded version via `scripts/utils/bump-claude-version.sh`, smoke-tests a candidate amd64 image (`scripts/utils/smoke-test-image.sh`, shared with the publish workflow), and opens an `auto-bump/claude-<version>` PR. Merging that PR is the human gate: `.github/workflows/publish-on-bump-merge.yml` then tags `v<version>` and dispatches the Docker Hub publish.

## The build scripts directory

`claude-linux-desktop-build/` is vendored directly in this repo (it began life as a git submodule on a private Gitea, but the files are now tracked here — there is no `.gitmodules`). It contains `build-claude.sh`, `install.sh`, `build-module.sh`, `packaging.sh`, `dependencies.sh`, `utils.sh`, `rust-code.rs`. These do the actual `.exe` → Linux conversion (download Claude-Setup-x64.exe, extract via 7z, repack the asar, build a native Rust module via napi-rs, generate a `.desktop` entry and launcher). `CLAUDE_VERSION` is hard-coded in `claude-linux-desktop-build/build-claude.sh` (currently `0.14.10`); the dockerhub Dockerfile passes it via the `VERSION` build-arg.

## Command dispatch architecture

User-facing entry point is `./claude.sh COMMAND [args]` (a thin wrapper that execs `scripts/main.sh`). `scripts/main.sh` is a `case` dispatcher that routes to one of four script categories:

- `scripts/build/` — Docker image + Claude Desktop builds, distribution archive
- `scripts/run/` — container lifecycle (`run.sh start|stop|restart`), `startup.sh` (the container's `CMD`), `setup.sh`, `start-claude.sh`
- `scripts/utils/` — shell, logs, status, dep verification, plus the VNC `xstartup`/`config` files and `find-electron.sh` for diagnosing PATH issues
- `scripts/fix/` — targeted repair scripts (dbus, electron sandbox, VNC, desktop paths)

The `dockerhub` subcommand is a parallel dispatcher (`dockerhub/dockerhub-main.sh`) for the multi-arch flow with its own `build`/`check`/`push`/`menu` subcommands. Don't merge the two dispatchers — they have different working directories and config defaults.

## Common commands

```bash
# First-time on a host: ensure permissions, then build image + Claude Desktop, then start
./claude.sh setup
./claude.sh build                  # builds image AND runs build-claude.sh inside the container
./claude.sh build --no-cache       # rebuild image from scratch
./claude.sh build --clean          # docker-compose down + rm before building

./claude.sh start                  # docker-compose up -d, auto-launches Claude if already built
./claude.sh start --build-claude   # also (re)build Claude Desktop on start
./claude.sh restart
./claude.sh stop

./claude.sh shell                  # exec bash in container
./claude.sh logs                   # docker-compose logs -f
./claude.sh status                 # container + Claude Desktop health
./claude.sh find-electron          # locate electron binary for PATH troubleshooting
./claude.sh fix-vnc                # multi-strategy VNC repair
./claude.sh distribute             # create shareable tarball

# Multi-arch publish (separate dispatcher)
./claude.sh dockerhub check --verbose
./claude.sh dockerhub build --platforms linux/amd64,linux/arm64
./claude.sh dockerhub push --version 0.14.10
./claude.sh dockerhub menu         # interactive
```

There is no test suite, linter, or package manager in this repo — it is shell scripts and Dockerfiles. "Verification" means `verify-dependencies.sh` (checks for required binaries inside the container) and `check-dockerhub-env.sh` (checks Buildx/QEMU on the host).

## Runtime layout inside the container

- `/startup.sh` is the `CMD`. It starts `vncserver :1 -geometry 1920x1080`, launches `novnc_proxy` (or falls back to `websockify`), then auto-runs `/root/claude-app/bin/claude-desktop --no-sandbox` (with fallbacks to `./electron --no-sandbox .`) under a watchdog that relaunches the app whenever it exits (disable with `CLAUDE_AUTO_RESTART=0`; skipped in kiosk mode, which relaunches via `Super+Space`; gives up after 5 rapid crash-loop exits). Required env: `DISPLAY=:1`, `ELECTRON_DISABLE_SANDBOX=1`, `ELECTRON_NO_ASAR=1`. Uses `--no-sandbox` because the container runs as root.
- Named volumes persist across rebuilds: `app` → `/root/claude-app` (the built Electron app), `cache` → `/root/.cache` (build cache, including `~/.cache/claude-desktop-build`), `config` → `/root/.config/Claude` (login state/prefs), `home` → `/root/home`.
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
- The Windows `.exe` URL in `build-claude.sh` points at an **unversioned** Google Cloud Storage object Anthropic overwrites in place — the download is always "latest", and `CLAUDE_VERSION` is only a label. `CLAUDE_SHA256` pins the installer hash; when upstream moves, `scripts/utils/check-upstream-version.sh` (run in CI before publish and weekly via `.github/workflows/upstream-version-check.yml`) blocks publishing, and the weekly workflow auto-opens a smoke-tested bump PR. To bump by hand instead: `scripts/utils/bump-claude-version.sh <version> <sha256>`.
