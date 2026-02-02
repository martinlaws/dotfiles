---
status: diagnosed
trigger: "Claude desktop app installs via Homebrew and launches as GUI application - but no claude GUI app"
created: 2026-02-01T00:00:00Z
updated: 2026-02-01T00:00:00Z
symptoms_prefilled: true
goal: find_root_cause_only
---

## Current Focus

hypothesis: UAT Test 3 expected automatic installation but install-apps.sh requires interactive selection - user may have skipped/cancelled the prompt
test: verify if UAT expectation matches actual behavior of install-apps.sh
expecting: will find that test expectation doesn't match interactive nature of script
next_action: check if install-apps.sh should be automatic or if test expectation is wrong

## Symptoms

expected: Claude desktop app installs via Homebrew and launches as GUI application
actual: no claude GUI app
errors: None reported
reproduction: Test 3 in UAT (Phase 06-gap-closure-fixes)
started: Discovered during UAT

## Eliminated

- hypothesis: Brewfile.apps entry is malformed or missing
  evidence: File exists at correct location with valid `cask "claude"` entry on line 25
  timestamp: 2026-02-01T00:01:00Z

- hypothesis: Cask name "claude" is incorrect or doesn't exist
  evidence: `brew info --cask claude` confirms cask exists and is installable
  timestamp: 2026-02-01T00:02:00Z

- hypothesis: User cancelled interactive selection in install-apps.sh
  evidence: install-apps.sh never executed due to path error, so user never saw the prompt
  timestamp: 2026-02-01T00:07:00Z

## Evidence

- timestamp: 2026-02-01T00:01:00Z
  checked: Brewfile.apps location and content
  found: File exists at config/Brewfile.apps with `cask "claude"` on line 25 in Dev Tools section
  implication: Entry is present and in correct location as per Task 3 of Plan 06-01

- timestamp: 2026-02-01T00:02:00Z
  checked: Homebrew cask repository for "claude" cask
  found: `brew info --cask claude` shows cask exists, version 1.1.1520 available, already installed at version 0.10.14
  implication: Cask name is correct and cask is installable

- timestamp: 2026-02-01T00:03:00Z
  checked: /Applications/ directory for Claude.app
  found: Claude.app exists at /Applications/Claude.app (confirmed with ls and mdfind)
  implication: The GUI app IS installed and present on the system

- timestamp: 2026-02-01T00:04:00Z
  checked: install-apps.sh script logic
  found: Script is INTERACTIVE - requires user to select via gum (lines 96-104). If user cancels selection (no MODE chosen), script exits with status 0 at line 103
  implication: If user cancelled the gum selection prompt or pressed Esc, no apps would be installed

- timestamp: 2026-02-01T00:05:00Z
  checked: Running Claude processes on system
  found: Multiple Claude processes running, app was installed on 2025-06-14
  implication: Claude WAS successfully installed in the past, but NOT during this UAT test

- timestamp: 2026-02-01T00:06:00Z
  checked: configure-system.sh for SCRIPT_DIR redefinition bug
  found: Line 9 redefines SCRIPT_DIR using same pattern as the fixed Phase 2 scripts
  implication: configure-system.sh sources before install-apps.sh and breaks SCRIPT_DIR, causing "scripts/scripts/" double path

- timestamp: 2026-02-01T00:07:00Z
  checked: UAT Test 1 error message
  found: "setup: line 128: /Users/mlaws/dotfiles/scripts/scripts/install-apps.sh: No such file or directory"
  implication: Install-apps.sh never ran because the path was broken by configure-system.sh's SCRIPT_DIR redefinition

- timestamp: 2026-02-01T00:08:00Z
  checked: All scripts for SCRIPT_DIR redefinition pattern
  found: Only configure-system.sh still has the bug (grep confirmed no other scripts match pattern)
  implication: Fix is targeted - only configure-system.sh needs update

## Resolution

root_cause: configure-system.sh (line 9) redefines SCRIPT_DIR variable using `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`, which resolves to scripts/ directory instead of repo root. When setup sources configure-system.sh at line 127, SCRIPT_DIR changes from /Users/mlaws/dotfiles to /Users/mlaws/dotfiles/scripts. Then setup line 128 tries to source "$SCRIPT_DIR/scripts/install-apps.sh" which becomes /Users/mlaws/dotfiles/scripts/scripts/install-apps.sh (double scripts/ path). This file doesn't exist, so the source command fails and install-apps.sh never executes. Since install-apps.sh is the script that installs GUI applications (including Claude), no apps are installed during setup. Task 1 of Plan 06-01 fixed the same bug in Phase 2 scripts (symlink-dotfiles.sh, setup-git.sh, setup-ssh.sh) by changing SCRIPT_DIR to SCRIPTS_DIR, but configure-system.sh in Phase 3 was missed.
fix:
verification:
files_changed: []
