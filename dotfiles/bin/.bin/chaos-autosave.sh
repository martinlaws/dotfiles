#!/usr/bin/env bash
# chaos-autosave.sh — snapshot the ENTIRE chaos working tree (including untracked
# new notes) to this Mac's autosave branch on the private remote, WITHOUT touching
# the working tree, index, or main. Safety net against a crash/wipe losing thinking.
#
# - Uses a throwaway index, so your real index/working tree are never touched.
# - Commits via commit-tree (unsigned, no 1Password needed) parented on HEAD.
# - Keeps a local ref (refs/autosave/latest) so the snapshot survives even if the
#   push fails (e.g. 1Password locked / offline) — it just catches up next time.
# - Pushes only what's new. A run is skipped when its tree AND parent both match
#   refs/remotes/origin/<branch> — what origin last got from this Mac, as far as
#   this clone knows. That ref moves ONLY on a successful push (or a fetch, which
#   resets it to what GitHub really holds, so a tip overwritten from elsewhere is
#   pushed again). ⚠ Never skip on refs/autosave/latest instead: it is written
#   before the push, so a failed push would not be retried until the content
#   changed. (2026-09-23: comparing only against HEAD re-pushed one identical tree
#   every ~4s, ~4,200 pushes in a day, because chaos always carries an
#   uncommitted dashboard/.cache/calendar.json.)
# - One remote branch per Mac. The Studio (LocalHostName `studio`) keeps
#   `autosave`; any other Mac pushes `autosave-<LocalHostName>`. Both used to
#   force-push `autosave`, so each Mac's snapshot was overwritten at the tip by
#   the other's next push.
# - `--if-unpushed` (the watcher's idle retry, every 15 min): do nothing unless
#   refs/autosave/latest never reached origin, and stay silent on no-op outcomes.
# - Packs loose objects after a burst (pack_if_grown), so the snapshot's own
#   re-hash can't keep re-triggering the watcher.
#
# Recover (FIRST-RUN.md §8):
#   this Mac:     git -C ~/code/chaos restore --source=refs/autosave/latest -- <file>
#   from GitHub:  git -C ~/code/chaos fetch origin
#                 git -C ~/code/chaos restore --source=origin/autosave -- <file>
#                 (origin/autosave-<host> for a Mac other than the Studio)
set -uo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

CHAOS="$HOME/code/chaos"
LOG="$HOME/.local/state/chaos-autosave.log"
LOCKDIR="$HOME/.local/state/chaos-autosave.lock.d"
LOG_MAX_BYTES=2097152   # past 2 MB the log rolls to .log.1 (one old file kept)
LOCK_STALE_SECS=600     # a lock this old is broken even if its pid looks alive
PACK_STAMP="$HOME/.local/state/chaos-autosave.loose"   # loose-object count at the last pack
PACK_GROWTH=1000        # pack once this many new loose objects have piled up
PRIMARY_HOST="studio"   # the one Mac that pushes plain `autosave`
mkdir -p "$(dirname "$LOG")"

log() { echo "$(date '+%F %T') $*" >>"$LOG"; }

MODE="${1:-}"
QUIET=0; [ "$MODE" = "--if-unpushed" ] && QUIET=1
note() { [ "$QUIET" = 1 ] || log "$@"; }   # no-op outcomes; silent on the idle retry

# ⚠ scutil by ABSOLUTE path. It lives in /usr/sbin, which launchd's PATH (the
# plist's, above) does not include; until 2026-09-23 the lookup silently fell
# through to `hostname -s`, the kernel hostname, which DHCP / reverse DNS can
# change from one network to the next — and the branch name with it. No
# network-dependent fallback: unreadable → `unknown`, logged every run.
# AUTOSAVE_SCUTIL points the lookup at a stub (tests only).
SCUTIL="${AUTOSAVE_SCUTIL:-/usr/sbin/scutil}"
HOST="$("$SCUTIL" --get LocalHostName 2>/dev/null)"
HOST="$(printf '%s' "$HOST" | tr -c 'A-Za-z0-9-' '-')"
[ -n "$HOST" ] || { HOST="unknown"; log "⚠ LocalHostName unreadable via $SCUTIL — using 'unknown'"; }
if [ "$HOST" = "$PRIMARY_HOST" ]; then BRANCH="autosave"; else BRANCH="autosave-$HOST"; fi
REMOTE_REF="refs/remotes/origin/$BRANCH"

cd "$CHAOS" 2>/dev/null || { log "no chaos dir"; exit 0; }
[ -d .git ] || exit 0

if [ "$MODE" = "--if-unpushed" ]; then
  LATEST="$(git rev-parse -q --verify refs/autosave/latest 2>/dev/null)"
  [ -n "$LATEST" ] || exit 0
  [ "$LATEST" = "$(git rev-parse -q --verify "$REMOTE_REF" 2>/dev/null)" ] && exit 0
fi

