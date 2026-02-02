---
phase: 04-maintenance-and-updates
plan: 04
subsystem: scripts
tags: [bash, bugfix, function-order, update-mode]

requires:
  - 04-01-PLAN.md # State management infrastructure
  - 04-02-PLAN.md # Update detection scripts
  - 04-03-PLAN.md # Update mode integration

provides:
  - Working show-report.sh with correct function ordering
  - show_update_report callable in UPDATE_MODE=true
  - show_first_time_report callable in default mode

affects:
  - UAT Test 1 (now unblocked and passing)
  - setup script (update mode now functional)

tech-stack:
  added: []
  patterns:
    - Function definitions before calls (bash best practice)

key-files:
  created: []
  modified:
    - scripts/show-report.sh

decisions:
  - id: func-order-fix
    what: Reordered functions before mode routing
    why: Bash requires function definitions before calls
    impact: Unblocks UAT Test 1, enables update mode functionality

metrics:
  duration: 1 minute
  completed: 2026-02-02
---

# Phase [4] Plan [04]: Function Order Fix Summary

Fixed "command not found" error in show-report.sh by reordering function definitions before mode routing logic.

## What Was Built

**Gap Closure:** Resolved UAT Test 1 blocker preventing update mode from working.

### Changes Made

**scripts/show-report.sh restructured:**

1. Source libraries (lines 1-16) - unchanged
2. **show_first_time_report() definition** (lines 20-247) - moved up
3. **show_update_report() definition** (lines 250-331) - moved up
4. **Mode routing logic** (lines 334-338) - moved down
5. exit 0 (line 340)

**Root cause fixed:** Function call at line 19 attempted to call show_update_report before it was defined at line 254.

**No function internals changed** - purely structural reordering.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added execute permission to show-report.sh**

- **Found during:** Task 1 verification
- **Issue:** File had 644 permissions, preventing execution during testing
- **Fix:** Added chmod +x to make script executable
- **Files modified:** scripts/show-report.sh
- **Commit:** Included in 15473c1 (mode change 100644 => 100755)

No other deviations - plan executed as written.

## Verification Results

All verification checks passed:

1. **Syntax validation:**
   - `UPDATE_MODE=true bash -n scripts/show-report.sh` → Syntax OK
   - `bash -n scripts/show-report.sh` → Syntax OK

2. **Update mode execution:**
   - `UPDATE_MODE=true ./scripts/show-report.sh` → Shows "Update Complete" header
   - No "command not found" error

3. **Default mode execution:**
   - `./scripts/show-report.sh` → Shows "Setup Complete: Mac Ready" header
   - Both function calls work correctly

4. **UAT Test 1 status:** Blocker resolved, ready for re-test

## Implementation Details

### File Structure Changes

**Before (broken):**
```
Lines 1-16:   Library sources
Lines 17-21:  Mode check + call show_update_report ← ERROR HERE
Lines 24-251: show_first_time_report definition
Lines 254-335: show_update_report definition
Lines 337-338: Call show_first_time_report
```

**After (working):**
```
Lines 1-16:   Library sources
Lines 20-247: show_first_time_report definition
Lines 250-331: show_update_report definition
Lines 334-338: Mode routing (calls appropriate function)
Line 340:     exit 0
```

### Technical Notes

- Bash requires functions to be defined before they're called
- Mode routing now happens after both functions are available
- No behavior changes, only structural reordering
- Both UPDATE_MODE=true and default paths verified working

## Decisions Made

| ID | Decision | Rationale |
|----|----------|-----------|
| func-order-fix | Reorder functions before mode routing | Bash requires function definitions before calls; fixes "command not found" error |

## Next Phase Readiness

**Status:** Gap closed successfully

**Blockers removed:**
- UAT Test 1 now unblocked (update mode can execute)
- show_update_report callable in UPDATE_MODE=true
- Full setup script ready for re-testing

**No new blockers introduced.**

## Commits

| Commit | Type | Description | Files |
|--------|------|-------------|-------|
| 15473c1 | fix | Reorder functions before mode routing | scripts/show-report.sh |

**Total:** 1 commit

**Note:** This was a gap closure plan addressing a UAT-discovered blocker.
