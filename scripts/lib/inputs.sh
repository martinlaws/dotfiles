#!/bin/bash
#
# Input Library - front-loaded answers for every question setup asks
#
# Gathers git identity + every interactive confirm at minute 0, so the rest of
# `sh setup` runs without babysitting. Answers come from three places, in order:
#
#   1. ~/.config/dotfiles.env, sourced if present — config present, zero prompts
#   2. what the machine already has (git config, a reachable SSH key, ~/.claude)
#   3. asking — once, up front. --unattended substitutes safe defaults for every
#      skippable question instead of asking.
#
# dotfiles.env is plain shell, every key optional:
#
#   DOTFILES_GIT_NAME="Martin Laws"      # git identity for ~/.gitconfig
#   DOTFILES_GIT_EMAIL="hey@mlaws.ca"
#   DOTFILES_RESTORE_CLAUDE=yes          # restore ~/.claude from claude-config?
#   DOTFILES_GENERATE_SSH_KEY=no         # mint a local key when none is found?
#   DOTFILES_SSH_EMAIL=""                # key comment (default: git email)
#   DOTFILES_APPLY_SYSTEM_SETTINGS=yes   # apply ALL recommended macOS defaults?
#   DOTFILES_CONTINUE_ON_ERROR=yes       # pre-answer every "continue anyway?"
#
# ⚠ DOTFILES_GENERATE_SSH_KEY=yes under --unattended mints the key with an
# EMPTY passphrase — ssh-keygen's passphrase prompt would block the run, and
# the 1Password agent is the expected key source anyway.

DOTFILES_ENV_FILE="${DOTFILES_ENV_FILE:-$HOME/.config/dotfiles.env}"

inputs_load_env() {
    [ -f "$DOTFILES_ENV_FILE" ] || return 0
    # shellcheck source=/dev/null
    . "$DOTFILES_ENV_FILE"
    ui_success "Answers loaded from ${DOTFILES_ENV_FILE/#$HOME/~}"
}

# Default-yes confirm that works before gum exists. ui_confirm's plain-read
# fallback defaults to No; every question here is "recommended — do it", so
# a bare Enter must mean yes on both paths.
inputs_confirm_yes() {
    local question="$1" response
    if command -v gum >/dev/null 2>&1; then
        gum confirm "$question"
    else
        printf "%s [Y/n] " "$question"
        read -r response
        case "$response" in
            [Nn]*) return 1 ;;
            *) return 0 ;;
        esac
    fi
}

inputs_gather() {
    ui_section "Setup questions — answering everything now, no prompts after this"
    echo ""

    # Git identity: env file first, then whatever this machine already has.
    # Only ask git once CLT exists — before that /usr/bin/git is a stub that
    # nags about developer tools instead of answering.
    if [ -z "${DOTFILES_GIT_NAME:-}" ] && xcode-select -p >/dev/null 2>&1; then
        DOTFILES_GIT_NAME="$(git config --global user.name 2>/dev/null || true)"
    fi
    if [ -z "${DOTFILES_GIT_EMAIL:-}" ] && xcode-select -p >/dev/null 2>&1; then
        DOTFILES_GIT_EMAIL="$(git config --global user.email 2>/dev/null || true)"
    fi
    while [ -z "${DOTFILES_GIT_NAME:-}" ]; do
        printf "Git name: "
        read -r DOTFILES_GIT_NAME
    done
    while [ -z "${DOTFILES_GIT_EMAIL:-}" ]; do
        printf "Git email: "
        read -r DOTFILES_GIT_EMAIL
    done

    # Claude config restore — moot once ~/.claude is already a repo (the
    # restore script early-returns before its confirm), so only ask when not.
    if [ -z "${DOTFILES_RESTORE_CLAUDE:-}" ] && [ ! -d "$HOME/.claude/.git" ]; then
        if [ "${DOTFILES_UNATTENDED:-false}" = true ]; then
            DOTFILES_RESTORE_CLAUDE=yes
        elif inputs_confirm_yes "Restore Claude Code config (skills/agents/memory) from claude-config?"; then
            DOTFILES_RESTORE_CLAUDE=yes
        else
            DOTFILES_RESTORE_CLAUDE=no
        fi
    fi

    # SSH keygen — a live question only when no key is reachable at all
    # (1Password agent empty/absent AND no local key). The unattended default
    # is NO: the key is expected to arrive via the 1Password agent, and
    # skipping never blocks — setup-ssh.sh prints the GitHub fix-it steps.
    if [ -z "${DOTFILES_GENERATE_SSH_KEY:-}" ]; then
        local op_sock="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
        if [ -f "$HOME/.ssh/id_ed25519" ] \
            || { [ -S "$op_sock" ] && SSH_AUTH_SOCK="$op_sock" ssh-add -l >/dev/null 2>&1; }; then
            DOTFILES_GENERATE_SSH_KEY=no    # a key already exists — moot
        elif [ "${DOTFILES_UNATTENDED:-false}" = true ]; then
            DOTFILES_GENERATE_SSH_KEY=no
            ui_info "⚠ No SSH key found — skipping keygen (unattended); sign into 1Password to supply one"
        elif inputs_confirm_yes "No SSH key found. Generate a local Ed25519 key?"; then
            DOTFILES_GENERATE_SSH_KEY=yes
        else
            DOTFILES_GENERATE_SSH_KEY=no
        fi
    fi
    if [ "${DOTFILES_GENERATE_SSH_KEY:-no}" = yes ] && [ -z "${DOTFILES_SSH_EMAIL:-}" ]; then
        DOTFILES_SSH_EMAIL="$DOTFILES_GIT_EMAIL"
    fi

    # macOS defaults — one up-front yes/no replaces the mid-run multi-select;
    # run scripts/configure-system.sh alone for the per-item picker.
    if [ -z "${DOTFILES_APPLY_SYSTEM_SETTINGS:-}" ]; then
        if [ "${DOTFILES_UNATTENDED:-false}" = true ]; then
            DOTFILES_APPLY_SYSTEM_SETTINGS=yes
        elif inputs_confirm_yes "Apply recommended macOS settings (Dock/Finder/Keyboard/Trackpad/Screenshots)?"; then
            DOTFILES_APPLY_SYSTEM_SETTINGS=yes
        else
            DOTFILES_APPLY_SYSTEM_SETTINGS=no
        fi
    fi

    # "Continue anyway?" failure prompts stay interactive on attended runs
    # unless the env file pre-answers them (ui_confirm_continue handles the
    # unattended default at the call sites).
    DOTFILES_SSH_EMAIL="${DOTFILES_SSH_EMAIL:-}"
    export DOTFILES_GIT_NAME DOTFILES_GIT_EMAIL DOTFILES_GENERATE_SSH_KEY
    export DOTFILES_SSH_EMAIL DOTFILES_APPLY_SYSTEM_SETTINGS
    if [ -n "${DOTFILES_RESTORE_CLAUDE:-}" ]; then
        export DOTFILES_RESTORE_CLAUDE
    fi
    if [ -n "${DOTFILES_CONTINUE_ON_ERROR:-}" ]; then
        export DOTFILES_CONTINUE_ON_ERROR
    fi

    echo ""
    ui_success "Inputs locked in — the rest of the run won't ask questions"
}
