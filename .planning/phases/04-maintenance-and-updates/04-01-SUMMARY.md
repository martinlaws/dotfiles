---
phase: 04-maintenance-and-updates
plan: 01
subsystem: infrastructure
tags: [state-management, backup, logging, json, jq]
requires: [01-foundation, homebrew, jq]
provides: [state-tracking, package-tracking, backup-system, logging-system]
affects: [04-02, 04-03]
tech-stack:
  added: [jq]
  patterns: [json-state-files, timestamped-backups, file-based-logging]
key-files:
  created:
    - scripts/lib/state.sh
    - scripts/lib/backup.sh
    - scripts/lib/logging.sh
  modified:
    - config/Brewfile
decisions:
  - id: json-state-location
    choice: ~/.local/state/dotfiles/
    rationale: Outside git repo, follows XDG Base Directory spec
  - id: package-tracking-approach
    choice: Save formulae and casks lists in state file
    rationale: Enables drift detection without expensive brew checks
  - id: backup-retention
    choice: Keep last 5 backups
    rationale: Balance between disk space and recovery options
  - id: logging-strategy
    choice: Detailed logs to file, clean terminal UI
    rationale: Users want fast visual feedback, logs for troubleshooting
metrics:
  duration: 2 min
  completed: 2026-02-01
---

# Phase 04 Plan 01: State Management Infrastructure Summary

**One-liner:** JSON state file tracking with jq, timestamped backups, and file-based logging for update mode detection.

## What Was Built

### Core Infrastructure
Created three library scripts providing state management, backup utilities, and logging capabilities:

1. **State Management (scripts/lib/state.sh)**
   - JSON state file at ~/.local/state/dotfiles/setup-state.json
   - Tracks last run timestamp, phase completion, and installed packages (formulae + casks)
   - `state_exists()` enables first-run vs update mode detection
   - `state_save_packages()` captures current brew installations
   - `state_get_packages()` retrieves saved package lists for drift detection
   - All JSON operations use jq for safety (no sed/awk/echo)

2. **Backup System (scripts/lib/backup.sh)**
   - Timestamped backup directories at ~/.local/state/dotfiles/backups/
   - ISO 8601 format: YYYY-MM-DDTHH-MM-SS
   - `backup_defaults()` exports macOS defaults domains to plist files
   - `backup_state()` copies state file before modifications
   - `backup_cleanup_old()` keeps only last 5 backups automatically
   - Updates state file with last backup directory path

3. **Logging System (scripts/lib/logging.sh)**
   - Daily log files at ~/.local/state/dotfiles/logs/setup-YYYY-MM-DD.log
   - `log_cmd()` runs commands, captures output to file, keeps terminal clean
   - Session headers with timestamps
   - Separate functions: log_info(), log_error(), log_debug()
   - Terminal shows clean UI, file has verbose details

### Dependencies
Added jq to Brewfile (config/Brewfile) in file utilities section for JSON operations required by state.sh.

## Technical Details

### State File Structure
```json
{
  "version": "1.0",
  "last_run": "2026-02-01T20:15:00Z",
  "phases": {
    "01-foundation": {
      "completed_at": "2026-02-01T15:30:00Z"
    }
  },
  "packages": {
    "formulae": ["git", "node", "jq", "gum", "stow"],
    "casks": ["visual-studio-code", "slack"]
  },
  "backups": {
    "last_backup_dir": "/Users/mlaws/.local/state/dotfiles/backups/2026-02-01T20-15-00"
  }
}
```

### Backup Directory Structure
```
~/.local/state/dotfiles/backups/
├── 2026-02-01T10-30-00/
│   ├── com.apple.dock.plist
│   ├── com.apple.finder.plist
│   └── setup-state.json
├── 2026-02-01T14-15-00/
└── 2026-02-01T20-00-00/
```

### Log File Format
```
========================================
Session started: 2026-02-01 20:15:00
========================================
[INFO] 20:15:01 Running: brew bundle check
[INFO] 20:15:02 Success: Check brew bundle status
[DEBUG] 20:15:03 All formulae installed
```

## Integration Points

### For Update Scripts (04-02)
```bash
source "$(dirname "$0")/lib/state.sh"
source "$(dirname "$0")/lib/backup.sh"
source "$(dirname "$0")/lib/logging.sh"

log_init

if state_exists; then
    last_run=$(state_get_last_run)
    ui_info "Last run: $last_run"

    # Create backup before changes
    backup_create_dir
    backup_state
    backup_defaults "com.apple.dock"

    # Track changes
    old_packages=$(state_get_packages)
    # ... perform updates ...
    state_save_packages
    state_set_last_run
else
    ui_info "First run - no state file"
fi
```

### For Drift Detection (04-03)
```bash
# Compare current vs recorded state
saved=$(state_get_packages)
current_formulae=$(brew list --formula)
current_casks=$(brew list --cask)

# Detect added/removed packages
diff <(echo "$saved" | jq -r '.formulae[]' | sort) \
     <(echo "$current_formulae" | sort)
```

