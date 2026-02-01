# Architecture Research: Mac Setup Automation & Dotfiles

**Domain:** Mac development environment setup automation and dotfiles management
**Researched:** 2026-02-01
**Confidence:** HIGH

## Standard Architecture

### System Overview

Mac setup automation and dotfiles repositories typically follow a **layered architecture** with clear separation of concerns:

```
┌─────────────────────────────────────────────────────────────┐
│                    User Interface Layer                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │ CLI Commands │  │   README     │  │  Makefile    │       │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘       │
├─────────┴──────────────────┴──────────────────┴──────────────┤
│                  Orchestration Layer                          │
│  ┌─────────────────────────────────────────────────────┐     │
│  │  Bootstrap/Setup Script (main entry point)          │     │
│  └────────┬────────────────────────────────────────────┘     │
│           │                                                   │
│  ┌────────┴───────┬──────────────┬───────────────┐           │
│  │                │              │               │           │
├──┴────────────────┴──────────────┴───────────────┴───────────┤
│                 Installation Layer                            │
│  ┌──────────┐  ┌────────────┐  ┌─────────────┐  ┌─────────┐ │
│  │ Homebrew │  │   Symlink  │  │   macOS     │  │  Other  │ │
│  │ (apps)   │  │  Manager   │  │  Defaults   │  │ Install │ │
│  └──────────┘  └────────────┘  └─────────────┘  └─────────┘ │
├─────────────────────────────────────────────────────────────┤
│                   Configuration Layer                         │
│  ┌──────────────────────────────────────────────────────┐    │
│  │  Dotfiles (shell, git, vim, etc.)                    │    │
│  ├──────────────────────────────────────────────────────┤    │
│  │  Config Files (Brewfile, app lists, settings)        │    │
│  └──────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| Bootstrap/Setup Script | Main entry point, orchestrates all installation steps | Shell script (bash/zsh) with idempotent operations |
| Homebrew Manager | Install package manager and applications | `brew.sh` or Brewfile using `brew bundle` |
| Symlink Manager | Create links from dotfiles repo to home directory | GNU Stow, custom script, or chezmoi |
| macOS Defaults | Configure system preferences programmatically | Shell script using `defaults write` commands |
| Dotfiles | Version-controlled configuration files | Shell configs (.zshrc, .bashrc), tool configs (.gitconfig, .vimrc) |
| Config Directory | Non-dotfile configurations and metadata | Brewfiles, app lists, installation manifests |

## Recommended Project Structure

Based on research of popular repositories (mathiasbynens, holman, thoughtbot), there are three main organizational approaches:

### Approach 1: Flat Structure (Mathias Bynens Pattern)

**Best for:** Simple setups, personal use, learning

```
dotfiles/
├── .aliases             # Command shortcuts
├── .bash_profile        # Login shell config
├── .bashrc              # Interactive shell config
├── .exports             # Environment variables
├── .functions           # Custom bash functions
├── .gitconfig           # Git configuration
├── .gitignore_global    # Global git ignores
├── .macos               # macOS system settings
├── .vimrc               # Vim configuration
├── .zshrc               # Zsh configuration
├── bootstrap.sh         # Main setup script (rsync-based)
├── brew.sh              # Homebrew installation script
├── bin/                 # Custom executables
│   └── [scripts]
├── init/                # First-time setup utilities
└── README.md
```

**Characteristics:**
- Files named with leading dot in repository
- Bootstrap copies/rsyncs files to home directory
- Simple, direct mapping
- Easy to understand
- Can become cluttered with many tools

**Source:** [mathiasbynens/dotfiles](https://github.com/mathiasbynens/dotfiles)

### Approach 2: Topic-Based Structure (Holman Pattern)

**Best for:** Complex setups, multiple tools, team sharing

```
dotfiles/
├── git/
│   ├── gitconfig.symlink       # Gets symlinked as ~/.gitconfig
│   ├── gitignore.symlink       # Gets symlinked as ~/.gitignore
│   └── aliases.zsh             # Auto-sourced by zsh
├── ruby/
│   ├── gemrc.symlink
│   └── rbenv.zsh
├── vim/
│   ├── vimrc.symlink
│   └── vim.symlink/            # Directory becomes ~/.vim
├── zsh/
│   ├── zshrc.symlink
│   ├── prompt.zsh
│   ├── completion.zsh          # Loaded last
│   └── path.zsh                # Loaded first
├── homebrew/
│   └── install.sh              # Executed during setup
├── system/
│   ├── env.zsh
│   └── aliases.zsh
├── macos/
│   └── set-defaults.sh
├── bin/                        # Added to $PATH
│   └── [executables]
├── script/
│   ├── bootstrap               # Main installer (symlink-based)
│   └── install                 # Runs all topic install.sh scripts
└── README.md
```

**Characteristics:**
- Organized by topic/tool
- Special file extensions control behavior:
  - `*.symlink` → gets symlinked to `~/.filename`
  - `*.zsh` → auto-sourced by shell
  - `path.zsh` → loaded first (PATH setup)
  - `completion.zsh` → loaded last (autocomplete)
  - `install.sh` → executed during installation
- Highly modular and extensible
- Easy to share specific topics
- Scale well with complexity

**Source:** [holman/dotfiles](https://github.com/holman/dotfiles)

### Approach 3: Minimal Script-Based (Thoughtbot Pattern)

**Best for:** Quick onboarding, team standardization, minimal maintenance

```
laptop/
├── mac                  # Single main script
├── .laptop.local        # User customizations (not in repo)
└── README.md
```

**Characteristics:**
- Single-file setup script
- Idempotent (safe to run multiple times)
- Focuses on installation, not dotfile management
- Users customize via `~/.laptop.local` (not version controlled)
- Minimal to maintain
- Great for team standardization

**Source:** [thoughtbot/laptop](https://github.com/thoughtbot/laptop)

### Approach 4: Hybrid Config-Driven (Recommended for Your Case)

**Best for:** Balance of clarity and functionality, Mac-specific needs

```
dotfiles/
├── dotfiles/            # Files to symlink
│   ├── shell/
│   │   ├── .zshrc
│   │   ├── .bash_profile
│   │   └── .aliases
│   ├── git/
│   │   ├── .gitconfig
│   │   └── .gitignore_global
│   ├── vim/
│   │   └── .vimrc
│   └── tools/
│       └── [other configs]
├── config/              # Non-dotfile configurations
│   ├── Brewfile         # Homebrew bundle file
│   ├── apps.txt         # App list (optional)
│   ├── mas-apps.txt     # Mac App Store apps (optional)
│   └── macos-defaults.sh # System settings
├── bin/                 # Custom executables
│   └── [scripts]
├── setup                # Main entry point (no extension)
├── scripts/             # Internal setup scripts
│   ├── bootstrap.sh     # Symlink creation
│   ├── homebrew.sh      # Package installation
│   ├── macos.sh         # System configuration
│   └── utils.sh         # Helper functions
├── .gitignore
└── README.md
```

**Structure Rationale:**

- **dotfiles/**: Clear separation - only files meant to be symlinked
  - Organized by tool category for clarity
  - Files include the dot in filename (what you see is what you get)
  - No special extensions needed

- **config/**: Non-symlinked configuration and metadata
  - Brewfile: Declarative package management via `brew bundle`
  - macOS defaults: System preferences as code
  - Lists: Optional manifest files for tracking

- **bin/**: Custom executables added to PATH
  - No file extension needed
  - Make executable with `chmod +x`

- **setup**: Single entry point that orchestrates everything
  - Calls scripts in dependency order
  - Idempotent operations
  - Clear logging

- **scripts/**: Implementation details hidden from user
  - Each script has single responsibility
  - Reusable utility functions
  - Can be tested independently

**Why this structure addresses your problem:**
- Clear organization prevents confusion about "what goes where"
- Separation of concerns: dotfiles vs config vs scripts
- Easy to see relationship: setup script orchestrates config and dotfiles
- Maintainable: adding new tool = add config + symlink, update setup

## Architectural Patterns

### Pattern 1: Idempotent Installation

**What:** Scripts can be run multiple times without causing errors or duplicating work. Each operation checks if work is already done before proceeding.

**When to use:** Always. Essential for Mac setup automation.

**Trade-offs:**
- Pros: Safe reruns, incremental updates, easy debugging
- Cons: More complex logic, slower (needs to check state)

**Example:**
```bash
# Bad: Fails on rerun
echo 'export PATH="/opt/bin:$PATH"' >> ~/.zshrc

