#!/usr/bin/env bash
# chaos-weather-refresh.sh — refresh dashboard/.cache/weather.json on a timer.
#
# Loaded by ca.mlaws.chaos-weather (~/dotfiles/config/launchd/), StartInterval
# 3600. The Kobo desk panel's weather row reads that cache and NEVER fetches on
# its own: the frame renders on a request from a battery-powered panel, and a
# network call on that path fails in the one place nobody is watching. So this
# job owns the network and the panel owns nothing.
#
# Hourly rather than the calendar job's 15 minutes because the reader drops the
# block past three hours — three consecutive misses — and an hourly forecast
# does not change meaningfully inside an hour.
#
# Same three non-obvious guards as chaos-calendar-refresh.sh — see that file's
# header for the reasoning. The short version:
#
#   PATH        the fnm ALIAS path, never `which node` (per-shell, dies on reboot)
#   host gate   Studio only; the panel fetches /frame from the Studio's
#               dashboard, so a laptop refreshing a cache nothing reads is noise
#   timestamps  the agent this pattern replaces failed 1,279 times into a log
#               with none
#
# ⚠ Like the calendar job this one does NOT swallow failures. There is no
# KeepAlive on this label, so a non-zero exit cannot crash-loop — it lands in
# `launchctl list` as the last exit status, which is where doctor.sh looks.
#
# ✓ Unlike the calendar job there is no cold-start refusal, and that difference
# is deliberate. weather.json is gitignored (only calendar.json is tracked, for
# remote /morning), and refresh-weather.ts writes NOTHING on failure rather than
# writing an empty cache — so a missing cache here is a missing weather row for
# one hour, not a lie propagated into a committed file.

set -uo pipefail

export PATH="$HOME/.local/share/fnm/aliases/default/bin:$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

DASHBOARD="$HOME/code/chaos/dashboard"
EXPECT_HOST="${CHAOS_DASHBOARD_HOST:-studio}"

log() { printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

# /usr/sbin/scutil by absolute path: launchd's PATH has no /usr/sbin, and the old
# `hostname -s` fallback followed the network (2026-09-23). Unreadable → unknown.
host="$(/usr/sbin/scutil --get LocalHostName 2>/dev/null || true)"; host="${host:-unknown}"
if [ "$host" != "$EXPECT_HOST" ]; then
  log "✗ not the weather-refresh host — this is '$host', expected '$EXPECT_HOST'. Skipping."
  exit 0
fi

[ -d "$DASHBOARD" ] || { log "✗ $DASHBOARD not present. Skipping."; exit 0; }
cd "$DASHBOARD" || { log "✗ cannot cd to $DASHBOARD. Skipping."; exit 0; }

command -v node >/dev/null 2>&1 || { log "✗ node not on PATH. Skipping."; exit 0; }
[ -x node_modules/.bin/tsx ] || {
  log "✗ node_modules/.bin/tsx missing — run 'npm ci' in $DASHBOARD."
  exit 0
}

# ⚠ tsx is invoked directly rather than through `npm run refresh-weather`,
# because that script does not exist in package.json yet. Once it is added
#     "refresh-weather": "tsx scripts/refresh-weather.ts"
# this line can become `npm run --silent refresh-weather` to match the calendar
# job. Direct invocation is equivalent and does not depend on that edit landing.
log "refreshing (node $(node --version))"
if node_modules/.bin/tsx scripts/refresh-weather.ts; then
  log "✓ refreshed."
else
  status=$?
  log "✗ refresh failed (exit $status) — no cache written, existing one left in place."
  log "  Open-Meteo is keyless, so this is a network or DNS problem, not auth."
  exit "$status"
fi
