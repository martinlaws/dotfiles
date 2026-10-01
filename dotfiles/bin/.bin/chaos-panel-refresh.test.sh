#!/bin/bash
# Tests for chaos-panel-refresh.sh and the K1 rule in gen-pad-rules.py.
# Everything runs against a temp cache and state dir with a fake launchctl and a
# fake notifier: no real agent is kicked, no notification is shown, the real
# panel cache is never read or written. Run: chaos-panel-refresh.test.sh

set -u
HERE="$(cd "$(dirname "$0")" && pwd -P)"
SCRIPT="$HERE/chaos-panel-refresh.sh"
GEN="$HERE/../../../config/karabiner/gen-pad-rules.py"

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); echo "  ✓ $1"; }
bad() { FAIL=$((FAIL + 1)); echo "  ✗ $1"; }

if [ ! -x "$SCRIPT" ]; then
  echo "✗ $SCRIPT missing or not executable"
  exit 1
fi

assert_contains() { # name haystack needle
  case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 (wanted '$3' in: $2)" ;; esac
}
assert_not_contains() {
  case "$2" in *"$3"*) bad "$1 (did not want '$3' in: $2)" ;; *) ok "$1" ;; esac
}
assert_eq() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got '$2', wanted '$3')"; fi; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/panel-refresh-test.XXXXXX")"
cleanup() {
  for f in "$TMP"/state*/chaos-panel-refresh.pid; do
    [ -f "$f" ] && /bin/kill "$(cut -d'|' -f1 "$f")" 2>/dev/null
  done
  rm -rf "$TMP"
}
trap cleanup EXIT

utc_now() { date -u -v"${1:-+0S}" '+%Y-%m-%dT%H:%M:%S.000Z'; }
local_now() { # offset spec → 2026-09-30T13:06:35-04:00
  local t
  t="$(TZ=America/Toronto date -v"${1:-+0S}" '+%Y-%m-%dT%H:%M:%S%z')"
  echo "${t%??}:${t: -2}"
}

# Fake launchctl. Scenario comes from FAKE_* env vars set per run.
FAKEBIN="$TMP/bin"
mkdir -p "$FAKEBIN"
cat >"$FAKEBIN/launchctl" <<'EOF'
#!/bin/bash
echo "$*" >>"$FAKE_CALLS"
case "$*" in
  *chaos-calendar*)
    [ "${FAKE_FAIL_CAL:-0}" != 0 ] && exit "$FAKE_FAIL_CAL"
    if [ "${FAKE_CAL:-land}" = land ]; then
      now="$(date -u '+%Y-%m-%dT%H:%M:%S.000Z')"
      printf '{"lastRefresh":"%s","events":[]}' "$now" >"$FAKE_CACHE/calendar.json"
      case "${FAKE_POLL:-ahead}" in
        ahead)
          t="$(TZ=America/Toronto date -v+10S '+%Y-%m-%dT%H:%M:%S%z')"
          at="${t%??}:${t: -2}"
          printf '{"at":"%s","status":"%s","served":"%s","held":"%s","unpainted":%s,"error":null,"failures":0}' "$at" "${FAKE_STATUS:-200}" "${FAKE_SERVED:-etag-new}" "${FAKE_HELD:-etag-old}" "${FAKE_UNPAINTED:-0}" >"$FAKE_CACHE/frame-heartbeat.json"
          ;;
      esac
    fi
    ;;
  *chaos-weather*)
    [ "${FAKE_FAIL_WX:-0}" != 0 ] && exit "$FAKE_FAIL_WX"
    ;;
esac
exit 0
EOF
chmod +x "$FAKEBIN/launchctl"
cat >"$FAKEBIN/notify" <<'EOF'
#!/bin/bash
echo "$1" >>"$FAKE_NOTIFY"
EOF
chmod +x "$FAKEBIN/notify"

N=0
# setup → fresh cache/state; heartbeat is stale and served=etag-old.
setup() {
  N=$((N + 1))
  CACHE="$TMP/cache$N"
  STATE="$TMP/state$N"
  mkdir -p "$CACHE" "$STATE"
  printf '{"lastRefresh":"%s","events":[]}' "$(utc_now -20M)" >"$CACHE/calendar.json"
  printf '{"at":"%s","status":200,"served":"etag-old","error":null,"failures":0}' "$(local_now -10M)" >"$CACHE/frame-heartbeat.json"
  export FAKE_CALLS="$TMP/calls$N" FAKE_NOTIFY="$TMP/notify$N" FAKE_CACHE="$CACHE"
  : >"$FAKE_CALLS"
  : >"$FAKE_NOTIFY"
  unset FAKE_CAL FAKE_POLL FAKE_STATUS FAKE_SERVED FAKE_HELD FAKE_UNPAINTED FAKE_FAIL_CAL FAKE_FAIL_WX
}

