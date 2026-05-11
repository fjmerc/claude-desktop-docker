#!/bin/bash
# Script to install common text editors and tools in a running container

echo "Installing common editing tools..."

# Update package lists
apt-get update

# Install common text editors
apt-get install -y --no-install-recommends nano vim

# Install additional useful tools
apt-get install -y --no-install-recommends \
  less \
  htop \
  curl \
  wget \
  jq

# Clean up
apt-get clean
rm -rf /var/lib/apt/lists/*

echo "Installation complete. The following editors are now available:"
echo "- nano: Simple text editor (nano filename)"
echo "- vim: Advanced text editor (vim filename)"
echo ""
echo "Additional tools installed:"
echo "- less: Text file viewer"
echo "- htop: System monitor"
echo "- curl/wget: File download tools" 
echo "- jq: JSON processor"
