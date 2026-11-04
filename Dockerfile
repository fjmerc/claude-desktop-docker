FROM ubuntu:22.04

# Set environment variables
ENV USER=root
ENV HOME=/root
ENV DEBIAN_FRONTEND=noninteractive

# Install basic dependencies first
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    apt-utils \
    apt-transport-https \
    curl \
    gnupg \
    lsb-release \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Setup NodeSource repository for Node.js 22.x
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash -

# Node.js (for npx-launched MCP servers; Claude Desktop bundles its own runtime)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    nodejs \
    git \
    rsync \
    wget \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install desktop environment
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    xfce4 \
    xfce4-terminal \
    mousepad \
    tigervnc-standalone-server \
    tigervnc-common \
    tigervnc-tools \
    novnc \
    websockify \
    net-tools \
    netcat-openbsd \
    python3-pip \
    xfonts-base \
    xfonts-75dpi \
    xfonts-100dpi \
    xauth \
    dbus \
    dbus-x11 \
    at-spi2-core \
    libglib2.0-bin \
    autocutsel \
    xclip \
    wmctrl \
    openbox \
    x11-utils \
    scrot \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Editors and desktop utilities
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    nano \
    vim \
    xdg-utils \
    desktop-file-utils \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install library dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    x11-xserver-utils \
    libnspr4 \
    libnss3 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libgtk-3-0 \
    libgbm1 \
    libasound2 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Git MCP server, referenced by the default claude_desktop_config.json
# (python -m mcp_server_git). Without it every fresh container has a broken
# MCP entry that costs users 30+ min to diagnose.
RUN pip3 install --no-cache-dir mcp-server-git

# Replace Ubuntu 22.04's noVNC 1.0.0 with upstream v1.6.0. The apt package is
# pre-Async-Clipboard-API, so browser Ctrl+C/V cannot push text into the VNC
# session — only the manual sidebar Clipboard panel works. v1.5+ integrates
# the browser's Async Clipboard API, making Ctrl+V transparent on localhost
# (browser asks for clipboard permission once). websockify ships separately,
# so removing the directory contents is safe.
RUN rm -rf /usr/share/novnc && \
    mkdir -p /usr/share/novnc && \
    curl -fsSL https://github.com/novnc/noVNC/archive/refs/tags/v1.6.0.tar.gz | \
        tar -xz -C /usr/share/novnc --strip-components=1

# Create necessary directories
RUN mkdir -p /root/.vnc /scripts/utils /scripts/run /scripts/build /scripts/fix

# X authority + VNC dir. The password file is written by startup.sh on
# first boot from the VNC_PASSWORD env var (or a generated random one if
# unset and no /root/.vnc/passwd exists yet from a prior run).
RUN touch /root/.Xauthority && chmod 600 /root/.Xauthority

# Create VNC directories and structure in the container
COPY scripts/utils/xstartup /scripts/utils/xstartup
COPY scripts/utils/xstartup /root/.vnc/xstartup
COPY scripts/utils/config /root/.vnc/config
RUN chmod +x /root/.vnc/xstartup /scripts/utils/xstartup && \
    chmod 644 /root/.vnc/config

# We'll create symlinks for compatibility with old scripts
RUN ln -sf /scripts/utils/xstartup /scripts/xstartup && \
    ln -sf /scripts/utils/config /scripts/config

# Copy main startup script
COPY scripts/run/startup.sh /startup.sh
COPY scripts/utils/verify-dependencies.sh /scripts/utils/verify-dependencies.sh
RUN chmod +x /startup.sh /scripts/utils/verify-dependencies.sh

# Create symlink for compatibility
RUN ln -sf /scripts/utils/verify-dependencies.sh /scripts/verify-dependencies.sh

# Claude Desktop itself: Anthropic's official .deb, version + per-arch SHA256
# pinned in claude-desktop.pin (shared with dockerhub/Dockerfile.dockerhub).
# The rest of scripts/ is bind-mounted from the host at runtime, so only what
# the install step needs is copied in.
COPY claude-desktop.pin /tmp/claude-desktop.pin
COPY scripts/build/install-claude-desktop.sh /tmp/install-claude-desktop.sh
COPY scripts/utils/desktop-integration.sh /tmp/desktop-integration.sh
RUN bash /tmp/install-claude-desktop.sh /tmp/claude-desktop.pin && \
    bash /tmp/desktop-integration.sh && \
    rm -f /tmp/claude-desktop.pin /tmp/install-claude-desktop.sh /tmp/desktop-integration.sh

WORKDIR /root

# Expose ports
EXPOSE 5901 6080

# Start VNC server and Claude Desktop
CMD ["/startup.sh"]
