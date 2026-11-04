# Claude Desktop Docker

Run [Claude Desktop](https://claude.ai/desktop) in a Docker container with VNC and web access. The image ships Anthropic's official Linux build of Claude Desktop, installed from their APT repository and verified against a pinned SHA256.

## Features

- **Multi-Architecture Support**: Runs on both AMD64 and ARM64 platforms
- **VNC Access**: Connect via any VNC client on port 5901
- **Web Access**: Access via web browser at http://localhost:6080
- **Clipboard Integration**: Share clipboard between host and container
- **Persistent Storage**: Maintain Claude settings and data between runs

## Quick Start

```bash
# Pull and run the container
docker run -d \
  --name claude-desktop \
  -p 5901:5901 \
  -p 6080:6080 \
  --privileged \
  --shm-size=2g \
  fjmerc/claude-desktop:latest

# Access via web browser
# Open http://localhost:6080 in your browser

# Or access via VNC client at localhost:5901
# First run generates a random VNC password — check `docker logs claude-desktop`.
# To pin a password, set VNC_PASSWORD in the container environment.
```

## Using Docker Compose

```yaml
version: '3'
services:
  claude-desktop:
    image: fjmerc/claude-desktop:latest
    container_name: claude-desktop
    ports:
      - "5901:5901"  # VNC port
      - "6080:6080"  # noVNC web interface port
    volumes:
      - cache:/root/.cache
      - config:/root/.config/Claude
      - home:/root/home
    environment:
      - DISPLAY=:1
    privileged: true
    shm_size: 2gb
    restart: unless-stopped
volumes:
  cache:
  config:
  home:
```

Save this as `docker-compose.yml` and run:

```bash
docker-compose up -d
```

## Environment Variables

- `DISPLAY`: X display number (default: `:1`)
- `USER`: User for the container (default: `root`)
- `HOME`: Home directory (default: `/root`)

## Volumes

Claude Desktop itself lives in the image (`/usr/lib/claude-desktop`), not in a volume, so pulling a new tag really updates it. If you used an image older than 4.x, delete its leftover `app` volume.


- `/root/.cache`: Cache directory
- `/root/.config/Claude`: Claude configuration
- `/root/home`: Home directory for user files

## Tags

- `latest`: Latest stable build
- `4.4212.0`: Specific version (matches the Claude Desktop version inside)
- `4.4212`: Major.minor version

## Architectures

- `linux/amd64`: For Intel/AMD processors
- `linux/arm64`: For ARM processors (e.g., Apple Silicon, Raspberry Pi 4)

## Troubleshooting

### VNC Connection Issues

If you can't connect via VNC, try:

```bash
docker exec -it claude-desktop bash -c "/scripts/fix/fix-vnc.sh"
```

### Claude Desktop Not Starting

If Claude Desktop doesn't start automatically:

```bash
docker exec -d -e DISPLAY=:1 claude-desktop claude-desktop
```

## Building from Source

This image is built from the [Claude Desktop Docker](https://github.com/fjmerc/claude-desktop-docker) project.

To build it yourself:

```bash
git clone https://github.com/fjmerc/claude-desktop-docker.git
cd claude-desktop-docker
./claude.sh dockerhub build --platforms linux/amd64,linux/arm64
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.
