#!/bin/bash
# Script to verify dependencies for Claude Desktop build

echo "=== Checking Dependencies for Claude Desktop Build ==="

# Check wget
echo -n "wget: "
if command -v wget &> /dev/null; then
    echo $(wget --version | head -1)
    echo "✅ wget is installed"
else
    echo "❌ Not installed"
fi

# Check Node.js version
echo -n "Node.js: "
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    echo "$NODE_VERSION"
    
    # Convert version string to comparable number (e.g., v14.17.0 to 14)
    NODE_MAJOR=$(echo $NODE_VERSION | cut -d. -f1 | tr -d 'v')
    
    if [[ $NODE_MAJOR -ge 14 ]]; then
        echo "✅ Node.js version is compatible (v14+ required)"
    else
        echo "❌ Node.js version is not compatible (v14+ required)"
        echo "   Please rebuild with the updated Dockerfile"
    fi
else
    echo "❌ Not installed"
fi

# Check npm version
echo -n "npm: "
if command -v npm &> /dev/null; then
    echo $(npm --version)
    echo "✅ npm is installed"
else
    echo "❌ Not installed"
fi

# Check Rust/Cargo
echo -n "Rust/Cargo: "
if command -v rustc &> /dev/null; then
    echo $(rustc --version)
    echo "✅ Rust is installed"
else
    echo "❌ Not installed"
fi

# Check asar
echo -n "asar: "
if command -v asar &> /dev/null; then
    echo $(asar --version)
    echo "✅ asar is installed"
else
    echo "❌ Not installed"
fi

# Check build essentials
echo "Build essentials:"
for cmd in gcc g++ make pkg-config; do
    if command -v $cmd &> /dev/null; then
        echo "✅ $cmd: $(which $cmd)"
    else
        echo "❌ $cmd: Not installed"
    fi
done

# Check required utilities for Claude Desktop build
echo
echo "Claude Desktop Build Utilities:"
for cmd in 7za electron wrestool icotool convert; do
    if command -v $cmd &> /dev/null; then
        echo "✅ $cmd: $(which $cmd)"
    else
        echo "❌ $cmd: Not installed"
    fi
done

echo
echo "=== System Info ==="
echo "Distribution: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d \")"
echo "Architecture: $(uname -m)"
echo "Memory: $(free -h | grep Mem | awk '{print $2}')"
echo "Disk space: $(df -h / | tail -1 | awk '{print $4}') available"

echo
echo "=== NPM Packages ==="
for pkg in asar @napi-rs/cli; do
    if npm list -g "$pkg" &> /dev/null; then
        echo "✅ $pkg is installed"
        version=$(npm list -g "$pkg" | grep $pkg | cut -d'@' -f3)
        if [ ! -z "$version" ]; then
            echo "   Version: $version"
        fi
    else
        echo "❌ $pkg is not installed"
    fi
done

echo
echo "If any dependencies are missing, rebuild the container using:"
echo "./claude.sh build --clean"
