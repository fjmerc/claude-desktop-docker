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

# Install Node.js and core build tools
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    nodejs \
    build-essential \
    git \
    rsync \
    wget \
    && npm install -g asar @napi-rs/cli electron \
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

# Install Rust via rustup. Ubuntu 22.04's apt rustc lags far behind the MSRV
# of crates the napi-rs build pulls in (e.g. unicode-segmentation requires
# rustc 1.85+). rustup ships current stable. --profile minimal keeps it ~250MB.
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
        sh -s -- -y --profile minimal --default-toolchain stable && \
    ln -sf /root/.cargo/bin/cargo /usr/local/bin/cargo && \
    ln -sf /root/.cargo/bin/rustc /usr/local/bin/rustc

# Install Claude Desktop build dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    p7zip-full \
    imagemagick \
    icoutils \
    nano \
    vim \
    xdg-utils \
    desktop-file-utils \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install library dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libssl-dev \
    pkg-config \
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

# Set up build directory
WORKDIR /root
RUN mkdir -p /root/claude-linux-desktop-build

# We'll mount the source scripts from the host at runtime
# for more flexibility during development

# Expose ports
EXPOSE 5901 6080

# Start VNC server and Claude Desktop
CMD ["/startup.sh"]
