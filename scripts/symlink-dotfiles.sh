#!/bin/bash
#
# Symlink Dotfiles - Uses GNU Stow to create symlinks with backup functionality
#
set -euo pipefail

# Get script directory for relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source UI library
source "$SCRIPT_DIR/lib/ui.sh"

# Backup existing file/directory
backup_existing() {
  local target="$1"
  if [ -e "$target" ] || [ -L "$target" ]; then
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup="${target}.backup.${timestamp}"
    mv "$target" "$backup"
    ui_info "Backed up: $(basename "$target") -> $(basename "$backup")"
  fi
}

# Main function
main() {
  ui_header "Symlinking Dotfiles"

  # Check that stow is installed
  if ! command -v stow >/dev/null 2>&1; then
    ui_error "GNU Stow is not installed"
    ui_info "Install with: brew install stow"
    exit 1
  fi

  # Define dotfiles directory
  DOTFILES_DIR="$REPO_ROOT/dotfiles"

  # Backup existing files before stowing
  ui_section "Backing up existing configs"

  backup_existing "$HOME/.zshrc"

  # Create ~/.config if needed
  mkdir -p "$HOME/.config"
  backup_existing "$HOME/.config/starship.toml"

  backup_existing "$HOME/.hyper.js"

  # Create parent directories for VS Code if needed
  mkdir -p "$HOME/Library/Application Support/Code/User"
  backup_existing "$HOME/Library/Application Support/Code/User/settings.json"

  # Create ~/.ssh if needed with proper permissions
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  backup_existing "$HOME/.ssh/config"

  # Stow packages
  ui_section "Creating symlinks"

  # Stow shell package
  stow -d "$DOTFILES_DIR" -t ~ shell
  ui_success "Symlinked shell configs"

  # Stow terminal package
  stow -d "$DOTFILES_DIR" -t ~ terminal
  ui_success "Symlinked terminal configs"

  # Stow editors package (VS Code/Cursor settings)
  stow -d "$DOTFILES_DIR" -t ~ editors
  ui_success "Symlinked editor configs"

  # Stow ssh package with directory permissions
  stow -d "$DOTFILES_DIR" -t ~ ssh
  chmod 700 "$HOME/.ssh"
  ui_success "Symlinked SSH config"

  echo ""
  ui_success "Dotfiles symlinked successfully!"
  ui_info "Note: Git config will be generated from template by setup-git.sh"

  return 0
}

main "$@"
