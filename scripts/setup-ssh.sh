#!/bin/bash
#
# SSH Key Setup and GitHub Connectivity Test
#
# This script handles SSH key generation with Ed25519, macOS keychain integration,
# and GitHub connectivity verification.

set -euo pipefail

# Detect script directory and source UI library
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=scripts/lib/ui.sh
. "$SCRIPT_DIR/lib/ui.sh"

#
# Main SSH Setup Function
#
setup_ssh() {
    ui_section "SSH Key Setup"

    # Check for existing Ed25519 key
    if [ -f ~/.ssh/id_ed25519 ]; then
        ui_success "SSH key already exists (~/.ssh/id_ed25519)"
    else
        # Prompt to generate
        ui_info "No SSH key found"
        if ui_confirm "Generate new Ed25519 SSH key?"; then
            # Get email for key comment
            echo -n "Enter email for SSH key: "
            read -r ssh_email

            if [ -z "$ssh_email" ]; then
                ui_error "Email is required for SSH key"
                return 1
            fi

            # Ensure .ssh directory exists with correct permissions
            mkdir -p ~/.ssh
            chmod 700 ~/.ssh

            # Generate key (ssh-keygen will prompt for passphrase interactively)
            ssh-keygen -t ed25519 -C "$ssh_email" -f ~/.ssh/id_ed25519

            # Add to macOS keychain
            ssh-add --apple-use-keychain ~/.ssh/id_ed25519

            ui_success "SSH key generated and added to keychain"

            # Show public key for copying
            echo ""
            ui_info "Your public key (add to GitHub):"
            echo ""
            cat ~/.ssh/id_ed25519.pub
            echo ""
            ui_info "Copy with: cat ~/.ssh/id_ed25519.pub | pbcopy"
        else
            ui_info "Skipped SSH key generation"
        fi
    fi

    # Ensure SSH config exists (should be symlinked from Plan 01)
    if [ ! -f ~/.ssh/config ]; then
        echo ""
        ui_info "Note: SSH config not found. Run symlink-dotfiles.sh first."
    fi
}

#
# GitHub Connectivity Test
#
verify_github_ssh() {
    ui_section "GitHub SSH Verification"
    ui_info "Testing connection to GitHub..."

    # ssh -T returns non-zero even on success, so check output
    local result
    result=$(ssh -T git@github.com 2>&1 || true)

    if echo "$result" | grep -q "successfully authenticated"; then
        ui_success "GitHub SSH: Connected"
        return 0
    else
        ui_error "GitHub SSH: Not connected"
        echo ""
        ui_info "To fix:"
        ui_info "  1. Copy your public key: cat ~/.ssh/id_ed25519.pub | pbcopy"
        ui_info "  2. Add to GitHub: https://github.com/settings/keys"
        ui_info "  3. Re-run this script to verify"
        return 1
    fi
}

#
# Main Execution
#
main() {
    setup_ssh
    echo ""
    verify_github_ssh || true  # Don't fail script if GitHub not configured
}

main
