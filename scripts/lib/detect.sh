#!/bin/bash
#
# Detection Library - Architecture and state detection utilities

# Detect script directory (works when sourced)
if [ -z "$SCRIPT_DIR" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi

# Detect architecture
ARCH=$(uname -m)

# Set Homebrew prefix based on architecture
if [ "$ARCH" = "arm64" ]; then
    BREW_PREFIX="/opt/homebrew"
else
    BREW_PREFIX="/usr/local"
fi

# Check if Homebrew is installed
is_homebrew_installed() {
    command -v brew >/dev/null 2>&1
}

# Check if Xcode Command Line Tools are installed
is_xcode_clt_installed() {
    xcode-select -p >/dev/null 2>&1
}

# Generic tool check
is_tool_installed() {
    local tool="$1"
    command -v "$tool" >/dev/null 2>&1
}

# Export variables and functions
export SCRIPT_DIR
export ARCH
export BREW_PREFIX
export -f is_homebrew_installed
export -f is_xcode_clt_installed
export -f is_tool_installed