# single-flight lock (coalesce overlapping triggers) — mkdir is atomic on macOS.
# The holder writes its pid inside. ⚠ A run killed without its trap (SIGKILL,
# power cut, panic; the lock survives a reboot) used to leave the lock behind
# for good: every later run logged `skip (locked)` and nothing pushed again. So
# a lock whose pid is dead, or that is older than LOCK_STALE_SECS, is broken. A
# lock with no pid yet is someone mid-acquire (or pre-2026-09-23): age only.
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

# ⚠ Pack a burst's loose objects. `git add -A` below re-hashes every file on
# every run, and git re-stamps (utime) each object it "re-writes". With
# thousands of LOOSE objects that is thousands of events under .git: enough to
# overflow FSEvents, whose "rescan the root" event gets past the watcher's
# /.git/ exclude and, being an overflow, skips the 90s latency too. After a
# 6,000-new-note burst that was a no-op run every ~5s for as long as the objects
# stayed loose (2026-09-23, scratch test at --latency=90), and gc --auto packs
# only at 6,700. Packed, the same re-hash touches one .pack file. Measured as
# growth since the last pack, so the unreachable loose objects old snapshots
# leave behind (pruned by gc in time) don't make every run repack.
pack_if_grown() {
  local loose base
  loose="$(git count-objects 2>/dev/null | cut -d' ' -f1)"
  case "$loose" in ''|*[!0-9]*) return 0 ;; esac
  { read -r base <"$PACK_STAMP"; } 2>/dev/null
  case "${base:-}" in ''|*[!0-9]*) base=0 ;; esac
  if [ "$loose" -lt "$base" ]; then echo "$loose" >"$PACK_STAMP"; return 0; fi   # gc ran: re-baseline
  [ $((loose - base)) -gt "$PACK_GROWTH" ] || return 0
  if git repack -d -q >/dev/null 2>>"$LOG"; then
    base="$(git count-objects 2>/dev/null | cut -d' ' -f1)"
    echo "${base:-0}" >"$PACK_STAMP"
    log "packed loose objects ($loose loose, ${base:-?} left)"
  fi
}
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

# build a snapshot tree of the full working dir via a throwaway index: seed it
# from HEAD (so git add diffs against HEAD), then stage every working-tree change
# including untracked files and deletions.
TMPIDX="$(mktemp "${TMPDIR:-/tmp}/chaos-idx.XXXXXX")"
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
  note "no changes"; pack_if_grown; exit 0
fi

# origin's branch already holds this tree on this parent? skip. Both halves must
# match: a new HEAD under an unchanged tree still pushes, so new main commits
# reach GitHub as the snapshot's parent.
PUSHED_TREE="$(git rev-parse -q --verify "$REMOTE_REF^{tree}" 2>/dev/null)"
PUSHED_PARENT="$(git rev-parse -q --verify "$REMOTE_REF^" 2>/dev/null)"
if [ "$TREE" = "$PUSHED_TREE" ] && [ "$HEAD_REV" = "$PUSHED_PARENT" ]; then
  note "unchanged since last push"; pack_if_grown; exit 0
fi

# Same tree on the same parent as the last snapshot, which never got out (its
# push failed)? Push that commit again instead of minting a new one on every
# retry — offline, the idle retry comes round every 15 min.
if [ "$TREE" = "$(git rev-parse -q --verify 'refs/autosave/latest^{tree}' 2>/dev/null)" ] &&
   [ "$HEAD_REV" = "$(git rev-parse -q --verify 'refs/autosave/latest^' 2>/dev/null)" ]; then
  COMMIT="$(git rev-parse -q --verify refs/autosave/latest 2>/dev/null)"
else
  COMMIT="$(git commit-tree "$TREE" -p "$HEAD_REV" -m "autosave $HOST $(date '+%F %T')" 2>>"$LOG")" || exit 0
  [ -n "$COMMIT" ] || exit 0
  # keep a local ref so it can't be gc'd and is locally recoverable even if push fails
  git update-ref "refs/autosave/latest" "$COMMIT" 2>>"$LOG" || true
fi
[ -n "$COMMIT" ] || exit 0

# force-push the snapshot to this Mac's remote branch (no local branch touched).
# The remote's chatter (GitHub's "This repository moved" notice was half the
# log) is kept only when the push fails.
if OUT="$(git push --force --quiet origin "$COMMIT:refs/heads/$BRANCH" 2>&1)"; then
  # git push moves the tracking ref itself when remote.origin.fetch maps this
  # branch (the default +refs/heads/*); set it anyway, so a narrower refspec
  # can't quietly turn every run back into a push.
  git update-ref "$REMOTE_REF" "$COMMIT" 2>>"$LOG" || true
  log "pushed $COMMIT to $BRANCH$([ "$QUIET" = 1 ] && echo ' (idle retry)')"
else
  [ -n "$OUT" ] && printf '%s\n' "$OUT" >>"$LOG"
  log "push FAILED (1Password locked / offline?) — snapshot kept locally at refs/autosave/latest ($COMMIT)"
fi
pack_if_grown   # after update-ref, so a burst's new blobs are reachable and get packed
