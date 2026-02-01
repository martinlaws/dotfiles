# Phase 3: Applications & System Settings - Context

**Gathered:** 2026-02-01
**Status:** Ready for planning

<domain>
## Phase Boundary

Automate installation of GUI applications and configuration of macOS system preferences on a fresh Mac. Users can select apps (all/categories/individual) via beautiful CLI prompts and customize which system settings to apply.

</domain>

<decisions>
## Implementation Decisions

### App selection flow
- Prompt at start: "Install all (recommended) / Choose categories / Choose individual apps"
- Default mode is "Install all" (recommended)
- Category selection uses multi-select checkboxes (show all categories at once, user selects multiple)
- Individual app selection shows apps grouped by category with multi-select checkboxes

### App organization
- Apps organized by function: Browsers, Dev Tools, Communication, Creative, Utilities, Productivity, Gaming
- Each app/category marked with priority: (essential), (recommended), or unmarked (optional)
- Priority labels shown in UI to guide user choices

**App List:**

**Browsers**
- Chrome (essential)
- Dia (recommended) - daily driver
- Firefox (optional)

**Dev Tools**
- VS Code (essential)
- Cursor (recommended)
- Hyper (recommended)
- Claude Desktop (recommended)
- Claude Code (recommended)
- Docker Desktop (optional)
- Postman (optional)

**Communication**
- Slack (essential)
- Zoom (recommended)
- Discord (optional)

**Creative**
- Figma Beta (recommended)
- Descript (optional)
- Bambu Studio (optional)

**Utilities**
- Raycast (recommended)

**Productivity**
- Notion (recommended)
- Spotify (recommended)

**Gaming**
- Steam (optional)
- Battle.net (optional)

### System settings application
- Preview settings before applying: Show all settings grouped by category (Dock, Finder, Keyboard, Mouse/Trackpad, Screenshots)
- Multi-select checkboxes: All checked by default (user's preferences), user can uncheck what they don't want
- Settings grouped by category for easier scanning
- Variable settings (speeds, delays) use preset options with "Aggressive/Fast (recommended)" as default

### Settings customization
- All settings selectable in preview (maximum flexibility)
- User's aggressive/fast preferences pre-selected as defaults
- Preset options for variable settings with recommended default highlighted
- Settings categories: Dock, Finder, Keyboard, Mouse/Trackpad, Screenshots

**Specific settings (all pre-checked by default):**
- Mouse/trackpad: Maximum speed, fast tracking
- Keyboard: Fast repeat rate, minimal delay, press-and-hold disabled
- Screenshots: Save to ~/Desktop/Screenshots, PNG format
- Finder: Show file extensions, column view, no .DS_Store on network drives
- Dock: Auto-hide enabled, fast animations, optimal size

### Claude's Discretion
- Timing of system settings application (before or after apps)
- Exact preset category names (speed-focused vs workflow-focused)
- Specific values for "aggressive/fast" settings (exact mouse speed, keyboard delay numbers)
- Error handling for app installation failures
- Progress reporting during installation

</decisions>

<specifics>
## Specific Ideas

- Beautiful CLI prompts using gum (already established in Phase 1)
- Follow Phase 1 patterns: modular scripts, ui.sh for consistent styling
- Installation mode prompt should feel natural - default to "all" makes setup fastest for fresh Mac
- Priority labels guide users but don't restrict choice - everything is available

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 03-applications-and-system-settings*
*Context gathered: 2026-02-01*
