# Mac Setup Automation

## What This Is

A Mac setup automation system that transforms setting up a new Mac from a painful chore into a delightful guided experience. It manages dotfiles through symlinks, installs curated tools and apps, and applies system preferences with a beautiful CLI interface that makes you feel in control.

## Core Value

New Mac setup should be delightful and maintainable, not confusing and broken.

## Requirements

### Validated

- ✓ Symlink dotfiles automatically (.gitconfig, .zshrc, .hyper.js, starship.toml, .ssh/config, Cursor settings) — v1.0
- ✓ Install CLI tools (nodejs, npm, yarn, pnpm, fnm, tree, gh, git, opencode, gum, stow, starship) — v1.0
- ✓ Install curated apps with option to select all or pick individually (21 GUI apps) — v1.0
- ✓ Apply system settings with preview and confirmation (mouse speed, keyboard, screenshots, Finder, Dock) — v1.0
- ✓ Auto-detect SSH keys, prompt to generate if missing — v1.0
- ✓ Configure Git from dotfiles .gitconfig or prompt for name/email — v1.0
- ✓ Beautiful CLI with colors, progress indicators, clear sections, and helpful emojis — v1.0
- ✓ Idempotent - safe to re-run without breaking existing setup — v1.0
- ✓ Update mode for maintaining setup over time — v1.0
- ✓ Apple Silicon compatible (correct Homebrew paths) — v1.0
- ✓ Auto-install Xcode Command Line Tools (required for development) — v1.0
- ✓ Clear directory structure (dotfiles/, config/, scripts/, setup script) — v1.0
- ✓ Guided walkthrough - prompts for major steps, user feels in control — v1.0

### Active

(None - v1.0 complete, define v2.0 requirements if continuing)

### Out of Scope

- Cross-platform support (Windows/Linux) — Mac-only tool, complexity not justified
- GUI interface — CLI is the right tool for this job
- Cloud sync of settings — Local dotfiles repo is simpler and more reliable
- Automatic updates — User controls when to run setup/updates
- Package manager choice — Homebrew is the standard, no need to support alternatives

## Context

**Current State (v1.0 shipped):**
- Mac setup automation system with 19 shell scripts (~2,646 LOC)
- Modular architecture: setup entry point, scripts/lib/ libraries, phase-specific scripts
- Tech stack: Bash 3.2, Homebrew, GNU Stow, Gum (CLI UI)
- 5 stow packages managing dotfiles (shell, git, terminal, editors, ssh)
- 21 GUI apps curated and categorized in Brewfile.apps
- State management in ~/.local/state/dotfiles/ for update mode
- Full Bash 3.2 compatibility after fixing process substitution, nameref, and special character handling

**Development workflow:**
- Primary editor: Cursor
- Terminal: Hyper with Starship prompt
- Node.js: fnm (Fast Node Manager) for version management, pnpm for packages
- Version control: Git with GitHub (gh CLI)

**Installed apps (21 total):**
- Browsers: Arc (primary), Chrome (secondary), Firefox (optional)
- Dev: Cursor, VS Code, Hyper, Claude, OpenCode (CLI + desktop)
- Communication: Slack, Discord, Zoom
- Creative: Figma Beta, Descript, Bambu Studio
- Utilities: Raycast, Superwhisper
- Productivity: Notion, Spotify
- Gaming: Steam, Battle.net

**System settings automated:**
- Mouse/trackpad speed (fast tracking)
- Keyboard repeat rate (fast, press-and-hold disabled)
- Screenshot location (~/Desktop/Screenshots, PNG format)
- Finder preferences (show extensions, column view, no .DS_Store on network)
- Dock behavior (auto-hide, optimal size, fast animations)

## Constraints

- **Platform**: macOS only — Apple Silicon Mac Studio is primary target
- **Homebrew path**: Must use `/opt/homebrew` for Apple Silicon (not `/usr/local`)
- **Fresh machine compatible**: Must work on brand new Mac with only iCloud login
- **Maintainability**: Must be clear enough to understand and modify 6 months from now
- **Idempotent**: Must be safe to re-run without manual cleanup

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Guided walkthrough vs full automation | User wants to feel in control, not have things happen magically behind their back | ✓ Good - User controls each phase, sees progress, can customize selections |
| Symlinks vs copies for dotfiles | Symlinks keep dotfiles repo as source of truth, easy to update and commit changes | ✓ Good - GNU Stow works perfectly, 5 packages cleanly organized |
| Shell script vs tool (Python/Go/etc.) | Shell script is simpler, no runtime dependencies, easier to customize | ✓ Good - Pure Bash works on fresh Mac, no dependencies before Homebrew |
| Monorepo structure (dotfiles/ and config/ separated) | Clear separation makes it obvious what gets symlinked vs what configures setup | ✓ Good - Very clear organization, easy to maintain |
| Bash 3.2 compatibility required | macOS ships with Bash 3.2 (2007), can't rely on newer features | ✓ Good - Fixed all compatibility issues (process substitution, nameref, etc.) |
| Gum for CLI UI with fallbacks | Beautiful interface when available, graceful degradation if not | ✓ Good - Elegant UI with printf fallbacks for early bootstrap |
| Update mode with state management | Safe re-run and maintenance over time | ✓ Good - Drift detection works, state persists in ~/.local/state/ |

---
*Last updated: 2026-02-02 after v1.0 milestone completion*
