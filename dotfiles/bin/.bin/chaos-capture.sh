#!/bin/bash
# chaos-capture.sh — macropad K2: a one-line dialog whose text lands in chaos's
# _inbox.md, the same landing zone superwhisper's Capture mode writes to.
#
# Fired by Karabiner (rule "ZXW pad K2", written by
# ~/dotfiles/config/karabiner/gen-pad-rules.py). The line format is exactly what
# .claude/skills/slurp/drain.sh appends — a `## YYYY-MM-DD` heading, then
# `- HH:MM text`, newest at the bottom. Nothing is filed into an area here.
# drain.sh lists what is already pending in _inbox.md (a `pending in _inbox.md`
# block, newest 15), so /slurp and /daily show these lines until they are filed.
#
# ✗ Never: send email, write a calendar, commit, or touch anything but the inbox
# and this script's own log. Dictation (K3) works inside the dialog.
#
# Karabiner runs shell_command as `/bin/sh -c` under the console user with
# PATH=/usr/bin:/bin:/usr/sbin:/sbin, cwd=/, no TZ, stdin /dev/null, and kills the
# previous command when the key fires again. Hence: no dependency on PATH, and the
# dialog lives in a detached worker that a newer press replaces (a fresh dialog on
# top), so a stray second press never stacks two. The dialog is left WITHOUT
# `activate`: measured 2026-09-30, plain `display dialog` under a bare env takes
# focus (osascript frontmost) and `tell current application to activate` did not.
# bash 3.2 (macOS /bin/bash) compatible.
#
# Usage: chaos-capture.sh [--dry-run] [--foreground] [--text TEXT]
#   --text TEXT    skip the dialog and capture TEXT (manual use, tests)
#   --dry-run      say what would be written; write nothing, notify nothing
#   --foreground   run the dialog inline instead of detaching (manual use, tests)
#   --print-dialog-script   print the AppleScript (tests compile it)
#
# Env (tests override these): CHAOS_CAPTURE_INBOX CHAOS_CAPTURE_STATE
#   CHAOS_CAPTURE_ASK CHAOS_CAPTURE_NOTIFY CHAOS_CAPTURE_WAIT
#   CHAOS_CAPTURE_NOW (epoch seconds) CHAOS_CAPTURE_SPAWN_PAUSE (seconds)

set -u
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
export TZ="${TZ:-America/Toronto}"

INBOX="${CHAOS_CAPTURE_INBOX:-$HOME/code/chaos/_inbox.md}"
STATE="${CHAOS_CAPTURE_STATE:-$HOME/.local/state}"
ASK="${CHAOS_CAPTURE_ASK:-}"
NOTIFY="${CHAOS_CAPTURE_NOTIFY:-}"
WAIT="${CHAOS_CAPTURE_WAIT:-300}"
LOG="$STATE/chaos-capture.log"
PIDFILE="$STATE/chaos-capture.pid"

# Returns whatever was typed, even when the dialog gave up waiting; empty on
# Cancel/Esc. A typed line is never thrown away by a timeout.
DIALOG_SCRIPT='on run argv
  try
    set r to display dialog (item 1 of argv) default answer "" with title (item 2 of argv) buttons {"Cancel", "Capture"} default button "Capture" cancel button "Cancel" giving up after (item 3 of argv as integer)
    return text returned of r
  on error number -128
    return ""
  end try
end run'

NOTE_SCRIPT='on run argv
  set t to item 3 of argv
  if (count of t) > 90 then set t to (text 1 thru 90 of t) & "…"
  display notification t with title "Capture" subtitle ((item 1 of argv) & " " & (item 2 of argv))
end run'

DRY=0
FOREGROUND=0
TEXT=""
HAVE_TEXT=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    --foreground) FOREGROUND=1 ;;
    --text)
      if [ $# -lt 2 ]; then echo "usage: ${0##*/} [--dry-run] [--foreground] [--text TEXT]" >&2; exit 2; fi
      TEXT="$2"; HAVE_TEXT=1; shift ;;
    --print-dialog-script) echo "$DIALOG_SCRIPT"; echo "---"; echo "$NOTE_SCRIPT"; exit 0 ;;
    *) echo "usage: ${0##*/} [--dry-run] [--foreground] [--text TEXT]" >&2; exit 2 ;;
  esac
  shift
