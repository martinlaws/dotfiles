# Phase 2: Dotfiles & Developer Config - Research

**Researched:** 2026-02-01
**Domain:** Dotfiles management with GNU Stow, Git/SSH configuration, shell config symlinking
**Confidence:** HIGH

## Summary

This phase implements automated dotfiles management using GNU Stow for symlinking, combined with templated Git configuration and SSH key setup. The research focused on GNU Stow's capabilities (locked decision), configuration validation patterns, backup strategies, and the .local override pattern for machine-specific settings.

GNU Stow is the industry standard for dotfiles symlinking, using a symlink farm management approach that mirrors home directory structure. The standard pattern organizes dotfiles in package-based subdirectories (e.g., `zsh/`, `git/`, `ssh/`) within a repository, with Stow creating symlinks from `~` back to these packages. Configuration files requiring user-specific values (like `.gitconfig`) use a template approach with setup-time prompting, while machine-specific overrides follow the `.local` pattern convention (`.zshrc.local`, `.gitconfig.local`).

Key technical requirements identified: backup existing files before symlinking to avoid data loss, validate configuration syntax before linking (using `zsh -n` for shell configs, git config parsing for `.gitconfig`), handle SSH key generation with ed25519 algorithm, integrate with macOS keychain for SSH agent persistence, and test GitHub connectivity with `ssh -T git@github.com` post-setup.

**Primary recommendation:** Use package-based GNU Stow organization with pre-symlinking backup, template-based `.gitconfig` generation, ed25519 SSH keys with macOS keychain integration, and documented .local override pattern for machine-specific settings.

## Standard Stack

The established tools for dotfiles management and developer configuration:

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| GNU Stow | 2.3+ | Symlink farm manager for dotfiles | Industry standard, transparent symlinks, no magic, handles nested structures reliably |
| OpenSSH | 8.0+ (macOS bundled) | SSH key generation and agent | Native macOS tool, ed25519 support since v6.5, keychain integration |
| Git | 2.13+ | Git configuration management | Native tool, conditional includes since v2.13, template support built-in |
| Zsh | 5.8+ (macOS bundled) | Shell interpreter | macOS default shell since Catalina, native syntax validation with `zsh -n` |

### Supporting
| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| gum | Latest via Homebrew | Interactive prompts for setup | Already established in Phase 1 for UI consistency |
| shellcheck | Latest via Homebrew | Shell script validation (bash/sh only) | Validate installer scripts, but NOT for `.zshrc` (zsh unsupported) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| GNU Stow | chezmoi | chezmoi adds templating complexity; overkill when .local pattern suffices for machine-specific settings |
| GNU Stow | yadm | yadm uses bare repo pattern with higher risk of accidentally committing secrets |
| GNU Stow | Custom symlink script | Reinventing the wheel; Stow handles edge cases, conflict detection, nested directories reliably |

**Installation:**
```bash
# GNU Stow is typically installed via Homebrew (Phase 1)
brew install stow

# No additional packages needed - Git, OpenSSH, Zsh are macOS bundled
```

## Architecture Patterns

### Recommended Project Structure

**Package-based organization** (Standard Stow pattern):
```
dotfiles/
├── .stow-local-ignore    # Patterns to exclude from symlinking
├── git/
│   ├── .gitconfig        # Template file with placeholder values
│   └── .gitignore_global
├── zsh/
│   └── .zshrc            # Sources .zshrc.local if exists
├── ssh/
│   └── .ssh/
│       └── config        # Base SSH config (or template if user-specific)
├── starship/
│   └── .config/
│       └── starship.toml
└── scripts/
    └── setup-dotfiles.sh # Phase 2 setup script
```

**Key structural requirements:**
- Each package directory mirrors the target structure under `~`
- Root dotfiles (`.zshrc`) go in package root: `zsh/.zshrc` → `~/.zshrc`
- `.config/` subdirectories: `starship/.config/starship.toml` → `~/.config/starship.toml`
- Stow run from repo root with `stow zsh git starship` to selectively install packages

