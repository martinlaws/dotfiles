#!/bin/bash
# Tests for chaos-capture.sh and the K2 and K5 rules in gen-pad-rules.py.
# Everything runs against a temp inbox and state dir with a fake dialog and a fake
# notifier: no real dialog opens, no notification shows, the real _inbox.md is
# never read or written. The one real-UI check (focus, a real dialog) is by hand.
# Run: chaos-capture.test.sh

set -u
HERE="$(cd "$(dirname "$0")" && pwd -P)"
SCRIPT="$HERE/chaos-capture.sh"
GEN="$HERE/../../../config/karabiner/gen-pad-rules.py"
DRAIN="$HOME/code/chaos/.claude/skills/slurp/drain.sh"

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); echo "  ✓ $1"; }
bad() { FAIL=$((FAIL + 1)); echo "  ✗ $1"; }

if [ ! -x "$SCRIPT" ]; then
  echo "✗ $SCRIPT missing or not executable"
  exit 1
fi

assert_contains() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 (wanted '$3' in: $2)" ;; esac; }
assert_not_contains() { case "$2" in *"$3"*) bad "$1 (did not want '$3' in: $2)" ;; *) ok "$1" ;; esac; }
assert_eq() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got '$2', wanted '$3')"; fi; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/capture-test.XXXXXX")"
cleanup() {
  for f in "$TMP"/*/state/chaos-capture.pid; do
    [ -f "$f" ] && /bin/kill "$(cut -d'|' -f1 "$f")" 2>/dev/null
  done
  rm -rf "$TMP"
}
trap cleanup EXIT

TODAY="$(TZ=America/Toronto date +%Y-%m-%d)"

# Fake dialog. FAKE_ASK_OUT is what the user "typed"; FAKE_ASK_SLEEP keeps it open.
FAKEBIN="$TMP/bin"
mkdir -p "$FAKEBIN"
cat >"$FAKEBIN/ask" <<'EOF'
#!/bin/bash
echo "$*" >>"$FAKE_ASK_CALLS"
echo "$$" >>"$FAKE_ASK_CALLS.pids"
[ -n "${FAKE_ASK_PRINT_FIRST:-}" ] && printf '%s' "${FAKE_ASK_OUT:-}"
if [ -n "${FAKE_ASK_SLEEP:-}" ]; then
  trap 'kill $! 2>/dev/null; exit 143' TERM
  sleep "$FAKE_ASK_SLEEP" &
  wait $!
fi
[ -n "${FAKE_ASK_ERR:-}" ] && echo "$FAKE_ASK_ERR" >&2
[ -z "${FAKE_ASK_PRINT_FIRST:-}" ] && printf '%s' "${FAKE_ASK_OUT:-}"
exit "${FAKE_ASK_RC:-0}"
EOF
cat >"$FAKEBIN/notify" <<'EOF'
#!/bin/bash
echo "$1|$2|$3" >>"$FAKE_NOTES"
EOF
chmod +x "$FAKEBIN/ask" "$FAKEBIN/notify"

new_env() { # name → E_STATE E_INBOX E_NOTES E_ASKCALLS
  E="$TMP/$1"
  mkdir -p "$E"
  E_STATE="$E/state"
  E_INBOX="$E/_inbox.md"
  E_NOTES="$E/notes"
  E_ASKCALLS="$E/ask-calls"
  : >"$E_NOTES"
  : >"$E_ASKCALLS"
}

cap() { # script args → OUT, RC
  OUT="$(CHAOS_CAPTURE_STATE="$E_STATE" CHAOS_CAPTURE_INBOX="$E_INBOX" CHAOS_CAPTURE_NOTIFY="$FAKEBIN/notify" \
    CHAOS_CAPTURE_ASK="$FAKEBIN/ask" FAKE_NOTES="$E_NOTES" FAKE_ASK_CALLS="$E_ASKCALLS" \
    FAKE_ASK_OUT="${FAKE_ASK_OUT:-}" FAKE_ASK_SLEEP="${FAKE_ASK_SLEEP:-}" FAKE_ASK_RC="${FAKE_ASK_RC:-0}" FAKE_ASK_ERR="${FAKE_ASK_ERR:-}" \
    FAKE_ASK_PRINT_FIRST="${FAKE_ASK_PRINT_FIRST:-}" CHAOS_CAPTURE_NOW="${CHAOS_CAPTURE_NOW:-}" CHAOS_CAPTURE_SPAWN_PAUSE="${CHAOS_CAPTURE_SPAWN_PAUSE:-}" \
    "$SCRIPT" "$@" 2>&1)"
  RC=$?
}

# What Karabiner does: /bin/sh -c under env -i, no TZ, no locale.
run_bare() {
  env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin HOME="$HOME" \
    CHAOS_CAPTURE_STATE="$E_STATE" CHAOS_CAPTURE_INBOX="$E_INBOX" CHAOS_CAPTURE_NOTIFY="$FAKEBIN/notify" \
    CHAOS_CAPTURE_ASK="$FAKEBIN/ask" FAKE_NOTES="$E_NOTES" FAKE_ASK_CALLS="$E_ASKCALLS" \
    FAKE_ASK_OUT="${FAKE_ASK_OUT:-}" FAKE_ASK_SLEEP="${FAKE_ASK_SLEEP:-}" \
    FAKE_ASK_PRINT_FIRST="${FAKE_ASK_PRINT_FIRST:-}" CHAOS_CAPTURE_SPAWN_PAUSE="${CHAOS_CAPTURE_SPAWN_PAUSE:-}" \
    /bin/sh -c "\"$SCRIPT\" $*"
}

wait_for() { # seconds, shell condition
  local n=$(($1 * 10))
  while [ "$n" -gt 0 ]; do
    eval "$2" && return 0
    sleep 0.1
    n=$((n - 1))
  done
  return 1
}

last_text() { tail -1 "$E_INBOX" | sed 's/^- [0-9][0-9]:[0-9][0-9] //'; }
count_lines() { grep -c '^- [0-9][0-9]:[0-9][0-9] ' "$E_INBOX" 2>/dev/null; }
count_today() { grep -c "^## $TODAY\$" "$E_INBOX" 2>/dev/null; }
notes() { cat "$E_NOTES"; }
log_text() { cat "$E_STATE/chaos-capture.log" 2>/dev/null; }
temp_files() { ls "$E_STATE" 2>/dev/null | grep -c 'chaos-capture\.\(out\|err\)'; }
pid_field() { cut -d'|' -f"$1" "$E_STATE/chaos-capture.pid" 2>/dev/null; }
live_dialogs() { local n=0 p; for p in $(cat "$E_ASKCALLS.pids" 2>/dev/null); do kill -0 "$p" 2>/dev/null && n=$((n + 1)); done; echo "$n"; }
# Toronto-local epochs at fixed instants, so times and headings are checked at hours
# the suite does not happen to run in (and a stray read of the real clock shows).
epoch() { TZ=America/Toronto date -j -f '%Y-%m-%d %H:%M:%S' "$1" +%s; }
EP_1507="$(epoch '2026-06-15 15:07:30')"
EP_2359="$(epoch '2026-06-15 23:59:59')"
EP_0005="$(epoch '2026-06-16 00:05:30')"

echo "flags"
new_env flags
cap --bogus
assert_eq "unknown flag exits 2" "$RC" "2"
cap --text
assert_eq "--text without a value exits 2" "$RC" "2"
cap --print-dialog-script
assert_eq "--print-dialog-script exits 0" "$RC" "0"
printf '%s\n' "$OUT" | awk -v d="$TMP" 'BEGIN{n=0} /^---$/{n++; next} {print > (d "/s" n ".applescript")}'
for n in 0 1; do
  if /usr/bin/osacompile -o "$TMP/x$n.scpt" "$TMP/s$n.applescript" 2>"$TMP/osacompile.err"; then ok "embedded AppleScript $n compiles"; else bad "embedded AppleScript $n does not compile: $(cat "$TMP/osacompile.err")"; fi
done

echo "dry run"
new_env dry
cap --dry-run --text "hello"
assert_contains "dry run says what it would write" "$OUT" "would append"
assert_eq "dry run wrote no inbox" "$([ -e "$E_INBOX" ] && echo yes || echo no)" "no"
assert_eq "dry run notified nothing" "$(notes)" ""
cap --dry-run
assert_contains "dry run without text names the dialog" "$OUT" "would open the capture dialog"
assert_eq "dry run without text never opened the dialog" "$(cat "$E_ASKCALLS")" ""

echo "format"
new_env fmt
cap --text "first"
assert_eq "capture exits 0" "$RC" "0"
assert_contains "a fresh inbox gets the title" "$(head -1 "$E_INBOX")" "# Inbox"
assert_eq "one heading for today" "$(count_today)" "1"
assert_eq "line format is '- HH:MM text'" "$(grep -c "^- [0-9][0-9]:[0-9][0-9] first\$" "$E_INBOX")" "1"
cap --text "second"
assert_eq "still one heading after a second capture" "$(count_today)" "1"
assert_eq "two lines, in order" "$(grep '^- ' "$E_INBOX" | sed 's/^- [0-9:]* //' | tr '\n' ',')" "first,second,"
assert_contains "the success notification carries the text" "$(notes)" "✓|Captured "
assert_contains "the notification body is the text" "$(notes)" "|second"
assert_contains "a success is logged with its time" "$(log_text)" "✓ Captured "

new_env golden
printf '# Inbox\n' >"$E_INBOX"
CHAOS_CAPTURE_NOW="$EP_1507" cap --text "afternoon"
assert_eq "a new day appends exactly: blank line, heading, line" "$(cat "$E_INBOX"; echo x)" "$(printf '# Inbox\n\n## 2026-06-15\n- 15:07 afternoon\n'; echo x)"
assert_contains "the notification carries the same time" "$(notes)" "✓|Captured 15:07|afternoon"
CHAOS_CAPTURE_NOW="$EP_2359" cap --text "late"
CHAOS_CAPTURE_NOW="$EP_0005" cap --text "after midnight"
assert_eq "23:59 stays under its day; 00:05 opens the next" "$(cat "$E_INBOX"; echo x)" "$(printf '# Inbox\n\n## 2026-06-15\n- 15:07 afternoon\n- 23:59 late\n\n## 2026-06-16\n- 00:05 after midnight\n'; echo x)"
assert_contains "the midnight notification says 00:05" "$(notes)" "✓|Captured 00:05|after midnight"

new_env existing
printf -- '---\ntype: working-memory\n---\n\n# Inbox\n\n(Empty — say something.)\n\n## 2026-06-06\n- 20:30 older one\n' >"$E_INBOX"
before="$(cat "$E_INBOX")"
cap --text "today one"
assert_contains "older sections are untouched" "$(cat "$E_INBOX")" "$before"
assert_eq "today's heading is added after them" "$(grep '^## ' "$E_INBOX" | tr '\n' ',')" "## 2026-06-06,## $TODAY,"
assert_eq "the placeholder stays" "$(grep -c 'Empty — say something' "$E_INBOX")" "1"

new_env sameday
printf '# Inbox\n\n## %s\n- 08:00 earlier today\n' "$TODAY" >"$E_INBOX"
cap --text "later"
assert_eq "an existing heading for today is reused" "$(count_today)" "1"
assert_eq "the new line follows the old one" "$(tail -2 "$E_INBOX" | sed 's/^- [0-9:]* //' | tr '\n' ',')" "earlier today,later,"

new_env lastheading
printf '# Inbox\n\n## 2026-06-15\n- 08:00 this morning\n\n## 2026-06-06\n- 20:30 a late voice note\n' >"$E_INBOX"
CHAOS_CAPTURE_NOW="$EP_1507" cap --text "new pad line"
assert_eq "a heading that is not the last is not reused" "$(grep '^## ' "$E_INBOX" | tr '\n' ',')" "## 2026-06-15,## 2026-06-06,## 2026-06-15,"
assert_eq "the line sits under the new last heading, earlier sections untouched" "$(awk '/^## /{h=$0; next} /^- /{print h "@" $0}' "$E_INBOX" | tr '\n' ',')" "## 2026-06-15@- 08:00 this morning,## 2026-06-06@- 20:30 a late voice note,## 2026-06-15@- 15:07 new pad line,"

new_env decoy
printf '# Inbox\n\n## 2026-06-06\n- 09:00 see ## 2026-06-15 for notes\n- 10:00 ## 2026-06-15\n' >"$E_INBOX"
CHAOS_CAPTURE_NOW="$EP_1507" cap --text "real"
assert_eq "a date inside a bullet is not a heading" "$(grep '^## ' "$E_INBOX" | tr '\n' ',')" "## 2026-06-06,## 2026-06-15,"
assert_eq "the real line went under the real heading" "$(awk '/^## /{h=$0; next} /real$/{print h}' "$E_INBOX")" "## 2026-06-15"

new_env nonl
printf '# Inbox\n\n## 2026-06-06\n- 20:30 no newline at the end' >"$E_INBOX"
cap --text "after"
assert_eq "an unterminated last line is left intact" "$(grep -c '^- 20:30 no newline at the end$' "$E_INBOX")" "1"
assert_eq "the new heading starts its own line" "$(grep -c "^## $TODAY\$" "$E_INBOX")" "1"

new_env nonl2
printf '# Inbox\n\n## %s\n- 08:00 no newline today' "$TODAY" >"$E_INBOX"
cap --text "after that"
assert_eq "same-day: the unterminated line is intact" "$(grep -c '^- 08:00 no newline today$' "$E_INBOX")" "1"
assert_eq "same-day: the new line is its own line" "$(grep -c '^- [0-9][0-9]:[0-9][0-9] after that$' "$E_INBOX")" "1"
assert_eq "same-day: still one heading" "$(count_today)" "1"

echo "text fidelity"
new_env fidelity
touch_marker="$TMP/PWNED"
check_text() { # name text [expected]
  local want="${3-$2}"
  cap --text "$2"
  assert_eq "$1 round-trips" "$(last_text)" "$want"
}
check_text "printf specifiers" '100% %s %d %n \\ \n'
check_text "shell metacharacters" "\$(touch $touch_marker) \`touch $touch_marker\` ; & | > < * ? ~"
check_text "a leading dash" '-n -e --text'
check_text "a fake heading inside the text" "## $TODAY"
check_text "a fake heading with prose around it" "see ## $TODAY for notes"
check_text "quotes" "\"double\" 'single'"
check_text "unicode and emoji" 'é ✓ 日本 🙂'
long="$(printf 'word%.0s ' $(seq 1 500))"
check_text "a 2500-char line" "$long" "${long% }"
assert_eq "no command in the text ran" "$([ -e "$touch_marker" ] && echo ran || echo clean)" "clean"
assert_eq "no fake heading was created" "$(count_today)" "1"
before_n="$(count_lines)"
cap --text "$(printf 'a\r\nb\tc\001d')"
assert_eq "CR, LF and tab become spaces, control bytes vanish" "$(last_text)" "a  b cd"
assert_eq "it is exactly one new line" "$(($(count_lines) - before_n))" "1"
bad_bytes=""
for n in 1 2 3 4 5 6 7 8 11 12 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 127; do
  cap --text "$(printf "a\\$(printf '%03o' "$n")b")"
  [ "$(last_text)" = "ab" ] || bad_bytes="$bad_bytes $n"
done
assert_eq "every C0 control byte and DEL is stripped" "$bad_bytes" ""
bad_bytes=""
for n in 9 10 13; do
  cap --text "$(printf "a\\$(printf '%03o' "$n")b")"
  [ "$(last_text)" = "a b" ] || bad_bytes="$bad_bytes $n"
done
assert_eq "tab, LF and CR each become one space" "$bad_bytes" ""
cap --text "   padded   "
assert_eq "edge whitespace is trimmed" "$(last_text)" "padded"
n="$(count_lines)"
cap --text "   "
assert_eq "whitespace-only writes nothing" "$(count_lines)" "$n"
cap --text ""
assert_eq "empty writes nothing" "$(count_lines)" "$n"
assert_eq "empty and whitespace notify nothing" "$(notes | grep -c -e '^✗' -e '^⚠')" "0"

echo "failures"
new_env nodir
E_INBOX="$TMP/does-not-exist/_inbox.md"
cap --text "keep me"
assert_eq "a missing folder exits 1" "$RC" "1"
assert_eq "a missing folder is not created" "$([ -d "$TMP/does-not-exist" ] && echo made || echo absent)" "absent"
assert_contains "a missing folder says ✗ Not saved" "$(notes)" "✗|Not saved"
assert_contains "the text survives in the log" "$(cat "$E_STATE/chaos-capture.log")" "keep me"
assert_contains "the failure headline is logged" "$(log_text)" "✗ Not saved"

new_env ro
printf '# Inbox\n' >"$E_INBOX"
chmod 444 "$E_INBOX"
cap --text "cannot write"
chmod 644 "$E_INBOX"
assert_eq "an unwritable inbox exits 1" "$RC" "1"
assert_contains "an unwritable inbox says ✗ Not saved" "$(notes)" "✗|Not saved"
assert_contains "that text survives in the log too" "$(cat "$E_STATE/chaos-capture.log")" "cannot write"
assert_eq "nothing reached the unwritable file" "$(count_lines)" "0"
assert_contains "that failure headline is logged too" "$(log_text)" "✗ Not saved"

echo "dialog path"
new_env dialog
FAKE_ASK_OUT="typed in the dialog" cap --foreground
assert_eq "the dialog text is captured" "$(last_text)" "typed in the dialog"
assert_eq "one success notification" "$(notes | grep -c '^✓')" "1"
assert_eq "the dialog got prompt, title and timeout" "$(cat "$E_ASKCALLS")" "one line to the inbox capture 300"
assert_eq "the pidfile is cleaned up" "$([ -e "$E_STATE/chaos-capture.pid" ] && echo left || echo gone)" "gone"
assert_eq "no temp files left behind" "$(temp_files)" "0"

new_env cancel
FAKE_ASK_OUT="" cap --foreground
assert_eq "Cancel exits 0" "$RC" "0"
assert_eq "Cancel writes nothing" "$([ -e "$E_INBOX" ] && echo wrote || echo nothing)" "nothing"
assert_eq "Cancel notifies nothing" "$(notes)" ""
assert_eq "Cancel leaves no temp files" "$(temp_files)" "0"

new_env failing
FAKE_ASK_RC=1 FAKE_ASK_ERR="boom: no window server" cap --foreground
assert_eq "a dialog error exits 1" "$RC" "1"
assert_contains "a dialog error says ✗" "$(notes)" "✗|The capture dialog failed"
assert_contains "the error reaches the log" "$(cat "$E_STATE/chaos-capture.log")" "boom: no window server"
assert_eq "a dialog error writes nothing" "$([ -e "$E_INBOX" ] && echo wrote || echo nothing)" "nothing"
assert_eq "a dialog error leaves no temp files" "$(temp_files)" "0"
assert_contains "the dialog failure headline is logged" "$(log_text)" "✗ The capture dialog failed"

echo "detached (the Karabiner way)"
new_env detached
s=$SECONDS
FAKE_ASK_SLEEP=3 FAKE_ASK_OUT="late text" run_bare >/dev/null 2>&1
took=$((SECONDS - s))
[ "$took" -le 1 ] && ok "the press returns at once while the dialog is open (${took}s)" || bad "the press blocked for ${took}s"
wait_for 2 '[ -e "$E_STATE/chaos-capture.pid" ]' && ok "the open dialog is tracked in the pidfile" || bad "no pidfile while the dialog was open"
wait_for 8 'grep -q "late text" "$E_INBOX" 2>/dev/null' && ok "the detached worker captured it when the dialog closed" || bad "the detached worker never wrote"

new_env bare
FAKE_ASK_OUT='é ✓ 日本 🙂 from a bare env' run_bare >/dev/null 2>&1
wait_for 5 'grep -q "bare env" "$E_INBOX" 2>/dev/null' && ok "a bare-env press writes" || bad "a bare-env press wrote nothing"
assert_eq "UTF-8 survives a bare env with no locale" "$(last_text)" "é ✓ 日本 🙂 from a bare env"
assert_eq "the heading is today's local date with no TZ set" "$(grep '^## ' "$E_INBOX")" "## $TODAY"
bare_hm="$(grep '^- ' "$E_INBOX" | sed 's/^- \([0-9][0-9]:[0-9][0-9]\) .*/\1/')"
now_hm="$(TZ=America/Toronto date +%H:%M)"
prev_hm="$(TZ=America/Toronto date -v-1M +%H:%M)"
case "$bare_hm" in "$now_hm"|"$prev_hm") ok "the time is Toronto local with no TZ set" ;; *) bad "the time is '$bare_hm', Toronto is '$now_hm'" ;; esac

