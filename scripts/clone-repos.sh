#!/bin/bash
#
# clone-repos.sh — clone my active repos into ~/code on a fresh machine.
#
# The repo LIST names private/client repos, so it is NOT kept here. It lives in
# the private claude-config repo at ~/.claude/repos.txt (override via REPOS_LIST).
# This script is generic — no private data — so it's safe in the public repo.
#
# repos.txt format (one entry per line; everything after '#' is a comment):
#   <git-url> [target-dir]
# target-dir is optional and defaults to the repo name; set it when the local
# directory name differs from the repo name (e.g. mlaws-agent → martin-context-builder).

set -uo pipefail

REPOS_LIST="${REPOS_LIST:-$HOME/.claude/repos.txt}"
CODE_DIR="${CODE_DIR:-$HOME/code}"

echo "== Clone work repos =="
if [ ! -f "$REPOS_LIST" ]; then
  echo "  No repo list at ${REPOS_LIST/#$HOME/~} — skipping (nothing to clone)."
  exit 0
fi

mkdir -p "$CODE_DIR"
cloned=0; skipped=0; failed=0
while IFS= read -r raw || [ -n "$raw" ]; do
  line="${raw%%#*}"                          # strip trailing comments
  url="$(awk '{print $1}' <<<"$line")"
  target="$(awk '{print $2}' <<<"$line")"
  [ -z "$url" ] && continue                   # blank / comment-only line
  [ -z "$target" ] && target="$(basename "$url" .git)"
  dest="$CODE_DIR/$target"
  if [ -d "$dest/.git" ]; then
    skipped=$((skipped+1)); continue
  fi
  if git clone "$url" "$dest" >/dev/null 2>&1; then
    echo "  ✓ cloned $target"; cloned=$((cloned+1))
  else
    echo "  ✗ FAILED $target ($url)"; failed=$((failed+1))
  fi
done < "$REPOS_LIST"
echo "  done — cloned $cloned · skipped(exist) $skipped · failed $failed"
