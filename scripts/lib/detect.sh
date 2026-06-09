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
#
# Brewfile entries are formula names, which frequently differ from the binary
# they install (ripgrep→rg, git-delta→delta, imagemagick→magick, poppler→pdfinfo,
# charmbracelet/tap/freeze→freeze). A plain `command -v <formula>` therefore
# reports installed tools as missing and produces phantom "failed to install"
# reports. Prefer an authoritative `brew list` check (stripping any tap prefix),
# and fall back to PATH lookup for non-brew tools (brew itself, claude, etc.).
is_tool_installed() {
    local tool="$1"
    local formula="${tool##*/}"   # charmbracelet/tap/freeze -> freeze
    if command -v brew >/dev/null 2>&1 \
        && brew list --formula --versions "$formula" >/dev/null 2>&1; then
        return 0
    fi
    command -v "$tool" >/dev/null 2>&1
}

# Fall back gracefully when macOS is newer than Homebrew knows about.
#
# A too-new macOS (e.g. a developer beta) isn't in Homebrew's version table, so
# every bottle operation aborts with "unknown or unsupported macOS version:
# :dunno". This detects that and points Homebrew at the newest macOS it DOES
# know via HOMEBREW_FAKE_MACOS, so installs pull last-OS bottles (binary-
# compatible) instead of hard-failing. Self-healing: once Homebrew ships support
# the running major is no longer greater than the newest known, so nothing is
# faked. No-op if HOMEBREW_FAKE_MACOS is already set or brew is unavailable.
#
# Returns 0 (and sets HOMEBREW_FAKE_MACOS + FAKE_MACOS_APPLIED) when it applies
# the fallback; non-zero otherwise. Caller owns any user-facing messaging.
maybe_fake_unsupported_macos() {
    FAKE_MACOS_APPLIED=""
    if [ -n "${HOMEBREW_FAKE_MACOS:-}" ]; then return 1; fi
    if ! command -v brew >/dev/null 2>&1; then return 1; fi

    local os_major newest_known="" macos_rb
    os_major=$(/usr/bin/sw_vers -productVersion 2>/dev/null | cut -d. -f1)
    case "$os_major" in ''|*[!0-9]*) return 1 ;; esac

    # Read the newest version in Homebrew's own SYMBOLS table (no brew startup,
    # no network). `brew --repository` is bash-handled, so it's safe even while
    # brew's Ruby would choke on the version.
    macos_rb="$(brew --repository 2>/dev/null)/Library/Homebrew/macos_version.rb"
    if [ -r "$macos_rb" ]; then
        newest_known=$(sed -n '/SYMBOLS = /,/}/p' "$macos_rb" \
            | grep -oE ':[[:space:]]*"[0-9.]+"' \
            | grep -oE '[0-9.]+' | cut -d. -f1 | sort -n | tail -1)
    fi
    # Heuristic fallback if the table can't be parsed: macOS majors are sequential,
    # so the previous major is the most likely newest-supported.
    case "$newest_known" in ''|*[!0-9]*) newest_known=$((os_major - 1)) ;; esac

    if [ "$os_major" -gt "$newest_known" ]; then
        export HOMEBREW_FAKE_MACOS="$newest_known"
        FAKE_MACOS_APPLIED="$os_major"
        return 0
    fi
    return 1
}

# Export variables and functions
export SCRIPT_DIR
export ARCH
export BREW_PREFIX
export -f is_homebrew_installed
export -f is_xcode_clt_installed
export -f is_tool_installed
export -f maybe_fake_unsupported_macos