# Good: Idempotent
if ! grep -q 'export PATH="/opt/bin:$PATH"' ~/.zshrc; then
  echo 'export PATH="/opt/bin:$PATH"' >> ~/.zshrc
fi

# Better: Using Homebrew bundle (inherently idempotent)
brew bundle --file=~/dotfiles/config/Brewfile
```

**Sources:**
- [thoughtbot/laptop](https://github.com/thoughtbot/laptop) - "It can be run multiple times on the same machine safely"
- [Getting started with dotfiles](https://webpro.nl/articles/getting-started-with-dotfiles)

### Pattern 2: Local Customization Override

**What:** Provide mechanism for user-specific overrides that aren't committed to repository. Allows personal customization without forking.

**When to use:** When dotfiles are shared across machines or team members.

**Trade-offs:**
- Pros: Privacy for secrets/personal settings, clean git history
- Cons: Overrides not backed up, can drift between machines

**Example:**
```bash
# In .zshrc
source ~/.zsh/config.zsh

# Source local customizations (not in git)
if [[ -f ~/.zshrc.local ]]; then
  source ~/.zshrc.local
fi
```

**Sources:**
- [thoughtbot/laptop](https://github.com/thoughtbot/laptop) - Uses `~/.laptop.local`
- [mathiasbynens/dotfiles](https://github.com/mathiasbynens/dotfiles) - Uses `~/.extra`

### Pattern 3: Declarative Package Management

**What:** Use Brewfile to declare desired packages rather than scripting installation commands. `brew bundle` handles installation/updates idempotently.

**When to use:** Always for macOS. Homebrew Bundle is the standard.

**Trade-offs:**
- Pros: Declarative (what not how), version control, portable, idempotent
- Cons: Homebrew-specific, need to learn Brewfile syntax

**Example:**
```ruby
# config/Brewfile
tap "homebrew/bundle"
tap "homebrew/cask-fonts"

