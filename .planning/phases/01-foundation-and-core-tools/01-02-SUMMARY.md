---
phase: 01-foundation-and-core-tools
plan: 02
subsystem: infra
tags: [homebrew, cli-tools, shell, setup, automation]

# Dependency graph
requires:
  - phase: 01-01
    provides: "Homebrew installation and project structure"
provides:
  - "CLI tools installation via Brewfile (git, node, pnpm, gh, tree, gum, stow)"
  - "Completion report showing installed tools with versions"
  - "Complete Phase 1 setup flow from fresh Mac to working development environment"
affects: [02-dotfiles-and-symlinks, 03-git-and-github, 04-shell-customization]

# Tech tracking
tech-stack:
  added: [git, node, pnpm, gh, tree, gum, stow]
  patterns:
    - "Idempotent installation with brew bundle check"
    - "Graceful degradation for UI when gum not yet installed"
    - "Per-tool failure handling with user prompts"
    - "Completion report with dynamic version detection"

key-files:
  created:
    - scripts/install-tools.sh
    - scripts/show-report.sh
  modified:
    - setup
    - scripts/install-homebrew.sh
    - scripts/lib/ui.sh

key-decisions:
  - "Use brew bundle check for idempotency (fast skip when all tools installed)"
  - "Graceful UI degradation with ANSI fallbacks before gum installed"
  - "Simplified Xcode CLT detection (removed confusing softwareupdate logic)"
  - "Create .zprofile if missing to ensure shell config exists"
  - "Per-tool failure handling (prompt user, track skipped tools)"

patterns-established:
  - "Idempotent script pattern: check before install, return early if satisfied"
  - "UI function pattern: check for gum availability, fallback to ANSI codes"
  - "Progress display pattern: spinner for quiet mode, full output for verbose mode"
  - "Completion report pattern: dynamic version detection, clear sections"

# Metrics
duration: 10min
completed: 2026-02-01
---

# Phase 1 Plan 2: CLI Tools Installation Summary

**Complete Phase 1 foundation: CLI tools installation via Brewfile, idempotent setup flow, and beautiful completion report with fallback UI**

## Performance

- **Duration:** 10 min
- **Started:** 2026-02-01T14:07:48Z
- **Completed:** 2026-02-01T14:20:09Z (includes checkpoint verification)
- **Tasks:** 2 (1 auto + 1 checkpoint:human-verify)
- **Files modified:** 6

## Accomplishments

- CLI tools installation via brew bundle with progress indicators
- Idempotent setup flow (skips already-installed tools)
- Beautiful completion report showing all tools with versions
- Graceful UI degradation for scripts running before gum is installed
- Fixed three critical bugs discovered during verification (Xcode CLT detection, gum fallbacks, shell config)

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement CLI tools installation with progress and error handling** - `494359c` (feat)
2. **Bug fixes during verification** - `79c8e7d` (fix)

## Files Created/Modified

- `scripts/install-tools.sh` - CLI tools installation via brew bundle with idempotency checks
- `scripts/show-report.sh` - Phase 1 completion report with tool versions and next steps
- `setup` - Updated to call install-tools.sh and show-report.sh
- `scripts/install-homebrew.sh` - Fixed Xcode CLT detection and shell config creation
- `scripts/lib/ui.sh` - Added gum fallback functions for all UI operations

## Decisions Made

1. **Idempotency via brew bundle check**: Fast detection of already-installed tools without expensive re-checks
2. **Graceful UI degradation**: All ui_* functions check for gum availability and fallback to ANSI codes, allowing scripts to work before gum is installed
3. **Simplified Xcode CLT detection**: Removed confusing softwareupdate logic that showed "No such update" messages, simplified to single clear detection path
4. **Create .zprofile if missing**: Ensures shell config file exists for Homebrew path configuration

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed Xcode CLT detection showing confusing messages**
- **Found during:** Task 2 (human verification checkpoint)
- **Issue:** Xcode CLT detection used softwareupdate logic that showed "No such update" even when CLT was installed, causing user confusion. Also showed BOTH success and failure messages.
- **Fix:** Simplified to single detection path using `xcode-select -p` with clear messaging. Shows only ONE status message.
- **Files modified:** scripts/install-homebrew.sh
- **Verification:** User confirmed detection now works correctly and shows clear status
- **Committed in:** 79c8e7d (fix commit)

**2. [Rule 2 - Missing Critical] Added gum fallback functions for all UI operations**
- **Found during:** Task 2 (human verification checkpoint)
- **Issue:** ui_* functions failed when called before gum was installed. Scripts that run early in setup (like install-homebrew.sh) couldn't use UI functions.
- **Fix:** Added `command -v gum` checks to every ui_* function with ANSI color code fallbacks. Allows all scripts to work both before and after gum installation.
- **Files modified:** scripts/lib/ui.sh
- **Verification:** User confirmed scripts work correctly before gum installed
- **Committed in:** 79c8e7d (fix commit)

**3. [Rule 1 - Bug] Fixed shell config not being created/updated**
- **Found during:** Task 2 (human verification checkpoint)
- **Issue:** Shell config (.zprofile) wasn't created if missing, and wasn't updated when Homebrew already installed. Report used wrong grep flag (-qF instead of -q).
- **Fix:** Create .zprofile if doesn't exist, update shell config even when Homebrew already installed, fix grep flag in show-report.sh
- **Files modified:** scripts/install-homebrew.sh, scripts/show-report.sh
- **Verification:** User confirmed shell config properly created and updated
- **Committed in:** 79c8e7d (fix commit)

---

**Total deviations:** 3 auto-fixed (2 bugs, 1 missing critical functionality)
**Impact on plan:** All fixes necessary for correct operation and good user experience. No scope creep - these were correctness issues discovered during verification.

## Issues Encountered

**Checkpoint revealed three issues:**
1. Xcode CLT detection confusing (fixed via simplified logic)
2. UI functions failed before gum installed (fixed via fallback pattern)
3. Shell config not created/updated properly (fixed via file creation and idempotency fix)

All issues resolved in single fix commit 79c8e7d, user re-verified and approved.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

**Phase 1 Complete:** Foundation is ready.

- All CLI tools installed and available in PATH
- Setup flow is idempotent (can be re-run safely)
- UI is beautiful with graceful degradation
- Completion report provides clear feedback
- Project structure established (setup, scripts/lib/, config/)

**Ready for Phase 2:** Dotfiles and symlinks
- Stow is installed (ready for symlink management)
- Git is installed (ready for configuration)
- Foundation scripts can be reused as patterns

**No blockers or concerns.**

---
*Phase: 01-foundation-and-core-tools*
*Completed: 2026-02-01*
