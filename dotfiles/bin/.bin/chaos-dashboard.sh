#!/usr/bin/env bash
# chaos-dashboard.sh — run the chaos dashboard as a supervised service on :2424.
#
# Loaded by ca.mlaws.chaos-dashboard (~/dotfiles/config/launchd/). The dashboard
# UI is not the point — the Kobo desk panel fetches /frame from this server, so
# it has to be up without anyone opening a tab.
#
# Four things here look like boilerplate and are not:
#
# 1. PATH. The autosave plists set PATH=/opt/homebrew/bin:… which resolves
#    Homebrew's node (v26.8.2). dashboard/node_modules was installed under fnm's
#    default (v24.13.0). That is a silent major-version swap, not a "command not
#    found" you would notice. The fnm ALIAS path below is stable across reboots;
#    `which node` is NOT — it returns ~/.local/state/fnm_multishells/<PID>_<ts>/
#    which is per-shell and gone after a restart.
#
# 2. The host gate. ~/dotfiles is shared with the MacBook Pro, and
#    dashboard/.cache/calendar.json is git-TRACKED on purpose (remote /morning
#    has no `hey` binary and reads the committed copy). Two machines refreshing
#    it on a timer, both with autosave fswatch committing, fight over a tracked
#    file — and a laptop that has been shut for a day would push a stale cache
#    that /morning then trusts. Studio only.
#
# 3. exit 0 on every failure. The plist sets KeepAlive, so a non-zero exit is a
#    throttled crash loop. Say what broke, in the log, and stop.
#
# 4. Refusing to start on a failed build. A stale server serves a stale frame,
#    and e-ink holds its last frame forever — a quiet lie on the glass is worse
#    than a loud fetch failure in render.sh.

set -uo pipefail

export PATH="$HOME/.local/share/fnm/aliases/default/bin:$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

DASHBOARD="$HOME/code/chaos/dashboard"
EXPECT_HOST="${CHAOS_DASHBOARD_HOST:-studio}"
LABEL="ca.mlaws.chaos-dashboard"

# Timestamped, because the agent this replaces failed 1,279 consecutive times
# into an untimestamped log and nobody could tell when it had started.
log() { printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

host="$(scutil --get LocalHostName 2>/dev/null || hostname -s)"
if [ "$host" != "$EXPECT_HOST" ]; then
  log "✗ not the dashboard host — this is '$host', expected '$EXPECT_HOST'. Not starting."
  log "  The calendar cache is git-tracked; two machines on a timer fight over it."
  exit 0
fi

[ -d "$DASHBOARD" ] || { log "✗ $DASHBOARD not present. Not starting."; exit 0; }
cd "$DASHBOARD" || { log "✗ cannot cd to $DASHBOARD. Not starting."; exit 0; }

command -v node >/dev/null 2>&1 || {
  log "✗ node not on PATH — is ~/.local/share/fnm/aliases/default/bin still there?"
  exit 0
}
[ -x node_modules/.bin/next ] || {
  log "✗ node_modules/.bin/next missing — run 'npm ci' in $DASHBOARD, then:"
  log "    launchctl kickstart -k gui/\$(id -u)/$LABEL"
  exit 0
}

# ── build, only when stale ───────────────────────────────────────────────────
# `[ src -newer .next/BUILD_ID ]` would be wrong: a directory's mtime moves only
# when entries are added or removed, not when a file inside is edited. find with
# -print -quit stops at the first newer file, so this is cheap.
WATCH=(src public package.json package-lock.json next.config.ts tsconfig.json)
needs_build=0
if [ ! -f .next/BUILD_ID ]; then
  log "no .next/BUILD_ID — building."
  needs_build=1
elif [ -n "$(find "${WATCH[@]}" -newer .next/BUILD_ID -print -quit 2>/dev/null)" ]; then
  log "build is stale (source newer than .next/BUILD_ID) — rebuilding."
  needs_build=1
fi

if [ "$needs_build" = 1 ]; then
  if npm run build; then
    log "✓ build complete."
  else
    log "✗ next build FAILED — refusing to serve a stale build. Fix it, then:"
    log "    launchctl kickstart -k gui/\$(id -u)/$LABEL"
    exit 0
  fi
fi

# 127.0.0.1 deliberately: render.sh fetches from the Mac itself, and the Kobo
# gets PNGs from kobo/serve.sh on :8765. No reason to put the whole dashboard —
# every parser, every client name — on the LAN.
#
# exec the binary rather than `npm start` so launchd supervises next itself and
# signals reach it, instead of supervising an npm wrapper process.
log "starting next start on 127.0.0.1:2424 (node $(node --version))"
exec node_modules/.bin/next start --hostname 127.0.0.1 --port 2424
