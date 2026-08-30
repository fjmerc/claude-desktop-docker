#!/bin/bash
#
# Native module and extraction functions for Claude Desktop build

# Create and setup the patchy-cnb native module
setup_patchy_cnb() {
    echo "Setting up patchy-cnb native module..."
    mkdir -p "$WORK_DIR/patchy-cnb"
    cd "$WORK_DIR/patchy-cnb"
    
    # Create Cargo.toml with minimal dependencies
    cat > Cargo.toml << 'EOF'
[package]
name = "patchy-cnb"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib"]

[dependencies]
napi = { version = "2.12.2", default-features = false, features = ["napi4"] }
napi-derive = "2.12.2"
EOF

    # Create src/lib.rs from the external rust code file
    mkdir -p src
    cp "${SCRIPT_DIR}/rust-code.rs" src/lib.rs || {
        echo "Failed to copy Rust code"
        exit 1
    }

    # Detect system architecture and prepare proper configuration
    ARCH=$(uname -m)
    if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
        # Both ARM64 and x86_64 for cross-compilation support
        echo "Detected ARM64 architecture, configuring for ARM64 and x86_64 support"
        TRIPLES='"x86_64-unknown-linux-gnu",
        "aarch64-unknown-linux-gnu"'
    else
        # Only x86_64 on standard systems
        echo "Detected x86_64 architecture, configuring for x86_64 support only"
        TRIPLES='"x86_64-unknown-linux-gnu"'
    fi

    # Create package.json with architecture-specific configuration
    cat > package.json << EOF
{
  "name": "patchy-cnb",
  "version": "0.1.0",
  "main": "index.js",
  "napi": {
    "name": "patchy-cnb",
    "triples": {
      "defaults": false,
      "additional": [
        $TRIPLES
      ]
    }
  },
  "scripts": {
    "build": "napi build --platform --release"
  },
  "devDependencies": {
    "@napi-rs/cli": "^2.18.4"
  }
}
EOF

    # Build native module with error handling
    echo "Building native module..."
    npm install
    npm run build
    
    echo "Successfully built native module"
}

# Download and extract the Windows client
download_and_extract() {
    echo "Downloading Claude Desktop..."
    mkdir -p "$WORK_DIR"
    cd "$WORK_DIR"
    
    NUPKG_FILE="AnthropicClaude-${CLAUDE_VERSION}-full.nupkg"

    # A cached nupkg from an earlier build may be corrupt or predate a re-pin;
    # re-download instead of failing the build on it.
    if [ -f "$NUPKG_FILE" ] && [ -n "${CLAUDE_SHA256:-}" ] && \
       ! echo "${CLAUDE_SHA256}  ${NUPKG_FILE}" | sha256sum -c - >/dev/null 2>&1; then
        echo "Cached ${NUPKG_FILE} does not match pinned SHA256 — re-downloading."
        rm -f "$NUPKG_FILE"
    fi

    if [ ! -f "$NUPKG_FILE" ]; then
        wget "$CLAUDE_URL" -O "$NUPKG_FILE" || {
            echo "Failed to download Claude Desktop"
            exit $EXIT_DOWNLOAD_ERROR
        }
    fi

    # Optional integrity check. Set CLAUDE_SHA256 in the environment (or
    # CLAUDE_SHA256="..." in build-claude.sh) to enforce a known-good hash.
    if [ -n "${CLAUDE_SHA256:-}" ]; then
        echo "Verifying SHA256..."
        echo "${CLAUDE_SHA256}  ${NUPKG_FILE}" | sha256sum -c - || {
            echo "SHA256 mismatch for ${NUPKG_FILE}"
            echo "Expected: ${CLAUDE_SHA256}"
            echo "Actual:   $(sha256sum "$NUPKG_FILE" | cut -d' ' -f1)"
            rm -f "$NUPKG_FILE"
            exit $EXIT_DOWNLOAD_ERROR
        }
    else
        echo "WARNING: CLAUDE_SHA256 unset — skipping integrity verification."
        echo "  Computed hash: $(sha256sum "$NUPKG_FILE" | cut -d' ' -f1)"
        echo "  Pin this value in build-claude.sh to enforce on subsequent builds."
    fi

    # WORK_DIR persists across builds (cache volume / ~/.cache); remove
    # leftover installers and extracted app files from older versions so
    # they can't shadow the fresh payload.
    find . -maxdepth 1 -name '*.nupkg' ! -name "$NUPKG_FILE" -delete
    rm -f Claude-Setup-x64.exe
    rm -rf lib

    # A nupkg is a plain zip; extracting it yields lib/net45/... directly.
    echo "Extracting..."
    7z x -y "$NUPKG_FILE" || {
        echo "Failed to extract $NUPKG_FILE"
        exit $EXIT_EXTRACTION_ERROR
    }
}

# Process icons
process_icons() {
    echo "Processing icons..."
    cd "$WORK_DIR"
    
    wrestool -x -t 14 "lib/net45/claude.exe" -o claude.ico || {
        echo "Failed to extract icons from claude.exe"
        exit $EXIT_EXTRACTION_ERROR
    }
    
    icotool -x claude.ico || {
        echo "Failed to convert ico file"
        exit $EXIT_EXTRACTION_ERROR
    }
    
    mkdir -p "$OUTPUT_DIR/share/icons/hicolor"
    for size in 16 24 32 48 64 256; do
        mkdir -p "$OUTPUT_DIR/share/icons/hicolor/${size}x${size}/apps"
        $IMAGE_CMD "claude_*${size}x${size}x32.png" \
            "$OUTPUT_DIR/share/icons/hicolor/${size}x${size}/apps/claude.png" || {
            echo "Warning: Failed to convert icon for size ${size}x${size}"
        }
    done
    
    echo "Successfully processed icons"
}

# Export functions for the main script
export -f setup_patchy_cnb download_and_extract process_icons