run() { # extra env assignments are exported by the caller; args pass through
  CHAOS_PANEL_CACHE="$CACHE" CHAOS_PANEL_STATE="$STATE" \
    CHAOS_PANEL_LAUNCHCTL="$FAKEBIN/launchctl" CHAOS_PANEL_NOTIFY="$FAKEBIN/notify" \
    CHAOS_PANEL_HOST="${HOST_OVERRIDE:-studio}" CHAOS_PANEL_TICK=1 \
    CHAOS_PANEL_REFRESH_WAIT="${WAIT_CAL:-5}" CHAOS_PANEL_POLL_WAIT="${WAIT_POLL:-5}" \
    /bin/bash "$SCRIPT" "$@" 2>&1
}

run_bare() { # the environment Karabiner gives a shell_command: nothing but PATH
  env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin HOME="$HOME" FAKE_CALLS="$FAKE_CALLS" FAKE_NOTIFY="$FAKE_NOTIFY" FAKE_CACHE="$CACHE" \
    FAKE_CAL="${FAKE_CAL:-land}" FAKE_SERVED="${FAKE_SERVED:-etag-new}" \
    CHAOS_PANEL_CACHE="$CACHE" CHAOS_PANEL_STATE="$STATE" CHAOS_PANEL_LAUNCHCTL="$FAKEBIN/launchctl" CHAOS_PANEL_NOTIFY="$FAKEBIN/notify" \
    CHAOS_PANEL_HOST=studio CHAOS_PANEL_TICK=1 CHAOS_PANEL_REFRESH_WAIT="${WAIT_CAL:-5}" CHAOS_PANEL_POLL_WAIT="${WAIT_POLL:-5}" \
    /bin/sh -c "$SCRIPT $*" 2>&1 </dev/null
}

echo "host gate and flags"
setup
out="$(HOST_OVERRIDE=macbook run --foreground)"; rc=$?
assert_eq "wrong host exits 1" "$rc" 1
assert_contains "wrong host says so, no glass claim" "$out" "✗ Not the Studio ('macbook'"
assert_eq "wrong host kicks nothing" "$(wc -c <"$FAKE_CALLS" | tr -d ' ')" 0
assert_contains "wrong host still notifies" "$(cat "$FAKE_NOTIFY")" "✗ Not the Studio"

setup
out="$(run --bogus)"; rc=$?
assert_eq "unknown flag exits 2" "$rc" 2
assert_contains "unknown flag prints usage" "$out" "usage:"

echo "dry run"
setup
out="$(run --dry-run)"; rc=$?
assert_eq "dry run exits 0" "$rc" 0
assert_contains "dry run names both agents" "$out" "ca.mlaws.chaos-calendar and gui/$(id -u)/ca.mlaws.chaos-weather"
assert_eq "dry run kicks nothing" "$(wc -c <"$FAKE_CALLS" | tr -d ' ')" 0
assert_eq "dry run notifies nothing" "$(wc -c <"$FAKE_NOTIFY" | tr -d ' ')" 0

echo "verdicts (foreground)"
setup
out="$(FAKE_SERVED=etag-new run --foreground)"; rc=$?
assert_eq "new frame exits 0" "$rc" 0
assert_contains "new frame verdict" "$out" "✓ Calendar refreshed"
assert_contains "new frame says the glass has a new frame" "$out" "The glass has a new frame."
assert_contains "verdict is notified" "$(cat "$FAKE_NOTIFY")" "✓ Calendar refreshed"
assert_contains "kicks the calendar agent in this user's domain" "$(cat "$FAKE_CALLS")" "kickstart gui/$(id -u)/ca.mlaws.chaos-calendar"
assert_contains "kicks the weather agent" "$(cat "$FAKE_CALLS")" "kickstart gui/$(id -u)/ca.mlaws.chaos-weather"
assert_not_contains "never kickstart -k" "$(cat "$FAKE_CALLS")" " -k"
assert_contains "log carries the verdict" "$(cat "$STATE/chaos-panel-refresh.log")" "✓ Calendar refreshed"

