#!/usr/bin/env bash
# chaos-calendar-refresh.sh — refresh dashboard/.cache/calendar.json on a timer.
#
# Loaded by ca.mlaws.chaos-calendar (~/dotfiles/config/launchd/), StartInterval
# 900. Until now the cache only moved when Martin happened to run /daily,
# /calendar or /morning, and two things on the Kobo panel read it.
#
# Same three non-obvious guards as chaos-dashboard.sh — see that file's header
# for the reasoning. The short version:
#
#   PATH        the fnm ALIAS path, never `which node` (per-shell, dies on reboot)
#   host gate   Studio only; .cache/calendar.json is git-tracked and the MacBook
#               shares these dotfiles, so two timers would fight over it
#   timestamps  the agent this replaces failed 1,279 times into a log with none
#
# ⚠ Unlike the dashboard agent this one does NOT swallow failures. There is no
# KeepAlive on this label, so a non-zero exit cannot crash-loop — it just lands
# in `launchctl list` as the last exit status, which is exactly where doctor.sh
# looks. A refresher that reports success when it failed is the whole failure
# mode this job has already been through once.

set -uo pipefail

export PATH="$HOME/.local/share/fnm/aliases/default/bin:$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

DASHBOARD="$HOME/code/chaos/dashboard"
EXPECT_HOST="${CHAOS_DASHBOARD_HOST:-studio}"

log() { printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

host="$(scutil --get LocalHostName 2>/dev/null || hostname -s)"
if [ "$host" != "$EXPECT_HOST" ]; then
  log "✗ not the calendar-refresh host — this is '$host', expected '$EXPECT_HOST'. Skipping."
  exit 0
fi

[ -d "$DASHBOARD" ] || { log "✗ $DASHBOARD not present. Skipping."; exit 0; }
cd "$DASHBOARD" || { log "✗ cannot cd to $DASHBOARD. Skipping."; exit 0; }

command -v node >/dev/null 2>&1 || { log "✗ node not on PATH. Skipping."; exit 0; }
[ -x node_modules/.bin/tsx ] || {
  log "✗ node_modules/.bin/tsx missing — run 'npm ci' in $DASHBOARD."
  exit 0
}

# ⚠ Never run against a repo with the cache deleted. refresh-calendar.ts skips
# its anti-clobber guard when the file is absent, so a cold start with every
# feed down writes an EMPTY cache — and that empty cache is what remote
# /morning would then read as the day's schedule.
if [ ! -f .cache/calendar.json ]; then
  log "✗ .cache/calendar.json is missing. Refusing to cold-start:"
  log "    a total failure now would write an empty cache over nothing,"
  log "    and remote /morning reads the committed copy as its only schedule."
  log "  Restore it first:  git checkout -- dashboard/.cache/calendar.json"
  exit 1
fi

log "refreshing (node $(node --version))"
if npm run --silent refresh-calendar; then
  log "✓ refreshed."
else
  status=$?
  log "✗ refresh failed (exit $status) — existing cache left in place."
  log "  Check auth first:  hey auth status"
  exit "$status"
fi
