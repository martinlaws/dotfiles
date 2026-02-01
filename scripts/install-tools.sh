#!/bin/bash
#
# CLI Tools Installation - Install tools via Brewfile
#

# Source libraries
SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
# shellcheck source=scripts/lib/detect.sh
. "$SCRIPT_DIR/scripts/lib/detect.sh"
# shellcheck source=scripts/lib/ui.sh
. "$SCRIPT_DIR/scripts/lib/ui.sh"

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

# Check if all tools already installed
if brew bundle check --file="$SCRIPT_DIR/config/Brewfile" >/dev/null 2>&1; then
    ui_success "All tools already installed"
    return 0
fi

# Install tools with progress
if [ "$VERBOSE" = true ]; then
    # Verbose mode: show full brew output
    echo "Running: brew bundle install --file=$SCRIPT_DIR/config/Brewfile"
    brew bundle install --file="$SCRIPT_DIR/config/Brewfile"
    INSTALL_STATUS=$?
else
    # Normal mode: use spinner
    ui_spin "Installing CLI tools..." "brew bundle install --file='$SCRIPT_DIR/config/Brewfile' 2>&1"
    INSTALL_STATUS=$?
fi

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

        # Prompt to continue
        if ui_confirm "Continue anyway?"; then
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

echo ""