### Pattern 1: GNU Stow Basic Usage
**What:** Symlink dotfiles packages from repository to home directory
**When to use:** All symlinking operations for version-controlled configs
**Example:**
```bash
# From dotfiles repo root, symlink packages to parent directory (~)
cd ~/dotfiles
stow -v zsh       # Symlinks zsh/.zshrc → ~/.zshrc
stow -v starship  # Symlinks starship/.config/starship.toml → ~/.config/starship.toml

# Check what would happen without making changes
stow -n -v git    # Dry-run mode

# Remove symlinks (useful for testing)
stow -D zsh       # Unstow/remove zsh package symlinks
```

### Pattern 2: Backup Before Symlinking
**What:** Move existing files to timestamped backups before creating symlinks
**When to use:** First-time setup or when conflicts exist
**Example:**
```bash
# Backup pattern: ~/.filename.backup.TIMESTAMP
backup_file() {
    local file="$1"
    if [ -e "$file" ] && [ ! -L "$file" ]; then
        local timestamp=$(date +%Y%m%d-%H%M%S)
        local backup="${file}.backup.${timestamp}"
        mv "$file" "$backup"
        echo "Backed up: $backup"
    fi
}

# Before stowing, backup potential conflicts
backup_file ~/.zshrc
backup_file ~/.gitconfig
backup_file ~/.ssh/config

# Then proceed with stow
stow zsh git ssh
```

### Pattern 3: .local Override Pattern
**What:** Source machine-specific overrides without committing them to repo
**When to use:** Machine-specific paths, credentials, font sizes, work vs personal settings
**Example:**
```bash
# In zsh/.zshrc (committed to repo)
# At end of file:
if [ -f ~/.zshrc.local ]; then
    source ~/.zshrc.local
fi

# In git/.gitconfig (committed to repo)
[include]
    path = ~/.gitconfig.local

# In .gitignore (committed to repo)
*.local
```

**User creates as needed (not committed):**
```bash
# ~/.zshrc.local (machine-specific)
export WORK_API_KEY="secret"
alias work_vpn="openvpn ~/work/config.ovpn"

# ~/.gitconfig.local (machine-specific)
[user]
    signingkey = ABC123DEF456  # GPG key specific to this machine
```

### Pattern 4: Git Config Templating
**What:** Prompt for user-specific values during setup, generate personalized config
**When to use:** Configs requiring user input (name, email) for shareability
**Example:**
```bash
# Keep .gitconfig.template in repo with placeholders
# During setup:
read -p "Enter your Git user.name: " git_name
read -p "Enter your Git user.email: " git_email

# Generate ~/.gitconfig (NOT symlinked, NOT in repo)
sed -e "s/{{NAME}}/$git_name/g" \
    -e "s/{{EMAIL}}/$git_email/g" \
    dotfiles/git/.gitconfig.template > ~/.gitconfig

# Add include for .local overrides
echo -e "\n[include]\n    path = ~/.gitconfig.local" >> ~/.gitconfig
```

### Pattern 5: SSH Key Generation with Keychain
**What:** Generate ed25519 SSH keys and integrate with macOS keychain
**When to use:** SSH keys missing or setup on fresh machine
**Example:**
```bash
# Check for existing keys
if [ ! -f ~/.ssh/id_ed25519 ]; then
    # Generate with current year in comment for rotation tracking
    ssh-keygen -t ed25519 -C "user@example.com-2026" -f ~/.ssh/id_ed25519

    # Add to macOS keychain (persists across reboots)
    ssh-add --apple-use-keychain ~/.ssh/id_ed25519
fi

# Ensure ~/.ssh/config has keychain integration
cat >> ~/.ssh/config <<EOF
Host *
    AddKeysToAgent yes
    UseKeychain yes
    IdentityFile ~/.ssh/id_ed25519
EOF

# Test GitHub connection
ssh -T git@github.com
# Expected output: "Hi [username]! You've successfully authenticated..."
```

