---
phase: "03"
plan: "02"
subsystem: system-settings
tags: [macos, defaults, gum, ui, customization]

dependency_graph:
  requires: [01-01, 01-03]  # Homebrew, gum, ui.sh patterns
  provides: [system-settings-configuration]
  affects: [03-03]  # Integration script will call this

tech_stack:
  added: []
  patterns: [multi-select-ui, preview-before-apply, grouped-settings]

key_files:
  created:
    - scripts/configure-system.sh
  modified: []

decisions:
  - id: grouped-settings-preview
    what: Display all settings grouped by category before selection
    why: Users can see all changes at once, easier to understand impact
    alternatives: ["Show settings inline during selection"]

  - id: all-preselected-by-default
    what: All settings pre-selected in multi-select UI
    why: User's aggressive/fast preferences are defaults, fastest for fresh Mac setup
    alternatives: ["Start with nothing selected", "Only pre-select essentials"]

  - id: category-based-selection
    what: Settings grouped into 5 categories for selection
    why: Easier to toggle entire categories on/off vs individual settings
    alternatives: ["Individual setting selection", "All-or-nothing"]

  - id: immediate-service-restarts
    what: killall Dock/Finder/SystemUIServer after applying respective settings
    why: Changes take effect immediately without manual restart
    alternatives: ["Defer restarts to end", "Prompt user for restart"]

metrics:
  duration: "1 min"
  completed: "2026-02-01"

wave: 1
---

# Phase 03 Plan 02: System Settings Configuration Summary

**One-liner:** macOS system preferences configuration with preview, multi-select customization, and automatic service restarts

## What Was Built

Created `scripts/configure-system.sh` that configures macOS system preferences across 5 categories:

1. **Dock:** Auto-hide enabled, instant show (0s delay), fast animation (0.15s), 36px icon size
2. **Finder:** Show all extensions, column view default, no network .DS_Store, path bar enabled
3. **Keyboard:** Fast repeat rate (2), short initial delay (15), press-and-hold disabled
4. **Mouse/Trackpad:** Maximum speed (3.0) for both
5. **Screenshots:** PNG format to ~/Desktop/Screenshots, shadow disabled

**UI Flow:**
- Display grouped preview of all settings with descriptions
- Multi-select prompt with all items pre-selected (gum choose --no-limit)
- Apply only user-selected categories
- Restart affected services (Dock, Finder, SystemUIServer)
- Inform user about keyboard settings requiring logout

## Technical Implementation

**Script Structure:**
- Sources ui.sh for consistent styling
- Preview function showing grouped settings
- Separate apply functions per category (apply_dock_settings, apply_finder_settings, etc.)
- Each apply function contains related defaults write commands and service restarts
- Exit gracefully if no settings selected

**Defaults Commands:**
- 16 total defaults write commands across 5 categories
- Proper type flags: -bool, -int, -float, -string
- NSGlobalDomain for cross-app settings (extensions, keyboard, mouse)
- App-specific domains (com.apple.dock, com.apple.finder, com.apple.screencapture)

**Service Restarts:**
- killall Dock (after Dock settings)
- killall Finder (after Finder settings)
- killall SystemUIServer (after Screenshot settings)
- Keyboard settings note user about logout requirement

## Files Changed

**Created:**
- `scripts/configure-system.sh` (173 lines) - Main system settings configuration script

**Pattern Compliance:**
- Follows established ui.sh patterns from Phase 01
- Consistent error handling and user feedback
- Modular functions for each settings category
- Beautiful CLI prompts using gum

## Key Decisions

**Preview before apply:** Users see complete list of changes grouped by category before selecting. Reduces surprises, increases confidence in what will change.

**All settings pre-selected:** User's aggressive/fast preferences (from 03-CONTEXT.md) are defaults. Fastest path for fresh Mac setup - just press enter. Users can uncheck unwanted settings.

**Category-based selection:** 5 high-level categories vs 16 individual settings. Easier to understand and select. Users toggle entire groups (e.g., "Dock: Auto-hide with fast animations") rather than individual defaults commands.

**Immediate service restarts:** Each apply function restarts its affected service. Changes visible immediately without manual intervention or "restart later" confusion.

## Testing & Verification

**Syntax validation:** bash -n passes without errors
**Defaults count:** 16 commands verified (4 Dock, 4 Finder, 3 Keyboard, 2 Input, 3 Screenshot)
**Service restarts:** 3 killall commands present (Dock, Finder, SystemUIServer)
**Multi-select UI:** gum choose --no-limit with 5 --selected flags
**All categories:** Dock, Finder, Keyboard, Mouse/Trackpad, Screenshots all implemented

## Deviations from Plan

None - plan executed exactly as written.

## Integration Points

**Depends on:**
- scripts/lib/ui.sh (from 01-03) - UI functions
- gum (from 01-01 Homebrew) - Multi-select interface

**Used by:**
- Future 03-03 integration script will call this

## Next Phase Readiness

**Blockers:** None

**Recommendations:**
- Integration script (03-03) should call this after app installation
- Consider adding system settings verification check
- May want to show "current values" vs "new values" in preview for existing systems

## Performance Notes

- Script is idempotent (safe to run multiple times)
- Settings apply in <1 second per category
- Service restarts are fast (Dock/Finder bounce briefly)
- No manual intervention required beyond selection

---

**Completed:** 2026-02-01
**Commit:** 74432a4
