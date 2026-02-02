#!/bin/bash
#
# Completion Report - Display Phase 1 completion details
#

# Source libraries
SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
# shellcheck source=scripts/lib/detect.sh
. "$SCRIPT_DIR/scripts/lib/detect.sh"
# shellcheck source=scripts/lib/ui.sh
. "$SCRIPT_DIR/scripts/lib/ui.sh"
# shellcheck source=scripts/lib/state.sh
. "$SCRIPT_DIR/scripts/lib/state.sh"
# shellcheck source=scripts/lib/logging.sh
. "$SCRIPT_DIR/scripts/lib/logging.sh"

# Determine report mode
if [ "${UPDATE_MODE:-false}" = "true" ]; then
  show_update_report
  exit 0
fi

# First-time report follows below
show_first_time_report() {

echo ""
echo ""

# Display header
ui_header "Setup Complete: Mac Ready"

echo ""

# Installed tools section
ui_section "Installed:"
echo ""

# Get versions for each tool
show_tool_version() {
    local tool="$1"
    local display_name="${2:-$tool}"

    if is_tool_installed "$tool"; then
        case "$tool" in
            brew)
                VERSION=$(brew --version 2>/dev/null | head -1 | awk '{print $2}')
                LOCATION="$BREW_PREFIX"
                ;;
            git)
                VERSION=$(git --version 2>/dev/null | awk '{print $3}')
                LOCATION=$(which git 2>/dev/null)
                ;;
            node)
                VERSION=$(node --version 2>/dev/null | sed 's/^v//')
                LOCATION=$(which node 2>/dev/null)
                ;;
            pnpm)
                VERSION=$(pnpm --version 2>/dev/null)
                LOCATION=$(which pnpm 2>/dev/null)
                ;;
            yarn)
                VERSION=$(yarn --version 2>/dev/null)
                LOCATION=$(which yarn 2>/dev/null)
                ;;
            gh)
                VERSION=$(gh --version 2>/dev/null | head -1 | awk '{print $3}')
                LOCATION=$(which gh 2>/dev/null)
                ;;
            tree)
                VERSION=$(tree --version 2>/dev/null | head -1 | awk '{print $2}')
                LOCATION=$(which tree 2>/dev/null)
                ;;
            gum)
                VERSION=$(gum --version 2>/dev/null | awk '{print $3}')
                LOCATION=$(which gum 2>/dev/null)
                ;;
            stow)
                VERSION=$(stow --version 2>/dev/null | head -1 | awk '{print $4}')
                LOCATION=$(which stow 2>/dev/null)
                ;;
            claude)
                VERSION=$(claude --version 2>/dev/null | awk '{print $2}')
                LOCATION=$(which claude 2>/dev/null)
                ;;
            *)
                VERSION="installed"
                LOCATION=$(which "$tool" 2>/dev/null)
                ;;
        esac

        if [ "$tool" = "brew" ]; then
            ui_success "$display_name ($VERSION) - $LOCATION"
        else
            ui_success "$display_name ($VERSION)"
        fi
    else
        # Check if tool is in skipped list
        if [[ " ${SKIPPED_TOOLS} " =~ " ${tool} " ]]; then
            if command -v gum >/dev/null 2>&1; then
                gum style --foreground 214 "⚠ $display_name (skipped - installation failed)"
            else
                printf "\033[38;5;214m⚠\033[0m %s\n" "$display_name (skipped - installation failed)"
            fi
        fi
    fi
}

# Show all tools
show_tool_version "brew" "Homebrew"
show_tool_version "git"
show_tool_version "node" "Node.js"
show_tool_version "pnpm"
show_tool_version "yarn"
show_tool_version "gh" "GitHub CLI"
show_tool_version "tree"
show_tool_version "gum"
show_tool_version "stow"
show_tool_version "claude" "Claude CLI"

echo ""

# Paths section
ui_section "Paths:"
echo ""
echo "  Homebrew: $BREW_PREFIX"

# Check shell config file
SHELLENV_CONFIGURED=false
if [ -f "$HOME/.zprofile" ] && grep -q "brew shellenv" "$HOME/.zprofile" 2>/dev/null; then
    echo "  Shell config: ~/.zprofile (updated)"
    SHELLENV_CONFIGURED=true
elif [ -f "$HOME/.bash_profile" ] && grep -q "brew shellenv" "$HOME/.bash_profile" 2>/dev/null; then
    echo "  Shell config: ~/.bash_profile (updated)"
    SHELLENV_CONFIGURED=true
fi

if [ "$SHELLENV_CONFIGURED" = false ]; then
    echo "  Shell config: (not updated)"
fi

echo ""

# Dotfiles & Config Status
ui_section "Dotfiles & Developer Config"
echo ""

# Check symlinks
check_symlink() {
  local target="$1"
  local name="$2"
  if [ -L "$target" ]; then
    ui_success "$name symlinked"
  elif [ -e "$target" ]; then
    ui_info "$name exists (not symlinked)"
  else
    ui_error "$name not found"
  fi
}

check_symlink "$HOME/.zshrc" "Shell config (.zshrc)"
check_symlink "$HOME/.config/starship.toml" "Starship prompt"
check_symlink "$HOME/.hyper.js" "Hyper terminal"
check_symlink "$HOME/Library/Application Support/Code/User/settings.json" "VS Code settings"
check_symlink "$HOME/.ssh/config" "SSH config"

