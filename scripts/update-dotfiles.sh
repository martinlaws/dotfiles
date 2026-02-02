#!/usr/bin/env bash
set -euo pipefail

# Refresh dotfile symlinks with conflict and content drift detection

# Set SCRIPT_DIR to repo root if not already set
SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"

# Source required libraries
. "$SCRIPT_DIR/scripts/lib/detect.sh"
. "$SCRIPT_DIR/scripts/lib/ui.sh"
. "$SCRIPT_DIR/scripts/lib/state.sh"
. "$SCRIPT_DIR/scripts/lib/backup.sh"
. "$SCRIPT_DIR/scripts/lib/logging.sh"

check_dotfile_conflict() {
  local target="$1"
  local expected_source="$2"

  if [ -L "$target" ]; then
    # It's a symlink - check if it points to our repo
    CURRENT_LINK=$(readlink "$target")
    if [[ "$CURRENT_LINK" != *"$SCRIPT_DIR"* ]]; then
      ui_info "Warning: $target points to unexpected location: $CURRENT_LINK"
      return 1
    fi

    # NEW: Check for content drift - symlink target may differ from repo source
    # This catches cases where user edited the symlink target directly
    ACTUAL_CONTENT="$CURRENT_LINK"
    if [ -f "$ACTUAL_CONTENT" ] && [ -f "$expected_source" ]; then
      if ! diff -q "$ACTUAL_CONTENT" "$expected_source" >/dev/null 2>&1; then
        ui_info "Warning: $target content differs from repo version"
        echo "  Symlink points to: $ACTUAL_CONTENT"
        echo "  Repo source: $expected_source"
        echo ""
        # Show a brief diff
        diff --color=auto -u "$expected_source" "$ACTUAL_CONTENT" | head -20 || true
        echo ""
        if ui_confirm "Update repo with current version before restow?"; then
          cp "$ACTUAL_CONTENT" "$expected_source"
          ui_success "Repo updated with your changes"
        else
          ui_info "Will overwrite with repo version on restow"
        fi
      fi
    fi
  elif [ -f "$target" ]; then
    # Regular file - user may have edited it directly (not a symlink at all)
    ui_info "Warning: $target is a regular file, not a symlink"
    if ui_confirm "Move $target to repo and create symlink?"; then
      cp "$target" "$expected_source"
      rm "$target"
      ui_success "Moved to repo"
    else
      ui_info "Skipping $target"
      return 1
    fi
  fi
  return 0
}

update_dotfiles() {
  ui_section "Refreshing Dotfile Symlinks"

  # Define stow packages to refresh
  STOW_PACKAGES="git shell terminal editors ssh"
  STOW_DIR="$SCRIPT_DIR/dotfiles"

  # Check for conflicts (simplified - full check would iterate all expected files)
  # For now, focus on the common ones users edit
  COMMON_FILES=(
    "$HOME/.gitconfig:$STOW_DIR/git/.gitconfig"
    "$HOME/.zshrc:$STOW_DIR/zsh/.zshrc"
    "$HOME/.ssh/config:$STOW_DIR/ssh/.ssh/config"
  )

  HAS_CONFLICTS=false
  for file_pair in "${COMMON_FILES[@]}"; do
    IFS=':' read -r target source <<< "$file_pair"
    if ! check_dotfile_conflict "$target" "$source" 2>/dev/null; then
      HAS_CONFLICTS=true
    fi
  done

  # Show what will be restowed
  ui_info "Will refresh symlinks for: $STOW_PACKAGES"
  echo ""
  stow --simulate -v -R -d "$STOW_DIR" -t "$HOME" $STOW_PACKAGES 2>&1 | head -20
  echo ""

  # Confirm before proceeding
  if ! ui_confirm "Refresh these symlinks?"; then
    ui_info "Symlink refresh skipped"
    return 0
  fi

  # Run stow --restow for each package
  for pkg in $STOW_PACKAGES; do
    if stow -R -d "$STOW_DIR" -t "$HOME" "$pkg" 2>/dev/null; then
      ui_success "Restowed: $pkg"
    else
      ui_error "Failed to restow: $pkg"
      log_error "Stow failed for package: $pkg"
      # Continue to next package, don't abort
    fi
  done
}

# Run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  update_dotfiles
fi
