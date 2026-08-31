#!/bin/bash
#
# hey CLI install (official release binary)
#
# `hey` (https://github.com/basecamp/hey-cli) ships tagged releases and an
# official installer as of v1.0.0 (2026-08-24). Martin moved off his local
# fork build on 2026-08-31 — see chaos technical/2026-08-31-hey-fork-retirement-*.
#
# The installer downloads the release for this platform, verifies its SHA-256
# against the release checksums (and its Sigstore signature when cosign is
# present), and installs to $HOME/.local/bin — which is already on PATH and is
# the path chaos hardcodes (dashboard/scripts/refresh-calendar.ts resolves
# ~/.local/bin/hey before falling back to PATH).
#
# HEY_SETUP_AGENT=none: do NOT auto-connect coding agents or link a hey skill
# into ~/.claude — chaos carries its own /triage-emails and /book skills, and an
# ungated vendor skill that advertises "send email" would sit beside them.
# HEY_SKIP_SETUP=1: no interactive OAuth wizard during an unattended `sh setup`.
#
# ⚠ The env vars MUST sit to the RIGHT of the pipe. `VAR=x curl … | bash` binds
# them to curl, and bash never sees them.

set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/ui.sh
. "$SCRIPTS_DIR/lib/ui.sh"

DEST="$HOME/.local/bin/hey"

install_hey() {
    ui_section "hey CLI"

    # Idempotent: if hey is already installed, leave it. Upgrades are `hey upgrade`.
    if [ -x "$DEST" ]; then
        ui_success "hey already installed ($DEST, $("$DEST" --version 2>/dev/null || echo unknown)) — skipping"
        ui_info "To upgrade later: hey upgrade"
        return 0
    fi

    if ! command -v curl >/dev/null 2>&1; then
        ui_error "curl not found — cannot fetch the hey installer."
        return 1
    fi

    ui_info "Installing hey from the official release channel…"
    curl -fsSL https://hey.com/install-cli \
      | HEY_BIN_DIR="$HOME/.local/bin" HEY_SETUP_AGENT=none HEY_SKIP_SETUP=1 bash

    if [ ! -x "$DEST" ]; then
        ui_error "hey did not land at $DEST — check the installer output above."
        return 1
    fi

    ui_success "hey installed → $DEST ($("$DEST" --version 2>/dev/null || echo unknown))"
    ui_info "Authenticate with: hey auth login"
}

install_hey
