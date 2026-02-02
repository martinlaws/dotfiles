---
phase: 05-fix-update-mode-integration-breaks
plan: 01
subsystem: maintenance
tags: [stow, homebrew, update-mode, dotfiles, brewfile]

# Dependency graph
requires:
  - phase: 02-dotfiles
    provides: Stow-based symlink management with package directories
  - phase: 03-applications-and-system-settings
    provides: Brewfile.apps catalog for GUI applications
  - phase: 04-maintenance-and-updates
    provides: Update scripts for dotfiles and apps
provides:
  - Correct stow package references in update-dotfiles.sh
  - Correct Brewfile path in update-apps.sh
  - Working update mode for dotfiles refresh and app drift detection
affects: [update-mode, maintenance, fresh-mac-setup]

# Tech tracking
tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified:
    - scripts/update-dotfiles.sh
    - scripts/update-apps.sh

key-decisions: []

patterns-established: []

# Metrics
duration: 1min
completed: 2026-02-02
---

# Phase 5 Plan 1: Fix Update Mode Integration Breaks Summary

**Stow package names and Brewfile reference corrected for working update mode**

## Performance

- **Duration:** 45 seconds
- **Started:** 2026-02-02T02:31:56Z
- **Completed:** 2026-02-02T02:32:41Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Fixed stow package name mismatch causing "package does not exist" errors
- Fixed Brewfile reference pointing to CLI tools instead of GUI app catalog
- Update mode scripts now correctly reference their configuration sources

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix stow package names in update-dotfiles.sh** - `bf29289` (fix)
2. **Task 2: Fix Brewfile reference in update-apps.sh** - `2bd74b0` (fix)

## Files Created/Modified
- `scripts/update-dotfiles.sh` - Changed STOW_PACKAGES from non-existent names (zsh, hyper, vscode, starship) to actual directory names (git, shell, terminal, editors, ssh)
- `scripts/update-apps.sh` - Changed BREWFILE from config/Brewfile (CLI tools) to config/Brewfile.apps (GUI app catalog)

## Decisions Made
None - followed plan as specified. These were pure bug fixes identified in v1.0 milestone audit.

## Deviations from Plan
None - plan executed exactly as written.

## Issues Encountered
None - straightforward one-line fixes in each script.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Update mode integration breaks are now fixed
- Update scripts correctly reference actual stow packages and app catalog
- Ready for testing update mode with state file present
- Gap closure for Phase 5 complete

---
*Phase: 05-fix-update-mode-integration-breaks*
*Completed: 2026-02-02*
