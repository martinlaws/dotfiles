# Requirements: Mac Setup Automation

**Defined:** 2026-02-01
**Core Value:** New Mac setup should be delightful and maintainable, not confusing and broken.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Dotfiles Management

- [ ] **DOT-01**: Symlink shell configs (.zshrc, starship.toml)
- [ ] **DOT-02**: Symlink git config (.gitconfig)
- [ ] **DOT-03**: Symlink terminal config (.hyper.js)
- [ ] **DOT-04**: Symlink SSH config (.ssh/config)
- [ ] **DOT-05**: Symlink Cursor/VS Code settings
- [ ] **DOT-06**: Support local overrides (.zshrc.local for machine-specific settings)

### Package Management

- [ ] **PKG-01**: Auto-install Homebrew (with Apple Silicon path detection)
- [ ] **PKG-02**: Install CLI tools via Brewfile (nodejs, npm, yarn, pnpm, tree, gh, git, claude)
- [ ] **PKG-03**: Install GUI apps via Brewfile (Dia, Chrome, Cursor, Hyper, Slack, Discord, Spotify, Raycast, Superwhisper, Opal Composer, Notion, Descript, Bambu Studio, Steam, Zoom, Battle.net, Figma Beta, Tuple)
- [ ] **PKG-04**: Allow user to select all apps or pick individually during setup
- [ ] **PKG-05**: Auto-install Xcode Command Line Tools

### System Configuration

- [ ] **SYS-01**: Apply mouse/trackpad speed settings
- [ ] **SYS-02**: Apply keyboard settings (repeat rate, disable press-and-hold)
- [ ] **SYS-03**: Configure screenshot location (~/Desktop/Screenshots) and format (PNG)
- [ ] **SYS-04**: Apply Finder preferences (show extensions, column view, no .DS_Store on network)
- [ ] **SYS-05**: Apply Dock settings (auto-hide, size, animations)
- [ ] **SYS-06**: Preview system settings changes before applying
- [ ] **SYS-07**: Allow user to customize which settings to apply

### Developer Setup

- [ ] **DEV-01**: Auto-detect existing SSH keys
- [ ] **DEV-02**: Prompt to generate SSH keys if missing
- [ ] **DEV-03**: Configure Git from .gitconfig in dotfiles
- [ ] **DEV-04**: Prompt for Git name/email if .gitconfig missing

### User Experience

- [ ] **UX-01**: Beautiful CLI with colors and formatting
- [ ] **UX-02**: Progress indicators for long operations
- [ ] **UX-03**: Clear section headers with emojis
- [ ] **UX-04**: Guided walkthrough (user feels in control, not magic)

### Maintenance

- [ ] **MAINT-01**: Idempotent setup (safe to re-run)
- [ ] **MAINT-02**: Update mode (detect existing setup, update packages/configs)
- [ ] **MAINT-03**: Clear project structure (dotfiles/, config/, scripts/, setup entry point)

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Advanced Features

- **ADV-01**: Machine-specific configs (work vs personal Mac via hostname detection)
- **ADV-02**: Secrets management (API keys, credentials via macOS Keychain)
- **ADV-03**: Backup before changes with rollback capability
- **ADV-04**: Mac App Store apps via mas CLI
- **ADV-05**: Shell prompt customization wizard

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Cross-platform support (Windows/Linux) | Mac-only simplifies implementation significantly; no need for platform abstraction |
| GUI interface | CLI is the right tool for developer automation; GUI adds complexity without value |
| Cloud sync of settings | Local dotfiles repo is simpler and more reliable; no network dependency |
| Automatic updates | User should control when setup runs; auto-updates can break working systems |
| Custom package managers | Homebrew is the macOS standard; supporting alternatives adds complexity |
| Docker/VM for testing | Manual testing on Mac Studio is sufficient for personal tool |
| Configuration templating | Complexity not justified for single-user setup; .local pattern handles machine differences |
| Ansible/Chef/Puppet | Massive overkill for managing one machine's dotfiles |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| | | |

**Coverage:**
- v1 requirements: 0 total
- Mapped to phases: 0
- Unmapped: 0 ⚠️

---
*Requirements defined: 2026-02-01*
*Last updated: 2026-02-01 after initial definition*
