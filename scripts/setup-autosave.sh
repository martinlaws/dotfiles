#!/bin/bash
# setup-autosave.sh — install + load the chaos autosave launchd agent.
# Idempotent: re-running reloads the agent with the latest plist. Non-fatal —
# skips cleanly if fswatch or the chaos repo isn't present yet.
set -euo pipefail

LABEL="ca.mlaws.chaos-autosave"
SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
TEMPLATE="$SCRIPT_DIR/config/launchd/${LABEL}.plist.template"
DEST="$HOME/Library/LaunchAgents/${LABEL}.plist"

if ! command -v fswatch >/dev/null 2>&1; then
  echo "⚠ fswatch not installed — skipping chaos autosave (install via Brewfile, then re-run)"
  exit 0
fi
if [ ! -d "$HOME/code/chaos/.git" ]; then
  echo "⚠ ~/code/chaos not cloned yet — skipping chaos autosave (re-run after clone)"
  exit 0
fi
if [ ! -f "$TEMPLATE" ]; then
  echo "⚠ plist template missing at $TEMPLATE — skipping"
  exit 0
fi

mkdir -p "$HOME/Library/LaunchAgents" "$HOME/.local/state"

# Render the plist from the template (launchd doesn't expand ~ / $HOME).
sed "s#__HOME__#${HOME}#g" "$TEMPLATE" > "$DEST"

# Reload (bootout then bootstrap) so changes take effect.
launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null || true
if launchctl bootstrap "gui/$(id -u)" "$DEST" 2>/dev/null; then
  echo "✓ chaos autosave agent loaded (${LABEL})"
else
  echo "⚠ could not bootstrap ${LABEL} — load manually: launchctl bootstrap gui/\$(id -u) $DEST"
fi
