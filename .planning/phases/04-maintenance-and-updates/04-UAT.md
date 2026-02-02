---
status: diagnosed
phase: 04-maintenance-and-updates
source: 04-01-SUMMARY.md, 04-02-SUMMARY.md, 04-03-SUMMARY.md
started: 2026-02-01T20:40:00Z
updated: 2026-02-01T20:45:00Z
---

## Current Test

[testing complete]

## Tests

### 1. State file creation on first run
expected: After running setup for the first time, a state file should exist at ~/.local/state/dotfiles/setup-state.json with valid JSON including version, last_run timestamp, phases object, packages arrays (formulae and casks), and backups object.
result: issue
reported: "I just tried to run it and it errored out on: /Users/mlaws/dotfiles/scripts/show-report.sh: line 19: show_update_report: command not found"
severity: blocker

### 2. Update mode detection
expected: Running ./setup a second time should detect the existing state file and show "Detected previous setup" message before presenting update options.
result: pass

### 3. Multi-select category UI
expected: Update mode should display a multi-select checklist with all four categories pre-selected (Homebrew packages, dotfiles, system settings, apps). User can deselect unwanted categories using arrow keys and space.
result: skipped
reason: Blocked by Test 1 - cannot reach this menu due to show_update_report error

### 4. Homebrew dry-run preview
expected: When Homebrew update is selected, the script should run "brew upgrade --dry-run" and show which packages would be upgraded before asking for confirmation.
result: skipped
reason: Blocked by Test 1 - cannot reach this functionality

### 5. Package-level upgrade reporting
expected: After Homebrew upgrades complete, the report should show specific packages upgraded with version numbers (e.g., "nodejs 20.0 -> 20.1", "git 2.40 -> 2.41"), not just "Homebrew updated".
result: skipped
reason: Blocked by Test 1 - cannot complete updates

### 6. Dotfiles content drift detection
expected: When update-dotfiles runs, it should compare symlink target content to repo source using diff. If user edited a symlinked file directly, it should detect the difference and offer to copy changes back to repo before restow.
result: skipped
reason: Blocked by Test 1 - cannot reach this functionality

### 7. System settings type-aware comparison
expected: When checking macOS defaults drift, the script should normalize bool values (true/1 treated as equivalent), compare integers numerically (not as strings), and handle float values correctly. Should not show false positives for "48" vs 48 or true vs 1.
result: skipped
reason: Blocked by Test 1 - cannot reach this functionality

### 8. Backup creation before changes
expected: Before applying any destructive changes (Homebrew upgrade, system settings), a timestamped backup directory should be created at ~/.local/state/dotfiles/backups/ in ISO 8601 format (YYYY-MM-DDTHH-MM-SS).
result: skipped
reason: Blocked by Test 1 - cannot trigger backups

### 9. Detailed logging to file
expected: All verbose command output should be written to ~/.local/state/dotfiles/logs/setup-YYYY-MM-DD.log with timestamps, while terminal shows only clean UI messages.
result: skipped
reason: Blocked by Test 1 - cannot verify logging

### 10. Error handling with continue option
expected: If a category update fails (e.g., Homebrew upgrade error), the script should show the error and ask "Continue with remaining categories?" User can choose to stop or continue with other updates.
result: skipped
reason: Blocked by Test 1 - cannot reach error handling

### 11. Brewfile drift detection
expected: update-apps.sh should detect manually installed casks not in config/Brewfile and offer to add them. Should also detect casks in Brewfile but not installed and offer to install or remove from Brewfile.
result: skipped
reason: Blocked by Test 1 - cannot reach apps update

### 12. Completion report with all sections
expected: After updates complete, the report should show: specific packages upgraded (with versions), categories completed, categories skipped, any errors, backup location, log file location, and recommendation for next update timing.
result: skipped
reason: Blocked by Test 1 - cannot complete updates to see report

## Summary

total: 12
passed: 1
issues: 1
pending: 0
skipped: 10

## Gaps

- truth: "Setup script runs successfully and creates state file on first run"
  status: failed
  reason: "User reported: I just tried to run it and it errored out on: /Users/mlaws/dotfiles/scripts/show-report.sh: line 19: show_update_report: command not found"
  severity: blocker
  test: 1
  root_cause: "Function call before definition - show_update_report() called at line 19 but defined at line 254"
  artifacts:
    - path: "scripts/show-report.sh"
      issue: "Lines 18-21 check UPDATE_MODE and call show_update_report, but function is defined much later at lines 254-335"
  missing:
    - "Move function definitions before the mode check/function calls"
    - "Correct order: libraries → function definitions → mode routing → function call"
  debug_session: "inline diagnosis"
