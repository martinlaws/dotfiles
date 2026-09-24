#!/bin/bash
# setup-dashboard-agents.sh — install + load the chaos dashboard launchd agents:
#   ca.mlaws.chaos-dashboard  (next start on :2424, supervised)
#   ca.mlaws.chaos-calendar   (npm run refresh-calendar, every 15 min)
#   ca.mlaws.chaos-weather    (npm run refresh-weather, hourly)
#
# The Kobo desk panel fetches /frame from the dashboard server and two of its
# rows read dashboard/.cache/calendar.json, so both have to be up without anyone
# opening a tab or running /daily.
#
#   scripts/setup-dashboard-agents.sh            install (or reload) both
#   scripts/setup-dashboard-agents.sh uninstall  bootout + remove both plists
#
# Idempotent. Non-fatal — skips cleanly when a precondition is missing.
#
# ★ STUDIO ONLY, and that is the interesting part. These dotfiles are shared
#   with the MacBook Pro, and dashboard/.cache/calendar.json is git-TRACKED on
#   purpose (remote /morning has no `hey` binary and reads the committed copy as
#   its only schedule source). Two machines refreshing it on a 15-minute timer,
#   both with an autosave fswatch committing continuously, would fight over a
#   tracked file — and a laptop shut for a day would push a stale cache that
#   /morning then trusts. So the gate is here AND in each wrapper script: the
#   plist never lands on the wrong host, and a plist that somehow survives is
#   inert anyway.
#
# ✗ Deliberately NOT folded into setup-autosave.sh: its install_agent() gates on
#   `-d "$repo/.git"`, which is a meaningful precondition for a repo watcher and
#   meaningless for a web server.
set -euo pipefail

SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
LABELS=(ca.mlaws.chaos-dashboard ca.mlaws.chaos-calendar ca.mlaws.chaos-weather)
EXPECT_HOST="${CHAOS_DASHBOARD_HOST:-studio}"
CHAOS="$HOME/code/chaos"

uninstall() {
  for label in "${LABELS[@]}"; do
    dest="$HOME/Library/LaunchAgents/${label}.plist"
    launchctl bootout "gui/$(id -u)/${label}" 2>/dev/null || true
    if [ -f "$dest" ]; then
      rm -f "$dest"
      echo "✓ removed ${label}"
    else
      echo "  ${label} was not installed"
    fi
  done
  echo
  echo "  Logs left in place: ~/.local/state/chaos-{dashboard,calendar}.*.log"
  exit 0
}

[ "${1:-}" = "uninstall" ] && uninstall

# /usr/sbin/scutil by absolute path: launchd's PATH has no /usr/sbin, and the old
# `hostname -s` fallback followed the network (2026-09-23). Unreadable → unknown.
host="$(/usr/sbin/scutil --get LocalHostName 2>/dev/null || true)"; host="${host:-unknown}"
if [ "$host" != "$EXPECT_HOST" ]; then
  echo "⚠ not the dashboard host — this is '$host', expected '$EXPECT_HOST'."
  echo "  Skipping the dashboard agents on purpose: dashboard/.cache/calendar.json"
  echo "  is git-tracked, and a second machine refreshing it on a timer would"
  echo "  fight the Studio for it. Override with CHAOS_DASHBOARD_HOST=$host."
  exit 0
fi

if [ ! -d "$CHAOS/dashboard/node_modules" ]; then
  echo "⚠ $CHAOS/dashboard/node_modules missing — skipping dashboard agents"
  echo "  (run 'npm ci' in $CHAOS/dashboard, then re-run this script)"
  exit 0
fi

mkdir -p "$HOME/Library/LaunchAgents" "$HOME/.local/state"

for label in "${LABELS[@]}"; do
  template="$SCRIPT_DIR/config/launchd/${label}.plist.template"
  dest="$HOME/Library/LaunchAgents/${label}.plist"

  if [ ! -f "$template" ]; then
    echo "⚠ plist template missing at $template — skipping ${label}"
    continue
  fi

  # launchd doesn't expand ~ or $HOME.
  sed "s#__HOME__#${HOME}#g" "$template" > "$dest"

  launchctl bootout "gui/$(id -u)/${label}" 2>/dev/null || true

  # ⚠ `bootout` RETURNS BEFORE THE SERVICE IS GONE. A bootstrap fired straight
  # after it races the teardown and fails — observed live on 2026-09-21, where
  # the dashboard agent booted out, failed to bootstrap, and was left UNLOADED
  # while the script reported the other two as loaded. A half-install that
  # reports partial success is the rot this whole file is trying to avoid, so
  # wait for the service to actually disappear, then retry a few times.
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    launchctl print "gui/$(id -u)/${label}" >/dev/null 2>&1 || break
    sleep 0.5
  done

  loaded=0
  for attempt in 1 2 3; do
    if launchctl bootstrap "gui/$(id -u)" "$dest" 2>/dev/null; then loaded=1; break; fi
    sleep 1
  done

  # ✗ Never trust bootstrap's exit code alone — confirm the service is really
  # registered. This is the same rule doctor.sh follows for the same reason.
  if [ "$loaded" = 1 ] && launchctl list "${label}" >/dev/null 2>&1; then
    echo "✓ dashboard agent loaded (${label})"
  else
    echo "✗ ${label} is NOT loaded — bootstrap failed after 3 attempts. Load it by hand:"
    echo "    launchctl bootstrap gui/\$(id -u) $dest"
    failed=1
  fi
done

if [ "${failed:-0}" = 1 ]; then
  echo
  echo "⚠ At least one agent did not load. Re-run this script, or use the command above."
fi

echo
echo "  Dashboard:  http://127.0.0.1:2424"
echo "  Logs:       ~/.local/state/chaos-dashboard.out.log"
echo "              ~/.local/state/chaos-calendar.out.log"
echo "              ~/.local/state/chaos-weather.out.log"
echo "  Uninstall:  scripts/setup-dashboard-agents.sh uninstall"
