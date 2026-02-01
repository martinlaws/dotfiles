---
phase: 01-foundation-and-core-tools
plan: 03
subsystem: ui-and-error-handling
type: gap-closure
status: complete
tags:
  - ui
  - error-handling
  - homebrew
  - macos-compatibility
requires:
  - 01-01-PLAN.md
  - 01-02-PLAN.md
provides:
  - Clean UI fallback output without artifacts
  - Defensive Homebrew availability check
affects:
  - All future scripts using ui.sh library
  - Any script depending on Homebrew
tech-stack:
  added: []
  patterns:
    - printf for ANSI escape sequences (macOS compatible)
    - Defensive command availability checks
key-files:
  created: []
  modified:
    - scripts/lib/ui.sh
    - scripts/install-tools.sh
decisions:
  - "Use printf instead of echo -e for ANSI codes to avoid macOS artifacts"
  - "Check brew availability before use to provide helpful error messages"
metrics:
  duration: 2m 5s
  completed: 2026-02-01
---

# Phase 01 Plan 03: UI Fallback Fixes & Homebrew Check Summary

**One-liner:** Fixed echo -e artifacts in UI fallbacks with printf and added defensive Homebrew check with helpful error messages

## What Was Built

### Gap Closures

**Gap 2: UI fallback shows "-e" artifacts on macOS**
- Replaced all `echo -e` statements with `printf` in ui.sh fallback functions
- Fixed: ui_header, ui_section, ui_success, ui_error, ui_info
- Used `%s` format specifier for variable text to prevent format string injection
- Clean colored terminal output now works correctly without gum installed

**Gap 4: install-tools.sh fails confusingly when Homebrew not installed**
- Added defensive check for brew availability at start of install-tools.sh
- Exits early with clear error message if Homebrew not found
- Provides helpful troubleshooting steps (check /opt/homebrew/bin, /usr/local/bin)
- Prevents cascade of confusing "brew: command not found" errors

## Tasks Executed

### Task 1: Replace echo -e with printf in ui.sh
**Files:** scripts/lib/ui.sh
**Commit:** aec979c

Replaced all `echo -e` statements with `printf` in fallback functions:
- ui_header: 3 replacements (border lines and header text)
- ui_section: 1 replacement (bold styled text)
- ui_success: 1 replacement (checkmark + message)
- ui_error: 1 replacement (X + error message)
- ui_info: 1 replacement (info message)

All replacements use `%s` format specifier for variable text to prevent format string injection.

**Verification:** Tested all ui_* functions with gum hidden from PATH - clean colored output with no "-e" artifacts

### Task 2: Add defensive Homebrew check to install-tools.sh
**Files:** scripts/install-tools.sh
**Commit:** a4e7c71

Added Homebrew availability check after library sourcing:
- Uses `command -v brew` to detect availability
- Exits with code 1 and helpful error message if not found
- Provides troubleshooting steps for both Apple Silicon and Intel Macs
- Prevents script from failing with confusing "brew: command not found" errors

**Verification:** Tested with brew hidden from PATH - exits gracefully with clear error message and exit code 1

## Deviations from Plan

None - plan executed exactly as written.

## Decisions Made

1. **Use printf with %s format specifier for variable text**
   - Rationale: Prevents format string injection vulnerabilities
   - Impact: Safer string handling in UI functions
   - Alternative considered: Direct variable interpolation (less safe)

2. **Check brew availability with command -v**
   - Rationale: POSIX-compliant, works in both bash and sh
   - Impact: Portable across different shell environments
   - Alternative considered: type -P (bash-specific)

## Technical Notes

### printf vs echo -e on macOS
macOS's default `/bin/echo` doesn't support the `-e` flag (it prints it literally). The printf command consistently interprets escape sequences across platforms.

### ANSI Escape Code Testing
Verified that ANSI color codes work correctly in fallback mode:
- Green checkmark for success
- Red X for errors
- Pink styling for headers and info
- Bold text where appropriate

### Homebrew Check Placement
Placed the Homebrew check after library sourcing so ui_error function is available for formatted error output, maintaining consistent styling.

## Next Phase Readiness

**Blockers:** None

**Concerns:** None

**Recommendations:**
- Consider adding similar defensive checks for other external dependencies
- Could extract brew check into a reusable function in detect.sh if used elsewhere

## Files Modified

### scripts/lib/ui.sh
- Replaced 7 echo -e statements with printf
- All fallback functions now use printf with %s format specifier
- Clean ANSI output on macOS without gum installed

### scripts/install-tools.sh
- Added Homebrew availability check after library sourcing
- Clear error message with troubleshooting steps
- Graceful failure instead of confusing cascade errors

## Testing Performed

1. UI fallback testing (gum hidden from PATH):
   - ui_success: Clean colored output with checkmark
   - ui_error: Clean colored output with X
   - ui_info: Clean colored output
   - ui_header: Clean colored border and text
   - ui_section: Clean colored bold text
   - No "-e" artifacts visible

2. Homebrew check testing (brew hidden from PATH):
   - install-tools.sh exits with code 1
   - Clear error message displayed
   - Helpful troubleshooting steps shown

3. Normal operation testing (gum and brew available):
   - UI functions work correctly
   - install-tools.sh continues normally
   - No regressions introduced

## Conclusion

Successfully closed gaps 2 and 4 from Phase 1 UAT testing:
- UI fallback output is now clean on macOS without gum
- install-tools.sh fails gracefully with helpful guidance when Homebrew unavailable

Both fixes improve user experience during setup script execution, especially in error scenarios.
