#!/usr/bin/env bash
# claude-autosave.sh — snapshot ~/.claude's tracked "brain" (skills, agents,
# hooks, settings, memory) to claude-config's `autosave` branch, WITHOUT touching
# the working tree, index, or main. Sibling of chaos-autosave.sh — same
# throwaway-index commit-tree pattern; the repo's whitelist .gitignore keeps
# transcripts/credentials out of the snapshot automatically.
#
# Recover: git -C ~/.claude fetch && git -C ~/.claude checkout autosave -- <file>
set -uo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

REPO="$HOME/.claude"
LOG="$HOME/.local/state/claude-autosave.log"
LOCKDIR="$HOME/.local/state/claude-autosave.lock.d"
BRANCH="autosave"
mkdir -p "$(dirname "$LOG")"

cd "$REPO" 2>/dev/null || { echo "$(date '+%F %T') no ~/.claude" >>"$LOG"; exit 0; }
[ -d .git ] || exit 0

# single-flight lock (coalesce overlapping triggers) — mkdir is atomic on macOS
if ! mkdir "$LOCKDIR" 2>/dev/null; then
  echo "$(date '+%F %T') skip (locked)" >>"$LOG"; exit 0
fi
trap 'rmdir "$LOCKDIR" 2>/dev/null; rm -f "${TMPIDX:-}"' EXIT INT TERM

sleep 2  # let any mid-write files settle

# snapshot tree via a throwaway index seeded from HEAD; add -A respects the
# whitelist .gitignore, so only the brain lands in the tree.
TMPIDX="$(mktemp "${TMPDIR:-/tmp}/claude-idx.XXXXXX")"
if ! GIT_INDEX_FILE="$TMPIDX" git read-tree HEAD 2>>"$LOG"; then
  echo "$(date '+%F %T') read-tree failed" >>"$LOG"; exit 0
fi
if ! GIT_INDEX_FILE="$TMPIDX" git add -A 2>>"$LOG"; then
  echo "$(date '+%F %T') add failed" >>"$LOG"; exit 0
fi
TREE="$(GIT_INDEX_FILE="$TMPIDX" git write-tree 2>>"$LOG")" || exit 0
[ -n "$TREE" ] || exit 0

HEAD_REV="$(git rev-parse HEAD 2>/dev/null)"
HEAD_TREE="$(git rev-parse 'HEAD^{tree}' 2>/dev/null)"
if [ "$TREE" = "$HEAD_TREE" ]; then
  echo "$(date '+%F %T') no changes" >>"$LOG"; exit 0
fi

COMMIT="$(git commit-tree "$TREE" -p "$HEAD_REV" -m "autosave $(date '+%F %T')" 2>>"$LOG")" || exit 0
[ -n "$COMMIT" ] || exit 0

git update-ref "refs/autosave/latest" "$COMMIT" 2>>"$LOG" || true

if git push --force --quiet origin "$COMMIT:refs/heads/$BRANCH" 2>>"$LOG"; then
  echo "$(date '+%F %T') pushed $COMMIT" >>"$LOG"
else
  echo "$(date '+%F %T') push FAILED (1Password locked / offline?) — snapshot kept locally at refs/autosave/latest ($COMMIT)" >>"$LOG"
fi
