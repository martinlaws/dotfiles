# Phase 4: Maintenance & Updates - Context

**Gathered:** 2026-02-01
**Status:** Ready for planning

<domain>
## Phase Boundary

Enable safe re-runs of the setup script for ongoing maintenance. Script detects previous installation and switches to update mode, allowing user to update Homebrew packages, refresh dotfile symlinks, reapply system settings, and install new apps/tools without breaking existing setup.

</domain>

<decisions>
## Implementation Decisions

### Update detection & mode switching
- State file tracks: completion timestamps per phase + installed package lists
- State file location: Claude's discretion, but MUST NOT be git-tracked (repo is public)
- Detection method: Check for state file existence to determine first-run vs update mode
- Always confirm before running: Show "Detected previous setup. Run updates?" prompt every time
- Mode is automatic based on state file, but requires user confirmation to proceed

### Update scope & granularity
- Four update categories (all optional via multi-select checklist):
  1. Update Homebrew packages (brew update && brew upgrade)
  2. Refresh dotfile symlinks (re-run stow)
  3. Re-apply system settings (run defaults write commands)
  4. Check for new apps/tools (show what's in Brewfile but not installed)
- All categories shown in multi-select checklist, all pre-selected by default
- User can uncheck any category before updates run
- Manual installs: Detect apps installed but not in Brewfile, offer to add them to Brewfile
- Removed packages: Show packages in Brewfile but no longer installed, offer to either:
  - Reinstall them, or
  - Remove from Brewfile
  User chooses per-package via prompt

### Conflict handling & safety
- Modified dotfiles: Detect if symlink target differs from repo, warn, and offer to move user's edit back to repo before refreshing
- System settings drift: Check current values with 'defaults read', show diffs, prompt before changing
- Always create timestamped backups of configs/settings before any updates
- Homebrew breaking changes: Run 'brew upgrade --dry-run' first, show what would change, require confirmation before applying
- Rollback: Backups available if user needs to revert changes

### Progress reporting & feedback
- Same beautiful UI as first-time setup (gum spinners, progress indicators)
- Completion report shows:
  - What was updated (packages upgraded, configs refreshed, settings reapplied)
  - What was skipped (unselected categories, conflicts, user choices)
  - Time since last update
  - Next recommended update timing
- Logs: Write detailed logs to file automatically (Claude decides location), keep UI clean
- Error handling: Stop on first error, show error clearly, ask user if they want to continue to next category

### Claude's Discretion
- State file location (home directory or XDG, but never git-tracked)
- State file format (JSON recommended but not required)
- Backup directory structure and naming
- Log file location and rotation
- Exact timing for "next recommended update" suggestion
- Exact wording of prompts and confirmations

</decisions>

<specifics>
## Specific Ideas

- State tracking should be robust enough to detect drift (what's actually installed vs what's recorded)
- Offer to sync Brewfile with reality (add manual installs, remove uninstalled packages)
- Error handling should be graceful — user can skip problematic category and continue
- Beautiful UI consistency — updates should feel as polished as first-time setup

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 04-maintenance-and-updates*
*Context gathered: 2026-02-01*
