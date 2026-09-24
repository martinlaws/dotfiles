#!/usr/bin/env bash
# chaos-autosave-watch.sh — watch chaos for changes and fire a debounced snapshot.
# Run as a kept-alive launchd agent (ca.mlaws.chaos-autosave). fswatch coalesces
# bursts of edits over a 90s window, and the loop drains whatever else is queued
# before it snapshots, so we snapshot ~once per active stretch and again ~90s
# after you stop — not on every keystroke. After 15 quiet minutes it retries a
# snapshot that never reached origin (see the loop).
set -uo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

CHAOS="$HOME/code/chaos"
SNAP="$HOME/.bin/chaos-autosave.sh"
RETRY_SECS="${AUTOSAVE_RETRY_SECS:-900}"   # idle retry period (override: tests only)
case "$RETRY_SECS" in ''|*[!0-9]*) RETRY_SECS=900 ;; esac
[ "$RETRY_SECS" -ge 10 ] || RETRY_SECS=900

[ -d "$CHAOS/.git" ] || { echo "chaos repo not present; watcher exiting"; exit 0; }
command -v fswatch >/dev/null 2>&1 || { echo "fswatch not installed; watcher exiting"; exit 0; }

# -o: one event (a count) per coalesced batch. --latency: debounce window (s).
# Exclude .git so the snapshot's own ref/object writes don't re-trigger us.
# ⚠ Also the rm2 desk panel's machine state (2026-09-23): /frame.raw rewrites
# frame-heartbeat.json on every panel poll (60s) and frame-edition.json on
# every content change. Both are gitignored, so a snapshot never commits them,
# but each write still woke this loop — an autosave run a minute, all day.
# Basic regex (no -E), so one --exclude per file; each also matches the
# `.tmp-<pid>` temp name the atomic write renames from.
# Same reasoning for the heavy gitignored build/dependency dirs: a `next build`
# (.next), `npm ci` (node_modules), a Go build (kobo/rm2/dist) or a render loop
# (kobo/out) writes thousands of files a snapshot never includes. Agent
# worktrees (.claude/worktrees) are gitignored checkouts of their own.
#
# ⚠ -o does NOT merge a big burst into one line: 6,000 events came out as ~200
# lines (2026-09-23), and each queued line used to become its own snapshot and
# force-push, one every ~4s for an hour after the burst. So after each line,
# swallow whatever else is already queued (anything arriving within 2s), capped
# at 60s so a never-ending stream still gets snapshotted.
# launchd's PATH resolves `env bash` to /bin/bash 3.2: integer `read -t` only.
#
# Idle retry: when no line arrives for RETRY_SECS, run the snapshot with
# --if-unpushed, which does nothing unless refs/autosave/latest never reached
# origin. Without it a push that failed while you were away (1Password locked,
# offline) waited for your next edit, with the snapshot on this disk only.
# ⚠ bash 3.2's `read -t` returns 1 on a timeout exactly as on EOF, so elapsed
# time tells them apart: a read that gives up early is EOF (fswatch died), and
# the loop exits so launchd's KeepAlive restarts the whole watcher.
exec fswatch -o --latency=90 --exclude='/\.git/' \
  --exclude='/dashboard/\.cache/frame-heartbeat\.json' \
  --exclude='/dashboard/\.cache/frame-edition\.json' \
  --exclude='/node_modules/' \
  --exclude='/\.next/' \
  --exclude='/dist/' \
  --exclude='/__pycache__/' \
  --exclude='/dashboard/kobo/out/' \
  --exclude='/\.claude/worktrees/' \
  "$CHAOS" | while :; do
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