### Pattern 6: Configuration Validation
**What:** Syntax check configs before symlinking to prevent broken shells
**When to use:** Before symlinking any shell or git configs
**Example:**
```bash
# Validate zsh config
validate_zsh() {
    local file="$1"
    if zsh -n "$file" 2>/dev/null; then
        echo "✓ Valid zsh syntax: $file"
        return 0
    else
        echo "✗ Invalid zsh syntax: $file"
        return 1
    fi
}

# Validate git config structure
validate_git() {
    local file="$1"
    if git config -f "$file" --list >/dev/null 2>&1; then
        echo "✓ Valid git config: $file"
        return 0
    else
        echo "✗ Invalid git config: $file"
        return 1
    fi
}

# Validate before stowing
validate_zsh dotfiles/zsh/.zshrc || exit 1
validate_git dotfiles/git/.gitconfig || exit 1
```

### Anti-Patterns to Avoid
- **Using `stow --adopt` without git commit:** The --adopt flag moves existing files INTO your stow directory, potentially overwriting your repo files. Always commit before using --adopt so you can recover if needed.
- **Symlinking .gitconfig directly:** Makes repo user-specific and not shareable. Use template approach instead.
- **Creating stub .local files in repo:** Defeats the purpose of .local pattern. Only document the pattern, let users create when needed.
- **Ignoring backup step:** Risk of data loss on first run. Always backup existing files before symlinking.
- **Custom .stow-local-ignore without defaults:** Overrides Stow's built-in ignore list. Must re-specify `.git`, `README.md`, etc. if creating custom ignore file.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Symlinking dotfiles | Custom script with `ln -s` loops | GNU Stow | Handles nested directories, conflict detection, unstow/removal, ignore patterns, directory folding/unfolding edge cases |
| SSH key passphrases | Custom keychain wrapper script | OpenSSH + macOS keychain (`ssh-add --apple-use-keychain`) | Native integration, persists across reboots, secure storage, automatic loading on first use |
| Machine-specific config | Separate git branches per machine | .local override pattern + .gitignore | Industry convention, simpler mental model, no merge conflicts between branches |
| Config file validation | Regex parsing of syntax | Native tool validators (`zsh -n`, `git config -f`) | Language-aware, handles edge cases, detects semantic errors not just syntax |
| Backup timestamping | Manual naming or UUID | `date +%Y%m%d-%H%M%S` | Human-readable, sortable, standard format, no collisions in practice |

**Key insight:** GNU Stow is mature (first released 1993, stable 2.x since 2011) and handles symlink edge cases that custom scripts miss: conflict detection, target directory creation, symlink cleanup on unstow, ignore patterns, and "tree folding" (symlinking directories vs individual files based on context). The two-phase scan (check conflicts, then execute) prevents partial broken states.

## Common Pitfalls

### Pitfall 1: Symlink Conflicts Breaking Stow
**What goes wrong:** Running `stow package` fails with "existing target is neither a link nor a directory" error because a regular file exists where Stow wants to create a symlink.
**Why it happens:** Fresh Mac or existing dotfiles setup has files in `~/.zshrc`, `~/.gitconfig` that conflict with Stow's target paths.
**How to avoid:** Always backup existing files before first Stow run. Use `stow -n -v package` to dry-run and see what would happen.
**Warning signs:** Error message like `WARNING! stowing zsh would cause conflicts:` followed by list of conflicting files.

### Pitfall 2: .stow-local-ignore Overriding Defaults
**What goes wrong:** Creating `.stow-local-ignore` causes Stow to symlink `.git`, `README.md`, or other files you wanted ignored.
**Why it happens:** Custom ignore file completely replaces Stow's built-in ignore list (doesn't extend it).
**How to avoid:** If creating custom `.stow-local-ignore`, copy Stow's default patterns first: `.git`, `.gitignore`, `.gitmodules`, `README.*`, `LICENSE.*`, `COPYING`, backup files (`.+~`), autosave (`\#.*\#`).
**Warning signs:** Git repo metadata appears symlinked in home directory, or README files showing up in `~`.

