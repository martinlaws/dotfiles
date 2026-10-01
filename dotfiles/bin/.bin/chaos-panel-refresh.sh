#!/bin/bash
# chaos-panel-refresh.sh — macropad K1: refresh what the desk panel reads, now,
# then say honestly whether the glass has anything new to show.
#
# Fired by Karabiner (rule "ZXW pad K1", written by
# ~/dotfiles/config/karabiner/gen-pad-rules.py). It kicks the two refresher agents
# that already run on timers (ca.mlaws.chaos-calendar every 15 min,
# ca.mlaws.chaos-weather hourly) and reimplements neither: todos and the daily
# note are read from disk on every panel poll, so those two caches are the only
# things that can be stale.
#
# ★ Honest by design. The footer rail (Cal/Wx/Queue/Planned) is frozen with the
# edition and the glass repaints only when its content hash moves, so a refresh
# that finds nothing new changes nothing on the glass. dashboard/kobo/README.md:
# "Anything else that moves the glass without the content moving is a bug." So
# this script never moves a stamp. It reads the panel heartbeat and reports
# whether the served frame changed after the refresh landed.
#
# ✗ Never: kickstart -k (kills a live run), restart the dashboard, request
# /frame.raw itself, touch the tablet (ssh, glass.sh, tether) or edit the
# frame-edition / frame-heartbeat caches. The only write outside the log is the
# kickstart.
#
# Karabiner runs shell_command as `/bin/sh -c` under the console user with
# PATH=/usr/bin:/bin:/usr/sbin:/sbin, cwd=/, no TZ, stdin /dev/null, and kills the
# previous command when the key fires again. Hence: no dependency on PATH, a
# detached verifier that a newer press replaces, and every background child
# redirected off Karabiner's pipes. bash 3.2 (macOS /bin/bash) compatible.
#
# Usage: chaos-panel-refresh.sh [--dry-run] [--foreground]
#   --dry-run      say what would be kicked; kick nothing, notify nothing
#   --foreground   run the verifier inline instead of detaching (manual use, tests)
#
# Env (tests override these): CHAOS_PANEL_CACHE CHAOS_PANEL_STATE
#   CHAOS_PANEL_LAUNCHCTL CHAOS_PANEL_NOTIFY CHAOS_PANEL_HOST CHAOS_PANEL_TICK
#   CHAOS_PANEL_REFRESH_WAIT CHAOS_PANEL_POLL_WAIT CHAOS_DASHBOARD_HOST

set -u
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
export TZ="${TZ:-America/Toronto}"

CACHE="${CHAOS_PANEL_CACHE:-$HOME/code/chaos/dashboard/.cache}"
STATE="${CHAOS_PANEL_STATE:-$HOME/.local/state}"
LAUNCHCTL="${CHAOS_PANEL_LAUNCHCTL:-/bin/launchctl}"
NOTIFY="${CHAOS_PANEL_NOTIFY:-}"
EXPECT_HOST="${CHAOS_DASHBOARD_HOST:-studio}"
TICK="${CHAOS_PANEL_TICK:-2}"
REFRESH_WAIT="${CHAOS_PANEL_REFRESH_WAIT:-45}"
POLL_WAIT="${CHAOS_PANEL_POLL_WAIT:-150}"
POLL_SLACK=5
UNPAINTED_MAX=2   # frame-liveness.sh's bar: held ≠ served for more than 2 polls with the held tag standing still
LOG="$STATE/chaos-panel-refresh.log"
PIDFILE="$STATE/chaos-panel-refresh.pid"
CAL="$CACHE/calendar.json"
HEARTBEAT="$CACHE/frame-heartbeat.json"

DRY=0
FOREGROUND=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY=1 ;;
    --foreground) FOREGROUND=1 ;;
    *) echo "usage: ${0##*/} [--dry-run] [--foreground]" >&2; exit 2 ;;
  esac
done

/bin/mkdir -p "$STATE" 2>/dev/null

log() { printf '%s  %s\n' "$(/bin/date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$LOG"; }

# Empty on any failure: a null or missing key is "no value", never an error.
jget() { /usr/bin/plutil -extract "$2" raw -o - "$1" 2>/dev/null || true; }

# 2026-09-30T16:56:15.137Z → epoch. Empty in, empty out.
epoch_utc() {
  local t="${1%%.*}"
  t="${t%Z}"
  [ -n "$t" ] && /bin/date -j -u -f '%Y-%m-%dT%H:%M:%S' "$t" +%s 2>/dev/null
}