new_env replace
FAKE_ASK_SLEEP=30 FAKE_ASK_OUT="first press" run_bare >/dev/null 2>&1
wait_for 3 '[ -e "$E_STATE/chaos-capture.pid" ]' || bad "first dialog never opened"
first_pid="$(cut -d'|' -f1 "$E_STATE/chaos-capture.pid" 2>/dev/null)"
FAKE_ASK_SLEEP="" FAKE_ASK_OUT="second press" run_bare >/dev/null 2>&1
wait_for 6 'grep -q "second press" "$E_INBOX" 2>/dev/null' && ok "the newer press captured" || bad "the newer press wrote nothing"
sleep 1
assert_eq "the replaced dialog was killed" "$(kill -0 "$first_pid" 2>/dev/null && echo alive || echo dead)" "dead"
assert_eq "exactly one line was written" "$(count_lines)" "1"
assert_eq "the replaced press never captured" "$(grep -c 'first press' "$E_INBOX")" "0"
assert_eq "exactly one success notification" "$(notes | grep -c '^✓')" "1"
assert_eq "the replaced press raised no failure notification" "$(notes | grep -c -e '^✗' -e '^⚠')" "0"
assert_eq "the replaced press leaves no temp files" "$(temp_files)" "0"
assert_contains "the log says it was superseded" "$(cat "$E_STATE/chaos-capture.log")" "superseded by a newer press"
assert_not_contains "the replaced press is not logged as a failure" "$(cat "$E_STATE/chaos-capture.log")" "dialog failed"

