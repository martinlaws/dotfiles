#!/usr/bin/env bash
set -euo pipefail

# Update Homebrew packages with preview and backup

# Set SCRIPT_DIR to repo root if not already set
SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"

# Source required libraries
. "$SCRIPT_DIR/scripts/lib/detect.sh"
. "$SCRIPT_DIR/scripts/lib/ui.sh"
. "$SCRIPT_DIR/scripts/lib/state.sh"
. "$SCRIPT_DIR/scripts/lib/backup.sh"
. "$SCRIPT_DIR/scripts/lib/logging.sh"

update_homebrew() {
  ui_section "Updating Homebrew Packages"

  # Update Homebrew
  ui_spin "Updating Homebrew..." brew update

  # Check for outdated packages
  OUTDATED=$(brew outdated)
  if [ -z "$OUTDATED" ]; then
    ui_success "All packages up to date"
    return 0
  fi

  # Show dry-run preview
  ui_info "Packages to upgrade:"
  echo ""
  brew upgrade --dry-run
  echo ""

  # Confirm before proceeding
  if ! ui_confirm "Apply these upgrades?"; then
    ui_info "Homebrew upgrade skipped"
    return 0
  fi

  # Create backup before upgrade
  backup_create_dir
  # Save current package versions
  brew list --formula --versions > "$BACKUP_DIR/brew-formulae.txt"
  brew list --cask --versions > "$BACKUP_DIR/brew-casks.txt"
  ui_info "Backup saved to: $BACKUP_DIR"

  # Run the upgrade and capture which packages were upgraded (for report)
  log_info "Starting brew upgrade"
  UPGRADE_OUTPUT=$(brew upgrade 2>&1)
  UPGRADE_STATUS=$?
  log_info "$UPGRADE_OUTPUT"

  if [ $UPGRADE_STATUS -eq 0 ]; then
    # Parse upgraded packages from output for the report
    # brew upgrade output format: "==> Upgrading package_name version1 -> version2"
    export UPGRADED_PACKAGES=$(echo "$UPGRADE_OUTPUT" | grep -E "^==> Upgrading" | sed 's/==> Upgrading //' || echo "")
    ui_success "Homebrew packages upgraded"
  else
    ui_error "Some packages failed to upgrade"
    return 1
  fi

  # Save updated package list to state
  state_save_packages
  log_info "Package list updated in state file"

  # Cleanup old backups
  backup_cleanup_old
}

# Run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  update_homebrew
fi
