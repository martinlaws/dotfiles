#!/bin/bash
#
# Playwright, global under fnm's default Node, with its Chromium — since 2026-11-14
#
# Why: a one-off browser check (a page loads, a screenshot, no console errors)
# is a script in /tmp, and `require('playwright')` only finds a global copy when
# NODE_PATH points at the global modules — which .zshrc now does. Claude's cloud
# machines work this way; before this, the Studio had Playwright only inside one
# project (martin-laws-website), and a check had to borrow it.
#
# Idempotent: npm skips the package when it's there, and `playwright install`
# skips a browser already in ~/Library/Caches/ms-playwright. Unpinned on
# purpose: re-running after a Node or Playwright upgrade fetches the matching
# Chromium. Old browser builds stay in the cache until `playwright uninstall`.

set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/ui.sh
. "$SCRIPTS_DIR/lib/ui.sh"

# fnm's default ALIAS, never `which node` (per-shell, dies on reboot) — the same
# path the chaos launchd agents use. setup runs this in a fresh `sh`, where
# fnm's shell init hasn't run.
export PATH="$HOME/.local/share/fnm/aliases/default/bin:$PATH"

ui_section "Playwright (global, with Chromium)"

if ! command -v npm >/dev/null 2>&1; then
    ui_error "npm not found — install Node first: fnm install --lts && fnm default lts-latest"
    exit 1
fi

GLOBAL_MODULES="$(npm root -g)"

if [ -d "$GLOBAL_MODULES/playwright" ]; then
    ui_success "playwright $(npx --no-install playwright --version 2>/dev/null | awk '{print $2}') already installed globally"
else
    ui_info "Installing playwright globally…"
    npm install -g playwright
    ui_success "playwright installed globally"
fi

# Foreground so the download progress streams to the terminal.
playwright install chromium
ui_success "Chromium for Playwright ready"

if NODE_PATH="$GLOBAL_MODULES" node -e "require('playwright')" 2>/dev/null; then
    ui_success "require('playwright') resolves from any folder (NODE_PATH in .zshrc)"
else
    ui_error "require('playwright') failed — check NODE_PATH in .zshrc"
    exit 1
fi
