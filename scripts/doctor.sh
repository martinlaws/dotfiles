#!/bin/bash
#
# Doctor — one-shot health check for a machine set up by this repo.
# Codifies the FIRST-RUN.md "Verify it worked" checks (BACKLOG #11) plus the
# failure classes from the June 2026 new-Mac bring-up (macOS-ahead-of-Homebrew,
# formula-vs-binary names, SSH-under-pipefail). Read-only: changes nothing.
#
# Run: sh ~/dotfiles/scripts/doctor.sh

set -uo pipefail

SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
# shellcheck source=scripts/lib/detect.sh
. "$SCRIPT_DIR/scripts/lib/detect.sh"
# shellcheck source=scripts/lib/ui.sh
. "$SCRIPT_DIR/scripts/lib/ui.sh"

PASS=0
WARN=0
FAIL=0

pass() { ui_success "$1"; PASS=$((PASS + 1)); }
warn() { ui_info "⚠ $1"; WARN=$((WARN + 1)); }
fail() { ui_error "$1"; FAIL=$((FAIL + 1)); }

ui_header "Dotfiles Doctor"

# ── Homebrew ─────────────────────────────────────────────────────────────────
ui_section "Homebrew"
if is_homebrew_installed; then
    pass "brew present ($(brew --version | head -1))"
    if [ -n "${HOMEBREW_FAKE_MACOS:-}" ]; then
        pass "macOS-ahead fallback active (HOMEBREW_FAKE_MACOS=$HOMEBREW_FAKE_MACOS)"
    elif maybe_fake_unsupported_macos; then
        # Detection exported the var into THIS process only — doctor is
        # read-only; we just report what the shell is missing.
        warn "macOS $FAKE_MACOS_APPLIED is newer than Homebrew knows — bottle ops will fail with ':dunno'."
        ui_info "  Fix: add 'export HOMEBREW_FAKE_MACOS=$HOMEBREW_FAKE_MACOS' to ~/.zshrc.local"
    else
        pass "macOS version known to Homebrew"
    fi
else
    fail "brew not found — run sh setup"
fi

