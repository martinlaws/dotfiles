#!/bin/bash
#
# GUI Application Installation — installs every cask in config/Brewfile.apps,
# one at a time, with visible per-app progress. No spinner (so brew's output and
# any password prompt stay visible and answerable), and one stuck cask never
# silently blocks the rest.
#

# Source libraries
SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
# shellcheck source=scripts/lib/detect.sh
. "$SCRIPT_DIR/scripts/lib/detect.sh"
# shellcheck source=scripts/lib/ui.sh
. "$SCRIPT_DIR/scripts/lib/ui.sh"

# Verify Homebrew is available before attempting app installation
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
ui_header "GUI Application Installation"
echo ""

# Parse Brewfile.apps to extract cask tokens (one per line)
parse_apps() {
    local brewfile="$SCRIPT_DIR/config/Brewfile.apps"
    while IFS= read -r line; do
        if [[ $line =~ ^cask[[:space:]]+\"([^\"]+)\" ]]; then
            echo "${BASH_REMATCH[1]}"
        fi
    done < "$brewfile"
}

# Collect all casks (default: install everything)
SELECTED_APPS=()
while IFS= read -r app; do
    [ -n "$app" ] && SELECTED_APPS+=("$app")
done <<EOF
$(parse_apps)
EOF

if [ ${#SELECTED_APPS[@]} -eq 0 ]; then
    ui_error "No casks found in config/Brewfile.apps"
    exit 1
fi

ui_success "Installing all ${#SELECTED_APPS[@]} applications"
ui_info "Edit config/Brewfile.apps to change the set. Watch for the occasional password prompt."
echo ""

# Install one cask at a time, in the FOREGROUND (no spinner) so brew's progress
# bars and any sudo/password prompt are visible and answerable. Failures are
# collected, not fatal — the run continues through the whole list.
total=${#SELECTED_APPS[@]}
i=0
installed=0
skipped=0
FAILED_APPS=()

for app in "${SELECTED_APPS[@]}"; do
    i=$((i + 1))
    if brew list --cask "$app" >/dev/null 2>&1; then
        ui_info "[$i/$total] $app — already installed, skipping"
        skipped=$((skipped + 1))
        continue
    fi
    echo ""
    ui_section "[$i/$total] Installing $app …"
    if brew install --cask "$app"; then
        ui_success "[$i/$total] $app installed"
        installed=$((installed + 1))
    else
        ui_error "[$i/$total] $app failed — continuing with the rest"
        FAILED_APPS+=("$app")
    fi
done

# Summary
echo ""
ui_section "Apps: ${installed} installed · ${skipped} already present · ${#FAILED_APPS[@]} failed (of ${total})"
if [ ${#FAILED_APPS[@]} -gt 0 ]; then
    echo ""
    ui_error "Failed casks — re-run setup to retry, or install by hand:"
    for app in "${FAILED_APPS[@]}"; do
        echo "  - $app   (brew install --cask $app)"
    done
    export SKIPPED_APPS="${FAILED_APPS[*]}"
fi
echo ""
