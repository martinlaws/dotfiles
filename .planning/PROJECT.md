# Mac Setup Automation

## What This Is

A Mac setup automation system that transforms setting up a new Mac from a painful chore into a delightful guided experience. It manages dotfiles through symlinks, installs curated tools and apps, and applies system preferences with a beautiful CLI interface that makes you feel in control.

## Core Value

New Mac setup should be delightful and maintainable, not confusing and broken.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Symlink dotfiles automatically (.gitconfig, .zshrc, .hyper.js, starship.toml, .ssh/config, Cursor settings)
- [ ] Install CLI tools (nodejs, npm, yarn, pnpm, tree, gh, git)
- [ ] Install curated apps with option to select all or pick individually
- [ ] Apply system settings with preview and confirmation (mouse speed, keyboard, screenshots, etc.)
- [ ] Auto-detect SSH keys, prompt to generate if missing
- [ ] Configure Git from dotfiles .gitconfig or prompt for name/email
- [ ] Beautiful CLI with colors, progress indicators, clear sections, and helpful emojis
- [ ] Idempotent - safe to re-run without breaking existing setup
- [ ] Update mode for maintaining setup over time
- [ ] Apple Silicon compatible (correct Homebrew paths)
- [ ] Auto-install Xcode Command Line Tools (required for development)
- [ ] Clear directory structure (dotfiles/, config/, setup script)
- [ ] Guided walkthrough - prompts for major steps, user feels in control

### Out of Scope

- Cross-platform support (Windows/Linux) — Mac-only tool, complexity not justified
- GUI interface — CLI is the right tool for this job
- Cloud sync of settings — Local dotfiles repo is simpler and more reliable
- Automatic updates — User controls when to run setup/updates
- Package manager choice — Homebrew is the standard, no need to support alternatives

## Context

**Current situation:**
- Brand new Mac Studio (Apple Silicon) with only iCloud login completed
- Existing dotfiles repo with confusing setup script that doesn't symlink dotfiles
- Setup script and dotfiles have diverged - unclear how they relate
- Need to test new setup on fresh machine

**Development workflow:**
- Primary editor: Cursor
- Terminal: Hyper with Starship prompt
- Node.js ecosystem: pnpm (daily driver), npm/yarn for client projects
- Version control: Git with GitHub (gh CLI)

**Critical apps (20+ total):**
- Browsers: Dia (primary), Chrome (secondary)
- Dev: Cursor, Hyper, GitHub Desktop (via gh)
- Communication: Slack, Discord, Zoom, Tuple
- Creative: Figma Beta, Descript, Notion
- Utilities: Raycast, Superwhisper, Opal Composer
- Personal: Spotify, Steam, Battle.net, Bambu Studio

**System settings priorities:**
- Mouse and trackpad speed (currently too slow by default)
- Keyboard repeat rate (press-and-hold disabled, faster repeat)
- Screenshot location (~/Desktop/Screenshots, PNG format)
- Finder preferences (show extensions, column view, no .DS_Store on network)
- Dock behavior (auto-hide, optimal size, fast animations)
- Safari/Chrome settings (disable backswipe, enable dev tools)

## Constraints

- **Platform**: macOS only — Apple Silicon Mac Studio is primary target
- **Homebrew path**: Must use `/opt/homebrew` for Apple Silicon (not `/usr/local`)
- **Fresh machine compatible**: Must work on brand new Mac with only iCloud login
- **Maintainability**: Must be clear enough to understand and modify 6 months from now
- **Idempotent**: Must be safe to re-run without manual cleanup

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Guided walkthrough vs full automation | User wants to feel in control, not have things happen magically behind their back | — Pending |
| Symlinks vs copies for dotfiles | Symlinks keep dotfiles repo as source of truth, easy to update and commit changes | — Pending |
| Shell script vs tool (Python/Go/etc.) | Shell script is simpler, no runtime dependencies, easier to customize | — Pending |
| Monorepo structure (dotfiles/ and config/ separated) | Clear separation makes it obvious what gets symlinked vs what configures setup | — Pending |

---
*Last updated: 2026-02-01 after initialization*