# ── Brewfile CLI tools ───────────────────────────────────────────────────────
ui_section "CLI Tools (config/Brewfile)"
MISSING_TOOLS=()
while IFS= read -r line; do
    if [[ $line =~ ^brew[[:space:]]+\"([^\"]+)\" ]]; then
        TOOL="${BASH_REMATCH[1]}"
        is_tool_installed "$TOOL" || MISSING_TOOLS+=("$TOOL")
    fi
done < "$SCRIPT_DIR/config/Brewfile"
if [ ${#MISSING_TOOLS[@]} -eq 0 ]; then
    pass "all Brewfile tools installed"
else
    fail "missing tools: ${MISSING_TOOLS[*]}"
    ui_info "  Fix: brew bundle install --file $SCRIPT_DIR/config/Brewfile"
fi

# ── Brewfile drift (reverse direction) ───────────────────────────────────────
# Things installed by hand never flow back into the Brewfiles, so the next
# machine silently misses them. Warn-only.
ui_section "Brewfile Drift"
if is_homebrew_installed; then
    # No process substitution — macOS `sh` (bash in POSIX mode) rejects it.
    # Formula/cask tokens never contain spaces, so word-splitting is safe.
    UNTRACKED_FORMULAE=()
    for leaf in $(brew leaves 2>/dev/null); do
        grep -qE "^brew[[:space:]]+\"([^\"]+/)?${leaf}\"" "$SCRIPT_DIR/config/Brewfile" || UNTRACKED_FORMULAE+=("$leaf")
    done
    if [ ${#UNTRACKED_FORMULAE[@]} -eq 0 ]; then
        pass "no untracked formulae"
    else
        warn "${#UNTRACKED_FORMULAE[@]} formula(e) installed but not in config/Brewfile: ${UNTRACKED_FORMULAE[*]}"
        ui_info "  Add the keepers to config/Brewfile so the next machine gets them."
    fi

    UNTRACKED_CASKS=()
    for cask in $(brew list --cask 2>/dev/null); do
        grep -qE "^cask[[:space:]]+\"${cask}\"" "$SCRIPT_DIR/config/Brewfile.apps" || UNTRACKED_CASKS+=("$cask")
    done
    if [ ${#UNTRACKED_CASKS[@]} -eq 0 ]; then
        pass "no untracked casks"
    else
        warn "${#UNTRACKED_CASKS[@]} cask(s) installed but not in config/Brewfile.apps: ${UNTRACKED_CASKS[*]}"
    fi
fi

# ── Node via fnm ─────────────────────────────────────────────────────────────
ui_section "Node (fnm)"
if command -v node >/dev/null 2>&1; then
    case "$(command -v node)" in
        *fnm*) pass "node $(node --version) served by fnm" ;;
        *)     warn "node $(node --version) NOT served by fnm ($(command -v node)) — shell init may be stale" ;;
    esac
else
    fail "node not on PATH — run 'fnm install --lts && fnm default lts-latest', then open a fresh shell"
fi

# ── GitHub SSH ───────────────────────────────────────────────────────────────
ui_section "GitHub SSH"
# Capture-then-grep: ssh -T git@github.com always exits non-zero (no shell),
# so a direct pipe under pipefail would report failure even on success.
ssh_result=$(ssh -o ConnectTimeout=8 -T git@github.com 2>&1 || true)
if echo "$ssh_result" | grep -q "successfully authenticated"; then
    pass "GitHub SSH authenticated (1Password agent)"
else
    fail "GitHub SSH not authenticating — is 1Password unlocked with the SSH agent on?"
    ui_info "  ($(echo "$ssh_result" | head -1))"
fi

# ── Dotfile symlinks ─────────────────────────────────────────────────────────
ui_section "Symlinks"
if [ -L "$HOME/.zshrc" ] && [[ "$(readlink "$HOME/.zshrc")" == *dotfiles* ]]; then
    pass "~/.zshrc symlinked into dotfiles"
else
    fail "~/.zshrc is not a dotfiles symlink — run scripts/symlink-dotfiles.sh"
fi

# ── Claude config (~/.claude) ────────────────────────────────────────────────
ui_section "Claude Code"
if [ -d "$HOME/.claude/.git" ]; then
    pass "~/.claude is version-controlled (claude-config)"
    dirty=$(git -C "$HOME/.claude" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    if [ "$dirty" != "0" ]; then
        warn "~/.claude has $dirty uncommitted change(s) — memory drift won't reach other machines until pushed"
    fi
    unpushed=$(git -C "$HOME/.claude" rev-list --count '@{upstream}..HEAD' 2>/dev/null || echo 0)
    if [ "$unpushed" != "0" ]; then
        warn "~/.claude has $unpushed unpushed commit(s)"
    fi
    if launchctl list "ca.mlaws.claude-autosave" >/dev/null 2>&1; then
        pass "claude-config autosave agent loaded (ca.mlaws.claude-autosave)"
    else
        fail "claude-config autosave agent NOT loaded — run ~/dotfiles/scripts/setup-autosave.sh"
    fi
else
    fail "~/.claude not version-controlled — run scripts/setup-claude.sh (needs GitHub SSH)"
fi

# ── chaos repo extras ────────────────────────────────────────────────────────
if [ -d "$HOME/code/chaos" ]; then
    ui_section "Chaos"
    if launchctl list "ca.mlaws.chaos-autosave" >/dev/null 2>&1; then
        pass "autosave agent loaded (ca.mlaws.chaos-autosave)"
    else
        fail "autosave agent NOT loaded — run ~/code/chaos/scripts/setup-autosave.sh"
    fi
    if command -v jq >/dev/null 2>&1 && [ -x "$HOME/code/chaos/.claude/skills/slurp/drain.sh" ]; then
        pass "/slurp deps present (jq + drain.sh)"
    else
        warn "/slurp deps incomplete (need jq + executable .claude/skills/slurp/drain.sh)"
    fi
fi

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
ui_section "Doctor: $PASS passed · $WARN warnings · $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
