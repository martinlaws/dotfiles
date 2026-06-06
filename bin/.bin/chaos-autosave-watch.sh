#!/usr/bin/env bash
# chaos-autosave-watch.sh — watch chaos for changes and fire a debounced snapshot.
# Run as a kept-alive launchd agent (ca.mlaws.chaos-autosave). fswatch coalesces
# bursts of edits over a 90s window, so we snapshot ~once per active stretch and
# again ~90s after you stop — not on every keystroke.
set -uo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

CHAOS="$HOME/code/chaos"
SNAP="$HOME/.bin/chaos-autosave.sh"

[ -d "$CHAOS/.git" ] || { echo "chaos repo not present; watcher exiting"; exit 0; }
command -v fswatch >/dev/null 2>&1 || { echo "fswatch not installed; watcher exiting"; exit 0; }

# -o: one event (a count) per coalesced batch. --latency: debounce window (s).
# Exclude .git so the snapshot's own ref/object writes don't re-trigger us.
exec fswatch -o --latency=90 --exclude='/\.git/' "$CHAOS" | while read -r _; do
  "$SNAP" || true
done