# Check Git config (not symlinked, but should exist)
if [ -f "$HOME/.gitconfig" ]; then
  local git_name
  local git_email
  git_name=$(git config --global user.name 2>/dev/null || echo "")
  git_email=$(git config --global user.email 2>/dev/null || echo "")
  if [ -n "$git_name" ]; then
    ui_success "Git configured ($git_name <$git_email>)"
  else
    ui_info "Git config exists but incomplete"
  fi
else
  ui_error "Git config not found"
fi

# Check SSH key
if [ -f "$HOME/.ssh/id_ed25519" ]; then
  ui_success "SSH key exists"
else
  ui_info "No SSH key (run setup-ssh.sh to generate)"
fi

# Check GitHub connectivity (quick test)
if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
  ui_success "GitHub SSH connected"
else
  ui_info "GitHub SSH not connected (add key to GitHub)"
fi

echo ""

# Applications Status
ui_section "Applications"
echo ""

# Check if apps were skipped (partial installation)
if [ -n "$SKIPPED_APPS" ]; then
  ui_info "Partial installation (some apps skipped or failed)"
else
  # Check if any cask apps are installed to determine if apps section ran
  if brew list --cask 2>/dev/null | grep -qE "(google-chrome|visual-studio-code|cursor|raycast|slack)" 2>/dev/null; then
    ui_success "GUI applications installed"
  else
    ui_info "No GUI applications installed (skipped during setup)"
  fi
fi

echo ""

# System Settings Status
ui_section "System Settings"
echo ""

# Check if settings were skipped
if [ -n "$SKIPPED_SETTINGS" ]; then
  ui_info "Partial configuration (some settings skipped)"
else
  # Check if key system settings were applied
  DOCK_AUTOHIDE=$(defaults read com.apple.dock autohide 2>/dev/null || echo "0")
  FINDER_EXTENSIONS=$(defaults read NSGlobalDomain AppleShowAllExtensions 2>/dev/null || echo "0")

  if [ "$DOCK_AUTOHIDE" = "1" ] || [ "$FINDER_EXTENSIONS" = "1" ]; then
    ui_success "System preferences configured"
    echo "  - Dock: Auto-hide with fast animations"
    echo "  - Finder: Show extensions, column view"
    echo "  - Keyboard: Fast repeat (logout may be needed)"
    echo "  - Mouse/Trackpad: Maximum speed"
    echo "  - Screenshots: ~/Desktop/Screenshots (PNG)"
  else
    ui_info "System settings not applied (skipped during setup)"
  fi
fi

echo ""

# Next steps
ui_section "Next Steps"
echo ""
ui_info "1. Open a new terminal to load shell config"
ui_info "2. If GitHub SSH not connected:"
ui_info "   cat ~/.ssh/id_ed25519.pub | pbcopy"
ui_info "   open https://github.com/settings/keys"
ui_info "3. Keyboard settings may require logout to take full effect"
echo ""

}

# Update mode report function with package-level detail
show_update_report() {
  echo ""
  ui_header "Update Complete"
  echo ""

  # Time since last update
  LAST_RUN=$(state_get_last_run)
  ui_info "Previous run: $LAST_RUN"
  ui_info "Updated: $(date)"
  echo ""

  # Package-level detail for Homebrew upgrades (NEW - per user decision)
  if [ -n "${UPGRADED_PACKAGES:-}" ]; then
    ui_section "Packages Upgraded:"
    echo ""
    # UPGRADED_PACKAGES format from update-homebrew.sh: "package version1 -> version2" per line
    echo "$UPGRADED_PACKAGES" | while read -r pkg_info; do
      [ -n "$pkg_info" ] && ui_success "  $pkg_info"
    done
    echo ""
  fi

  # Categories updated (high-level)
  if [ -n "${UPDATED_CATEGORIES:-}" ]; then
    ui_section "Categories Completed:"
    echo ""
    echo -e "$UPDATED_CATEGORIES" | while read -r cat; do
      [ -n "$cat" ] && ui_success "$cat"
    done
    echo ""
  fi

  # Categories skipped
  if [ -n "${SKIPPED_CATEGORIES:-}" ]; then
    ui_section "Skipped:"
    echo ""
    echo -e "$SKIPPED_CATEGORIES" | while read -r cat; do
      [ -n "$cat" ] && ui_info "$cat (not selected)"
    done
    echo ""
  fi

  # Errors encountered
  if [ -n "${UPDATE_ERRORS:-}" ]; then
    ui_section "Errors:"
    echo ""
    echo -e "$UPDATE_ERRORS" | while read -r cat; do
      [ -n "$cat" ] && ui_error "$cat"
    done
    echo ""
  fi

  # Backup location
  BACKUP_DIR=$(ls -td ~/.local/state/dotfiles/backups/*/ 2>/dev/null | head -1)
  if [ -n "$BACKUP_DIR" ]; then
    ui_section "Backups:"
    echo ""
    ui_info "Latest backup: $BACKUP_DIR"
    echo ""
  fi

  # Log file location
  LOG_FILE=$(log_get_file 2>/dev/null || echo "")
  if [ -n "$LOG_FILE" ] && [ -f "$LOG_FILE" ]; then
    ui_section "Logs:"
    echo ""
    ui_info "Detailed log: $LOG_FILE"
    echo ""
  fi

  # Next steps for update mode
  ui_section "Next Steps"
  echo ""
  ui_info "1. Some settings may require logout to take effect"
  ui_info "2. Check for any errors above"
  ui_info "3. Run again anytime with: ./setup"
  echo ""

  # Recommended next update
  ui_info "Recommended: Run updates monthly to keep packages current"
  echo ""
}

# Run first-time report
show_first_time_report