new_env stale
sleep 60 &
victim=$!
mkdir -p "$E_STATE"
echo "99999|$victim|Mon Jan  1 00:00:00 2001" >"$E_STATE/chaos-capture.pid"
FAKE_ASK_OUT="after stale" run_bare >/dev/null 2>&1
wait_for 5 'grep -q "after stale" "$E_INBOX" 2>/dev/null' || bad "stale-pidfile press wrote nothing"
assert_eq "an unrelated process with a reused pid is left alone" "$(kill -0 "$victim" 2>/dev/null && echo alive || echo dead)" "alive"
kill "$victim" 2>/dev/null
wait "$victim" 2>/dev/null

new_env finished
mkdir -p "$E_STATE"
( FAKE_ASK_SLEEP=1 FAKE_ASK_OUT="typed just before a new press" cap --foreground ) &
sleep 0.4
echo "424242||" >"$E_STATE/chaos-capture.pid"
wait
assert_eq "a dialog that finished is saved even after a newer claim" "$(grep -c 'typed just before a new press' "$E_INBOX" 2>/dev/null)" "1"
assert_contains "the newer claim is left in place" "$(cat "$E_STATE/chaos-capture.pid")" "424242"

new_env early
FAKE_ASK_SLEEP=30 FAKE_ASK_OUT="never typed" CHAOS_CAPTURE_SPAWN_PAUSE=1.5 run_bare >/dev/null 2>&1
wait_for 3 '[ -s "$E_STATE/chaos-capture.pid" ]' || bad "first press never claimed the pidfile"
assert_eq "the first press holds only a claim while its dialog is starting" "$(pid_field 2)" ""
FAKE_ASK_SLEEP=30 FAKE_ASK_OUT="second" CHAOS_CAPTURE_SPAWN_PAUSE="" run_bare >/dev/null 2>&1
wait_for 3 '[ -n "$(pid_field 2)" ]' || bad "second press never opened its dialog"
second_worker="$(pid_field 1)"
second_dialog="$(pid_field 2)"
sleep 2
assert_eq "both presses opened a dialog" "$(wc -l <"$E_ASKCALLS.pids" | tr -d ' ')" "2"
assert_eq "only the newer press's dialog is still open" "$(live_dialogs)" "1"
assert_eq "the survivor is the newer press's dialog" "$(kill -0 "$second_dialog" 2>/dev/null && echo alive || echo dead)" "alive"
assert_eq "the pidfile still names the newer press" "$(pid_field 1)" "$second_worker"
assert_contains "the log says it was superseded before opening" "$(log_text)" "superseded before the dialog opened"
assert_eq "nothing was written" "$([ -e "$E_INBOX" ] && echo wrote || echo nothing)" "nothing"
assert_eq "no failure was raised" "$(notes | grep -c -e '^✗' -e '^⚠')" "0"
assert_eq "only the live dialog's two temp files remain" "$(temp_files)" "2"
kill "$second_worker" "$second_dialog" 2>/dev/null
wait 2>/dev/null