brew "git"
brew "vim"
brew "zsh"
brew "fzf"

cask "iterm2"
cask "visual-studio-code"
cask "docker"

# Mac App Store apps (requires mas-cli)
mas "Xcode", id: 497799835
mas "Things", id: 904280696
```

```bash
# In setup script
brew bundle --file=~/dotfiles/config/Brewfile
```

**Sources:**
- [Homebrew Bundle Documentation](https://docs.brew.sh/Brew-Bundle-and-Brewfile)
- [Setting Up a New Mac with Dotfiles, Brew Bundle, and Mackup](https://respawn.io/posts/dotfiles-brew-bundle-and-mackup)

### Pattern 4: System Preferences as Code

**What:** Use `defaults write` commands to programmatically configure macOS system preferences instead of manual GUI clicks.

**When to use:** For reproducible Mac setups. Essential for automation.

**Trade-offs:**
- Pros: Repeatable, version controlled, fast, documentable
- Cons: Discovery is hard, settings can break across macOS versions, requires logout/restart

**Example:**
```bash
# config/macos-defaults.sh

# Finder: show hidden files by default
defaults write com.apple.finder AppleShowAllFiles -bool true

# Finder: show status bar
defaults write com.apple.finder ShowStatusBar -bool true

# Dock: automatically hide and show
defaults write com.apple.dock autohide -bool true

# Dock: make icons smaller
defaults write com.apple.dock tilesize -int 48

# Trackpad: enable tap to click
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true

# Screenshots: save to ~/Screenshots instead of Desktop
mkdir -p "${HOME}/Screenshots"
defaults write com.apple.screencapture location -string "${HOME}/Screenshots"

# Restart affected apps
killall Finder Dock SystemUIServer
```

**Discovery workflow:**
```bash
# Export current state
defaults read > before.txt

# Make changes in System Preferences GUI

# Export new state and compare
defaults read > after.txt
diff before.txt after.txt
```

**Sources:**
- [Automate Your macOS Default Settings](https://emmer.dev/blog/automate-your-macos-defaults/)
- [mathiasbynens/dotfiles .macos file](https://github.com/mathiasbynens/dotfiles/blob/main/.macos)

### Pattern 5: Convention-Based Loading

**What:** Use file naming conventions to control behavior automatically (e.g., `*.zsh` auto-sourced, `*.symlink` auto-linked, `path.zsh` loaded first).

**When to use:** When managing many configuration files across multiple tools.

**Trade-offs:**
- Pros: Less boilerplate, self-documenting, extensible
- Cons: "Magic" behavior, learning curve, debugging harder

**Example:**
```bash
# In bootstrap script
# Auto-symlink all *.symlink files
for src in $(find -H "$DOTFILES_ROOT" -maxdepth 2 -name '*.symlink')
do
  dst="$HOME/.$(basename "${src%.*}")"
  ln -s "$src" "$dst"
