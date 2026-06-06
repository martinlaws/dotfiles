#!/usr/bin/env bash
# sw-capture.sh — superwhisper "Capture" mode hook.
#
# Appends the just-dictated thought to the chaos inbox so a spoken note files
# itself — the "digital post-it." Wired as the script of the superwhisper
# "Capture" mode (capture.json).
#
# Result source: superwhisper writes each recording's text to
#   ~/Documents/superwhisper/recordings/<id>/meta.json  (key: .result, raw: .rawResult)
# This is the verified data model. We prefer a recording path if superwhisper
# passes one via env; otherwise we read the newest fresh meta.json. Every run
# logs what superwhisper actually passed (env/args/stdin) so the hand-off can be
# tightened to the exact variable once confirmed — see $LOG.

set -euo pipefail

# superwhisper runs this outside your shell, so PATH may be minimal. Ensure jq
# (Homebrew on the new Mac, /usr/bin here) and coreutils resolve.
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

INBOX="$HOME/code/chaos/_inbox.md"
REC_DIR="$HOME/Documents/superwhisper/recordings"
LOG="$HOME/.local/state/sw-capture.log"
mkdir -p "$(dirname "$LOG")" "$(dirname "$INBOX")"

# Capture any stdin once (superwhisper may pipe the result).
STDIN_DATA=""
if [ ! -t 0 ]; then STDIN_DATA="$(cat 2>/dev/null || true)"; fi

# --- self-documenting: record exactly what superwhisper handed us ---
{
  echo "=== invoked ==="
  echo "args: $*"
  echo "stdin: ${STDIN_DATA:0:200}"
  env | grep -iE 'super|whisper|result|recording|mode|transcri' || true
} >> "$LOG" 2>&1

result=""

# 1) recording path via a superwhisper-provided env var (if any)
for v in "${recordingPath:-}" "${SUPERWHISPER_RECORDING_PATH:-}" "${RECORDING_PATH:-}" "${SW_RECORDING_PATH:-}"; do
  if [ -n "$v" ] && [ -f "$v/meta.json" ]; then
    result=$(jq -r '.result // .rawResult // empty' "$v/meta.json" 2>/dev/null || true)
    [ -n "$result" ] && break
  fi
done

# 2) result text directly via a superwhisper-provided env var (if any)
if [ -z "$result" ]; then
  for v in "${result:-}" "${SUPERWHISPER_RESULT:-}" "${SW_RESULT:-}" "${llmResult:-}"; do
    [ -n "$v" ] && { result="$v"; break; }
  done
fi

# 3) fallback: newest recording with a fresh meta.json (poll briefly for timing)
if [ -z "$result" ]; then
  for _ in 1 2 3 4 5 6 7 8; do
    latest=$(ls -dt "$REC_DIR"/*/ 2>/dev/null | head -1)
    if [ -n "${latest:-}" ] && [ -f "${latest}meta.json" ]; then
      result=$(jq -r '.result // .rawResult // empty' "${latest}meta.json" 2>/dev/null || true)
      [ -n "$result" ] && break
    fi
    sleep 0.5
  done
fi

# 4) last resort: stdin
[ -z "$result" ] && result="$STDIN_DATA"

# trim whitespace / CRs
result="$(printf '%s' "$result" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
if [ -z "$result" ]; then
  echo "no result captured" >> "$LOG"
  exit 0
fi

# --- append to inbox under a date heading ---
today=$(date '+%Y-%m-%d')
now=$(date '+%H:%M')
[ -f "$INBOX" ] || printf '# Inbox\n' > "$INBOX"
if ! grep -q "^## ${today}\$" "$INBOX" 2>/dev/null; then
  printf '\n## %s\n' "$today" >> "$INBOX"
fi
printf -- '- %s %s\n' "$now" "$result" >> "$INBOX"
echo "captured ($(date '+%F %T')): $result" >> "$LOG"