new_env salvage
( FAKE_ASK_PRINT_FIRST=1 FAKE_ASK_SLEEP=30 FAKE_ASK_OUT="typed then killed" cap --foreground ) &
salvage_bg=$!
wait_for 3 '[ -n "$(pid_field 2)" ]' || bad "salvage: the first dialog never opened"
FAKE_ASK_PRINT_FIRST="" FAKE_ASK_SLEEP="" FAKE_ASK_OUT="second" run_bare >/dev/null 2>&1
wait "$salvage_bg"
wait_for 5 'grep -q "second$" "$E_INBOX" 2>/dev/null' || bad "salvage: the newer press wrote nothing"
assert_eq "a line typed before a newer press killed the dialog is kept" "$(grep -c 'typed then killed$' "$E_INBOX")" "1"
assert_eq "the newer press's line is kept too" "$(grep -c 'second$' "$E_INBOX")" "1"
assert_eq "salvage raised no failure notification" "$(notes | grep -c -e '^✗' -e '^⚠')" "0"
assert_contains "the log says what it salvaged" "$(log_text)" "saving what it printed"
assert_eq "salvage leaves no temp files" "$(temp_files)" "0"

echo "interop with /slurp (drain.sh)"
if [ -x "$DRAIN" ] || [ -f "$DRAIN" ]; then
  if command -v jq >/dev/null 2>&1 || [ -x /opt/homebrew/bin/jq ]; then
    now="$(date +%s)"
    H="$TMP/home"
    mkdir -p "$H/code/chaos" "$H/Documents/superwhisper/recordings/$now"
    printf '{"modeName":"Capture","result":"voice line"}' >"$H/Documents/superwhisper/recordings/$now/meta.json"
    new_env interop
    E_INBOX="$H/code/chaos/_inbox.md"
    cap --text "pad line one"
    HOME="$H" TZ=America/Toronto bash "$DRAIN" >/dev/null 2>&1
    cap --text "pad line two"
    assert_eq "one heading for today across both writers" "$(grep -c "^## $TODAY\$" "$E_INBOX")" "1"
    assert_eq "all three lines landed under it, in order" "$(grep '^- ' "$E_INBOX" | sed 's/^- [0-9:]* //' | tr '\n' ',')" "pad line one,voice line,pad line two,"

    yest=$((now - 86400))
    yday="$(TZ=America/Toronto date -r "$yest" +%F)"
    H2="$TMP/home2"
    mkdir -p "$H2/code/chaos" "$H2/Documents/superwhisper/recordings/$yest"
    printf '{"modeName":"Capture","result":"evening voice"}' >"$H2/Documents/superwhisper/recordings/$yest/meta.json"
    new_env interop2
    E_INBOX="$H2/code/chaos/_inbox.md"
    cap --text "pad one"
    HOME="$H2" TZ=America/Toronto bash "$DRAIN" >/dev/null 2>&1
    cap --text "pad two"
    assert_eq "a late drain of yesterday's note does not strand the next pad line" "$(awk '/^## /{h=$0; next} /^- /{sub(/^- [0-9:]* /,""); print h "@" $0}' "$E_INBOX" | tr '\n' ',')" "## $TODAY@pad one,## $yday@evening voice,## $TODAY@pad two,"
  else
    echo "  ⚠ jq not installed: drain.sh interop skipped"
  fi
