# Project Research Summary

**Project:** Mac Setup Automation
**Domain:** Development environment automation and dotfiles management
**Researched:** 2026-02-01
**Confidence:** HIGH (for completed research areas)

## Executive Summary

Mac setup automation is a well-established domain with clear best practices and battle-tested tools. The recommended approach uses **Bash scripts for orchestration, Homebrew Bundle for declarative package management, and direct symlinks for dotfiles** - avoiding both over-engineered solutions (Ansible, Docker) and under-engineered ones (manual commands, custom symlink scripts). This combination provides the sweet spot of simplicity, maintainability, and power.

The research reveals a **layered architecture** with four distinct concerns: orchestration (main setup script), installation (Homebrew + symlinks), configuration (dotfiles and Brewfiles), and presentation (CLI interface). The key insight is that dotfiles repositories fail when these layers blur - users get confused about what's configuration vs. what's automation. The recommended hybrid config-driven structure explicitly separates `dotfiles/` (what gets symlinked), `config/` (Brewfiles and settings), and `scripts/` (implementation details).

**Critical risks center on idempotency and Apple Silicon compatibility.** Non-idempotent scripts break on reruns, hardcoded paths fail across machines, and Intel-era paths (`/usr/local`) don't work on Apple Silicon. Mitigation is straightforward: use `brew bundle` (inherently idempotent), detect `DOTFILES_ROOT` dynamically, and verify `/opt/homebrew` paths for M-series Macs. The beautiful CLI requirement (Gum for prompts, progress indicators, emojis) differentiates this from typical dotfiles repos and makes the automation feel delightful rather than magical.

## Key Findings

### Recommended Stack

The stack research identified **Bash 5.x + Homebrew + GNU Stow + Gum** as the optimal foundation. Bash handles orchestration because every Mac has it and it's perfect for CLI commands and process management. Homebrew (via Homebrew Bundle) provides declarative package management with full Apple Silicon support. GNU Stow manages symlinks without custom logic - it's been battle-tested since 1993 and does one thing perfectly. Gum (from Charmbracelet) delivers beautiful interactive prompts without complex scripting.

**Core technologies:**
- **Bash 5.x** (via Homebrew): Primary automation language — native to macOS, perfect for glue code, fast for system tasks
- **Homebrew Bundle**: Declarative dependency management via Brewfile — infrastructure-as-code, idempotent by design, single command setup
- **GNU Stow**: Dotfiles symlink manager — simplest approach, creates/manages symlinks without complex logic, easy to migrate away from
- **Gum**: Interactive CLI prompts and styling — beautiful user-friendly prompts, single Go binary, makes setup delightful
- **mise**: Development tool version manager — for managing node/python versions, replaces asdf with better performance

**What NOT to use:**
- Custom symlink scripts (fragile, hard to maintain, breaks on edge cases)
- Ansible for personal dotfiles (massive overkill for 1 machine)
- Old Bash 3.2 (macOS default from 2007, missing modern features)
- Rosetta 2 for Homebrew (performance penalty, native ARM support exists)

**Apple Silicon specifics:**
All recommended tools have native Apple Silicon support. Homebrew installs to `/opt/homebrew/` (not `/usr/local/`). Migration from Intel Mac: `brew bundle dump` on old machine, `brew bundle install` on new machine - Homebrew handles architecture differences automatically.

### Expected Features

**Note:** FEATURES.md research was not completed. Based on PROJECT.md requirements:

**Must have (table stakes):**
- Symlink dotfiles automatically (.gitconfig, .zshrc, .hyper.js, starship.toml, .ssh/config, Cursor settings)
- Install CLI tools (nodejs, npm, yarn, pnpm, tree, gh, git)
- Install curated apps with option to select all or pick individually
- Idempotent - safe to re-run without breaking existing setup
- Apple Silicon compatible (correct Homebrew paths)
- Auto-install Xcode Command Line Tools (required for development)

**Should have (competitive - differentiators):**
- Beautiful CLI with colors, progress indicators, clear sections, helpful emojis (Gum integration)
- Guided walkthrough - prompts for major steps, user feels in control
- Update mode for maintaining setup over time
- Auto-detect SSH keys, prompt to generate if missing
- Apply system settings with preview and confirmation

**Defer (v2+):**
- Cross-platform support (Windows/Linux) — Mac-only simplifies significantly
- GUI interface — CLI is the right tool for this job
- Cloud sync of settings — Local dotfiles repo is simpler
- Automatic updates — User controls when to run

### Architecture Approach