done

/bin/mkdir -p "$STATE" 2>/dev/null

log() { printf '%s  %s\n' "$(/bin/date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$LOG"; }

# Process start time, locale-pinned (a terminal run and a Karabiner run must
# write and compare the same string). Only this call is pinned; exporting LC_ALL
# for the whole script would change how osascript reads argv.
started() { LC_ALL=C /bin/ps -o lstart= -p "$1" 2>/dev/null; }

# $1 = glyph (✓ ⚠ ✗), $2 = headline, $3 = body. Always logged; shown on screen
# unless --dry-run. The body (the captured text) is shown but never logged here.
report() {
  log "$1 $2"
  echo "$1 $2"
  [ "$DRY" = 1 ] && return 0
  if [ -n "$NOTIFY" ]; then
    "$NOTIFY" "$1" "$2" "${3:-}" >>"$LOG" 2>&1 </dev/null
    return 0
  fi
  /usr/bin/osascript -e "$NOTE_SCRIPT" "$1" "$2" "${3:-}" >>"$LOG" 2>&1 </dev/null
  if [ "$1" != "✓" ]; then
    /usr/bin/afplay /System/Library/Sounds/Basso.aiff >>"$LOG" 2>&1 </dev/null &
  fi
  return 0
}

# One line, no control characters, no edge whitespace. Byte-wise (C locale) so
# UTF-8 passes through untouched.
clean() {
  printf '%s' "$1" | LC_ALL=C /usr/bin/tr '\r\n\t' '   ' | LC_ALL=C /usr/bin/tr -d '\000-\010\013\014\016-\037\177' | LC_ALL=C /usr/bin/sed 's/^ *//;s/ *$//'
}

# $1 = text, $2 = day, $3 = HH:MM. Heading and line go out in one write so a
# capture is never torn. The heading is reused only when it is the LAST one: an
# earlier one would put the line under an older date once drain.sh has appended
# a section after it.
append() {
  local prefix=""
  [ -f "$INBOX" ] || printf '# Inbox\n' >"$INBOX" || return 1
  if [ -s "$INBOX" ] && [ "$(/usr/bin/tail -c1 "$INBOX" | /usr/bin/wc -l | /usr/bin/tr -d ' ')" = 0 ]; then
    prefix=$'\n'
  fi
  if [ "$(LC_ALL=C /usr/bin/grep '^## ' "$INBOX" | /usr/bin/tail -1)" = "## $2" ]; then
    printf '%s- %s %s\n' "$prefix" "$3" "$1" >>"$INBOX"
  else
    printf '%s\n## %s\n- %s %s\n' "$prefix" "$2" "$3" "$1" >>"$INBOX"
  fi
}

# $1 = raw text. Cleans, writes, reports. Empty text is a silent no-op. The clock
# is read once, so the heading, the line and the notification agree.
capture() {
  local text now stamp day hm
  text="$(clean "$1")"
  if [ -z "$text" ]; then
    log "· nothing to capture (cancelled or empty)"
    echo "(Nothing captured — the text was empty.)"
    return 0
  fi
  now="${CHAOS_CAPTURE_NOW:-$(/bin/date +%s)}"
  stamp="$(/bin/date -r "$now" '+%Y-%m-%d %H:%M')"
  day="${stamp% *}"
  hm="${stamp#* }"
  if [ "$DRY" = 1 ]; then
    echo "would append to $INBOX: - $hm $text"
    return 0
  fi
  if [ ! -d "$(/usr/bin/dirname "$INBOX")" ]; then
    log "✗ text kept here: $text"
    report "✗" "Not saved: $(/usr/bin/dirname "$INBOX") does not exist." "Text kept in $LOG"
    return 1
  fi
  if ! append "$text" "$day" "$hm"; then
    log "✗ text kept here: $text"
    report "✗" "Not saved: could not write $INBOX." "Text kept in $LOG"
    return 1
  fi
  report "✓" "Captured $hm" "$text"
  return 0
}