else
  echo "  ⚠ $DRAIN not found: drain.sh interop skipped"
fi

echo "K2 rule"
rules="$(python3 "$GEN" --print)"
k2="$(printf '%s' "$rules" | python3 -c '
import json, os, sys
rules = json.load(sys.stdin)
r = [x for x in rules if "K2" in x["description"]]
assert len(r) == 1, "want exactly one K2 rule"
ms = r[0]["manipulators"]
mods = sorted(m["from"]["modifiers"]["mandatory"][0] for m in ms)
print(len(ms), m := ms[0]["from"]["key_code"], ",".join(mods))
print(all("any" in m["from"]["modifiers"]["optional"] for m in ms))
print(all(m["to"] == [{"shell_command": os.path.expanduser("~/.bin/chaos-capture.sh")}] for m in ms))
print(all(m["conditions"] == [{"type": "device_if", "identifiers": [{"vendor_id": 21862, "product_id": 8}]}] for m in ms))
print(any("vk_none" in json.dumps(m) for x in r for m in x["manipulators"]))
k5 = [x for x in rules if "K5" in x["description"]]
assert len(k5) == 1, "want exactly one K5 rule"
a, b = k5[0]["manipulators"]
print(a["to"] == [{"key_code": "return_or_enter", "repeat": False}] and a["from"]["modifiers"]["optional"] == ["caps_lock"])
print(b["to"] == [{"key_code": "vk_none"}] and b["from"]["modifiers"]["optional"] == ["any"])
print(all(m["from"]["key_code"] == "d" and m["from"]["modifiers"]["mandatory"] == ["left_command"] for m in (a, b)))
print(all(m["conditions"] == [{"type": "device_if", "identifiers": [{"vendor_id": 21862, "product_id": 8}]}] for m in (a, b)))
def only(k):
    r = [x for x in rules if k in x["description"]]
    assert len(r) == 1 and len(r[0]["manipulators"]) == 1, "want exactly one " + k + " manipulator"
    return r[0]["manipulators"][0]["to"]
