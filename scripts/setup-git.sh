#!/bin/bash
#
# Git Configuration Setup
#
# This script generates ~/.gitconfig from template with user's name and email,
# symlinks .gitignore_global, and supports .local overrides.

set -euo pipefail

# Detect script directory and source UI library (use SCRIPTS_DIR for sourced scripts)
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/ui.sh
. "$SCRIPTS_DIR/lib/ui.sh"

# Detect repo root
REPO_ROOT="$(cd "$SCRIPTS_DIR/.." && pwd)"

#
# Generate .gitconfig from Template
#
setup_git() {
    ui_section "Git Configuration"

    local template="$REPO_ROOT/dotfiles/git/.gitconfig.template"
    local target="$HOME/.gitconfig"

    # Check if template exists
    if [ ! -f "$template" ]; then
        ui_error "Git config template not found: $template"
        ui_info "Run plan 02-01 first to create dotfiles structure"
        return 1
    fi

    # Check if ~/.gitconfig already exists with valid user
    if [ -f "$target" ]; then
        local existing_name existing_email
        existing_name=$(git config --global user.name 2>/dev/null || echo "")
        existing_email=$(git config --global user.email 2>/dev/null || echo "")

        if [ -n "$existing_name" ] && [ -n "$existing_email" ]; then
            ui_success "Git already configured"
            ui_info "  Name: $existing_name"
            ui_info "  Email: $existing_email"

            if ! ui_confirm "Reconfigure Git?"; then
                return 0
            fi
        fi
    fi

    # Prompt for user details
    ui_info "Enter your Git configuration:"
    echo -n "Name: "
    read -r git_name
    echo -n "Email: "
    read -r git_email

    if [ -z "$git_name" ] || [ -z "$git_email" ]; then
        ui_error "Name and email are required"
        return 1
    fi

    # Backup existing if present
    if [ -f "$target" ]; then
        local timestamp
        timestamp=$(date +%Y%m%d_%H%M%S)
        mv "$target" "${target}.backup.${timestamp}"
        ui_info "Backed up existing .gitconfig"
    fi

    # Escape special characters for sed (particularly forward slashes and ampersands)
    local escaped_name escaped_email
    escaped_name=$(echo "$git_name" | sed 's/[&/\]/\\&/g')
    escaped_email=$(echo "$git_email" | sed 's/[&/\]/\\&/g')

    # Generate from template using sed
    sed -e "s/{{NAME}}/$escaped_name/g" -e "s/{{EMAIL}}/$escaped_email/g" \
        "$template" > "$target"

    # Append .local include at bottom
    echo "" >> "$target"
    echo "[include]" >> "$target"
    echo "  path = ~/.gitconfig.local" >> "$target"

    ui_success "Git configured"
    ui_info "  Name: $git_name"
    ui_info "  Email: $git_email"
}

#
# Symlink Global Gitignore
#
setup_gitignore() {
    ui_section "Global Gitignore"

    local source="$REPO_ROOT/dotfiles/git/.gitignore_global"
    local target="$HOME/.gitignore_global"

    if [ ! -f "$source" ]; then
        ui_error "Global gitignore not found: $source"
        return 1
    fi

    if [ -L "$target" ]; then
        ui_success ".gitignore_global already symlinked"
        return 0
    fi

    if [ -e "$target" ]; then
        local timestamp
        timestamp=$(date +%Y%m%d_%H%M%S)
        mv "$target" "${target}.backup.${timestamp}"
        ui_info "Backed up existing .gitignore_global"
    fi

    ln -s "$source" "$target"
    ui_success ".gitignore_global symlinked"
}

#
# Main Execution
#
main() {
    setup_git
    echo ""
    setup_gitignore
}

main