### Pitfall 3: SSH Keys Not Persisting After Reboot
**What goes wrong:** SSH key passphrases work until reboot, then must be re-entered every time.
**Why it happens:** macOS changed default behavior in Sierra to not automatically load SSH keys from keychain. Keys added with `ssh-add` don't persist.
**How to avoid:** Use `ssh-add --apple-use-keychain` when adding keys, AND add to `~/.ssh/config`:
```
Host *
    AddKeysToAgent yes
    UseKeychain yes
```
**Warning signs:** After reboot, git push/pull prompts for passphrase despite entering it previously.

### Pitfall 4: Git Template Not Updated in Home Directory
**What goes wrong:** Changes to `dotfiles/git/.gitconfig` don't reflect in `~/.gitconfig` because it's a generated file, not a symlink.
**Why it happens:** Template approach means `.gitconfig` is copied/generated during setup, not symlinked.
**How to avoid:** Document clearly in README that `.gitconfig` changes require re-running setup or manual copying. Consider separate "system" and "user" config sections.
**Warning signs:** Git config changes in repo don't take effect, confusion about why Stow didn't link this file.

### Pitfall 5: Validation Fails but Setup Continues
**What goes wrong:** Syntax errors in `.zshrc` not caught until user opens new shell and sees error messages.
**Why it happens:** Setup script doesn't validate configs before symlinking, or validates but ignores failures.
**How to avoid:** Always validate with `zsh -n` and `git config -f` before symlinking. Exit on validation failure OR prompt user "Continue anyway?" for informed choice.
**Warning signs:** User reports broken shell after running setup, has to restore backup to recover.

### Pitfall 6: Directory Structure Mismatch
**What goes wrong:** Stow creates symlinks in wrong locations (e.g., `~/.config.starship.toml` instead of `~/.config/starship.toml`).
**Why it happens:** Package directory structure doesn't mirror target home directory structure. Common mistake: `starship/starship.toml` instead of `starship/.config/starship.toml`.
**How to avoid:** Mirror home directory structure exactly in each package. Use `stow -n -v` dry-run to verify target paths before executing.
**Warning signs:** Config files appear in home directory with wrong names or paths, applications can't find their configs.

### Pitfall 7: SSH Config Symlinked with User-Specific Values
**What goes wrong:** SSH config contains machine-specific hostnames or credentials, gets committed to public repo.
**Why it happens:** Not recognizing which configs need templating vs symlinking. Blindly symlinking everything.
**How to avoid:** Inspect SSH config for user-specific values. If present, use template approach or rely on `.ssh/config.local` override pattern.
**Warning signs:** Security scan flags committed credentials, or config references hosts that don't exist on other machines.

## Code Examples

Verified patterns from official sources and common implementations:

### GNU Stow Workflow
```bash
# Source: GNU Stow manual (https://www.gnu.org/software/stow/manual/stow.html)
# From dotfiles repository root

# Dry-run to see what would happen
stow -n -v zsh

# Stow package (creates symlinks)
stow -v zsh

# Unstow package (removes symlinks)
stow -D zsh

# Restow package (unstow then stow, useful after config changes)
stow -R zsh

# Stow multiple packages at once
stow -v zsh git starship ssh
```

