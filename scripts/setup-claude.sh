#!/bin/bash
#
# Claude Code Config Restore
#
# Clones the private claude-config repo (skills, agents, hooks, settings,
# memory) into ~/.claude. Claude Code creates ~/.claude on first run; this
# layers the versioned "brain" back on top.
#
# Repo: git@github.com:martinlaws/claude-config.git (PRIVATE)

set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/ui.sh
. "$SCRIPTS_DIR/lib/ui.sh"

CLAUDE_DIR="$HOME/.claude"
CLAUDE_REPO="git@github.com:martinlaws/claude-config.git"

setup_claude() {
    ui_section "Claude Code Config"

    # Already a git repo? Nothing to do.
    if [ -d "$CLAUDE_DIR/.git" ]; then
        ui_success "~/.claude already version-controlled"
        return 0
    fi

    if ! ui_confirm "Restore Claude Code config (skills/agents/memory) from claude-config?"; then
        ui_info "Skipped Claude config restore"
        return 0
    fi

    # Verify GitHub SSH works first (claude-config is private, SSH-only).
    # Capture-then-grep, NOT `ssh ... | grep`: `ssh -T git@github.com` always
    # exits non-zero (GitHub provides no shell), so under this script's
    # `set -o pipefail` a direct pipe makes the check fail even when auth
    # succeeds. Mirrors verify_github_ssh in setup-ssh.sh.
    local ssh_result
    ssh_result=$(ssh -T git@github.com 2>&1 || true)
    if ! echo "$ssh_result" | grep -q "successfully authenticated"; then
        ui_error "GitHub SSH not authenticated — run setup-ssh.sh first"
        ui_info "claude-config is private; the clone needs a working SSH key"
        return 1
    fi

    if [ -d "$CLAUDE_DIR" ]; then
        # ~/.claude exists (Claude Code ran once) but isn't a repo yet.
        # Init in place and pull, rather than clobbering live state.
        ui_info "~/.claude exists; attaching repo in place"
        git -C "$CLAUDE_DIR" init -q
        git -C "$CLAUDE_DIR" remote add origin "$CLAUDE_REPO"
        git -C "$CLAUDE_DIR" fetch origin -q
        git -C "$CLAUDE_DIR" checkout -f main
        ui_success "claude-config restored into existing ~/.claude"
    else
        git clone "$CLAUDE_REPO" "$CLAUDE_DIR"
        ui_success "claude-config cloned to ~/.claude"
    fi

    ui_info "Re-auth Claude Code (regenerates .credentials.json) and re-add MCP servers"
}

main() {
    setup_claude
}

main
