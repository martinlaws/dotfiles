---
status: diagnosed
trigger: "script-dir-double-path - setup: line 128: /Users/mlaws/dotfiles/scripts/scripts/install-apps.sh: No such file or directory"
created: 2026-02-01T00:00:00Z
updated: 2026-02-01T00:00:00Z
symptoms_prefilled: true
---

## Current Focus

hypothesis: CONFIRMED - configure-system.sh redefines SCRIPT_DIR when sourced
test: traced BASH_SOURCE resolution in sourced context
expecting: root cause identified, ready to return diagnosis
next_action: finalize root cause documentation

## Symptoms

expected: Phase 2 scripts source successfully without SCRIPT_DIR path errors
actual: setup: line 128: /Users/mlaws/dotfiles/scripts/scripts/install-apps.sh: No such file or directory
errors: setup: line 128: /Users/mlaws/dotfiles/scripts/scripts/install-apps.sh: No such file or directory
reproduction: Test 1 in UAT session
started: Discovered during UAT

## Eliminated

## Evidence

- timestamp: 2026-02-01T00:05:00Z
  checked: symlink-dotfiles.sh line 8
  found: SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  implication: This variable is SCRIPTS_DIR not SCRIPT_DIR

- timestamp: 2026-02-01T00:05:00Z
  checked: setup-git.sh line 11
  found: SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  implication: Also uses SCRIPTS_DIR not SCRIPT_DIR

- timestamp: 2026-02-01T00:05:00Z
  checked: setup-ssh.sh line 11
  found: SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  implication: Also uses SCRIPTS_DIR not SCRIPT_DIR

- timestamp: 2026-02-01T00:06:00Z
  checked: All three Phase 2 scripts (symlink-dotfiles.sh, setup-git.sh, setup-ssh.sh)
  found: Each script defines SCRIPTS_DIR locally using BASH_SOURCE[0]
  implication: SCRIPTS_DIR points to /Users/mlaws/dotfiles/scripts correctly in each script context

- timestamp: 2026-02-01T00:10:00Z
  checked: configure-system.sh line 9
  found: SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  implication: This redefines SCRIPT_DIR when the script is sourced!

- timestamp: 2026-02-01T00:12:00Z
  checked: Traced BASH_SOURCE[0] resolution in sourced context
  found: When configure-system.sh is sourced from setup, ${BASH_SOURCE[0]} = "scripts/configure-system.sh", dirname = "scripts", cd scripts && pwd = "/Users/mlaws/dotfiles/scripts"
  implication: SCRIPT_DIR changes from /Users/mlaws/dotfiles to /Users/mlaws/dotfiles/scripts

- timestamp: 2026-02-01T00:13:00Z
  checked: setup line 128 after configure-system.sh sources
  found: source "$SCRIPT_DIR/scripts/install-apps.sh" where SCRIPT_DIR=/Users/mlaws/dotfiles/scripts
  implication: This becomes /Users/mlaws/dotfiles/scripts/scripts/install-apps.sh - the double path!

## Resolution

root_cause: configure-system.sh line 9 redefines SCRIPT_DIR when sourced by setup script. The setup script initially sets SCRIPT_DIR=/Users/mlaws/dotfiles (line 36). When configure-system.sh is sourced on line 127, its line 9 runs SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" which resolves to /Users/mlaws/dotfiles/scripts. This overwrites the parent shell's SCRIPT_DIR variable. When setup line 128 executes source "$SCRIPT_DIR/scripts/install-apps.sh", it becomes /Users/mlaws/dotfiles/scripts/scripts/install-apps.sh.
fix:
verification:
files_changed: []