print(only("K3") == [{"key_code": "slash", "modifiers": ["left_option"], "repeat": False}])
print(only("K4") == [{"key_code": "escape", "modifiers": ["left_option"], "repeat": False}])
')"
assert_eq "K2 covers both firmware layers of v" "$(echo "$k2" | sed -n 1p)" "2 v left_command,left_control"
assert_eq "K2 froms carry optional any" "$(echo "$k2" | sed -n 2p)" "True"
assert_eq "K2 runs ~/.bin/chaos-capture.sh and nothing else" "$(echo "$k2" | sed -n 3p)" "True"
assert_eq "K2 is scoped to the pad" "$(echo "$k2" | sed -n 4p)" "True"
assert_eq "K2 is no swallow stub" "$(echo "$k2" | sed -n 5p)" "False"
assert_eq "K5 sends Return once per press (repeat false, not keypad Enter) under caps lock only, first" "$(echo "$k2" | sed -n 6p)" "True"
assert_eq "K5 then swallows any other modifier with vk_none, second" "$(echo "$k2" | sed -n 7p)" "True"
assert_eq "K5 matches the stock Cmd+D and nothing else" "$(echo "$k2" | sed -n 8p)" "True"
assert_eq "K5 is scoped to the pad" "$(echo "$k2" | sed -n 9p)" "True"
assert_eq "K3 sends Opt+/ once per press (repeat false, a held key would flip dictation)" "$(echo "$k2" | sed -n 10p)" "True"
assert_eq "K4 sends Opt+Esc once per press (repeat false)" "$(echo "$k2" | sed -n 11p)" "True"
assert_eq "the script the rule names exists and is executable" "$([ -x "$HOME/.bin/chaos-capture.sh" ] && echo yes || echo no)" "yes"
if [ -x "/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli" ]; then
  lint="$(python3 "$GEN" --lint 2>&1)"
  assert_contains "karabiner_cli lints the rules" "$lint" ": ok"
