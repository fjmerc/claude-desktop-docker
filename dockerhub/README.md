# Claude Desktop Docker - Docker Hub Multi-Architecture Build System

This directory contains scripts and configuration files for building and publishing multi-architecture Docker images of Claude Desktop to Docker Hub.

## Overview

The multi-architecture build system enables building Docker images for multiple CPU architectures (AMD64 and ARM64) and publishing them to Docker Hub. This allows users to run Claude Desktop Docker on different hardware platforms without manual configuration.

## Prerequisites

Before using these scripts, ensure your system meets the following requirements:

- Docker 19.03 or newer (with experimental features enabled)
- Docker Buildx plugin
- Docker Hub account (for pushing images)
- Sufficient system resources (recommended: 4+ GB RAM, 10+ GB free disk space)

You can verify your environment using the included checker script:

```bash
./check-dockerhub-env.sh --verbose
```

If issues are found, you can attempt to fix them automatically:

```bash
./check-dockerhub-env.sh --fix
```

## Scripts

### 1. `build-dockerhub-multiarch.sh`

The main build script for creating multi-architecture Docker images.

**Usage:**

```bash
./build-dockerhub-multiarch.sh [options]
```

**Options:**

- `--version VER` - Set version for the build (default: 0.9.2)
- `--platforms PLAT` - Comma-separated list of platforms (default: linux/amd64,linux/arm64)
- `--repo REPO` - Docker Hub repository (default: claudedesktop/claude-desktop)
- `--push` - Push images to Docker Hub
- `--load` - Load image into local Docker (single platform only)
- `--no-cache` - Disable build cache
- `--driver DRIVER` - Buildx driver (default: docker-container)
- `--node-version VER` - Node.js version (default: 22.x)
- `--progress TYPE` - Build progress type (auto, plain, tty)
- `--clean` - Clean up builder and context before building
- `--dry-run` - Print commands without executing them
- `--log-level LEVEL` - Set log level (DEBUG, INFO, WARN, ERROR, FATAL)
- `--help` - Show help message

**Examples:**

Build and push multi-architecture images to Docker Hub:
```bash
./build-dockerhub-multiarch.sh --version 0.9.2 --platforms linux/amd64,linux/arm64 --push
```

Build a single architecture image for local testing:
```bash
./build-dockerhub-multiarch.sh --platforms linux/amd64 --load --no-cache
```

### 2. `check-dockerhub-env.sh`

Script to verify that all prerequisites for Docker Hub builds are met.

**Usage:**

```bash
./check-dockerhub-env.sh [options]
```

**Options:**

- `--verbose` - Show detailed output
- `--fix` - Attempt to fix issues automatically
- `--log-level LEVEL` - Set log level
- `--help` - Show help message

### 3. `dockerhub-logger.sh`

Logging utility for Docker Hub multi-architecture builds. This script is sourced by other scripts and provides consistent logging functionality.

## Dockerfile

### `Dockerfile.dockerhub`

This Dockerfile is optimized for multi-architecture builds and Docker Hub compatibility. It includes:

- Architecture detection and handling
- Optimized layer caching
- Proper environment variable configuration
- Health checks
- Comprehensive logging

## Build Process

The multi-architecture build process works as follows:

1. **Environment Check**: Verify that all prerequisites are met
2. **Builder Setup**: Create and configure a Docker Buildx builder
3. **Build Preparation**: Set up build arguments and tags
4. **Build Execution**: Build images for all specified platforms
5. **Publishing**: Push images to Docker Hub (if --push is specified)

## Logging

All scripts include comprehensive logging with different verbosity levels:

- DEBUG: Detailed debugging information
- INFO: General information about the build process
- WARN: Warning messages that don't prevent the build
- ERROR: Error messages that might cause the build to fail
- FATAL: Critical errors that cause the build to abort

Logs are stored in the `logs` directory with timestamps for easy reference.

## Troubleshooting

If you encounter issues during the build process:

1. Check the logs in the `logs` directory
2. Run the environment checker with `--verbose` to identify potential issues
3. Try building with `--no-cache` to eliminate caching problems
4. For platform-specific issues, try building for a single platform first

## Docker Hub Repository

The default Docker Hub repository is `claudedesktop/claude-desktop`. You can change this using the `--repo` option.

Images are tagged with:
- The specific version (e.g., `claudedesktop/claude-desktop:0.9.2`)
- The `latest` tag for the most recent build

## Building from Different Machines

If you need to build and push images from different physical machines (e.g., one AMD64 machine and one ARM64 machine), you can follow these steps:

1. **On your AMD64 machine:**
   ```bash
   docker build --platform linux/amd64 -t fjmerc/claude-desktop:1.0.0-amd64 -f Dockerfile.dockerhub .
   docker push fjmerc/claude-desktop:1.0.0-amd64
   ```

2. **On your ARM64 machine:**
   ```bash
   docker build --platform linux/arm64 -t fjmerc/claude-desktop:1.0.0-arm64 -f Dockerfile.dockerhub .
   docker push fjmerc/claude-desktop:1.0.0-arm64
   ```

3. **Creating a multi-architecture manifest** (from either machine, after both images are pushed):
   ```bash
   docker manifest create fjmerc/claude-desktop:1.0.0 \
     fjmerc/claude-desktop:1.0.0-amd64 \
     fjmerc/claude-desktop:1.0.0-arm64

   docker manifest push fjmerc/claude-desktop:1.0.0
   ```

### Important Notes
- Use architecture-specific tags when building on different machines to avoid overwriting images
- The Docker CLI needs experimental features enabled for manifest commands (`"experimental": "enabled"` in Docker config)
- After creating the manifest, users can pull the generic tag (`fjmerc/claude-desktop:1.0.0`) and Docker will automatically select the appropriate architecture

## Resource Considerations

Multi-architecture builds can be resource-intensive. Consider the following:

- **CPU**: Building multiple architectures in parallel requires significant CPU resources
- **Memory**: Each architecture build requires at least 2GB of RAM
- **Disk Space**: Expect to use 5-10GB of disk space per architecture
- **Network**: Pushing images to Docker Hub requires a stable internet connection

You can adjust resource allocation in the Docker daemon configuration.