Mac setup automation follows a **layered architecture** with clear separation: User Interface Layer (CLI commands, README, Makefile), Orchestration Layer (bootstrap/setup script as main entry point), Installation Layer (Homebrew, symlink manager, macOS defaults), and Configuration Layer (dotfiles and config files).

The recommended structure is a **Hybrid Config-Driven approach** that balances clarity and functionality:

**Major components:**
1. **dotfiles/** directory — Contains files to be symlinked to home directory, organized by tool category (shell/, git/, vim/), files include the dot in filename
2. **config/** directory — Non-symlinked configuration and metadata (Brewfile for packages, macos-defaults.sh for system settings)
3. **scripts/** directory — Implementation details hidden from user (bootstrap.sh, homebrew.sh, macos.sh, utils.sh), each with single responsibility
4. **setup** entry point — Single executable that orchestrates everything, calls scripts in dependency order, idempotent operations
5. **bin/** directory — Custom executables added to PATH

**Critical patterns:**
- **Idempotent installation:** All operations can be run multiple times safely (`brew bundle` inherently idempotent, symlinks check before creating)
- **Local customization override:** Support `.local` files for machine-specific settings not in git (e.g., `.zshrc.local`)
- **Declarative package management:** Use Brewfile to declare packages, not script installation commands
- **System preferences as code:** Use `defaults write` to programmatically configure macOS instead of manual GUI clicks
- **Two-phase bootstrap:** Phase 1 installs prerequisites (Homebrew, Git), Phase 2 applies configurations and symlinks

**Data flow:**
```
[User runs ./setup]
  → [Check prerequisites]
  → [Install Homebrew]
  → [brew bundle --file=config/Brewfile]
  → [Create symlinks: dotfiles/ → ~/]
  → [Apply macOS defaults]
  → [Source customizations: ~/.local.zsh if exists]
  → [Success: Prompt to restart shell]
```

### Critical Pitfalls

**Note:** PITFALLS.md research was not completed. Based on ARCHITECTURE.md anti-patterns:

1. **Non-idempotent operations** — Appending to shell config files on each run duplicates entries and breaks reruns. **Avoid:** Use `grep -q` checks before appending, or better yet, symlink entire config files declaratively.

2. **Hardcoded paths** — Assuming dotfiles are in `~/dotfiles` breaks portability. **Avoid:** Use `DOTFILES_ROOT="$(cd "$(dirname "$0")" && pwd)"` to detect location dynamically.

3. **Manual symlink commands** — Listing `ln -s` commands in README as "installation instructions" is not reproducible. **Avoid:** Create automated symlink script that loops through dotfiles directory.

4. **Secrets in repository** — Committing `.gitconfig` with company email, `.aws/credentials`, or `.npmrc` with tokens is a security vulnerability. **Avoid:** Use `[include]` pattern with `.gitconfig.local` (not committed), add sensitive files to `.gitignore`.

5. **Copying instead of symlinking** — Using `cp` to copy dotfiles to home directory means changes to repo don't propagate. **Avoid:** Use symlinks so editing `~/.zshrc` edits the repo file directly.

6. **Wrong Homebrew path on Apple Silicon** — Using `/usr/local/bin` paths fails on M-series Macs. **Avoid:** Verify `/opt/homebrew` installation, add correct PATH in shell config.

7. **Monolithic setup script** — 500-line script with everything inline is impossible to test or maintain. **Avoid:** Separate concerns into focused scripts (homebrew.sh, symlinks.sh, macos.sh).

## Implications for Roadmap

Based on research, the recommended implementation order follows natural dependencies and allows for incremental testing:

### Phase 1: Foundation & Project Structure
**Rationale:** Can't build anything without directory structure and basic orchestration. This phase establishes the skeleton.

**Delivers:**
- Directory structure (dotfiles/, config/, scripts/, bin/)
- Empty setup script (entry point)
- README with basic instructions
- .gitignore for sensitive files

**Addresses:** Clear directory structure requirement from PROJECT.md
**Avoids:** Hardcoded paths pitfall (establish dynamic path detection early)

### Phase 2: Homebrew Installation & Core Tools
**Rationale:** Homebrew is the foundation for everything else - can't install tools without it. Must handle Apple Silicon paths correctly from the start.

**Delivers:**
- Homebrew installation script (scripts/homebrew.sh)
- Detection of Apple Silicon vs Intel
- Basic Brewfile with essential tools (git, stow, gum)
- Idempotent brew bundle execution

**Uses:** Bash for orchestration, Homebrew Bundle for declarative packages
**Implements:** Installation Layer from architecture
**Addresses:** Apple Silicon compatibility, auto-install Xcode Command Line Tools
**Avoids:** Wrong Homebrew path pitfall, non-idempotent operations

### Phase 3: Dotfiles Symlinking
**Rationale:** With tools installed, now implement core value proposition - managing dotfiles. This makes the system usable.

**Delivers:**
- Symlink creation script (scripts/bootstrap.sh)
- Support for shell configs (.zshrc, .bash_profile)
- Support for Git config (.gitconfig)
- Support for tool configs (.vimrc, starship.toml, .hyper.js)
- Local override pattern (.zshrc.local)

**Uses:** GNU Stow or custom symlinking logic
**Implements:** Symlink Manager component
**Addresses:** Symlink dotfiles automatically requirement
**Avoids:** Copying instead of symlinking, secrets in repository (via .local pattern)

### Phase 4: Application Installation
**Rationale:** With dotfiles working, expand Brewfile to install full app suite. Separating from Phase 2 allows testing foundation before adding complexity.

**Delivers:**
- Comprehensive Brewfile with all apps (Cursor, Hyper, Slack, Discord, etc.)
- Cask installations for GUI apps
- Option to select apps individually vs install all
- mas integration for Mac App Store apps

**Uses:** Homebrew Bundle cask support, mas CLI
**Implements:** Extended Installation Layer
**Addresses:** Install curated apps with selection option
**Avoids:** Monolithic script (keeps Brewfile declarative, separate from orchestration)

### Phase 5: Beautiful CLI Interface
**Rationale:** With core functionality working, add the delightful UX layer. This differentiates from standard dotfiles repos.

**Delivers:**
- Gum integration for prompts (app selection, confirmations)
- Progress indicators for long operations
- Colored output and clear section headers
- Helpful emojis for visual feedback
- Guided walkthrough with user control

**Uses:** Gum for interactive CLI
**Implements:** User Interface Layer
**Addresses:** Beautiful CLI requirement, guided walkthrough requirement
**Avoids:** "Magic" behavior - keeps user informed and in control

### Phase 6: macOS System Preferences
**Rationale:** System settings are optional but high-value. Save for later since they require restart/logout and can be finicky across macOS versions.

**Delivers:**
- macOS defaults script (config/macos-defaults.sh)
- Mouse/trackpad speed settings
- Keyboard repeat rate settings
- Screenshot location and format
- Finder preferences
- Dock behavior
- Preview and confirmation before applying

**Uses:** defaults write commands
**Implements:** macOS Defaults component
**Addresses:** Apply system settings with preview requirement
**Avoids:** Breaking system with incorrect defaults (preview before apply)

### Phase 7: SSH & Git Configuration
**Rationale:** Developer workflow improvements that depend on Git being installed and configured.

**Delivers:**
- SSH key detection
- SSH key generation prompt if missing
- Git configuration from .gitconfig or prompts
- SSH config file symlinking
- GitHub CLI authentication helper

**Uses:** Git, gh CLI, ssh-keygen
**Addresses:** Auto-detect SSH keys, configure Git requirements
**Avoids:** Secrets in repository (SSH keys never committed)

### Phase 8: Update Mode & Maintenance
**Rationale:** Once core functionality is proven, add update workflow for long-term maintenance.

**Delivers:**
- Detection of existing setup (first-time vs update)
- Safe update operations (re-stow, brew upgrade)
- Backup before destructive changes
- Rollback mechanism

**Implements:** Idempotent installation pattern at system level
**Addresses:** Update mode requirement, safe to re-run requirement

### Phase Ordering Rationale

- **Dependencies drive order:** Can't symlink configs without directories, can't install apps without Homebrew, can't use Gum without installing it first
- **Risk mitigation through layering:** Each phase builds on proven foundation - test Phase 2 thoroughly before adding Phase 3 complexity
- **Value delivery:** Phase 3 delivers core value (dotfiles management), later phases enhance but aren't required for basic functionality
- **Separation of concerns:** Each phase has single focus, making debugging and testing manageable
- **Allows early validation:** Can test setup on actual Mac Studio after Phase 2-3, validate approach before building full feature set

**Build order matches architecture:**
1. Foundation (structure)
2. Installation Layer (Homebrew)
3. Installation Layer (symlinks)
4. Installation Layer (apps)
5. User Interface Layer (Gum)
6. Installation Layer (macOS)
7. Configuration Layer (SSH/Git)
8. Orchestration Layer (update mode)

### Research Flags

**Phases with standard patterns (skip deep research during planning):**
- **Phase 1-4:** Well-documented, established patterns from mathiasbynens/holman/thoughtbot dotfiles repos
- **Phase 5:** Gum documentation is excellent, examples abundant
- **Phase 6:** mathiasbynens/.macos file is comprehensive reference

**Phases potentially needing targeted research:**
- **Phase 7 (SSH/Git):** GitHub CLI authentication flow may need specific research if complex
- **Phase 8 (Update mode):** Backup/rollback mechanisms for macOS might need research if going beyond simple git revert

**Overall:** This domain is extremely well-documented. Most phases can proceed directly to planning without additional research. The ARCHITECTURE.md and STACK.md provide sufficient guidance.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | **HIGH** | Verified with official Homebrew/Gum/Stow docs, multiple high-quality sources, clear consensus on tools |
| Features | **MEDIUM** | Based on PROJECT.md requirements only (FEATURES.md not completed), likely complete but unvalidated against domain norms |
| Architecture | **HIGH** | Research analyzed 3+ popular dotfiles repos (mathiasbynens 40k+ stars, holman 7k+ stars, thoughtbot), patterns are proven |
| Pitfalls | **MEDIUM** | Derived from ARCHITECTURE.md anti-patterns (not dedicated PITFALLS.md research), covers major issues but may miss domain-specific edge cases |

**Overall confidence:** **HIGH** for implementation guidance, **MEDIUM** for feature completeness

The completed research (STACK.md, ARCHITECTURE.md) is comprehensive and high-quality. Both files cite official documentation and well-established community resources. The architecture research analyzed multiple popular repositories and extracted proven patterns. Stack recommendations are backed by official docs and recent compatibility information (2026).

The missing research files (FEATURES.md, PITFALLS.md) reduce confidence slightly, but PROJECT.md provides detailed requirements and the architecture research captured anti-patterns. For a personal dotfiles project, the existing research is sufficient to proceed.

### Gaps to Address

**Feature validation:** Without FEATURES.md, we're relying on PROJECT.md requirements. Should validate during Phase 1 planning:
- Are there table-stakes features we're missing? (Compare against popular dotfiles repos)
- Are any "should have" features actually anti-patterns in this domain?

**Edge case pitfalls:** Without dedicated PITFALLS.md, may miss domain-specific gotchas:
- macOS version compatibility issues for defaults write commands
- Homebrew migration issues between architectures
- SSH key permission problems
- Git credential helper conflicts

**Mitigation strategy:**
- During each phase planning, do targeted research on that phase's specific domain (e.g., when planning Phase 6, research macOS defaults pitfalls)
- Reference the popular dotfiles repos (mathiasbynens, holman, thoughtbot) during implementation as working examples
- Test on actual Mac Studio (fresh machine) after each phase

**Machine-specific customization:**
- How to handle work vs personal machine differences? (Solution: Brewfile.$(hostname) pattern from STACK.md)
- How to handle secrets management? (Solution: .local files pattern + macOS Keychain)

These gaps are minor and can be resolved during planning/implementation. The core research is solid.

## Sources

### Primary (HIGH confidence)
- **STACK.md** — Homebrew Bundle, GNU Stow, Gum, mise, version compatibility, idempotency patterns, Apple Silicon specifics
- **ARCHITECTURE.md** — Layered architecture, 4 structure patterns, 6 architectural patterns, data flows, anti-patterns, build order
- **PROJECT.md** — Requirements, constraints, context, current situation, app list, system settings priorities

### Secondary (MEDIUM confidence)
- [mathiasbynens/dotfiles](https://github.com/mathiasbynens/dotfiles) — Flat structure pattern, .macos defaults reference
- [holman/dotfiles](https://github.com/holman/dotfiles) — Topic-based organization, convention-based loading
- [thoughtbot/laptop](https://github.com/thoughtbot/laptop) — Minimal script approach, idempotent patterns
- [Homebrew Bundle Documentation](https://docs.brew.sh/Brew-Bundle-and-Brewfile) — Declarative package management
- [Gum GitHub Repository](https://github.com/charmbracelet/gum) — Interactive CLI tool
- [chezmoi Comparison Table](https://www.chezmoi.io/comparison-table/) — Dotfiles tool comparison

### Tertiary (LOW confidence)
- Community blog posts on dotfiles management (webpro, Jake Wiesler, Daytona)
- macOS defaults automation guides (emmer.dev, Rex Yuan)
- Hacker News discussions (YADM vs Chezmoi, bash vs Python)

---
*Research completed: 2026-02-01*
*Research files synthesized: 2/4 (STACK.md, ARCHITECTURE.md completed; FEATURES.md, PITFALLS.md not found)*
*Ready for roadmap: Yes - sufficient research for planning*
