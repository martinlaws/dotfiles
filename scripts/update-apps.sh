#!/usr/bin/env bash
set -euo pipefail

# Check for Brewfile drift and sync applications

# Set SCRIPT_DIR to repo root if not already set
SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"

# Source required libraries
. "$SCRIPT_DIR/scripts/lib/detect.sh"
. "$SCRIPT_DIR/scripts/lib/ui.sh"
. "$SCRIPT_DIR/scripts/lib/state.sh"
. "$SCRIPT_DIR/scripts/lib/backup.sh"
. "$SCRIPT_DIR/scripts/lib/logging.sh"

update_apps() {
  ui_section "Checking Applications"

  # Brewfile location from Phase 1
  BREWFILE="$SCRIPT_DIR/config/Brewfile.apps"

  if [ ! -f "$BREWFILE" ]; then
    ui_error "Brewfile not found at: $BREWFILE"
    return 1
  fi

  # Get what's installed
  INSTALLED_CASKS=$(brew list --cask 2>/dev/null | sort)

  # Get what's in Brewfile (extract cask names from main Brewfile)
  # Pattern: cask "app-name" or cask "app-name", ...
  BREWFILE_CASKS=$(grep "^cask " "$BREWFILE" 2>/dev/null | sed 's/cask "\([^"]*\)".*/\1/' | sort)

  # Find manually installed casks (installed but not in Brewfile)
  MANUAL_INSTALLS=$(comm -23 <(echo "$INSTALLED_CASKS") <(echo "$BREWFILE_CASKS"))

  if [ -n "$MANUAL_INSTALLS" ]; then
    ui_info "Found manually installed apps not in Brewfile:"
    echo "$MANUAL_INSTALLS" | while read -r cask; do
      echo "  - $cask"
    done
    echo ""

    if ui_confirm "Add these to Brewfile?"; then
      # Backup Brewfile first
      cp "$BREWFILE" "$BREWFILE.backup.$(date +%Y%m%d-%H%M%S)"

      echo "$MANUAL_INSTALLS" | while read -r cask; do
        echo "cask \"$cask\"" >> "$BREWFILE"
      done
      ui_success "Added to Brewfile (backup saved)"
    fi
  fi

  # Find missing casks (in Brewfile but not installed)
  MISSING_CASKS=$(comm -13 <(echo "$INSTALLED_CASKS") <(echo "$BREWFILE_CASKS"))

  if [ -n "$MISSING_CASKS" ]; then
    ui_info "Apps in Brewfile but not installed:"
    echo "$MISSING_CASKS" | while read -r cask; do
      echo "  - $cask"
    done
    echo ""

    # Check if gum is available
    if command -v gum &> /dev/null; then
      CHOICE=$(gum choose "Install them" "Remove from Brewfile" "Skip")
    else
      # Fallback without gum
      ui_info "Options: [i]nstall, [r]emove from Brewfile, [s]kip"
      read -p "Choice: " -n 1 -r CHOICE_CHAR
      echo ""
      case "$CHOICE_CHAR" in
        i|I) CHOICE="Install them" ;;
        r|R) CHOICE="Remove from Brewfile" ;;
        *) CHOICE="Skip" ;;
      esac
    fi

    case "$CHOICE" in
      "Install them")
        echo "$MISSING_CASKS" | while read -r cask; do
          ui_spin "Installing $cask..." brew install --cask "$cask"
        done
        ;;
      "Remove from Brewfile")
        cp "$BREWFILE" "$BREWFILE.backup.$(date +%Y%m%d-%H%M%S)"
        echo "$MISSING_CASKS" | while read -r cask; do
          sed -i '' "/^cask \"$cask\"/d" "$BREWFILE"
        done
        ui_success "Removed from Brewfile (backup saved)"
        ;;
      "Skip")
        ui_info "Skipped"
        ;;
    esac
  fi

  # If nothing to do
  if [ -z "$MANUAL_INSTALLS" ] && [ -z "$MISSING_CASKS" ]; then
    ui_success "All Brewfile apps are in sync"
  fi
}

# Run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  update_apps
fi