### Complete Setup Script Structure
```bash
#!/bin/bash
# setup-dotfiles.sh - Phase 2 main script

set -euo pipefail

# Source UI library from Phase 1
source "$(dirname "$0")/lib/ui.sh"

ui_header "Dotfiles & Developer Config Setup"

# 1. Backup existing files
ui_section "Backing up existing files"
backup_if_exists() {
    local file="$1"
    if [ -e "$file" ] && [ ! -L "$file" ]; then
        local timestamp=$(date +%Y%m%d-%H%M%S)
        mv "$file" "${file}.backup.${timestamp}"
        ui_success "Backed up: $file"
    fi
}

backup_if_exists ~/.zshrc
backup_if_exists ~/.gitconfig
backup_if_exists ~/.ssh/config

# 2. Validate configs before symlinking
ui_section "Validating configurations"
if ! zsh -n zsh/.zshrc; then
    ui_error "Invalid zsh syntax in .zshrc"
    ui_confirm "Continue anyway?" || exit 1
fi

# 3. Setup Git config from template
ui_section "Configuring Git"
if [ ! -f ~/.gitconfig ]; then
    read -p "Git user.name: " git_name
    read -p "Git user.email: " git_email

    sed -e "s/{{NAME}}/$git_name/g" \
        -e "s/{{EMAIL}}/$git_email/g" \
        git/.gitconfig.template > ~/.gitconfig

    ui_success "Git configured"
else
    ui_info "Git config exists, skipping"
fi

# 4. Symlink with GNU Stow
ui_section "Creating symlinks"
stow -v zsh starship ssh
ui_success "Dotfiles symlinked"

# 5. SSH key setup
ui_section "Setting up SSH keys"
if [ ! -f ~/.ssh/id_ed25519 ]; then
    ui_info "Generating SSH key"
    read -p "Email for SSH key: " email
    ssh-keygen -t ed25519 -C "$email-2026" -f ~/.ssh/id_ed25519
    ssh-add --apple-use-keychain ~/.ssh/id_ed25519
    ui_success "SSH key generated and added to keychain"
else
    ui_info "SSH key exists"
fi

# 6. Test GitHub connection
ui_section "Testing GitHub connection"
if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
    ui_success "GitHub SSH connection working"
else
    ui_error "GitHub SSH connection failed"
    ui_info "Add your public key to GitHub: https://github.com/settings/keys"
    ui_info "Public key: ~/.ssh/id_ed25519.pub"
fi

# 7. Summary
ui_header "Setup Complete"
ui_success "Shell configs symlinked"
ui_success "Git configured"
ui_info "Restart your terminal or run: source ~/.zshrc"
```

### .stow-local-ignore File
```bash
# Source: GNU Stow documentation + common patterns
# .stow-local-ignore in repo root

# Version control
\.git
\.gitignore
\.gitmodules

# Documentation
^/README.*
^/LICENSE.*
^/COPYING
^/\.planning

# Editor backup/temp files
\.+~          # Emacs backup files
\#.*\#        # Emacs autosave files
\.swp$        # Vim swap files
\.DS_Store    # macOS metadata

# Scripts (not dotfiles)
^/scripts

# Templates (processed, not symlinked)
\.template$
```