# 2026-09-30T13:06:35-04:00 → epoch (BSD date wants the offset without its colon).
epoch_offset() {
  [ -n "$1" ] || return 1
  case "$1" in
    *Z) epoch_utc "$1" ;;
    *) /bin/date -j -f '%Y-%m-%dT%H:%M:%S%z' "${1%:*}${1##*:}" +%s 2>/dev/null ;;
  esac
}

# epoch → HH:MM Eastern, or the word in $2 when there is no epoch.
hhmm() {
  if [ -n "$1" ]; then /bin/date -r "$1" '+%H:%M' 2>/dev/null || echo "$2"; else echo "$2"; fi
}

# Like hhmm, but a stamp more than 12 h old carries its day and age, so a
# heartbeat from yesterday never reads as "13:24, just now".
when() {
  local age now
  if [ -z "$1" ]; then echo "$2"; return; fi
  now="$(/bin/date +%s)"
  age=$((now - $1))
  if [ "$age" -gt 43200 ]; then
    if [ "$age" -ge 172800 ]; then
      echo "$(/bin/date -r "$1" '+%a %H:%M') ($((age / 86400))d ago)"
    else
      echo "$(/bin/date -r "$1" '+%a %H:%M') ($((age / 3600))h ago)"
    fi
  else
    hhmm "$1" "$2"
  fi
}

# Process start time, locale-pinned: a terminal run (en_CA) and a Karabiner run
# (C locale) must write and compare the same string. Only this call is pinned;
# exporting LC_ALL for the whole script would change how osascript reads argv.
started() { LC_ALL=C /bin/ps -o lstart= -p "$1" 2>/dev/null; }

# Middle of a quoted ETag, for messages.
short() { local t="${1//\"/}"; echo "${t:0:8}"; }

# $1 = glyph (✓ ⚠ ✗), $2 = text. Always logged; shown on screen unless --dry-run.
report() {
  log "$1 $2"
  echo "$1 $2"
  [ "$DRY" = 1 ] && return 0
  if [ -n "$NOTIFY" ]; then
    "$NOTIFY" "$1 $2" >>"$LOG" 2>&1 </dev/null
    return 0
  fi
  /usr/bin/osascript -e 'on run argv' -e 'display notification (item 2 of argv) with title "Panel" subtitle (item 1 of argv)' -e 'end run' "$1" "$2" >>"$LOG" 2>&1 </dev/null
  if [ "$1" != "✓" ]; then
    /usr/bin/afplay /System/Library/Sounds/Basso.aiff >>"$LOG" 2>&1 </dev/null &
  fi
  return 0
}

# Runs after the kick: wait for the calendar cache to land, wait for the panel to
# ask again, then compare what it was served before and after.
verify() {
  local kick="$1" before_served="$2"
  local deadline=$((kick + REFRESH_WAIT)) landed="" lr e

  while [ "$(/bin/date +%s)" -le "$deadline" ]; do
    lr="$(jget "$CAL" lastRefresh)"
    e="$(epoch_utc "$lr")"
    # lastRefresh read from inside the json, never the mtime. A run that was
    # already in flight at the press counts: it lands after $kick too.
    if [ -n "$e" ] && [ "$e" -ge "$kick" ]; then landed="$e"; break; fi
    /bin/sleep "$TICK"
  done
  if [ -z "$landed" ]; then
    e="$(epoch_utc "$(jget "$CAL" lastRefresh)")"
    report "⚠" "Calendar didn't refresh within ${REFRESH_WAIT}s (last good read $(when "$e" unknown)). Still running, or hey auth: see ~/.local/state/chaos-calendar.out.log."
    return 1
  fi

  local want=$((landed + POLL_SLACK)) poll_deadline at ae="" status served
  poll_deadline=$(($(/bin/date +%s) + POLL_WAIT))
  while [ "$(/bin/date +%s)" -le "$poll_deadline" ]; do
    at="$(jget "$HEARTBEAT" at)"
    ae="$(epoch_offset "$at")"
    if [ -n "$ae" ] && [ "$ae" -ge "$want" ]; then break; fi
    ae=""
    /bin/sleep "$TICK"
  done

  if [ -z "$ae" ]; then
    at="$(epoch_offset "$(jget "$HEARTBEAT" at)")"
    report "⚠" "Calendar refreshed $(hhmm "$landed" unknown), but the panel hasn't asked since $(when "$at" ever). Is the tether up?"
    return 0
  fi

  status="$(jget "$HEARTBEAT" status)"
  served="$(jget "$HEARTBEAT" served)"
  held="$(jget "$HEARTBEAT" held)"
  unpainted="$(jget "$HEARTBEAT" unpainted)"
  case "$unpainted" in ''|*[!0-9]*) unpainted=0 ;; esac
  case "$status" in
    200|304) ;;
    *) report "✗" "Calendar refreshed $(hhmm "$landed" unknown), but the Studio answered the panel with ${status:-nothing}. Check the dashboard."; return 1 ;;
  esac

  local cal; cal="$(hhmm "$landed" unknown)"
  # A 200 is the Studio sending a frame the device did not hold. The device
  # paints it and holds it on the next poll; if its held tag stands still while
  # newer frames keep coming, it is fetching but not painting. That is checked
  # before anything says "new frame", so a stuck device cannot be told it has one.
  if [ "$status" = 200 ] && [ "$unpainted" -gt "$UNPAINTED_MAX" ]; then
    report "⚠" "Calendar refreshed $cal, but the glass isn't taking frames: it has held ${held:+$(short "$held") }for $unpainted polls while being served newer ones. Check the tablet."
    return 0
  fi

  if [ "$status" = 200 ]; then
    if [ -n "$before_served" ] && [ "$served" = "$before_served" ]; then
      report "✓" "Calendar refreshed $cal. The glass was behind and has been sent the current frame."
    else
      report "✓" "Calendar refreshed $cal. The glass has a new frame."
    fi
  elif [ -z "$before_served" ]; then
    report "✓" "Calendar refreshed $cal. The glass is current; no earlier poll on record, so can't say whether it changed."
  elif [ "$served" != "$before_served" ]; then
    report "✓" "Calendar refreshed $cal. The glass has a new frame."
  else
    report "✓" "Calendar refreshed $cal. Nothing new to show: the glass is current."
  fi
  return 0
}