# The dialog worker: replace any dialog a previous press left open, ask, capture.
worker() {
  local oldd old_started out err opid rc cur text
  # The pidfile is `worker-pid|dialog-pid|dialog-start`. A newer press CLAIMS it
  # (its own worker pid) before it kills the old dialog, so the old worker, waking
  # on the kill, already sees it has been replaced and stays silent.
  oldd=""; old_started=""
  [ -f "$PIDFILE" ] && IFS='|' read -r _ oldd old_started <"$PIDFILE"
  echo "$$||" >"$PIDFILE"
  if [ -n "$oldd" ] && [ -n "$old_started" ] && [ "$(started "$oldd")" = "$old_started" ]; then
    /bin/kill "$oldd" 2>/dev/null
    log "· replaced the dialog from an earlier press"
  fi

  out="$(/usr/bin/mktemp "$STATE/chaos-capture.out.XXXXXX")" || { report "✗" "Could not start the dialog." "no temp file in $STATE"; return 1; }
  err="$(/usr/bin/mktemp "$STATE/chaos-capture.err.XXXXXX")" || { /bin/rm -f "$out"; return 1; }

  # exec so $! is the dialog process itself, the one a newer press kills.
  if [ -n "$ASK" ]; then
    ( exec "$ASK" "one line to the inbox" "capture" "$WAIT" ) >"$out" 2>"$err" </dev/null &
  else
    ( exec /usr/bin/osascript -e "$DIALOG_SCRIPT" "one line to the inbox" "capture" "$WAIT" ) >"$out" 2>"$err" </dev/null &
  fi
  opid=$!
  [ -n "${CHAOS_CAPTURE_SPAWN_PAUSE:-}" ] && /bin/sleep "$CHAOS_CAPTURE_SPAWN_PAUSE"

  # A press that came in while this dialog was starting already replaced us.
  cur=""
  [ -f "$PIDFILE" ] && IFS='|' read -r cur _ <"$PIDFILE"
  if [ -n "$cur" ] && [ "$cur" != "$$" ]; then
    /bin/kill "$opid" 2>/dev/null
    wait "$opid" 2>/dev/null
    log "· superseded before the dialog opened; nothing written"
    /bin/rm -f "$out" "$err"
    return 0
  fi
  echo "$$|$opid|$(started "$opid")" >"$PIDFILE"

  wait "$opid"
  rc=$?

  cur=""
  [ -f "$PIDFILE" ] && IFS='|' read -r cur _ <"$PIDFILE"
  [ "$cur" = "$$" ] && /bin/rm -f "$PIDFILE"

  # Text already printed means the line was typed: a kill or crash after that
  # point must not throw it away, so only an empty result takes the failure paths.
  if [ "$rc" != 0 ] && [ ! -s "$out" ]; then
    if [ -n "$cur" ] && [ "$cur" != "$$" ]; then
      log "· superseded by a newer press; nothing written"
      /bin/rm -f "$out" "$err"
      return 0
    fi
    report "✗" "The capture dialog failed (exit $rc)." "$(/usr/bin/head -c 200 "$err")"
    log "  stderr: $(/usr/bin/head -c 500 "$err")"
    /bin/rm -f "$out" "$err"
    return 1
  fi
  [ "$rc" != 0 ] && log "· dialog exited $rc after it printed; saving what it printed"
  text="$(< "$out")"
  /bin/rm -f "$out" "$err"
  capture "$text"
}

if [ "$HAVE_TEXT" = 1 ]; then
  capture "$TEXT"
  exit $?
fi

if [ "$DRY" = 1 ]; then
  echo "would open the capture dialog and append the line to $INBOX; nothing written."
  exit 0
fi

if [ "$FOREGROUND" = 1 ]; then
  worker
  exit $?
fi

"$0" --foreground >/dev/null 2>>"$LOG" </dev/null &
exit 0
