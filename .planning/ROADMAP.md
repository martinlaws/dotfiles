# Roadmap: Mac Setup Automation

## Overview

Transform Mac setup from painful manual chore into delightful automated experience through four focused phases: establish foundation with Homebrew and development tools, automate dotfiles symlinking with SSH/Git configuration, install GUI applications with beautiful CLI prompts, and enable safe re-run for long-term maintenance. Each phase delivers complete, testable capability that builds toward the core value of making new Mac setup delightful and maintainable.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Foundation & Core Tools** - Homebrew installation, CLI tools, beautiful interface setup
- [x] **Phase 2: Dotfiles & Developer Config** - Symlink dotfiles, SSH keys, Git configuration
- [x] **Phase 3: Applications & System Settings** - GUI apps installation, macOS preferences
- [ ] **Phase 4: Maintenance & Updates** - Idempotent re-run, update mode

## Phase Details

### Phase 1: Foundation & Core Tools
**Goal**: User can run setup script on fresh Mac and get Homebrew with essential CLI tools installed
**Depends on**: Nothing (first phase)
**Requirements**: PKG-01, PKG-02, PKG-05, UX-01, UX-02, UX-03, UX-04, MAINT-03
**Success Criteria** (what must be TRUE):
  1. User runs ./setup on brand new Mac and sees beautiful CLI interface with progress indicators
  2. Homebrew installs to correct path for Apple Silicon (/opt/homebrew) or Intel (/usr/local)
  3. Xcode Command Line Tools install automatically without manual intervention
  4. Essential CLI tools (git, nodejs, pnpm, gh, tree, gum, stow) are available in PATH
  5. Project has clear directory structure (dotfiles/, config/, scripts/, setup entry point)
**Plans**: 4 plans (2 original + 2 gap closure)

Plans:
- [x] 01-01-PLAN.md — Project structure and Homebrew installation with beautiful UI
- [x] 01-02-PLAN.md — CLI tools installation and completion report
- [x] 01-03-PLAN.md — [GAP CLOSURE] Fix UI fallback artifacts and defensive Homebrew check
- [x] 01-04-PLAN.md — [GAP CLOSURE] Fix Xcode CLT auto-installation and Homebrew password prompt

### Phase 2: Dotfiles & Developer Config
**Goal**: User's dotfiles are symlinked and development environment is configured with SSH/Git
**Depends on**: Phase 1
**Requirements**: DOT-01, DOT-02, DOT-03, DOT-04, DOT-05, DOT-06, DEV-01, DEV-02, DEV-03, DEV-04
**Success Criteria** (what must be TRUE):
  1. Shell configs (.zshrc, starship.toml) are symlinked and active when user opens new terminal
  2. Git config (.gitconfig) is symlinked and git commands use correct name/email
  3. Terminal config (.hyper.js) is symlinked and Hyper launches with correct settings
  4. SSH config (.ssh/config) is symlinked and SSH connections use configured hosts
  5. Cursor/VS Code settings are symlinked and editor opens with correct preferences
  6. Local overrides (.zshrc.local) work for machine-specific settings without conflicting with symlinks
  7. SSH keys exist or user is guided to generate them during setup
  8. Git is configured from .gitconfig or user is prompted for name/email if missing
**Plans**: 3 plans

Plans:
- [x] 02-01-PLAN.md — Reorganize dotfiles for Stow and create symlink script
- [x] 02-02-PLAN.md — SSH key setup and Git configuration scripts
- [x] 02-03-PLAN.md — Integration into setup flow and completion verification

### Phase 3: Applications & System Settings
**Goal**: User's curated apps are installed and macOS preferences match their workflow
**Depends on**: Phase 2
**Requirements**: PKG-03, PKG-04, SYS-01, SYS-02, SYS-03, SYS-04, SYS-05, SYS-06, SYS-07
**Success Criteria** (what must be TRUE):
  1. User can choose to install all apps or select individually via beautiful CLI prompts
  2. All selected GUI apps (browsers, dev tools, communication, creative, utilities) are installed and launchable
  3. Mouse and trackpad speed are set to user's preferred fast settings
  4. Keyboard repeat rate is fast and press-and-hold is disabled
  5. Screenshots save to ~/Desktop/Screenshots in PNG format
  6. Finder shows file extensions, uses column view, and doesn't create .DS_Store on network drives
  7. Dock auto-hides with optimal size and fast animations
  8. User previews system settings changes before they are applied
  9. User can customize which system settings to apply
**Plans**: 3 plans

Plans:
- [x] 03-01-PLAN.md — GUI application installation with selection flow (all/categories/individual)
- [x] 03-02-PLAN.md — macOS system settings configuration with preview
- [x] 03-03-PLAN.md — Integration into setup flow and completion report

### Phase 4: Maintenance & Updates
**Goal**: User can safely re-run setup to update packages and configs without breaking existing setup
**Depends on**: Phase 3
**Requirements**: MAINT-01, MAINT-02
**Success Criteria** (what must be TRUE):
  1. Running setup script multiple times is safe and doesn't duplicate configs or break symlinks
  2. Setup script detects existing installation and switches to update mode
  3. Update mode upgrades Homebrew packages and refreshes symlinks without prompting for already-configured settings
  4. User can run setup months later to maintain their Mac without manual intervention
**Plans**: 3 plans

Plans:
- [ ] 04-01-PLAN.md — State management and backup infrastructure
- [ ] 04-02-PLAN.md — Update category scripts (Homebrew, dotfiles, system, apps)
- [ ] 04-03-PLAN.md — Integration into setup entry point and completion report

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation & Core Tools | 4/4 | Complete | 2026-02-01 |
| 2. Dotfiles & Developer Config | 3/3 | Complete | 2026-02-01 |
| 3. Applications & System Settings | 3/3 | Complete | 2026-02-01 |
| 4. Maintenance & Updates | 0/3 | Planned | - |

---
*Roadmap created: 2026-02-01*
*Last updated: 2026-02-01* (Phase 4 planned)
