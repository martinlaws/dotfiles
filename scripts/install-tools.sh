#!/bin/bash
#
# CLI Tools Installation - Install tools via Brewfile
#

# Strict mode (no -e: partial brew/fnm failures are handled inline below).
set -uo pipefail

# Source libraries
SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
# shellcheck source=scripts/lib/detect.sh
. "$SCRIPT_DIR/scripts/lib/detect.sh"
# shellcheck source=scripts/lib/ui.sh
. "$SCRIPT_DIR/scripts/lib/ui.sh"

# Report where an unexpected failure happened. Handled failures live in if/||
# conditions and won't trip this.
set -o errtrace
trap 'ui_error "failed at $(basename "$0"):$LINENO"' ERR

# Verify Homebrew is available before attempting tool installation
if ! command -v brew >/dev/null 2>&1; then
    echo ""
    ui_error "Homebrew is not installed or not in PATH"
    echo ""
    echo "Please ensure Homebrew installation completed successfully."
    echo "You may need to:"
    echo "  1. Check if /opt/homebrew/bin/brew exists (Apple Silicon)"
    echo "  2. Check if /usr/local/bin/brew exists (Intel)"
    echo "  3. Re-run the setup script"
    echo ""
    exit 1
fi

# Display section header
echo ""
ui_section "Installing CLI Tools"
echo ""

# Refresh Homebrew metadata before bundling. A freshly installed (or long-idle)
# Homebrew can carry a stale macOS-version table, so `brew bundle install` aborts
# with "unknown or unsupported macOS version: :dunno" and installs nothing.
# `brew update` is the documented prerequisite (see .planning phase 04 RESEARCH,
# pitfall #2). Foreground so progress streams; non-fatal if it complains.
ui_section "Refreshing Homebrew"
echo ""
brew update || ui_info "brew update reported an issue — continuing"
echo ""

# If macOS is newer than this Homebrew knows about (e.g. a macOS beta), every
# bottle op aborts with "unknown or unsupported macOS version: :dunno". Run this
# AFTER brew update (which may have just shipped support) and fall back to the
# newest known macOS's bottles rather than hard-failing the whole bundle.
if maybe_fake_unsupported_macos; then
    ui_info "⚠ Homebrew doesn't recognize macOS $FAKE_MACOS_APPLIED yet — using macOS $HOMEBREW_FAKE_MACOS bottles for this run (HOMEBREW_FAKE_MACOS=$HOMEBREW_FAKE_MACOS)."
    ui_info "  Once a future 'brew update' ships macOS $FAKE_MACOS_APPLIED support, unset HOMEBREW_FAKE_MACOS for native bottles."
    echo ""
fi

# Homebrew 6.x refuses to load formulae from untrusted third-party taps
# ("Refusing to load formula charmbracelet/tap/freeze from untrusted tap"), and
# `brew bundle install` ABORTS the whole file rather than skipping the one
# formula — so a single untrusted tap means ZERO tools install, not all-but-one.
# Hit on the Mac Studio 2026-08-13; the laptop was unaffected only because it had
# the formula from before the trust model landed.
#
# Trust every tap the Brewfile itself declares, so this needs no maintenance when
# taps are added or removed. Idempotent, and non-fatal if a tap is already
# trusted or the subcommand is missing on an older Homebrew.
ui_section "Trusting declared taps"
grep -E '^tap "' "$SCRIPT_DIR/config/Brewfile" 2>/dev/null \
  | sed 's/^tap "//; s/".*//' \
  | while IFS= read -r t; do
      [ -z "$t" ] && continue
      if brew trust "$t" >/dev/null 2>&1; then
          ui_success "trusted $t"
      else
          ui_info "$t — already trusted or trust unsupported; continuing"
      fi
  done
echo ""

# Check if all tools already installed
if brew bundle check --file="$SCRIPT_DIR/config/Brewfile" >/dev/null 2>&1; then
    ui_success "All tools already installed"
    exit 0
fi

# Install tools in the FOREGROUND (no spinner) so brew's progress streams to the
# terminal and a stuck step can never hang invisibly — mirrors install-apps.sh.
ui_section "Installing tools from Brewfile"
echo ""
if brew bundle install --file="$SCRIPT_DIR/config/Brewfile"; then
    INSTALL_STATUS=0
else
    INSTALL_STATUS=$?
fi
echo ""

# Check for partial failures
if [ $INSTALL_STATUS -ne 0 ] || ! brew bundle check --file="$SCRIPT_DIR/config/Brewfile" >/dev/null 2>&1; then
    echo ""
    ui_info "Checking for failed installations..."

    # Get list of all tools from Brewfile
    FAILED_TOOLS=()
    while IFS= read -r line; do
        # Extract tool name from lines like: brew "git"
        if [[ $line =~ brew[[:space:]]+\"([^\"]+)\" ]]; then
            TOOL="${BASH_REMATCH[1]}"
            if ! is_tool_installed "$TOOL"; then
                FAILED_TOOLS+=("$TOOL")
            fi
        fi
    done < "$SCRIPT_DIR/config/Brewfile"

    # Handle each failed tool
    if [ ${#FAILED_TOOLS[@]} -gt 0 ]; then
        echo ""
        ui_error "Some tools failed to install:"
        for tool in "${FAILED_TOOLS[@]}"; do
            echo "  - $tool"
        done
        echo ""

        # Prompt to continue (pre-answered under --unattended / dotfiles.env)
        if ui_confirm_continue "Continue anyway?"; then
            ui_info "Continuing with partial installation..."
            # Export failed tools for report
            export SKIPPED_TOOLS="${FAILED_TOOLS[*]}"
        else
            ui_error "Installation aborted"
            exit 1
        fi
    fi
else
    ui_success "All CLI tools installed successfully"
fi

# Pin a default Node via fnm so a fresh machine has working node/npm immediately.
# (fnm installs the manager but ships no Node until a version is installed.)
if command -v fnm >/dev/null 2>&1; then
    echo ""
    ui_section "Installing Node LTS (via fnm)"
    echo ""
    eval "$(fnm env)" 2>/dev/null || true
    if fnm list 2>/dev/null | grep -q 'lts-latest'; then
        ui_success "fnm default Node already installed"
    else
        # Foreground so fnm's download/build progress streams to the terminal.
        if fnm install --lts; then
            fnm default lts-latest 2>/dev/null || true
            ui_success "Node LTS installed and set as fnm default"
        else
            ui_error "fnm Node install failed — run 'fnm install --lts' by hand later"
        fi
    fi
fi

echo ""
