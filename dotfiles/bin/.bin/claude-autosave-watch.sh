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
RETRY_SECS="${AUTOSAVE_RETRY_SECS:-900}"   # idle retry period (override: tests only)
case "$RETRY_SECS" in ''|*[!0-9]*) RETRY_SECS=900 ;; esac
[ "$RETRY_SECS" -ge 10 ] || RETRY_SECS=900

[ -d "$REPO/.git" ] || { echo "~/.claude repo not present; watcher exiting"; exit 0; }
command -v fswatch >/dev/null 2>&1 || { echo "fswatch not installed; watcher exiting"; exit 0; }

# Watch only paths that exist (fswatch errors on missing ones).
WATCH=()
for p in "$REPO/skills" "$REPO/agents" "$REPO/commands" "$REPO/hooks" \
         "$REPO/settings.json" "$REPO/CLAUDE.md" "$REPO/README.md" "$REPO/repos.txt"; do
  [ -e "$p" ] && WATCH+=("$p")
done
# Memory dirs: only the ones the whitelist .gitignore lets into a snapshot
# (today just the chaos project's). The bare projects/*/memory glob also swept
# in ~80 empty scratchpad dirs that can never change a snapshot. Matched at
# start-up, so a newly whitelisted memory dir needs a watcher reload.
for m in "$REPO"/projects/*/memory; do
  [ -d "$m" ] || continue
  git -C "$REPO" check-ignore -q "${m#"$REPO"/}/x" || WATCH+=("$m")
done
[ ${#WATCH[@]} -gt 0 ] || { echo "nothing to watch; exiting"; exit 0; }

# -o: one event per coalesced batch. --latency: debounce window (s).
# skills/synced/ is claude.ai account content the harness re-syncs, rewriting
# its manifest.json every ~10 min, which woke this loop around the clock. It is
# gitignored in claude-config (since ff8230e) and nothing under it is tracked,
# so no event there can ever change a snapshot.
# Drain queued lines before snapshotting, and retry an unpushed snapshot after
# RETRY_SECS of quiet — both exactly as in chaos-autosave-watch.sh, which says why.
exec fswatch -o --latency=90 --exclude='/skills/synced/' "${WATCH[@]}" | while :; do
  waited_from=$SECONDS
  if read -r -t "$RETRY_SECS" _; then
    drain_start=$SECONDS
    while [ $((SECONDS - drain_start)) -lt 60 ] && read -r -t 2 _; do :; done
    "$SNAP" || true
  elif [ $((SECONDS - waited_from)) -lt $((RETRY_SECS / 2)) ]; then
    break
  else
    "$SNAP" --if-unpushed || true
  fi
done
