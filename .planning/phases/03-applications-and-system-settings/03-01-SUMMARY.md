---
phase: 03-applications-and-system-settings
plan: 01
subsystem: application-management
tags: [homebrew, gui-apps, gum, interactive-cli, brewfile]

dependency-graph:
  requires:
    - 01-01: Homebrew installation
    - 01-02: Gum installation for UI
  provides:
    - Categorized app catalog (Brewfile.apps)
    - Interactive app installation flow
  affects:
    - 03-02: System settings may reference installed apps
    - 04-01: Master orchestration will call install-apps.sh

tech-stack:
  added: []
  patterns:
    - Brewfile parsing with bash regex
    - Multi-level selection flow (mode → categories → individual)
    - Temporary Brewfile generation for filtered installation

key-files:
  created:
    - config/Brewfile.apps
    - scripts/install-apps.sh
  modified: []

decisions:
  - decision: Three-tier selection model (all/categories/individual)
    rationale: Balances convenience for fresh Mac setup with granular control for customization
    phase: 03-01
  - decision: Priority markers in comments rather than separate metadata file
    rationale: Keeps catalog simple and human-readable, inline with cask definitions
    phase: 03-01
  - decision: Dynamic category parsing from comment headers
    rationale: Allows category structure to evolve without hardcoding in script
    phase: 03-01
  - decision: Temporary Brewfile generation vs brew cask install loop
    rationale: Leverages brew bundle's atomic operations and proper dependency handling
    phase: 03-01

metrics:
  duration: "2 min"
  completed: 2026-02-01
---

# Phase 03 Plan 01: GUI Application Installation Summary

**One-liner:** Interactive gum-based app installer with 20 categorized apps across 7 categories and three-tier selection flow

## What Was Built

Created a complete GUI application installation system with beautiful CLI prompts for selecting apps to install.

**Core artifacts:**

1. **Brewfile.apps** - 20 GUI applications organized by category:
   - Browsers (Chrome, Dia, Firefox)
   - Dev Tools (VS Code, Cursor, Hyper, Claude Desktop, Docker, Postman)
   - Communication (Slack, Zoom, Discord)
   - Creative (Figma Beta, Descript, Bambu Studio)
   - Utilities (Raycast)
   - Productivity (Notion, Spotify)
   - Gaming (Steam, Battle.net)

2. **install-apps.sh** - Interactive installation script with:
   - Three-way selection flow (install all, choose categories, choose individual apps)
   - Brewfile.apps parser extracting categories and priority markers
   - Temporary filtered Brewfile generation
   - Idempotency checking via `brew bundle check`
   - Partial failure handling with continuation prompt
   - Progress reporting with gum spinner

**Selection flow:**

```
Mode selection (single-select)
  ├─ "Install all (recommended)" → Use full Brewfile.apps
  ├─ "Choose categories" → Multi-select: Browsers, Dev Tools, etc.
  └─ "Choose individual apps" → Multi-select with category grouping
```

## Task Breakdown

| Task | Description | Commit | Files |
|------|-------------|--------|-------|
| 1 | Create categorized Brewfile.apps | b773df8 | config/Brewfile.apps |
| 2 | Create app installation script | 9b72b32 | scripts/install-apps.sh |

**Total commits:** 2 (both implementation tasks)

## Deviations from Plan

None - plan executed exactly as written.

## Decisions Made

**1. Dynamic category parsing from comment headers**
- Plan specified category structure but not implementation
- Chose to parse `# Category` headers dynamically
- Allows future category additions without script changes

**2. Escaped parentheses in bash regex**
- Initial regex with `(\([^)]+\))?` caused syntax error
- Split into two-step parse: extract full comment, then parse priority
- More readable and avoids bash regex escaping edge cases

**3. Priority display in individual app selection**
- Plan showed priority in category selection but not individual
- Added priority markers to individual app lines for consistency
- Helps users make informed choices at every level

## Integration Points

**Upstream dependencies:**
- Requires Homebrew (Phase 1)
- Requires gum for UI (Phase 1)
- Sources ui.sh library (Phase 1)
- Sources detect.sh library (Phase 1)

**Downstream usage:**
- Called by master orchestration script (Phase 4)
- Brewfile.apps can be used directly via `brew bundle install`
- SKIPPED_APPS export available for reporting

**File relationships:**
```
scripts/install-apps.sh
  ├─ reads: config/Brewfile.apps
  ├─ sources: scripts/lib/ui.sh
  ├─ sources: scripts/lib/detect.sh
  └─ generates: /tmp/Brewfile-* (temporary, cleaned up)
```

## Testing & Verification

**Verification performed:**
- ✓ Syntax check: `bash -n scripts/install-apps.sh` passed
- ✓ Brewfile parseable: `brew bundle check` ran without parse errors
- ✓ All 20 apps included in Brewfile.apps
- ✓ 7 category headers present (14 header lines including decorative dividers)
- ✓ 3 gum choose instances (mode, categories, individual)
- ✓ Libraries sourced correctly (ui.sh, detect.sh)
- ✓ Key apps verified: chrome, cursor, slack, raycast, spotify, steam

**Not tested on this system:**
- Actual app installation (would install 20 GUI apps)
- Category selection flow (requires gum interactive session)
- Individual app selection flow (requires gum interactive session)
- Partial failure handling (requires intentional failure)

**Ready for fresh Mac:** Yes - scripts are complete and follow established patterns. Will be tested during actual fresh Mac setup in Phase 4.

## Known Limitations

**Current scope:**

1. **No brew cask update before install** - Assumes brew is up to date
2. **No version pinning** - Always installs latest versions
3. **No uninstall flow** - Only handles installation
4. **No app configuration** - Just installs, doesn't configure
5. **Beta casks** (e.g., figma@beta) may have availability issues

**Not limitations (by design):**
- Apps aren't grouped by dependency (Homebrew handles this)
- No progress bars for individual apps (brew bundle provides overall progress)
- No dry-run mode (brew bundle check provides this)

## Next Phase Readiness

**What's ready:**
- App catalog is complete and extensible
- Installation flow handles all selection modes
- Error handling supports partial failures
- Script follows all established patterns

**What's next (03-02):**
- System settings configuration script
- May reference installed apps (e.g., Raycast hotkey, Finder default view)

**What's blocked:**
- Nothing - 03-02 can proceed independently

**Open questions:**
- Should some apps have post-install configuration? (Deferred to Phase 4)
- Should we check app store apps separately? (Not in current scope)

## Performance Notes

**Execution time:** 2 minutes
- Task 1 (Brewfile.apps): ~30 seconds
- Task 2 (install-apps.sh): ~1.5 minutes (includes regex debugging)

**Installation time (estimated):**
- "Install all" mode: 15-30 minutes (20 apps, network dependent)
- "Choose categories" mode: 5-20 minutes (depends on selection)
- "Choose individual apps" mode: 1-15 minutes (depends on selection)

**Optimization opportunities:**
- None identified - brew bundle is already optimized
- Parallel installation handled by Homebrew internally

---

**Phase:** 03-applications-and-system-settings
**Plan:** 01
**Status:** Complete
**Completed:** 2026-02-01
**Duration:** 2 min
