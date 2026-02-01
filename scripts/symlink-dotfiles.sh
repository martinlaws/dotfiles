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

# Validate config files before symlinking
validate_configs() {
  local issues=()
  local DOTFILES_DIR="$1"

  ui_section "Validating Config Files"

  # Check .zshrc exists and has content
  if [ ! -f "$DOTFILES_DIR/shell/.zshrc" ]; then
    issues+=("shell/.zshrc: File not found")
  elif [ ! -s "$DOTFILES_DIR/shell/.zshrc" ]; then
    issues+=("shell/.zshrc: File is empty")
  fi

  # Check starship.toml is valid TOML (basic check - has format key)
  if [ -f "$DOTFILES_DIR/shell/.config/starship.toml" ]; then
    if ! grep -q "format\|add_newline" "$DOTFILES_DIR/shell/.config/starship.toml"; then
      issues+=("starship.toml: May be invalid (no format or add_newline key)")
    fi
  fi

  # Check .gitconfig.template has required placeholders
  if [ -f "$DOTFILES_DIR/git/.gitconfig.template" ]; then
    if ! grep -q "{{NAME}}" "$DOTFILES_DIR/git/.gitconfig.template"; then
      issues+=(".gitconfig.template: Missing {{NAME}} placeholder")
    fi
    if ! grep -q "{{EMAIL}}" "$DOTFILES_DIR/git/.gitconfig.template"; then
      issues+=(".gitconfig.template: Missing {{EMAIL}} placeholder")
    fi
  else
    issues+=(".gitconfig.template: File not found")
  fi

  # Check SSH config has basic structure
  if [ -f "$DOTFILES_DIR/ssh/.ssh/config" ]; then
    if ! grep -q "Host" "$DOTFILES_DIR/ssh/.ssh/config"; then
      issues+=("ssh/config: No Host entries found")
    fi
  fi

  # Check VS Code settings.json is valid JSON (basic check)
  local vscode_settings="$DOTFILES_DIR/editors/Library/Application Support/Code/User/settings.json"
  if [ -f "$vscode_settings" ]; then
    # Check it starts with { and ends with }
    if ! head -1 "$vscode_settings" | grep -q "^{" || ! tail -1 "$vscode_settings" | grep -q "}$"; then
      issues+=("VS Code settings.json: May be invalid JSON")
    fi
  fi

  # Report results
  if [ ${#issues[@]} -eq 0 ]; then
    ui_success "All config files validated"
    return 0
  else
    ui_error "Found ${#issues[@]} validation issue(s):"
    echo ""
    for issue in "${issues[@]}"; do
      ui_info "  - $issue"
    done
    echo ""

    # User decision point
    if ui_confirm "Continue anyway?"; then
      ui_info "Continuing with symlinking..."
      return 0
    else
      ui_error "Aborting. Fix issues and re-run."
      return 1
    fi
  fi
}

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

  # Validate configs before proceeding
  validate_configs "$DOTFILES_DIR" || return 1

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
