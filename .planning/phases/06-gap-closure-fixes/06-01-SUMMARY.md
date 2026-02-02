---
phase: 06-gap-closure-fixes
plan: 01
subsystem: foundation
tags: [bash, homebrew, starship, error-handling, shell-scripts]

# Dependency graph
requires:
  - phase: 05-fix-update-mode-integration-breaks
    provides: Update mode integration fixes
provides:
  - SCRIPT_DIR double path bug fixed in sourced scripts
  - Starship shell prompt in Brewfile
  - Claude desktop app correctly categorized as cask
  - Printf-based UI fallbacks for macOS compatibility
  - Error propagation in setup script
  - Homebrew verification before Phase 3
affects: [fresh-mac-setup, update-mode, all-future-phases]

# Tech tracking
tech-stack:
  added: [starship]
  patterns: [error-propagation, prerequisite-verification]

key-files:
  created: []
  modified:
    - scripts/symlink-dotfiles.sh
    - scripts/setup-git.sh
    - scripts/setup-ssh.sh
    - scripts/lib/ui.sh
    - config/Brewfile
    - config/Brewfile.apps
    - setup

key-decisions:
  - "Use SCRIPTS_DIR for sourced scripts to preserve parent SCRIPT_DIR"
  - "Add set -euo pipefail to setup script for immediate error exits"
  - "Verify Homebrew installed before Phase 3 with clear error message"

patterns-established:
  - "Sourced scripts use local SCRIPTS_DIR variable instead of SCRIPT_DIR"
  - "Setup script validates prerequisites between phases"

# Metrics
duration: 2 min
completed: 2026-02-02
---

# Phase 6 Plan 1: Gap Closure Fixes Summary

**Fixed 6 critical bugs from v1.0 audit: SCRIPT_DIR double paths, missing starship dependency, incorrect Claude categorization, and missing error propagation/verification**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-02T02:56:24Z
- **Completed:** 2026-02-02T02:58:34Z
- **Tasks:** 6
- **Files modified:** 7

## Accomplishments
- Fixed SCRIPT_DIR double path bug preventing Phase 2 script sourcing
- Added starship to Brewfile preventing "command not found" errors on fresh Mac
- Moved Claude desktop app to correct Brewfile location (cask vs brew)
- Ensured printf usage throughout ui.sh for macOS compatibility
- Added error propagation to setup script preventing cascading failures
- Added Homebrew verification before Phase 3 with clear error messaging

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix SCRIPT_DIR double path bug** - `1cafbde` (fix)
2. **Task 2: Add starship to Brewfile** - `60b5a17` (feat)
3. **Task 3: Move Claude to Brewfile.apps** - `9d6c0f5` (fix)
4. **Task 4: Fix echo fallback (use printf)** - `b7555a4` (fix)
5. **Task 5: Add error propagation to setup script** - `b3c183a` (feat)
6. **Task 6: Add Homebrew verification before Phase 3** - `d7abbef` (feat)

**Plan metadata:** (to be committed)

## Files Created/Modified
- `scripts/symlink-dotfiles.sh` - Changed SCRIPT_DIR to SCRIPTS_DIR to prevent double path
- `scripts/setup-git.sh` - Changed SCRIPT_DIR to SCRIPTS_DIR to prevent double path
- `scripts/setup-ssh.sh` - Changed SCRIPT_DIR to SCRIPTS_DIR to prevent double path
- `scripts/lib/ui.sh` - Changed echo "" to printf "\n" for consistency
- `config/Brewfile` - Added starship, removed claude (moved to apps)
- `config/Brewfile.apps` - Added cask "claude" in Dev Tools section
- `setup` - Added set -euo pipefail and Homebrew verification

## Decisions Made
- **Use SCRIPTS_DIR in sourced scripts:** Prevents overwriting parent's SCRIPT_DIR variable when scripts are sourced
- **Add starship to Brewfile:** Ensures dependency is installed before .zshrc tries to use it
- **Categorize Claude as cask:** Claude desktop app is a GUI application, not CLI tool
- **Add error propagation:** Setup script now stops on first error instead of continuing with broken state
- **Verify Homebrew before Phase 3:** Prevents confusing brew command errors in Phase 3

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

All v1.0 critical gaps closed. Ready for:
- Fresh Mac testing without manual intervention (except Xcode CLT button click)
- v1.0 milestone completion audit
- Final verification before milestone completion

**v1.0 Requirement Coverage:** 28/29 (97%)
- ⚠️ PKG-05 partially satisfied (Xcode CLT requires GUI click - acceptable per user)
- ✓ UX-01 satisfied (Beautiful CLI with no artifacts)
- ✓ Integration issues resolved (error propagation, Homebrew verification)

---
*Phase: 06-gap-closure-fixes*
*Completed: 2026-02-02*
