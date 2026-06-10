#!/usr/bin/env bash
# claude-autosave-watch.sh — watch ~/.claude's TRACKED paths and fire a debounced
# snapshot. Run as a kept-alive launchd agent (ca.mlaws.claude-autosave).
#
# Unlike the chaos watcher (whole repo), this watches only the whitelisted brain
# paths — ~/.claude also holds session transcripts that churn on every model
# turn, and watching the root would wake us pointlessly all day.
set -uo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

REPO="$HOME/.claude"
SNAP="$HOME/.bin/claude-autosave.sh"

[ -d "$REPO/.git" ] || { echo "~/.claude repo not present; watcher exiting"; exit 0; }
command -v fswatch >/dev/null 2>&1 || { echo "fswatch not installed; watcher exiting"; exit 0; }

# Watch only paths that exist (fswatch errors on missing ones). Memory dirs are
# matched by glob — new project memory dirs need a watcher reload to be seen.
WATCH=()
for p in "$REPO/skills" "$REPO/agents" "$REPO/commands" "$REPO/hooks" \
         "$REPO/settings.json" "$REPO/CLAUDE.md" "$REPO/README.md" "$REPO/repos.txt" \
         "$REPO"/projects/*/memory; do
  [ -e "$p" ] && WATCH+=("$p")
done
[ ${#WATCH[@]} -gt 0 ] || { echo "nothing to watch; exiting"; exit 0; }

# -o: one event per coalesced batch. --latency: debounce window (s).
exec fswatch -o --latency=90 "${WATCH[@]}" | while read -r _; do
  "$SNAP" || true
done