### SSH Config with Keychain Integration
```bash
# Source: GitHub SSH documentation + macOS keychain integration guides
# ~/.ssh/config

Host *
    AddKeysToAgent yes
    UseKeychain yes
    IdentityFile ~/.ssh/id_ed25519

# Include machine-specific config if exists
Include ~/.ssh/config.local
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| RSA 2048-bit keys | Ed25519 keys | ~2013 (OpenSSH 6.5) | Smaller keys, faster, more secure; industry standard in 2026 |
| `ssh-add -K` flag | `ssh-add --apple-use-keychain` | macOS Monterey (2021) | Changed to align with OpenSSH upstream; old flag deprecated |
| Flat dotfiles with symlink script | Package-based GNU Stow | Gained popularity ~2012 | Better organization, selective installation, cleaner structure |
| Single .gitconfig | Conditional includes + .local pattern | Git 2.13 (2017) | Machine-specific overrides without branches or templating |
| Oh My Zsh required | Minimal zsh configs | Trend since 2020+ | Faster shell startup, less bloat, simpler maintenance |

**Deprecated/outdated:**
- **chezmoi for simple setups:** Overkill when .local pattern handles machine-specific needs. Use only for complex multi-OS templating requirements.
- **Bare git repo method:** Higher risk of committing secrets compared to directory-based approach with explicit .gitignore.
- **shellcheck for zsh validation:** ShellCheck removed zsh support; use `zsh -n` instead.

## Open Questions

Things that couldn't be fully resolved:

1. **SSH config templating decision criteria**
   - What we know: Depends on whether config contains user-specific values (hostnames, IPs, usernames)
   - What's unclear: Exact heuristic for "inspect and decide." User's current SSH config content unknown.
   - Recommendation: Planner should include inspection step in setup script. If `~/.ssh/config` doesn't exist or is minimal, symlink directly. If contains Host entries with specific IPs/users, implement .local pattern instead.

2. **Git config include order**
   - What we know: Git includes are inserted at point of [include] directive, order matters for overrides
   - What's unclear: Whether to put .local include at top (base defaults, local overrides) or bottom (local is final word)
   - Recommendation: Include `.local` at BOTTOM of `.gitconfig` so local settings always override repo defaults.

3. **Validation thoroughness balance**
   - What we know: Can validate syntax with `zsh -n` and `git config -f`, but doesn't catch semantic errors (invalid paths, missing dependencies)
   - What's unclear: How deep to validate without over-engineering (e.g., checking if all sourced files exist, validating plugin availability)
   - Recommendation: Start with basic syntax validation. Semantic validation can be added in Phase 4 (maintenance) if users report issues.

## Sources

### Primary (HIGH confidence)
- [GNU Stow Manual](https://www.gnu.org/software/stow/manual/stow.html) - Official documentation
- [GitHub SSH Documentation](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/) - Official testing procedures
- [Git Config Documentation](https://git-scm.com/docs/git-config) - Official includeIf and template features
- [Stow Ignore Lists Syntax](https://www.gnu.org/software/stow/manual/html_node/Types-And-Syntax-Of-Ignore-Lists.html) - Official ignore pattern documentation

### Secondary (MEDIUM confidence)
- [How I manage my dotfiles using GNU Stow](https://tamerlan.dev/how-i-manage-my-dotfiles-using-gnu-stow/) - Verified practical patterns
- [SSH Key Best Practices for 2025](https://www.brandonchecketts.com/archives/ssh-ed25519-key-best-practices-for-2025) - Ed25519 best practices, key rotation
- [ArchWiki: Dotfiles](https://wiki.archlinux.org/title/Dotfiles) - Comprehensive patterns and backup strategies
- [Git Config Conditional Includes](https://blog.thomasheartman.com/posts/modularizing-your-git-config-with-conditional-includes/) - Verified includeIf usage
- [macOS SSH Keychain Integration](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent) - Official GitHub guide with macOS specifics

### Secondary (MEDIUM confidence) - Additional
- [skeptric: Customising Portable Dotfiles](https://skeptric.com/portable-custom-config/) - .local override pattern verification
- [thoughtbot dotfiles](https://github.com/thoughtbot/dotfiles) - Real-world .local pattern implementation
- [The Ultimate Guide to Mastering Dotfiles](https://www.daytona.io/dotfiles/ultimate-guide-to-dotfiles) - 2026 best practices overview

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - GNU Stow is documented locked decision, ed25519 and Git are official standards
- Architecture patterns: HIGH - Verified through GNU Stow official docs, GitHub official docs, multiple consistent sources
- Pitfalls: MEDIUM-HIGH - Combination of official documentation warnings and verified community experiences
- Code examples: HIGH - Sourced from official documentation and verified through multiple implementations

**Research date:** 2026-02-01
**Valid until:** 2026-04-01 (60 days) - Stable domain, mature tools, unlikely to see breaking changes. GNU Stow 2.x is stable since 2011, SSH/Git are standardized protocols.