fi

echo "gen-pad-rules write path"
G="$TMP/genhome"
mkdir -p "$G/.config/karabiner"
cat >"$G/.config/karabiner/karabiner.json" <<'JSON'
{"profiles":[{"name":"Default","selected":true,"complex_modifications":{"rules":[{"description":"Mine: caps to escape","manipulators":[]},{"description":"ZXW pad K2: an old stub","manipulators":[]}]},"devices":[{"identifiers":{"vendor_id":1,"product_id":2},"ignore":true}]}]}
JSON
gen_out="$(HOME="$G" python3 "$GEN" 2>&1)"
assert_contains "the first run writes" "$gen_out" "wrote 5 rules"
gen_state="$(python3 - "$G/.config/karabiner/karabiner.json" <<'PY'
import json, sys
p = json.load(open(sys.argv[1]))["profiles"][0]
rules = [r["description"] for r in p["complex_modifications"]["rules"]]
devs = {(d["identifiers"].get("vendor_id"), d["identifiers"].get("is_pointing_device", False)): d["ignore"] for d in p["devices"]}
print(len(rules), sum("ZXW pad" in r for r in rules), "Mine: caps to escape" in rules, sum("an old stub" in r for r in rules))
print(devs.get((21862, False)), devs.get((21862, True)), devs.get((1, False)))
mk = [d for d in p["devices"] if d["identifiers"] == {"is_keyboard": True, "product_id": 801, "vendor_id": 76}]
print(len(mk), mk[0]["ignore"] if mk else None)
PY
)"
assert_eq "five pad rules, the user's own rule kept, the old stub gone" "$(echo "$gen_state" | sed -n 1p)" "6 5 True 0"
assert_eq "both pad devices are un-ignored and an unrelated device is untouched" "$(echo "$gen_state" | sed -n 2p)" "False False True"
assert_eq "the Magic Keyboard is ignored once, so macOS keeps its caps lock -> Esc" "$(echo "$gen_state" | sed -n 3p)" "1 True"
assert_eq "a backup was taken" "$(ls "$G/.config/karabiner" | grep -c '\.bak-')" "1"
gen_out="$(HOME="$G" python3 "$GEN" 2>&1)"
assert_contains "the second run changes nothing" "$gen_out" "unchanged"
assert_eq "and takes no second backup" "$(ls "$G/.config/karabiner" | grep -c '\.bak-')" "1"

echo
if [ "$FAIL" = 0 ]; then
  echo "✓ $PASS checks passed"
else
  echo "✗ $FAIL failed, $PASS passed"
  exit 1
fi
