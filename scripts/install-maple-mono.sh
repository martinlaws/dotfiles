#!/bin/bash
#
# Maple Mono v8 (variable) install — the Ghostty + Zed font since 2026-09-14
#
# Why a script and not a Brewfile cask: `font-maple-mono` on Homebrew is the
# stable 7.9 release, and 7.9's upright face has NO ★ — a glyph the chaos
# skill-design palette uses heavily (`★ BEST PICK`). v8.0-beta.2 adds it: the
# upright variable font covers all 14 palette glyphs (★ ◆ ✓ ✗ → • ▸ ⚠ … ↳ × ━ ─ │),
# every one a single cell wide — checked with fontTools on 2026-09-14. The
# italic still lacks ★. Research: chaos
# technical/2026-09-14-monospace-font-round2-shortlist.md.
#
# ⚠ v8 is a PRE-RELEASE ("still under development"). It is pinned here by tag
# AND by SHA-256, so a re-published asset fails loudly instead of installing
# something different. When v8 ships stable (or Homebrew's cask reaches 8.x),
# swap this for `cask "font-maple-mono"` in config/Brewfile.apps and delete it.
#
# Installs MapleMono[wght].ttf + MapleMono-Italic[wght].ttf to ~/Library/Fonts.
# Family name is "Maple Mono" — what ghostty/config and zed/settings.json name.
# ⚠ Don't also install the 7.9 cask: two builds sharing one family name make
# macOS pick either, silently.

set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/ui.sh
. "$SCRIPTS_DIR/lib/ui.sh"

TAG="v8.0-beta.2"
ASSET="MapleMono-VF.zip"
SHA256="8af169297293d14d02731f1c3ccb73adec8ee88afbbfe652f439f2ba09479caa"
URL="https://github.com/subframe7536/maple-font/releases/download/${TAG}/${ASSET}"
FONT_DIR="$HOME/Library/Fonts"
MARKER="$FONT_DIR/.maple-mono-version"

install_maple_mono() {
    ui_section "Maple Mono ${TAG} (variable)"

    # Idempotent: the marker records which pinned build is on disk.
    if [ -f "$MARKER" ] && [ "$(cat "$MARKER")" = "$TAG" ] && [ -f "$FONT_DIR/MapleMono[wght].ttf" ]; then
        ui_success "Maple Mono ${TAG} already installed — skipping"
        return 0
    fi

    if [ -d "/opt/homebrew/Caskroom/font-maple-mono" ]; then
        ui_info "⚠ Homebrew's font-maple-mono (7.9) is installed — it shares the family name."
        ui_info "Remove it first so macOS doesn't pick it: brew uninstall --cask font-maple-mono"
    fi

    for tool in curl unzip shasum; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            ui_error "$tool not found — cannot install Maple Mono."
            return 1
        fi
    done

    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' RETURN

    ui_info "Downloading ${ASSET} (${TAG})…"
    curl -fsSL --max-time 120 -o "$tmp/$ASSET" "$URL"

    got="$(shasum -a 256 "$tmp/$ASSET" | awk '{print $1}')"
    if [ "$got" != "$SHA256" ]; then
        ui_error "SHA-256 mismatch for ${ASSET} — expected ${SHA256}, got ${got}. Nothing installed."
        return 1
    fi

    unzip -q -o "$tmp/$ASSET" -d "$tmp/x"
    mkdir -p "$FONT_DIR"
    cp "$tmp/x/MapleMono[wght].ttf" "$tmp/x/MapleMono-Italic[wght].ttf" "$FONT_DIR/"
    printf '%s' "$TAG" > "$MARKER"

    ui_success "Maple Mono ${TAG} installed → ${FONT_DIR}"
    ui_info "Reload Ghostty's config (⌘⇧,) — Zed picks the font up on its own."
}

install_maple_mono