setup
out="$(FAKE_STATUS=304 FAKE_SERVED=etag-old FAKE_HELD=etag-old run --foreground)"; rc=$?
assert_eq "unchanged exits 0" "$rc" 0
assert_contains "a 304 on the same frame says nothing new, honestly" "$out" "Nothing new to show: the glass is current."

setup
out="$(FAKE_STATUS=200 FAKE_SERVED=etag-old FAKE_HELD=etag-older run --foreground)"
assert_contains "a 200 on an unchanged frame says the glass was behind" "$out" "The glass was behind and has been sent the current frame."
assert_not_contains "a 200 is never 'nothing new'" "$out" "Nothing new to show"

setup
out="$(FAKE_STATUS=304 FAKE_SERVED=etag-new FAKE_HELD=etag-new run --foreground)"
assert_contains "a 304 on a different frame means an earlier poll delivered it" "$out" "The glass has a new frame."

echo "verdicts: the device, not just the Studio"
setup
out="$(FAKE_STATUS=200 FAKE_SERVED=etag-new FAKE_HELD=etag-stuck FAKE_UNPAINTED=3 run --foreground)"; rc=$?
assert_eq "a stuck device exits 0 (the refresh itself worked)" "$rc" 0
assert_contains "a stuck device is a warning" "$out" "⚠ Calendar refreshed"
assert_contains "a stuck device says it is not taking frames" "$out" "the glass isn't taking frames"
assert_contains "a stuck device names what it holds and for how long" "$out" "etag-stu for 3 polls"
assert_not_contains "a stuck device is never told it has a new frame" "$out" "new frame"
assert_not_contains "a stuck device is never called current" "$out" "is current"
assert_contains "the stuck warning is notified" "$(cat "$FAKE_NOTIFY")" "⚠ Calendar refreshed"

setup
out="$(FAKE_STATUS=200 FAKE_SERVED=etag-new FAKE_HELD=etag-stuck FAKE_UNPAINTED=2 run --foreground)"
assert_contains "unpainted 2 is still inside the bar (frame-liveness.sh: more than 2)" "$out" "The glass has a new frame."

setup
out="$(FAKE_STATUS=200 FAKE_SERVED=etag-new FAKE_HELD= FAKE_UNPAINTED=4 run --foreground)"
assert_contains "an empty held tag on a long run is a stuck device too" "$out" "isn't taking frames"

setup
out="$(FAKE_STATUS=304 FAKE_SERVED=etag-old FAKE_HELD=etag-old FAKE_UNPAINTED=9 run --foreground)"
assert_contains "a 304 is never read as stuck, whatever unpainted says" "$out" "Nothing new to show"

setup
printf '{"at":"%s","status":200,"served":"etag-old","held":"etag-x","unpainted":"many"}' "$(local_now -10M)" >"$CACHE/frame-heartbeat.json"
out="$(FAKE_STATUS=200 FAKE_SERVED=etag-new FAKE_UNPAINTED='"lots"' run --foreground)"; rc=$?
assert_eq "a non-numeric unpainted does not crash the verdict" "$rc" 0
assert_contains "a non-numeric unpainted reads as zero" "$out" "The glass has a new frame."

echo "verdicts: no heartbeat before the press"
setup
rm -f "$CACHE/frame-heartbeat.json"
out="$(FAKE_STATUS=304 FAKE_SERVED=etag-a FAKE_HELD=etag-a run --foreground)"
assert_contains "missing before-heartbeat + 304: current, honest about the unknown" "$out" "no earlier poll on record, so can't say whether it changed"
assert_not_contains "missing before-heartbeat + 304 never claims a new frame" "$out" "new frame"

setup
printf '{"at":"%s","status":503,"served":null,"held":"etag-a","error":"boom","failures":2}' "$(local_now -10M)" >"$CACHE/frame-heartbeat.json"
out="$(FAKE_STATUS=304 FAKE_SERVED=etag-a FAKE_HELD=etag-a run --foreground)"
assert_contains "a 503 before (served null) + 304 is treated as unknown" "$out" "can't say whether it changed"
assert_not_contains "a 503 before + 304 never claims a new frame" "$out" "new frame"

