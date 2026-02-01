---
phase: 02-dotfiles-developer-config
plan: 01
subsystem: dotfiles
tags: [stow, dotfiles, shell, git, vscode, ssh, symlinks]

# Dependency graph
requires:
  - phase: 01-foundation
    provides: Script patterns, ui.sh library
provides:
  - Stow-compatible dotfiles package structure
  - Symlink script with backup functionality
  - Template-based git configuration
  - Local override pattern for machine-specific config
affects: [02-02, 02-03, all-phases]

# Tech tracking
tech-stack:
  added: [GNU Stow]
  patterns: [Package-based dotfiles, template generation, local overrides]

key-files:
  created:
    - dotfiles/shell/.zshrc
    - dotfiles/shell/.config/starship.toml
    - dotfiles/shell/.vimrc
    - dotfiles/git/.gitconfig.template
    - dotfiles/git/.gitignore_global
    - dotfiles/terminal/.hyper.js
    - dotfiles/editors/Library/Application Support/Code/User/settings.json
    - dotfiles/ssh/.ssh/config
    - scripts/symlink-dotfiles.sh
    - .gitignore
  modified: []

key-decisions:
  - "Use GNU Stow for symlink management instead of custom script"
  - "Template-based .gitconfig with {{NAME}}/{{EMAIL}} placeholders"
  - "Local override pattern (*.local files) for machine-specific config"
  - "VS Code settings at macOS path (Library/Application Support) not Linux path (.config)"

patterns-established:
  - "Package structure: Each dotfiles package mirrors home directory structure"
  - "Backup pattern: Timestamped backups before symlinking"
  - "Local overrides: .local files sourced at end of configs, gitignored"

# Metrics
duration: 2min
completed: 2026-02-01
---

# Phase 2 Plan 1: Stow Package Structure Summary

**Dotfiles reorganized into GNU Stow packages with template-based git config and local override pattern**

## Performance

- **Duration:** 2 minutes
- **Started:** 2026-02-01T18:34:11Z
- **Completed:** 2026-02-01T18:36:37Z
- **Tasks:** 2
- **Files modified:** 15 (9 moves, 6 creates)

## Accomplishments
- Reorganized dotfiles into 5 stow-compatible packages (shell, git, terminal, editors, ssh)
- Converted .gitconfig to template with {{NAME}}/{{EMAIL}} placeholders for multi-machine use
- Established local override pattern (*.local files) for machine-specific config
- Created symlink script with backup functionality to prevent data loss

## Task Commits

Each task was committed atomically:

1. **Task 1: Reorganize dotfiles into Stow package structure** - `5550435` (refactor)
2. **Task 2: Create symlink script with backup and stow** - `db2a3d3` (feat)

## Files Created/Modified

### Created
- `dotfiles/shell/.zshrc` - Shell configuration with local override pattern
- `dotfiles/shell/.config/starship.toml` - Starship prompt config (nested .config path)
- `dotfiles/shell/.vimrc` - Vim configuration
- `dotfiles/git/.gitconfig.template` - Git config with {{NAME}}/{{EMAIL}} placeholders
- `dotfiles/git/.gitignore_global` - Global git ignore patterns
- `dotfiles/terminal/.hyper.js` - Hyper terminal configuration
- `dotfiles/editors/Library/Application Support/Code/User/settings.json` - VS Code settings (macOS path)
- `dotfiles/ssh/.ssh/config` - SSH config with keychain integration and GitHub settings
- `scripts/symlink-dotfiles.sh` - Symlink management script with backup functionality
- `.gitignore` - Repo-level gitignore for *.local files

### Removed
- Old directory structure: `zsh/`, `git/`, `hyper/`, `starship/`, `vscode/`, `vim/`

## Decisions Made

**1. GNU Stow for symlink management**
- Rationale: Industry-standard tool, handles nested directory structures correctly, prevents accidental overwrites
- Alternative considered: Custom symlink script (more complexity, reinventing wheel)

**2. Template-based .gitconfig with placeholders**
- Rationale: Same dotfiles work across multiple machines with different user names/emails
- Pattern: {{NAME}} and {{EMAIL}} placeholders replaced by setup-git.sh script

**3. Local override pattern with *.local files**
- Rationale: Machine-specific config (API keys, local paths) without polluting shared dotfiles
- Implementation: .zshrc sources ~/.zshrc.local if exists, .ssh/config includes ~/.ssh/config.local
- All *.local files gitignored at repo root

**4. VS Code settings at macOS path, not Linux path**
- Rationale: VS Code uses ~/Library/Application Support/Code/User on macOS, not ~/.config
- Decision: Mirror exact macOS path structure in stow package for correct symlinks

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## Next Phase Readiness

**Ready for Plan 02-02 (Git setup script):**
- .gitconfig.template ready for placeholder replacement
- Symlink script ready for integration into main setup flow

**Ready for Plan 02-03 (Development tools):**
- Package structure established for adding more tools
- Symlink script handles all current packages

**Blockers/Concerns:**
- None. GNU Stow must be installed (added to Brewfile in Plan 01-02).

---
*Phase: 02-dotfiles-developer-config*
*Completed: 2026-02-01*
