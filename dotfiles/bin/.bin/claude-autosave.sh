#!/usr/bin/env bash
# claude-autosave.sh — snapshot ~/.claude's tracked "brain" (skills, agents,
# hooks, settings, memory) to this Mac's autosave branch in claude-config,
# WITHOUT touching the working tree, index, or main. Sibling of chaos-autosave.sh
# — same throwaway-index commit-tree pattern, same push-only-what's-new check
# (against refs/remotes/origin/<branch>), same stale-lock breaker, same
# `--if-unpushed` idle retry and same one-branch-per-Mac rule (Studio
# `autosave`, any other Mac `autosave-<LocalHostName>`); see that file for the
# why. The repo's whitelist .gitignore keeps transcripts/credentials out of the
# snapshot.
#
# Recover:
#   this Mac:     git -C ~/.claude restore --source=refs/autosave/latest -- <file>
#   from GitHub:  git -C ~/.claude fetch origin
#                 git -C ~/.claude restore --source=origin/autosave -- <file>
#                 (origin/autosave-<host> for a Mac other than the Studio)
set -uo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

REPO="$HOME/.claude"
LOG="$HOME/.local/state/claude-autosave.log"
LOCKDIR="$HOME/.local/state/claude-autosave.lock.d"
LOG_MAX_BYTES=2097152   # past 2 MB the log rolls to .log.1 (one old file kept)
LOCK_STALE_SECS=600     # a lock this old is broken even if its pid looks alive
PRIMARY_HOST="studio"   # the one Mac that pushes plain `autosave`
mkdir -p "$(dirname "$LOG")"

log() { echo "$(date '+%F %T') $*" >>"$LOG"; }

MODE="${1:-}"
QUIET=0; [ "$MODE" = "--if-unpushed" ] && QUIET=1
note() { [ "$QUIET" = 1 ] || log "$@"; }   # no-op outcomes; silent on the idle retry

# ⚠ scutil by ABSOLUTE path — launchd's PATH has no /usr/sbin, and the old
# `hostname -s` fallback followed the network. See chaos-autosave.sh.
# AUTOSAVE_SCUTIL points the lookup at a stub (tests only).
SCUTIL="${AUTOSAVE_SCUTIL:-/usr/sbin/scutil}"
HOST="$("$SCUTIL" --get LocalHostName 2>/dev/null)"
HOST="$(printf '%s' "$HOST" | tr -c 'A-Za-z0-9-' '-')"
[ -n "$HOST" ] || { HOST="unknown"; log "⚠ LocalHostName unreadable via $SCUTIL — using 'unknown'"; }
if [ "$HOST" = "$PRIMARY_HOST" ]; then BRANCH="autosave"; else BRANCH="autosave-$HOST"; fi
REMOTE_REF="refs/remotes/origin/$BRANCH"

cd "$REPO" 2>/dev/null || { log "no ~/.claude"; exit 0; }
[ -d .git ] || exit 0

if [ "$MODE" = "--if-unpushed" ]; then
  LATEST="$(git rev-parse -q --verify refs/autosave/latest 2>/dev/null)"
  [ -n "$LATEST" ] || exit 0
  [ "$LATEST" = "$(git rev-parse -q --verify "$REMOTE_REF" 2>/dev/null)" ] && exit 0
fi

