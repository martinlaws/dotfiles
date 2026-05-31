#!/bin/bash
#
# hey CLI install (Go binary built from source)
#
# `hey` (https://github.com/basecamp/hey-cli) has no Homebrew tap and no release
# with calendar-event support. The event commands (list/create/edit/delete) that
# our /book + /avails booking flows depend on live ONLY on the open PR #79
# ("Add hey event commands"), which is itself pinned to an unreleased hey-sdk.
# So until #79 merges and a release is cut, we build from the PR head.
#
# TODO(when #79 merges + a release is tagged): drop the PR-head fetch below and
# switch to `go install github.com/basecamp/hey-cli/cmd/hey@latest` or a brew tap.

set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/ui.sh
. "$SCRIPTS_DIR/lib/ui.sh"

REPO_URL="https://github.com/basecamp/hey-cli"
REPO_DIR="$HOME/code/hey-cli"
PR_REF="pull/79/head"            # event commands — open PR #79
DEST="$HOME/.local/bin/hey"

install_hey() {
    ui_section "hey CLI"

    if ! command -v go >/dev/null 2>&1; then
        ui_error "Go not found — ensure 'brew \"go\"' is installed (Phase 1) first."
        return 1
    fi

    # Idempotent: if hey is already installed, leave it (and the repo) untouched.
    if [ -x "$DEST" ]; then
        ui_success "hey already installed ($DEST) — skipping build"
        return 0
    fi

    # Clone the source if we don't have it yet.
    if [ ! -d "$REPO_DIR/.git" ]; then
        ui_info "Cloning hey-cli into ${REPO_DIR/#$HOME/~}"
        git clone "$REPO_URL" "$REPO_DIR"
    fi

    cd "$REPO_DIR"

    # Never clobber a dirty working tree (e.g. in-progress local event work).
    if ! git diff --quiet || ! git diff --cached --quiet; then
        ui_error "${REPO_DIR/#$HOME/~} has uncommitted changes — build it manually."
        return 1
    fi

    # Build from the PR #79 head (detached) so we get event support.
    ui_info "Fetching PR #79 (event commands) and building…"
    git fetch --quiet origin "$PR_REF"
    git checkout --quiet --detach FETCH_HEAD

    # GOTOOLCHAIN=auto lets a stable Homebrew Go auto-fetch the 1.26 toolchain
    # that go.mod requires; `make build` stamps the version via LDFLAGS.
    GOTOOLCHAIN=auto make build
    mkdir -p "$(dirname "$DEST")"
    install -m 0755 bin/hey "$DEST"  # ~/.local/bin/hey — no sudo, unlike `make install`

    ui_success "hey installed → $DEST"
}

install_hey