setup
rm -f "$CACHE/frame-heartbeat.json"
out="$(FAKE_STATUS=200 FAKE_SERVED=etag-a FAKE_HELD=etag-0 run --foreground)"
assert_contains "missing before-heartbeat + 200 is a real new frame" "$out" "The glass has a new frame."

setup
out="$(FAKE_CAL=none run --foreground)"; rc=$?
assert_eq "calendar never lands exits 1" "$rc" 1
assert_contains "calendar timeout is a warning" "$out" "⚠ Calendar didn't refresh within 5s"
assert_not_contains "no glass claim when calendar is stale" "$out" "glass"
assert_contains "warning is notified" "$(cat "$FAKE_NOTIFY")" "⚠"

setup
out="$(FAKE_POLL=stale WAIT_POLL=2 run --foreground)"; rc=$?
assert_eq "panel silent exits 0" "$rc" 0
assert_contains "panel silent is a warning" "$out" "⚠ Calendar refreshed"
assert_contains "panel silent names the tether" "$out" "hasn't asked since"
assert_not_contains "panel silent does not claim a repaint" "$out" "new frame"

setup
out="$(FAKE_STATUS=500 run --foreground)"; rc=$?
assert_eq "studio 500 exits 1" "$rc" 1
assert_contains "studio 500 is a failure" "$out" "✗ Calendar refreshed"
assert_contains "studio 500 names the status" "$out" "answered the panel with 500"

echo "launchctl failures"
setup
out="$(FAKE_FAIL_CAL=3 run --foreground)"; rc=$?
assert_eq "calendar kick failure exits 1" "$rc" 1
assert_contains "calendar kick failure names the launchctl exit" "$out" "launchctl exit 3"
assert_not_contains "weather not kicked after calendar fails" "$(cat "$FAKE_CALLS")" "chaos-weather"

setup
out="$(FAKE_FAIL_WX=5 run --foreground)"; rc=$?
assert_eq "weather kick failure still completes" "$rc" 0
assert_contains "weather kick failure is logged" "$(cat "$STATE/chaos-panel-refresh.log")" "weather refresher didn't start (launchctl exit 5)"
assert_contains "weather failure does not stop the verdict" "$out" "✓ Calendar refreshed"

echo "robustness"
setup
printf '{"at":"%s","status":200,"served":"etag-old","error":"boom","failures":3}' "$(local_now -10M)" >"$CACHE/frame-heartbeat.json"
out="$(FAKE_SERVED=etag-old run --foreground)"
assert_contains "heartbeat with a string error field is fine" "$out" "✓ Calendar refreshed"

setup
rm -f "$CACHE/frame-heartbeat.json"
out="$(FAKE_POLL=none WAIT_POLL=2 run --foreground)"
assert_contains "missing heartbeat is a warning, not a crash" "$out" "hasn't asked since ever"

setup
rm -f "$CACHE/calendar.json"
out="$(FAKE_CAL=none run --foreground)"
assert_contains "missing calendar.json reports unknown, no crash" "$out" "last good read unknown"

setup
printf '{"at":"%s","status":200,"served":"etag-old"}' "$(TZ=UTC date -u -v+10S '+%Y-%m-%dT%H:%M:%SZ')" >"$CACHE/frame-heartbeat.json"
out="$(FAKE_POLL=none run --foreground)"
assert_contains "a Z-suffixed heartbeat stamp parses" "$out" "✓ Calendar refreshed"

echo "poll slack and stale stamps"
setup
printf '{"at":"%s","status":200,"served":"etag-old","held":"etag-old","unpainted":0}' "$(local_now +3S)" >"$CACHE/frame-heartbeat.json"
out="$(FAKE_POLL=none WAIT_POLL=2 run --foreground)"
assert_contains "a poll only 3 s after the refresh landed is too early to count (slack is 5 s)" "$out" "hasn't asked since"
setup
printf '{"at":"%s","status":200,"served":"etag-old","held":"etag-old","unpainted":0}' "$(local_now +8S)" >"$CACHE/frame-heartbeat.json"
out="$(FAKE_POLL=none WAIT_POLL=2 run --foreground)"
assert_contains "a poll 8 s after the refresh landed counts" "$out" "✓ Calendar refreshed"

