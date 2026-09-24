#!/bin/bash
# setup-autosave.sh — install + load the autosave launchd agents:
#   ca.mlaws.chaos-autosave   (watches ~/code/chaos — whole working tree)
#   ca.mlaws.claude-autosave  (watches ~/.claude tracked brain paths)
# Idempotent: re-running reloads each agent with the latest plist. Non-fatal —
# skips cleanly if fswatch or the target repo isn't present yet.
set -euo pipefail

SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"

if ! command -v fswatch >/dev/null 2>&1; then
  echo "⚠ fswatch not installed — skipping autosave agents (install via Brewfile, then re-run)"
  exit 0
fi

mkdir -p "$HOME/Library/LaunchAgents" "$HOME/.local/state"

install_agent() {
  local label="$1" repo="$2"
  local template="$SCRIPT_DIR/config/launchd/${label}.plist.template"
  local dest="$HOME/Library/LaunchAgents/${label}.plist"

  if [ ! -d "$repo/.git" ]; then
    echo "⚠ $repo not a git repo yet — skipping ${label} (re-run after clone)"
    return 0
  fi
  if [ ! -f "$template" ]; then
    echo "⚠ plist template missing at $template — skipping"
    return 0
  fi

  # Render the plist from the template (launchd doesn't expand ~ / $HOME).
  sed "s#__HOME__#${HOME}#g" "$template" > "$dest"

  # Reload (bootout then bootstrap) so changes take effect.
  launchctl bootout "gui/$(id -u)/${label}" 2>/dev/null || true

  # ⚠ `bootout` RETURNS BEFORE THE SERVICE IS GONE, and a bootstrap fired
  # straight after it races the teardown and fails — observed live on
  # 2026-09-21 in setup-dashboard-agents.sh, which left an agent UNLOADED.
  # Same fix as there: wait for the service to disappear, then retry.
  local loaded=0
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    launchctl print "gui/$(id -u)/${label}" >/dev/null 2>&1 || break
    sleep 0.5
  done

  # A snapshot killed hard during that teardown leaves its lock behind. The
  # snapshot script breaks a stale lock itself, but only once it is 10 minutes
  # old if it carries no pid (locks from before 2026-09-23 never did), so clear
  # it here when no snapshot of this repo is running.
  local lockdir="$HOME/.local/state/${label#ca.mlaws.}.lock.d" holder=""
  if [ -d "$lockdir" ] && ! pgrep -f "/${label#ca.mlaws.}\.sh" >/dev/null 2>&1; then
    { read -r holder <"$lockdir/pid"; } 2>/dev/null || true
    if [ -z "$holder" ] || ! kill -0 "$holder" 2>/dev/null; then
      rm -f "$lockdir/pid"
      if rmdir "$lockdir" 2>/dev/null; then echo "  ▸ cleared a stale lock ($lockdir)"; fi
    fi
  fi

  for _ in 1 2 3; do
    if launchctl bootstrap "gui/$(id -u)" "$dest" 2>/dev/null; then loaded=1; break; fi
    sleep 1
  done

  # ✗ Never trust bootstrap's exit code alone — confirm the service is really
  # registered (doctor.sh checks the same way).
  if [ "$loaded" = 1 ] && launchctl list "${label}" >/dev/null 2>&1; then
    echo "✓ autosave agent loaded (${label})"
  else
    echo "✗ ${label} is NOT loaded — bootstrap failed after 3 attempts. Load it by hand:"
    echo "    launchctl bootstrap gui/\$(id -u) $dest"
    failed=1
  fi
}

install_agent "ca.mlaws.chaos-autosave"  "$HOME/code/chaos"
install_agent "ca.mlaws.claude-autosave" "$HOME/.claude"

if [ "${failed:-0}" = 1 ]; then
  echo
  echo "⚠ At least one autosave agent did not load. Re-run this script, or use the command above."
fi

# One remote branch per Mac (see ~/.bin/chaos-autosave.sh): say which. Same
# lookup as the snapshot scripts — /usr/sbin/scutil by absolute path and no
# hostname fallback — so what this prints is what the agent really uses.
host="$(/usr/sbin/scutil --get LocalHostName 2>/dev/null || true)"
host="$(printf '%s' "$host" | tr -c 'A-Za-z0-9-' '-')"
if [ -z "$host" ]; then
  host="unknown"
  echo "⚠ LocalHostName is not set — this Mac will push to autosave-unknown."
  echo "  Set it in System Settings → General → Sharing → Local hostname, then re-run."
fi
if [ "$host" = "studio" ]; then branch="autosave"; else branch="autosave-$host"; fi
echo "  This Mac ($host) pushes snapshots to origin/${branch} in chaos and claude-config."