done

# In .zshrc
# Auto-source all *.zsh files
for config_file in $DOTFILES/**/*.zsh; do
  source $config_file
done
```

**Source:**
- [holman/dotfiles](https://github.com/holman/dotfiles)

### Pattern 6: Two-Phase Bootstrap

**What:** Separate dependency installation from configuration. Phase 1: Install prerequisites (Homebrew, Git, etc.). Phase 2: Apply configurations and symlinks.

**When to use:** Complex setups with many dependencies.

**Trade-offs:**
- Pros: Clear separation, can retry phase 2 without reinstalling
- Cons: More complex orchestration

**Example:**
```bash
#!/usr/bin/env bash
# setup script

set -e

DOTFILES_ROOT="$(cd "$(dirname "$0")" && pwd)"

# Phase 1: Install prerequisites
echo "Phase 1: Installing prerequisites..."
source "$DOTFILES_ROOT/scripts/homebrew.sh"

# Phase 2: Configure environment
echo "Phase 2: Configuring environment..."
source "$DOTFILES_ROOT/scripts/bootstrap.sh"
source "$DOTFILES_ROOT/scripts/macos.sh"

echo "Setup complete! Please restart your terminal."
```

## Data Flow

### Installation Flow

```
[User runs ./setup]
         ↓
[Check prerequisites]
         ↓
[Install Homebrew] ──────────────────────┐
         ↓                               │
[brew bundle --file=config/Brewfile] <───┘
         ↓
[Create symlinks: dotfiles/ → ~/]
         ↓
[Apply macOS defaults]
         ↓
[Run tool-specific installations]
         ↓
[Source customizations: ~/.local.zsh if exists]
         ↓
[Success: Prompt to restart shell]
```

### Symlink Management Flow

Two main approaches found in research:

**Approach A: Direct Symlinking (Most Common)**
```
dotfiles/dotfiles/.zshrc  →  (symlink)  →  ~/.zshrc
dotfiles/dotfiles/.gitconfig  →  (symlink)  →  ~/.gitconfig
```

**Approach B: GNU Stow (Cleaner, More Complex)**
```
dotfiles/
├── zsh/
│   └── .zshrc     →  (stow)  →  ~/.zshrc
├── git/
│   └── .gitconfig →  (stow)  →  ~/.gitconfig

# Command: cd dotfiles && stow zsh git
```

**Approach C: Chezmoi (Feature-Rich)**
```
~/.local/share/chezmoi/  →  (chezmoi apply)  →  ~/
  - Supports templates, encryption, scripts
  - No symlinks (copies files)
  - Can stop using tool without cleanup
```

**Recommendation for your case:** Direct symlinking with custom script. Simplest, most transparent, easy to debug.

### Update Flow

```
[User: git pull]
         ↓
[User: ./setup]  (idempotent rerun)
         ↓
[Homebrew: brew bundle]
    ↓
    ├─ Installs new packages
    ├─ Upgrades existing packages
    └─ Skips already-installed packages
         ↓
[Symlinks: skip if already linked]
         ↓
[macOS defaults: reapply settings]
         ↓
[Done: changes applied incrementally]
```

### Discovery: Adding New Tool to Dotfiles

```
[Install tool manually: brew install neovim]
         ↓
[Configure tool: edit ~/.config/nvim/init.vim]
         ↓
[Test configuration locally]
         ↓
[Capture in dotfiles repo]:
    ├─ Add to Brewfile: brew "neovim"
    ├─ Copy config: cp ~/.config/nvim dotfiles/dotfiles/nvim
    └─ Update setup script to symlink it
         ↓
[Commit and push to git]
         ↓
