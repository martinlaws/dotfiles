---
status: diagnosed
trigger: "apps is where it's failing!"
created: 2026-02-01T00:00:00Z
updated: 2026-02-01T00:06:00Z
symptoms_prefilled: true
---

## Current Focus

hypothesis: Phase 6 added Homebrew verification, but likely the SCRIPT_DIR double path issue from Test 1 is causing the apps phase to fail before verification can help
test: examining setup script and install-apps.sh path construction
expecting: find SCRIPT_DIR path construction error that causes wrong path to install-apps.sh
next_action: read setup script to find how SCRIPT_DIR is constructed and how apps phase is called

## Symptoms

expected: If Homebrew is missing when Phase 3 starts, setup shows clear error message instead of "brew: command not found"
actual: apps is where it's failing!
errors: Related to Test 1: setup: line 128: /Users/mlaws/dotfiles/scripts/scripts/install-apps.sh: No such file or directory
reproduction: Test 6 in UAT
started: Discovered during UAT

## Eliminated

## Evidence

- timestamp: 2026-02-01T00:01:00Z
  checked: setup script line 128 and actual scripts directory structure
  found: Line 128 uses `source "$SCRIPT_DIR/scripts/install-apps.sh"` but error says "/Users/mlaws/dotfiles/scripts/scripts/install-apps.sh" (double scripts path). File actually exists at /Users/mlaws/dotfiles/scripts/install-apps.sh (single scripts path).
  implication: SCRIPT_DIR must already include "/scripts" in its path, causing double path construction

- timestamp: 2026-02-01T00:02:00Z
  checked: SCRIPT_DIR construction at line 36
  found: `SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"` - this should set SCRIPT_DIR to /Users/mlaws/dotfiles (the repo root)
  implication: Something is modifying SCRIPT_DIR between line 36 and line 128, OR a sourced script is changing it

- timestamp: 2026-02-01T00:03:00Z
  checked: configure-system.sh (line 127 in setup, before line 128)
  found: Line 9 redefines SCRIPT_DIR: `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`. This sets SCRIPT_DIR to /Users/mlaws/dotfiles/scripts (the scripts directory, not repo root). This overwrites the exported SCRIPT_DIR from setup.
  implication: When setup runs line 128 `source "$SCRIPT_DIR/scripts/install-apps.sh"`, SCRIPT_DIR is now /Users/mlaws/dotfiles/scripts, resulting in /Users/mlaws/dotfiles/scripts/scripts/install-apps.sh (double scripts path)

- timestamp: 2026-02-01T00:04:00Z
  checked: symlink-dotfiles.sh for comparison (sourced earlier at line 104)
  found: Uses SCRIPTS_DIR (line 8) instead of SCRIPT_DIR: `SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`. This is correct - it doesn't overwrite the parent's SCRIPT_DIR.
  implication: configure-system.sh should use SCRIPTS_DIR (or CONFIG_SCRIPT_DIR) instead of SCRIPT_DIR to avoid collision with setup's exported SCRIPT_DIR

- timestamp: 2026-02-01T00:05:00Z
  checked: all other scripts for SCRIPT_DIR redefinition
  found: Most scripts use `SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"` (conditional assignment - only sets if not already set). Only configure-system.sh uses unconditional assignment that overwrites the existing value. Other scripts respect the exported SCRIPT_DIR.
  implication: configure-system.sh is the only culprit - it's the only one that unconditionally overwrites SCRIPT_DIR

## Resolution

root_cause: configure-system.sh redefines SCRIPT_DIR at line 9, overwriting setup's exported SCRIPT_DIR variable. When setup sources configure-system.sh (line 127), SCRIPT_DIR changes from /Users/mlaws/dotfiles (repo root) to /Users/mlaws/dotfiles/scripts. Then line 128 tries to source "$SCRIPT_DIR/scripts/install-apps.sh" which becomes /Users/mlaws/dotfiles/scripts/scripts/install-apps.sh (double scripts path). The file actually exists at /Users/mlaws/dotfiles/scripts/install-apps.sh. This is why Test 1 reported the double path error and Test 6 says "apps is where it's failing" - the Homebrew verification works fine, but the script can't find install-apps.sh due to the wrong path.

fix: Change configure-system.sh line 9 from unconditional `SCRIPT_DIR=` to either: (1) conditional assignment `SCRIPT_DIR="${SCRIPT_DIR:-...}"` like other scripts, or (2) use a different variable name like `CONFIG_SCRIPT_DIR` or `SCRIPTS_DIR` like symlink-dotfiles.sh does.

verification: (not performed - find_root_cause_only mode)

files_changed: [scripts/configure-system.sh]
