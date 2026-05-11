#!/bin/bash
# Master command script for Claude Desktop Docker
# This script provides a convenient way to run all the consolidated scripts

# Execute the main script with all arguments
"$(dirname "$0")/scripts/main.sh" "$@"
