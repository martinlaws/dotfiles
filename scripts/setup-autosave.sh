#!/bin/bash
# setup-autosave.sh — install + load the autosave launchd agents:
#   ca.mlaws.chaos-autosave   (watches ~/code/chaos — whole working tree)
#   ca.mlaws.claude-autosave  (watches ~/.claude tracked brain paths)
# Idempotent: re-running reloads each agent with the latest plist. Non-fatal —
# skips cleanly if fswatch or the target repo isn't present yet.
set -euo pipefail

SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"

if ! command -v fswatch >/dev/null 2>&1; then
  echo "⚠ fswatch not installed — skipping autosave agents (install via Brewfile, then re-run)"
  exit 0
fi

mkdir -p "$HOME/Library/LaunchAgents" "$HOME/.local/state"

install_agent() {
  local label="$1" repo="$2"
  local template="$SCRIPT_DIR/config/launchd/${label}.plist.template"
  local dest="$HOME/Library/LaunchAgents/${label}.plist"

  if [ ! -d "$repo/.git" ]; then
    echo "⚠ $repo not a git repo yet — skipping ${label} (re-run after clone)"
    return 0
  fi
  if [ ! -f "$template" ]; then
    echo "⚠ plist template missing at $template — skipping"
    return 0
  fi

  # Render the plist from the template (launchd doesn't expand ~ / $HOME).
  sed "s#__HOME__#${HOME}#g" "$template" > "$dest"

  # Reload (bootout then bootstrap) so changes take effect.
  launchctl bootout "gui/$(id -u)/${label}" 2>/dev/null || true
  if launchctl bootstrap "gui/$(id -u)" "$dest" 2>/dev/null; then
    echo "✓ autosave agent loaded (${label})"
  else
    echo "⚠ could not bootstrap ${label} — load manually: launchctl bootstrap gui/\$(id -u) $dest"
  fi
}

install_agent "ca.mlaws.chaos-autosave"  "$HOME/code/chaos"
install_agent "ca.mlaws.claude-autosave" "$HOME/.claude"
