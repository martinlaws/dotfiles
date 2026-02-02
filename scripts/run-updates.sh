#!/usr/bin/env bash
set -euo pipefail

# Update Mode Orchestrator - Main update flow with category selection

# Set SCRIPT_DIR to repo root if not already set
SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"

# Source required libraries
. "$SCRIPT_DIR/scripts/lib/detect.sh"
. "$SCRIPT_DIR/scripts/lib/ui.sh"
. "$SCRIPT_DIR/scripts/lib/state.sh"
. "$SCRIPT_DIR/scripts/lib/backup.sh"
. "$SCRIPT_DIR/scripts/lib/logging.sh"

# Initialize logging
log_init
log_info "Update mode started"

# Show update mode header
LAST_RUN=$(state_get_last_run)

ui_header "Update Mode"
echo ""
ui_info "Last setup run: $LAST_RUN"
echo ""

# Confirm user wants to proceed (REQUIRED per CONTEXT.md)
gum style --border normal --padding "1 2" --border-foreground 212 \
  "Detected previous setup" \
  "" \
  "This will check for updates and let you choose what to refresh."

echo ""
if ! ui_confirm "Run updates?"; then
  ui_info "Update cancelled"
  log_info "Update cancelled by user"
  exit 0
fi
echo ""

# Show multi-select category checklist (all pre-selected by default per CONTEXT.md)
ui_section "Select update categories:"
echo ""

# Use gum choose with --no-limit for multi-select
# All options pre-selected by default
SELECTED=$(gum choose --no-limit \
  --selected="Update Homebrew packages" \
  --selected="Refresh dotfile symlinks" \
  --selected="Re-apply system settings" \
  --selected="Check for new apps/tools" \
  "Update Homebrew packages" \
  "Refresh dotfile symlinks" \
  "Re-apply system settings" \
  "Check for new apps/tools")

if [ -z "$SELECTED" ]; then
  ui_info "No categories selected, exiting"
  log_info "No categories selected"
  exit 0
fi

# Track what was run for the report
export UPDATED_CATEGORIES=""
export SKIPPED_CATEGORIES=""
export UPDATE_ERRORS=""
export UPGRADED_PACKAGES=""  # Will be populated by update-homebrew.sh

# Run selected categories with error handling (per CONTEXT.md: stop on error, ask to continue)
run_category() {
  local name="$1"
  local script="$2"

  echo ""
  if echo "$SELECTED" | grep -q "$name"; then
    log_info "Running category: $name"
    if source "$SCRIPT_DIR/scripts/$script"; then
      UPDATED_CATEGORIES="${UPDATED_CATEGORIES}${name}\n"
      log_info "Category completed: $name"
    else
      UPDATE_ERRORS="${UPDATE_ERRORS}${name}\n"
      ui_error "$name encountered errors"
      log_error "Category failed: $name"

      if ! ui_confirm "Continue with remaining categories?"; then
        ui_info "Update stopped by user"
        log_info "Update stopped by user after error"
        return 1
      fi
    fi
  else
    SKIPPED_CATEGORIES="${SKIPPED_CATEGORIES}${name}\n"
    log_info "Category skipped (not selected): $name"
  fi
}

run_category "Update Homebrew packages" "update-homebrew.sh" || exit 1
run_category "Refresh dotfile symlinks" "update-dotfiles.sh" || exit 1
run_category "Re-apply system settings" "update-system.sh" || exit 1
run_category "Check for new apps/tools" "update-apps.sh" || exit 1

# Update state file with completion
state_set_last_run
state_set_phase_complete "04-maintenance-and-updates"
log_info "State file updated"

# Export results for report
export UPDATED_CATEGORIES
export SKIPPED_CATEGORIES
export UPDATE_ERRORS
export UPGRADED_PACKAGES  # From update-homebrew.sh
export UPDATE_MODE=true