setup
printf '{"at":"%s","status":200,"served":"etag-old"}' "$(local_now -26H)" >"$CACHE/frame-heartbeat.json"
out="$(FAKE_POLL=none WAIT_POLL=2 run --foreground)"
assert_contains "a 26 h old heartbeat says how old" "$out" "(26h ago)"
setup
printf '{"at":"%s","status":200,"served":"etag-old"}' "$(local_now -50H)" >"$CACHE/frame-heartbeat.json"
out="$(FAKE_POLL=none WAIT_POLL=2 run --foreground)"
assert_contains "a 50 h old heartbeat counts in days" "$out" "(2d ago)"
setup
printf '{"at":"%s","status":200,"served":"etag-old"}' "$(local_now -10M)" >"$CACHE/frame-heartbeat.json"
out="$(FAKE_POLL=none WAIT_POLL=2 run --foreground)"
assert_not_contains "a 10 min old heartbeat stays a plain HH:MM" "$out" "ago)"
setup
printf '{"lastRefresh":"%s","events":[]}' "$(utc_now -50H)" >"$CACHE/calendar.json"
out="$(FAKE_CAL=none run --foreground)"
assert_contains "a 2-day-old last good read carries its age" "$out" "(2d ago)"

echo "detached mode (what Karabiner runs)"
setup
start="$(date +%s)"
out="$(FAKE_CAL=none WAIT_CAL=20 run)"; rc=$?
took=$(($(date +%s) - start))
assert_eq "detached exits 0 while the verifier is still waiting" "$rc" 0
assert_contains "detached prints the kick line" "$out" "✓ Kicked calendar + weather"
[ "$took" -le 3 ] && ok "detached returns at once even though the verdict is 20 s away (${took}s)" || bad "detached took ${took}s: it is waiting for the verifier"
kill "$(cut -d'|' -f1 "$STATE/chaos-panel-refresh.pid")" 2>/dev/null
setup
out="$(FAKE_SERVED=etag-new run)"
[ -f "$STATE/chaos-panel-refresh.pid" ] && ok "detached writes a pidfile" || bad "no pidfile"
for _ in 1 2 3 4 5 6 7 8; do [ -s "$FAKE_NOTIFY" ] && break; sleep 1; done
assert_contains "detached verdict lands as a notification" "$(cat "$FAKE_NOTIFY")" "✓ Calendar refreshed"
assert_not_contains "detached verifier does not double-log" "$(grep -c 'Calendar refreshed' "$STATE/chaos-panel-refresh.log")" "2"

echo "a newer press replaces the older verifier"
setup
FAKE_CAL=none WAIT_CAL=30 run >/dev/null
first="$(cut -d"|" -f1 "$STATE/chaos-panel-refresh.pid")"
sleep 1
if kill -0 "$first" 2>/dev/null; then ok "first verifier is alive and waiting"; else bad "first verifier not alive"; fi
FAKE_CAL=land FAKE_SERVED=etag-new run >/dev/null
sleep 1
if kill -0 "$first" 2>/dev/null; then bad "first verifier survived the second press"; else ok "second press killed the first verifier"; fi
assert_contains "replacement is logged" "$(cat "$STATE/chaos-panel-refresh.log")" "replaced the verifier of the previous press"
for _ in 1 2 3 4 5 6 7 8; do [ -s "$FAKE_NOTIFY" ] && break; sleep 1; done
assert_eq "exactly one verdict from the pair" "$(wc -l <"$FAKE_NOTIFY" | tr -d ' ')" 1

setup
echo 99999 >"$STATE/chaos-panel-refresh.pid"
FAKE_SERVED=etag-new run >/dev/null; rc=$?
assert_eq "a stale pidfile for a dead pid is harmless" "$rc" 0
setup
echo "$$|$(LC_ALL=C ps -o lstart= -p $$)" >"$STATE/chaos-panel-refresh.pid"
FAKE_SERVED=etag-new run >/dev/null
kill -0 $$ 2>/dev/null && ok "never kills a live pid whose command is not the script (this runner)" || bad "killed an unrelated pid"

