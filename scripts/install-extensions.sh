#!/bin/bash
#
# install-extensions.sh — reinstall editor extensions on a fresh machine.
#
# Extension lists live in config/<editor>-extensions.txt (one extension id per
# line; '#' comments ignored). Runs after the editors are installed (Phase 3).
# Non-fatal: missing editor or list is skipped.

set -uo pipefail
SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"

echo "== Editor extensions =="
install_for() {
  bin="$1"; list="$2"
  command -v "$bin" >/dev/null 2>&1 || { echo "  $bin not found — skipping"; return; }
  [ -f "$list" ] || { echo "  no list for $bin — skipping"; return; }
  n=0
  while IFS= read -r raw || [ -n "$raw" ]; do
    ext="${raw%%#*}"; ext="$(echo "$ext" | tr -d '[:space:]')"
    [ -z "$ext" ] && continue
    if "$bin" --install-extension "$ext" --force >/dev/null 2>&1; then
      echo "  ✓ $ext"; n=$((n+1))
    else
      echo "  ✗ $ext"
    fi
  done < "$list"
  echo "  $bin: $n installed"
}

install_for cursor        "$SCRIPT_DIR/config/cursor-extensions.txt"
install_for code          "$SCRIPT_DIR/config/vscode-extensions.txt"
install_for code-insiders "$SCRIPT_DIR/config/vscode-insiders-extensions.txt"
