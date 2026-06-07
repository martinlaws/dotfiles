#!/usr/bin/env bash
# chaos-autosave.sh — snapshot the ENTIRE chaos working tree (including untracked
# new notes) to the `autosave` branch on the private remote, WITHOUT touching the
# working tree, index, or main. Safety net against a crash/wipe losing thinking.
#
# - Uses a throwaway index, so your real index/working tree are never touched.
# - Commits via commit-tree (unsigned, no 1Password needed) parented on HEAD.
# - Keeps a local ref (refs/autosave/latest) so the snapshot survives even if the
#   push fails (e.g. 1Password locked / offline) — it just catches up next time.
set -uo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

CHAOS="$HOME/code/chaos"
LOG="$HOME/.local/state/chaos-autosave.log"
LOCKDIR="$HOME/.local/state/chaos-autosave.lock.d"
BRANCH="autosave"
mkdir -p "$(dirname "$LOG")"

cd "$CHAOS" 2>/dev/null || { echo "$(date '+%F %T') no chaos dir" >>"$LOG"; exit 0; }
[ -d .git ] || exit 0

# single-flight lock (coalesce overlapping triggers) — mkdir is atomic on macOS
if ! mkdir "$LOCKDIR" 2>/dev/null; then
  echo "$(date '+%F %T') skip (locked)" >>"$LOG"; exit 0
fi
trap 'rmdir "$LOCKDIR" 2>/dev/null; rm -f "${TMPIDX:-}"' EXIT INT TERM

sleep 2  # let any mid-write files settle

# build a snapshot tree of the full working dir via a throwaway index: seed it
# from HEAD (so git add diffs against HEAD), then stage every working-tree change
# including untracked files and deletions.
TMPIDX="$(mktemp "${TMPDIR:-/tmp}/chaos-idx.XXXXXX")"
if ! GIT_INDEX_FILE="$TMPIDX" git read-tree HEAD 2>>"$LOG"; then
  echo "$(date '+%F %T') read-tree failed" >>"$LOG"; exit 0
fi
if ! GIT_INDEX_FILE="$TMPIDX" git add -A 2>>"$LOG"; then
  echo "$(date '+%F %T') add failed" >>"$LOG"; exit 0
fi
TREE="$(GIT_INDEX_FILE="$TMPIDX" git write-tree 2>>"$LOG")" || exit 0
[ -n "$TREE" ] || exit 0

# nothing new vs current HEAD? skip
HEAD_REV="$(git rev-parse HEAD 2>/dev/null)"
HEAD_TREE="$(git rev-parse 'HEAD^{tree}' 2>/dev/null)"
if [ "$TREE" = "$HEAD_TREE" ]; then
  echo "$(date '+%F %T') no changes" >>"$LOG"; exit 0
fi

COMMIT="$(git commit-tree "$TREE" -p "$HEAD_REV" -m "autosave $(date '+%F %T')" 2>>"$LOG")" || exit 0
[ -n "$COMMIT" ] || exit 0

# keep a local ref so it can't be gc'd and is locally recoverable even if push fails
git update-ref "refs/autosave/latest" "$COMMIT" 2>>"$LOG" || true

# force-push the snapshot to the remote autosave branch (no local branch touched)
if git push --force --quiet origin "$COMMIT:refs/heads/$BRANCH" 2>>"$LOG"; then
  echo "$(date '+%F %T') pushed $COMMIT" >>"$LOG"
else
  echo "$(date '+%F %T') push FAILED (1Password locked / offline?) — snapshot kept locally at refs/autosave/latest ($COMMIT)" >>"$LOG"
fi