[Test on another machine: git pull && ./setup]
```

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| 1 person, 1 machine | Flat structure (mathiasbynens pattern), single script, no complexity needed |
| 1 person, multiple machines | Add machine-specific overrides (`.local` files), Brewfile may differ per machine |
| Small team (2-5 people) | Topic-based structure (holman pattern), documented conventions, shared base + personal forks |
| Team standardization | Minimal script approach (thoughtbot pattern), shared repo, local customizations for individuals |
| Cross-platform (Mac + Linux) | Use cross-platform tool (chezmoi), conditional logic in scripts, separate OS-specific configs |

### Scaling Priorities

**First bottleneck: Machine-specific settings**
- Problem: Home vs work machine need different apps/settings
- Solution: Use environment detection or separate branches
```bash
if [[ "$(hostname)" == "work-laptop" ]]; then
  brew bundle --file=config/Brewfile.work
else
  brew bundle --file=config/Brewfile.personal
fi
```

**Second bottleneck: Secrets management**
- Problem: API keys, tokens, credentials can't be in git
- Solutions:
  - Use `.local` override files (not committed)
  - Use environment variables loaded from secure store
  - Use `git-crypt` or similar for encryption in repo
  - Use separate secrets manager (1Password, pass, etc.)

## Anti-Patterns

### Anti-Pattern 1: Manual Symlink Commands

**What people do:**
```bash
ln -s ~/dotfiles/.zshrc ~/.zshrc
ln -s ~/dotfiles/.gitconfig ~/.gitconfig
# ... repeated in README as "installation instructions"
```

**Why it's wrong:**
- Not reproducible
- Manual steps get forgotten
- Error-prone
- Breaks the "spilled coffee principle" (can't rebuild from scratch)

**Do this instead:**
```bash
# In setup script
for file in dotfiles/shell/*; do
  filename=$(basename "$file")
  ln -sf "$PWD/$file" "$HOME/$filename"
done
```

**Source:** [Manage Your Dotfiles Like a Superhero](https://www.jakewiesler.com/blog/managing-dotfiles)

### Anti-Pattern 2: Hardcoded Paths

**What people do:**
```bash
# Assumes dotfiles are in ~/dotfiles
ln -s ~/dotfiles/.zshrc ~/.zshrc
```

**Why it's wrong:**
- Breaks if user clones to different location
- Not portable across machines
- Forces specific directory structure

**Do this instead:**
```bash
DOTFILES_ROOT="$(cd "$(dirname "$0")" && pwd)"
ln -sf "$DOTFILES_ROOT/dotfiles/.zshrc" "$HOME/.zshrc"
```

### Anti-Pattern 3: Non-Idempotent Operations

**What people do:**
```bash
echo "export PATH=/usr/local/bin:$PATH" >> ~/.zshrc
```

**Why it's wrong:**
- Duplicates entries on each run
- Breaks on setup reruns
- Makes debugging painful

**Do this instead:**
```bash
if ! grep -q "export PATH=/usr/local/bin" ~/.zshrc; then
  echo "export PATH=/usr/local/bin:$PATH" >> ~/.zshrc
fi

# Or better: use declarative configuration
# Put in dotfiles/.zshrc directly, symlink entire file
```

### Anti-Pattern 4: Secrets in Repository

**What people do:**
- Commit `.gitconfig` with company email
- Commit `.aws/credentials`
- Commit `.npmrc` with auth tokens

**Why it's wrong:**
- Security vulnerability
- Can't open-source dotfiles
- Leaks personal/company info

**Do this instead:**
```bash
# In .gitconfig (committed)
[include]
  path = ~/.gitconfig.local

# In .gitconfig.local (NOT committed, in .gitignore)
[user]
  email = personal@email.com
  name = Your Name
```

**Source:** [The Ultimate Guide to Mastering Dotfiles](https://www.daytona.io/dotfiles/ultimate-guide-to-dotfiles) - "Never push any secrets to any public repository in plain text"

### Anti-Pattern 5: Copying Instead of Symlinking

**What people do:**
```bash
# bootstrap.sh
cp .zshrc ~/.zshrc
cp .gitconfig ~/.gitconfig
```

**Why it's wrong:**
- Changes to repo don't propagate to home directory
- Have to run bootstrap after every change
- Defeats purpose of version control

**Do this instead:**
```bash
ln -sf "$DOTFILES_ROOT/.zshrc" "$HOME/.zshrc"
# Now editing ~/.zshrc edits the repo file
```

**Exception:** When using chezmoi (which copies intentionally), but it tracks changes and can re-apply.

### Anti-Pattern 6: Monolithic Setup Script

**What people do:**
```bash
# 500-line setup.sh with everything inline
# - Homebrew installation
# - 100+ brew install commands
# - All symlinks
# - All macOS defaults
# ... impossible to test or maintain
```

**Why it's wrong:**
- Hard to debug
- Can't run parts independently
- Difficult to extend
- No separation of concerns

**Do this instead:**
```bash
# setup (main entry point)
source scripts/homebrew.sh
source scripts/symlinks.sh
source scripts/macos.sh

# Each script is focused and testable
```

### Anti-Pattern 7: Git Bare Repository for Dotfiles

**What people do:** Use `git init --bare` in `~/.dotfiles` and alias git commands to manage home directory directly.

**Why it's debatable:**
- Pros: No symlinks needed, direct version control
- Cons: Very complex, confusing, easy to accidentally commit wrong files, hard for others to understand

**Do this instead:** Use conventional git repo with symlinks or a tool like stow/chezmoi. Much clearer.

**Source:** [Atlassian Git Tutorial on Bare Repositories](https://www.atlassian.com/git/tutorials/dotfiles) vs [Multiple sources recommending against it](https://www.ackama.com/what-we-think/the-best-way-to-store-your-dotfiles-a-bare-git-repository-explained/)

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| Homebrew | `brew bundle --file=config/Brewfile` | Declarative package management, always idempotent |
| Mac App Store | `mas install <id>` in Brewfile | Requires mas-cli: `brew "mas"` |
| macOS System Preferences | `defaults write <domain> <key> <value>` | Requires killall/restart, OS version dependent |
| Shell (zsh/bash) | Source from profile: `source ~/.zshrc` | Use `.zshrc.local` pattern for overrides |
| Git | Symlink `~/.gitconfig`, use `[include]` for locals | Keep user.email in separate untracked file |
| SSH | Symlink `~/.ssh/config`, NEVER commit keys | Add `~/.ssh/*.pem` to .gitignore |
| Cloud Sync (Dropbox/iCloud) | Symlink from cloud to dotfiles or vice versa | Be careful of sync conflicts |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| setup → scripts/* | Source/execute | Scripts are sourced or called, share environment |
| dotfiles → home directory | Symlinks | One-way: changes in either location affect both |
| config/Brewfile → Homebrew | `brew bundle` command | Declarative: describes desired state |
| scripts → macOS APIs | `defaults` CLI | Imperative: directly modifies system state |

## Build Order Implications

Based on dependency analysis, recommended implementation order:

### Phase 1: Foundation (Build First)
1. **Directory structure** - Create the folder layout
2. **Basic setup script** - Entry point that can be run
3. **Homebrew installation** - Required for most other tasks
4. **Git configuration** - Needed to commit progress

**Rationale:** Can't do anything without directories and Homebrew. Git config needed to commit work.

### Phase 2: Core Functionality
5. **Symlink creation** - Core dotfiles feature
6. **Shell configuration** - Make terminal usable
7. **Brewfile basic apps** - Essential dev tools

**Rationale:** This makes the system usable for daily work. Can test and iterate.

### Phase 3: Polish
8. **macOS defaults** - System preferences automation
9. **Additional tools** - Nice-to-haves
10. **Documentation** - README with instructions

**Rationale:** These enhance the experience but aren't critical. Can be added incrementally.

### Phase 4: Advanced (Optional)
11. **Machine-specific configs** - .local file support
12. **Secret management** - Handling credentials
13. **Cross-machine sync** - Multiple computer support

**Rationale:** Only needed once basics are working. Don't prematurely optimize.

### Dependencies Diagram

```
setup (entry point)
  ↓
  ├─→ Homebrew installation
  │     ↓
  │     └─→ Brewfile execution
  │           ↓
  │           └─→ mas, stow, other tools available
  │
  ├─→ Symlink creation
  │     (depends on: directory structure)
  │
  ├─→ macOS defaults
  │     (independent, can run anytime)
  │
  └─→ Shell configuration
        (depends on: symlinks, Homebrew for zsh/bash)
```

## Real-World Examples Analysis

### mathiasbynens/dotfiles
- **Structure:** Flat (all files in root)
- **Approach:** Bootstrap copies files via rsync
- **Strengths:** Simple, easy to fork, well-documented
- **Weaknesses:** Copying instead of symlinking, can get cluttered
- **Best for:** Personal use, learning

### holman/dotfiles
- **Structure:** Topic-based (git/, ruby/, vim/, etc.)
- **Approach:** Convention-based with special extensions
- **Strengths:** Highly modular, scales well, extensible
- **Weaknesses:** "Magic" behavior, steeper learning curve
- **Best for:** Power users, complex setups, teams

### thoughtbot/laptop
- **Structure:** Single script
- **Approach:** Opinionated, minimal dotfile management
- **Strengths:** Dead simple, easy to maintain, great docs
- **Weaknesses:** Less customization, focused on installation not configs
- **Best for:** Team onboarding, standardization

## Recommendation for Your Project

Based on your stated goals (clarity, maintainability) and problem (confusion about relationship between script and dotfiles):

**Use Hybrid Config-Driven Structure** with these principles:

1. **Clear Separation:**
   - `dotfiles/` = what gets symlinked
   - `config/` = metadata and settings
   - `scripts/` = implementation details
   - `setup` = entry point

2. **Direct Symlinking:**
   - Not GNU Stow (adds complexity)
   - Not chezmoi (overkill for single user)
   - Custom script in `scripts/bootstrap.sh`

3. **Brewfile for Apps:**
   - `config/Brewfile` with all packages
   - `brew bundle` in setup script

4. **Idempotent Setup Script:**
   - Can run repeatedly safely
   - Clear logging of what's happening
   - Modular (calls scripts/ components)

5. **macOS Defaults:**
   - `config/macos-defaults.sh` for system prefs
   - Optional (can skip if not needed)

This gives you clarity (obvious what each directory does), maintainability (easy to add new tools), and solves your stated problem (clear relationship between scripts and dotfiles).

## Sources

### Architecture Patterns
- [mathiasbynens/dotfiles](https://github.com/mathiasbynens/dotfiles) - Flat structure pattern
- [holman/dotfiles](https://github.com/holman/dotfiles) - Topic-based organization
- [thoughtbot/laptop](https://github.com/thoughtbot/laptop) - Minimal script approach
- [Getting Started with Dotfiles](https://webpro.nl/articles/getting-started-with-dotfiles) - General patterns

### Symlink Management
- [Exploring Tools For Managing Your Dotfiles](https://gbergatto.github.io/posts/tools-managing-dotfiles/) - Stow vs chezmoi comparison
- [Managing dotfiles with GNU Stow](https://www.tusharchauhan.com/writing/dotfile-management-using-gnu-stow/)
- [Managing dotfiles with chezmoi](https://stoddart.github.io/2024/09/08/managing-dotfiles-with-chezmoi.html)

### Homebrew Integration
- [Homebrew Bundle Documentation](https://docs.brew.sh/Brew-Bundle-and-Brewfile) - Official docs
- [Setting Up a New Mac with Dotfiles, Brew Bundle, and Mackup](https://respawn.io/posts/dotfiles-brew-bundle-and-mackup) - Integration patterns
- [Setting up a new Mac with dotfiles and Homebrew bundle](https://lincolnmullen.com/blog/setting-up-a-new-mac-with-homebrew/) - Practical guide

### macOS Automation
- [Automate Your macOS Default Settings](https://emmer.dev/blog/automate-your-macos-defaults/) - defaults write patterns
- [How to create a "dotfile" for all your Mac system preferences](https://blog.rexyuan.com/how-to-create-a-dotfile-for-all-your-mac-system-preferences-76f992581bd7) - Discovery workflow

### Best Practices
- [The Ultimate Guide to Mastering Dotfiles](https://www.daytona.io/dotfiles/ultimate-guide-to-dotfiles) - Comprehensive guide
- [Manage Your Dotfiles Like a Superhero](https://www.jakewiesler.com/blog/managing-dotfiles) - Anti-patterns
- [dotfiles.github.io](https://dotfiles.github.io/) - Community resources
- [awesome-dotfiles](https://github.com/webpro/awesome-dotfiles) - Curated list

---
*Architecture research for: Mac setup automation and dotfiles management*
*Researched: 2026-02-01*
*Confidence: HIGH (verified with official sources and multiple popular repositories)*
