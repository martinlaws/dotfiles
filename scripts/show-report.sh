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

echo ""
echo ""

# Display header
ui_header "Phase 1 Complete: Foundation Ready"

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
                echo -e "\033[38;5;214m⚠\033[0m $display_name (skipped - installation failed)"
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

# Next steps
ui_section "Next Steps:"
echo ""
echo "  Run Phase 2 to symlink dotfiles and configure Git/SSH"
echo ""