## Verification Results

All verification checks passed:

- [x] scripts/lib/state.sh syntax valid
- [x] scripts/lib/backup.sh syntax valid
- [x] scripts/lib/logging.sh syntax valid
- [x] state_init creates valid JSON with packages key
- [x] state_exists correctly detects file presence
- [x] state_save_packages captures formulae and casks
- [x] backup_create_dir creates timestamped directories
- [x] log_init creates log file and writes messages
- [x] jq added to Brewfile
- [x] State file location outside git repo (~/.local/state/)

## Success Criteria Met

1. ✓ New user: state_exists() returns 1 (false) on first run
2. ✓ After setup: state file exists with last_run timestamp and package arrays
3. ✓ Second run: state_exists() returns 0 (true), enabling update mode
4. ✓ Backups use ISO 8601 timestamps (YYYY-MM-DDTHH-MM-SS)
5. ✓ Backups >5 cleaned up automatically by backup_cleanup_old()
6. ✓ Verbose output goes to log file, terminal stays clean
7. ✓ Package lists (formulae + casks) tracked in state file

## Decisions Made

### 1. State File Location: ~/.local/state/dotfiles/
**Context:** State file must persist across dotfiles repo updates, not be committed to git.

**Options considered:**
- ~/.local/state/dotfiles/ (XDG Base Directory spec)
- ~/.dotfiles-state/ (custom location)
- ~/.config/dotfiles/ (config directory)

**Decision:** ~/.local/state/dotfiles/

**Rationale:** Follows XDG Base Directory specification for state/cache data, automatically excluded from git, clear separation from dotfiles repo content.

### 2. Package Tracking Approach
**Context:** Update scripts need to detect what was installed previously.

**Options considered:**
- Run `brew list` every time (slow)
- Save package lists to state file (fast lookup)
- Use Brewfile as source of truth (doesn't catch manual installs)

**Decision:** Save formulae and casks arrays in state file

**Rationale:** Enables fast drift detection, captures actual installed state (including manual installs), avoids expensive brew commands on every run.

### 3. Backup Retention Policy
**Context:** Backups accumulate over time, need cleanup strategy.

**Options considered:**
- Keep all backups (disk space issues)
- Keep last 3 backups (limited recovery options)
- Keep last 5 backups (balanced approach)
- Time-based retention (complex logic)

**Decision:** Keep last 5 backups

**Rationale:** Provides multiple recovery points without excessive disk usage, simple to implement, sufficient for typical use cases.

### 4. Logging Strategy
**Context:** Users want clean, fast UI but need detailed logs for troubleshooting.

**Options considered:**
- Log everything to terminal (cluttered, slow)
- No logging (can't troubleshoot issues)
- Dual output: clean terminal + detailed log file
- Verbose flag for detailed terminal output

**Decision:** Write detailed logs to file automatically, keep UI clean

**Rationale:** Satisfies user preference for "aggressive" fast setup with clean UI, provides complete audit trail for debugging, log_cmd() function makes this pattern easy to use.

## Deviations from Plan

None - plan executed exactly as written.

## Next Phase Readiness

### Blockers
None.

### Ready for Next Plans
- 04-02 (Update Detection): Can source state.sh, call state_exists() and state_get_packages()
- 04-03 (Drift Detection): Can compare saved vs current package lists
- Future update scripts: Have complete infrastructure for tracking, backup, and logging

### Outstanding Items
None. All planned functionality delivered.

## Performance Metrics

- **Execution time:** 2 minutes
- **Tasks completed:** 4/4
- **Commits created:** 4 (one per task)
- **Files created:** 3 (state.sh, backup.sh, logging.sh)
- **Files modified:** 1 (config/Brewfile)

## Key Learnings

1. **jq for JSON safety:** Using jq instead of sed/awk/echo prevents JSON syntax errors with special characters in values
2. **Temp file pattern:** jq writes to temp file first, then moves to target (atomic operation)
3. **Export functions:** All library functions exported with `export -f` for use in sourced scripts
4. **XDG compliance:** ~/.local/state/ is the standard location for state files on Unix systems
5. **ISO 8601 timestamps:** Using +%Y-%m-%dT%H-%M-%S (colons replaced with hyphens) for filesystem-safe timestamps

## Related Documentation

- Phase 04 Context: .planning/phases/04-maintenance-and-updates/04-CONTEXT.md
- Phase 04 Research: .planning/phases/04-maintenance-and-updates/04-RESEARCH.md
- State file example: ~/.local/state/dotfiles/setup-state.json
- Existing library patterns: scripts/lib/detect.sh, scripts/lib/ui.sh

## Commits

- `9192a4a` feat(04-01): create state management library with package tracking
- `9e492ed` feat(04-01): create backup utilities library
- `a3baf67` feat(04-01): create logging library
- `a5c90f2` feat(04-01): add jq to Brewfile for state management