host="${CHAOS_PANEL_HOST:-$(/usr/sbin/scutil --get LocalHostName 2>/dev/null || true)}"
host="${host:-unknown}"
if [ "$host" != "$EXPECT_HOST" ]; then
  report "✗" "Not the Studio ('$host', expected '$EXPECT_HOST'): nothing refreshed."
  exit 1
fi

uid="$(/usr/bin/id -u)"
kick="$(/bin/date +%s)"
before_served="$(jget "$HEARTBEAT" served)"

if [ "$DRY" = 1 ]; then
  report "✓" "Dry run: would kickstart gui/$uid/ca.mlaws.chaos-calendar and gui/$uid/ca.mlaws.chaos-weather (no -k), then watch the heartbeat."
  exit 0
fi

# A newer press replaces the verifier of an older one, as Karabiner does with
# the shell it launched. The pidfile holds "pid|start time": the pid is only
# killed if the process still started then and is still this script, so a
# recycled pid can never take the signal.
if [ -f "$PIDFILE" ]; then
  IFS='|' read -r old old_started <"$PIDFILE" || true
  if [ -n "$old" ] && [ "$old" != "$$" ] && [ -n "$old_started" ] \
     && [ "$(started "$old")" = "$old_started" ] \
     && /bin/ps -o command= -p "$old" 2>/dev/null | /usr/bin/grep -q 'chaos-panel-refresh\.sh'; then
    /bin/kill "$old" 2>/dev/null
    log "replaced the verifier of the previous press (pid $old)"
  fi
  /bin/rm -f "$PIDFILE"
fi

# Without -k: a run already in flight is left alone, which is what makes a double
# press (or K1's layer-flip tap on a hold) harmless. ⚠ Observed 2026-09-30: a second
# press inside launchd's 10 s throttle blocks here for ~9 s until the job may start
# again; Karabiner runs this async, so nothing waits on it.
"$LAUNCHCTL" kickstart "gui/$uid/ca.mlaws.chaos-calendar" >>"$LOG" 2>&1 </dev/null
rc=$?
if [ "$rc" -ne 0 ]; then
  report "✗" "Couldn't start the calendar refresher (launchctl exit $rc): nothing refreshed."
  exit 1
fi
"$LAUNCHCTL" kickstart "gui/$uid/ca.mlaws.chaos-weather" >>"$LOG" 2>&1 </dev/null \
  || log "⚠ weather refresher didn't start (launchctl exit $?); calendar was kicked"
log "kicked calendar + weather (kick=$kick, served before=${before_served:-none})"

if [ "$FOREGROUND" = 1 ]; then
  verify "$kick" "$before_served"
  exit $?
fi

( verify "$kick" "$before_served" ) >/dev/null 2>>"$LOG" </dev/null &
verifier=$!
echo "$verifier|$(started "$verifier")" >"$PIDFILE"
echo "✓ Kicked calendar + weather. The verdict follows as a notification."
exit 0
