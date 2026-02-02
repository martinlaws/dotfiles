---
phase: 06-gap-closure-fixes
plan: 02
subsystem: foundation
tags: [bash, gap-closure, script-sourcing]

# Dependency graph
requires:
  - phase: 06-gap-closure-fixes
    plan: 01
    provides: SCRIPT_DIR fixes for Phase 2 scripts
provides:
  - SCRIPT_DIR collision fixed in configure-system.sh
  - install-apps.sh executes successfully
  - All Phase 3 apps (including Claude) can install
affects: [phase-3-apps, fresh-mac-setup, update-mode]

# Tech tracking
tech-stack:
  patterns: [variable-scoping, script-sourcing]

key-files:
  modified:
    - scripts/configure-system.sh

key-decisions:
  - "Use SCRIPTS_DIR in configure-system.sh to match pattern from 06-01"

patterns-established:
  - "All sourced scripts use unique variable names (SCRIPTS_DIR) to avoid collision"

# Metrics
duration: 2 min
completed: 2026-02-01
---

# Phase 6 Plan 2: Fix SCRIPT_DIR Collision Summary

**Fixed the ONE script missed in 06-01 that prevented all Phase 3 apps from installing**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-01T03:30:00Z
- **Completed:** 2026-02-01T03:32:00Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- Fixed SCRIPT_DIR collision in configure-system.sh (changed to SCRIPTS_DIR)
- Eliminated double scripts/scripts/ path error on setup line 128
- Unblocked install-apps.sh execution
- Enabled all Phase 3 GUI applications (including Claude) to install

## Task Commits

1. **Task 1: Fix SCRIPT_DIR collision** - `0fc5b8f` (fix)

**Plan metadata:** (committed separately)

## Files Created/Modified
- `scripts/configure-system.sh` - Changed SCRIPT_DIR to SCRIPTS_DIR (lines 9, 12)

## Decisions Made
- **Match 06-01 pattern:** Apply same SCRIPTS_DIR pattern to configure-system.sh that was used for Phase 2 scripts

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## UAT Gaps Closed

All 3 Phase 6 UAT gaps resolved by this single fix:
- ✓ Test 1: Scripts source without SCRIPT_DIR path errors
- ✓ Test 3: Claude desktop app installs
- ✓ Test 6: Apps phase no longer fails

## Next Phase Readiness

Phase 6 complete. All v1.0 critical gaps closed. Ready for:
- v1.0 milestone completion audit
- Testing on fresh Mac
- Milestone archival

**Root Cause:** configure-system.sh was the ONE script missed in 06-01 that still redefined SCRIPT_DIR, breaking all subsequent script sourcing in Phase 3.

---
*Phase: 06-gap-closure-fixes*
*Completed: 2026-02-01*