# single-flight lock, pid inside, stale locks broken — see chaos-autosave.sh.
take_lock() {
  if mkdir "$LOCKDIR" 2>/dev/null; then echo "$$" >"$LOCKDIR/pid"; return 0; fi
  local holder="" mtime age
  { read -r holder <"$LOCKDIR/pid"; } 2>/dev/null
  mtime="$(/usr/bin/stat -f %m "$LOCKDIR" 2>/dev/null)" || return 1   # gone: its owner just finished
  age=$(( $(date +%s) - mtime ))
  if [ "$age" -lt "$LOCK_STALE_SECS" ]; then
    [ -z "$holder" ] && return 1
    kill -0 "$holder" 2>/dev/null && return 1
  fi
  log "breaking stale lock (pid ${holder:-none}, ${age}s old)"
  rm -f "$LOCKDIR/pid"; rmdir "$LOCKDIR" 2>/dev/null
  if mkdir "$LOCKDIR" 2>/dev/null; then echo "$$" >"$LOCKDIR/pid"; return 0; fi
  return 1
}
take_lock || { log "skip (locked)"; exit 0; }
# release only a lock that is still ours (a stale-breaker may have taken it over)
cleanup() {
  local holder=""
  { read -r holder <"$LOCKDIR/pid"; } 2>/dev/null
  if [ "$holder" = "$$" ]; then rm -f "$LOCKDIR/pid"; rmdir "$LOCKDIR" 2>/dev/null; fi
  rm -f "${TMPIDX:-}"
}
trap cleanup EXIT
trap 'exit 130' INT    # exit, so the EXIT trap cleans up and the run stops here
trap 'exit 143' TERM

# rotate under the lock, so only one run ever moves the file
if [ -f "$LOG" ] && [ "$(wc -c <"$LOG")" -gt "$LOG_MAX_BYTES" ]; then
  mv -f "$LOG" "$LOG.1"
fi

sleep 2  # let any mid-write files settle

# snapshot tree via a throwaway index seeded from HEAD; add -A respects the
# whitelist .gitignore, so only the brain lands in the tree.
TMPIDX="$(mktemp "${TMPDIR:-/tmp}/claude-idx.XXXXXX")"
if ! GIT_INDEX_FILE="$TMPIDX" git read-tree HEAD 2>>"$LOG"; then
  log "read-tree failed"; exit 0
fi
if ! GIT_INDEX_FILE="$TMPIDX" git add -A 2>>"$LOG"; then
  log "add failed"; exit 0
fi
TREE="$(GIT_INDEX_FILE="$TMPIDX" git write-tree 2>>"$LOG")" || exit 0
[ -n "$TREE" ] || exit 0

# nothing new vs current HEAD? skip
HEAD_REV="$(git rev-parse HEAD 2>/dev/null)"
HEAD_TREE="$(git rev-parse 'HEAD^{tree}' 2>/dev/null)"
if [ "$TREE" = "$HEAD_TREE" ]; then
  note "no changes"; exit 0
fi

# origin's branch already holds this tree on this parent? skip
PUSHED_TREE="$(git rev-parse -q --verify "$REMOTE_REF^{tree}" 2>/dev/null)"
PUSHED_PARENT="$(git rev-parse -q --verify "$REMOTE_REF^" 2>/dev/null)"
if [ "$TREE" = "$PUSHED_TREE" ] && [ "$HEAD_REV" = "$PUSHED_PARENT" ]; then
  note "unchanged since last push"; exit 0
fi

# an unpushed snapshot of this same state is pushed again, not re-minted
if [ "$TREE" = "$(git rev-parse -q --verify 'refs/autosave/latest^{tree}' 2>/dev/null)" ] &&
   [ "$HEAD_REV" = "$(git rev-parse -q --verify 'refs/autosave/latest^' 2>/dev/null)" ]; then
  COMMIT="$(git rev-parse -q --verify refs/autosave/latest 2>/dev/null)"
else
  COMMIT="$(git commit-tree "$TREE" -p "$HEAD_REV" -m "autosave $HOST $(date '+%F %T')" 2>>"$LOG")" || exit 0
  [ -n "$COMMIT" ] || exit 0
  git update-ref "refs/autosave/latest" "$COMMIT" 2>>"$LOG" || true
fi
[ -n "$COMMIT" ] || exit 0

if OUT="$(git push --force --quiet origin "$COMMIT:refs/heads/$BRANCH" 2>&1)"; then
  # tracking ref: see chaos-autosave.sh
  git update-ref "$REMOTE_REF" "$COMMIT" 2>>"$LOG" || true
  log "pushed $COMMIT to $BRANCH$([ "$QUIET" = 1 ] && echo ' (idle retry)')"
else
  [ -n "$OUT" ] && printf '%s\n' "$OUT" >>"$LOG"
  log "push FAILED (1Password locked / offline?) — snapshot kept locally at refs/autosave/latest ($COMMIT)"
fi