setup
/bin/bash -c 'exec -a "/bin/bash /x/chaos-panel-refresh.sh" sleep 30' &
disown
impostor=$!
sleep 0.3
echo "$impostor|Thu Jan  1 00:00:00 1970" >"$STATE/chaos-panel-refresh.pid"
FAKE_SERVED=etag-new run >/dev/null
kill -0 "$impostor" 2>/dev/null && ok "never kills a recycled pid (command matches, start time does not)" || bad "killed a recycled pid"
kill "$impostor" 2>/dev/null
setup
/bin/bash -c 'exec -a "/bin/bash /x/chaos-panel-refresh.sh" sleep 30' &
disown
mine=$!
sleep 0.3
echo "$mine|$(LC_ALL=C ps -o lstart= -p $mine)" >"$STATE/chaos-panel-refresh.pid"
FAKE_SERVED=etag-new run >/dev/null
sleep 0.3
kill -0 "$mine" 2>/dev/null && { bad "did not kill a matching verifier"; kill "$mine" 2>/dev/null; } || ok "kills a pid that matches on start time and command"

echo "a terminal press and a Karabiner press share one pidfile format"
setup
c_fmt="$(LC_ALL=C ps -o lstart= -p $$)"
l_fmt="$(LC_ALL=en_CA.UTF-8 ps -o lstart= -p $$)"
if [ "$c_fmt" = "$l_fmt" ]; then
  echo "  ⚠ en_CA and C locale format lstart identically on this machine: the cross-locale check below proves nothing here"
fi
LANG=en_CA.UTF-8 LC_ALL=en_CA.UTF-8 FAKE_CAL=none WAIT_CAL=30 run >/dev/null
first="$(cut -d"|" -f1 "$STATE/chaos-panel-refresh.pid")"
sleep 1
if kill -0 "$first" 2>/dev/null; then ok "terminal-locale verifier is alive and waiting"; else bad "terminal-locale verifier not alive"; fi
FAKE_CAL=none run_bare >/dev/null
sleep 1
if kill -0 "$first" 2>/dev/null; then bad "a Karabiner press (C locale) did not replace a terminal press (en_CA)"; kill "$first" 2>/dev/null; else ok "a Karabiner press (C locale) replaces a terminal press (en_CA)"; fi
assert_contains "cross-locale replacement is logged" "$(cat "$STATE/chaos-panel-refresh.log")" "replaced the verifier of the previous press"

echo "bare Karabiner environment"
setup
out="$(FAKE_SERVED=etag-new run_bare --foreground)"
assert_contains "runs under /bin/sh -c with an empty environment" "$out" "✓ Calendar refreshed"

if [ -f "$GEN" ]; then
  echo "K1 rule"
  rules="$(/usr/bin/python3 "$GEN" --print)"
  k1="$(printf '%s' "$rules" | /usr/bin/python3 -c '
import json, sys
rules = json.load(sys.stdin)
k1 = next(r for r in rules if "K1" in r["description"])
out = []
for m in k1["manipulators"]:
    out.append(m["from"]["key_code"] + "+" + ",".join(m["from"]["modifiers"]["mandatory"]))
    out.append(json.dumps(m["to"], sort_keys=True))
    out.append(json.dumps(m["conditions"], sort_keys=True))
print("\n".join(out))
')"
  assert_contains "K1 rule covers the Ctrl layer" "$k1" "c+left_control"
  assert_contains "K1 rule covers the Cmd layer" "$k1" "c+left_command"
  assert_contains "K1 rule runs the refresh script" "$k1" "/Users/mlaws/.bin/chaos-panel-refresh.sh"
  assert_contains "K1 rule is scoped to the pad" "$k1" '"vendor_id": 21862'
  assert_not_contains "K1 rule does not pass -k anywhere" "$k1" " -k"
  assert_contains "K1 rule acknowledges the press" "$k1" "set_notification_message"
  unguarded="$(printf '%s' "$rules" | /usr/bin/python3 -c '
import json, sys
n = 0
for r in json.load(sys.stdin):
    for m in r["manipulators"]:
        if not m["from"].get("modifiers", {}).get("optional"):
            n += 1
print(n)
')"
  assert_eq "every pad from-event carries optional modifiers (no raw-key leak under Shift/Caps Lock)" "$unguarded" 0
  assert_contains "K1 accepts any extra modifier" "$(printf '%s' "$rules" | tr -d ' \n')" '"mandatory":["left_control"],"optional":["any"]'
  if [ "$(printf '%s' "$rules" | grep -c 'chaos-panel-refresh.sh')" -eq 2 ]; then
    ok "script wired on exactly the two layers"
  else
    bad "script should appear on exactly two manipulators"
  fi
else
  echo "⚠ $GEN missing, skipping the K1 rule checks"
fi

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
