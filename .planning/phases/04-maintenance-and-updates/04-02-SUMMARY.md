---
phase: 04-maintenance-and-updates
plan: 02
subsystem: maintenance
tags: [homebrew, stow, macos-defaults, drift-detection, backup]

# Dependency graph
requires:
  - phase: 04-01
    provides: State management infrastructure with backup and logging
provides:
  - Four standalone update scripts for Homebrew, dotfiles, system settings, and apps
  - Dry-run previews and user confirmation before all changes
  - Content drift detection for symlinked dotfiles
  - Type-aware comparison for macOS defaults (bool/int/float/string)
  - Brewfile drift detection and bi-directional sync
affects: [04-03]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Type-aware value comparison for macOS defaults to avoid false positives"
    - "Content diff detection for symlinked dotfiles (checks if target differs from repo)"
    - "Dry-run preview pattern before destructive operations"

key-files:
  created:
    - scripts/update-homebrew.sh
    - scripts/update-dotfiles.sh
    - scripts/update-system.sh
    - scripts/update-apps.sh
  modified: []

key-decisions:
  - "Homebrew: Export UPGRADED_PACKAGES for report generation"
  - "Dotfiles: Check symlink target content vs repo source to detect manual edits"
  - "System settings: Type-aware comparison normalizes bool (true/1), int (string/number), float"
  - "Apps: Use homebrew/Brewfile path (single file, not split Brewfile.casks)"
  - "All scripts: Backup before changes, confirm before destructive operations"

patterns-established:
  - "Update scripts are standalone and can be run independently or together"
  - "Preview → Confirm → Backup → Apply → Report pattern for all operations"
  - "Graceful degradation when optional tools (like gum) are not available"

# Metrics
duration: 2 min
completed: 2026-02-02
---

# Phase 4 Plan 2: Update Category Scripts Summary

**Four update scripts with preview/confirm/backup pattern: Homebrew with dry-run, dotfiles with content drift detection, system settings with type-aware comparison, apps with Brewfile sync**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-02T01:22:21Z
- **Completed:** 2026-02-02T01:24:45Z
- **Tasks:** 4
- **Files modified:** 4

## Accomplishments

- Created update-homebrew.sh with dry-run preview and package upgrade tracking
- Created update-dotfiles.sh with content drift detection (compares symlink target to repo source)
- Created update-system.sh with type-aware comparison to handle macOS defaults type quirks
- Created update-apps.sh with Brewfile drift detection and bi-directional sync
- All scripts follow preview → confirm → backup → apply pattern
- All scripts can run standalone or be called from main update orchestrator

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Homebrew update script** - `12971a3` (feat)
2. **Task 2: Create dotfiles update script with content drift detection** - `3b04dce` (feat)
3. **Task 3: Create system settings update script with type-aware comparison** - `c2a7e4c` (feat)
4. **Task 4: Create apps update script with correct Brewfile path** - `6dff2da` (feat)

## Files Created/Modified

- `scripts/update-homebrew.sh` - Updates Homebrew packages with dry-run preview, backs up package versions, exports UPGRADED_PACKAGES for report
- `scripts/update-dotfiles.sh` - Refreshes stow symlinks, detects content drift by diffing symlink target vs repo source, offers to save user edits
- `scripts/update-system.sh` - Reapplies macOS defaults, type-aware comparison (bool true/1, int numeric, float awk), only applies drifted settings
- `scripts/update-apps.sh` - Syncs Brewfile with installed casks, detects manual installs and missing apps, offers install/remove/add to Brewfile

## Decisions Made

**Homebrew script:**
- Export UPGRADED_PACKAGES variable for use in update report (lists what was actually upgraded)
- Show brew upgrade --dry-run output to user before confirming

**Dotfiles script:**
- Implement content drift detection: diff symlink target vs repo source, not just check symlink path
- Offer to copy user edits back to repo before restow (preserves manual changes)

**System settings script:**
- Type-aware comparison function to handle macOS defaults type quirks:
  - Bool: Normalize true/1/TRUE to 1, false/0/FALSE to 0 before comparison
  - Int: Compare numerically (not as strings) to avoid "48" != 48 false positives
  - Float: Use awk for float comparison since bc may not be available
- Only reapply settings that have drifted (not all settings)

**Apps script:**
- Use homebrew/Brewfile (single file) not split Brewfile.casks path
- Extract cask lines with grep "^cask " pattern
- Bi-directional sync: add manual installs to Brewfile OR install/remove missing casks
- Graceful fallback to simple prompt when gum is not available

All scripts follow consistent pattern:
- Source all required libraries (detect, ui, state, backup, logging)
- Preview changes before applying
- User confirmation required
- Backup created before destructive operations
- Graceful error handling (continue on individual failures)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - all scripts created successfully with proper syntax, library sourcing, and verification patterns.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

**Ready for 04-03:** Main update orchestrator script that ties these four category scripts together with multi-select UI and comprehensive reporting.

**What's in place:**
- All four update category scripts are standalone and testable
- Preview/confirm/backup pattern established across all operations
- Type-aware comparison prevents false positives in system settings drift
- Content drift detection catches manual dotfile edits
- Homebrew upgrade tracking exports data for reporting

**What 04-03 will add:**
- Main update.sh that calls these four scripts
- Multi-select checklist for choosing update categories
- Comprehensive update report showing what changed
- Integration of all pieces into cohesive update flow

---
*Phase: 04-maintenance-and-updates*
*Completed: 2026-02-02*
