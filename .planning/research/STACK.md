# Stack Research

**Domain:** Mac Setup Automation and Dotfiles Management
**Researched:** 2026-02-01
**Confidence:** HIGH

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Bash | 5.x (via Homebrew) | Primary automation script language | Native to macOS, perfect for CLI commands, process management, and system tasks. Every Mac has it. Fast for glue code. |
| Homebrew | Latest (4.x+) | Package manager and application installer | De facto standard for macOS package management. Full Apple Silicon support since 2021. Handles formulae, casks, and Mac App Store apps. |
| Homebrew Bundle | Built-in | Declarative dependency management via Brewfile | Infrastructure-as-code approach for packages. Idempotent by design. Single command setup. |
| GNU Stow | 2.4.x | Dotfiles symlink manager | Simplest, most maintainable approach. Creates/manages symlinks without complex logic. Easy to migrate away from if needed. Battle-tested since 1993. |
| Gum | Latest (0.14.x+) | Interactive CLI prompts and styling | Beautiful, user-friendly prompts without complex scripting. Single binary (Go). Part of trusted Charmbracelet ecosystem. Makes setup delightful. |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| mas | Latest | Mac App Store CLI | For installing Mac App Store apps in Brewfile (use with `mas` entries in Brewfile) |
| mise | 2026.x | Development tool version manager | For managing node, python, etc. versions. Replaces asdf with better performance and security. Use if you need multiple runtime versions. |
| jq | 1.7.x | JSON processor | For parsing JSON config files or API responses. Use sparingly - prefer structured data in bash arrays when possible. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| shellcheck | Bash linting | Critical for catching common bash mistakes. Install via Homebrew: `brew install shellcheck` |
| shfmt | Shell script formatting | Consistent formatting. Install via Homebrew: `brew install shfmt` |
| git | Version control | Ensure latest via Homebrew (macOS ships with old version). Required for dotfiles repo. |

## Installation

```bash
# Install Homebrew (prerequisite for everything else)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install core tools via Homebrew
brew install stow gum mas mise shellcheck shfmt git

# Install newer bash (optional but recommended)
brew install bash

# Clone your dotfiles repo
git clone https://github.com/yourusername/dotfiles.git ~/dotfiles

# Run setup script
cd ~/dotfiles && ./setup.sh
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| GNU Stow | chezmoi | Choose chezmoi if you need: encryption, cross-machine templates, password manager integration. Adds significant complexity. |
| GNU Stow | yadm | Choose yadm if you prefer Git-wrapper approach. Less explicit than Stow. Harder to understand what's linked where. |
| GNU Stow | homemade scripts | Never recommend. Reinventing the wheel. Stow is 30 years old and does one thing perfectly. |
| Bash | Python | Choose Python if: script >200 lines, complex data structures, need Windows support. For Mac-only setup automation, Bash is simpler. |
| Bash | Go/Rust | Choose compiled language if: distributing binary to non-technical users, need extreme performance. Overkill for personal dotfiles. |
| Homebrew Bundle | Manual `brew install` | Never recommend. Brewfile is declarative, version-controlled, and idempotent. Manual commands are none of these. |
| mise | asdf | Choose asdf only if: already using it, need specific asdf-only plugin. mise is faster, more secure, better UX. |
| Gum | enquirer.js | Never for bash. enquirer is Node.js. Would require Node runtime for setup script (circular dependency). |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Custom symlink scripts | Fragile, hard to maintain, breaks on edge cases. You'll miss `-n` flag and create nested symlinks. | GNU Stow - battle-tested, handles all edge cases |
| Ansible for personal dotfiles | Massive overkill. Requires Python, complex YAML. For 1 machine, it's cargo-culting from enterprise. | Bash + Stow + Brewfile - simpler, more maintainable |
| Docker for Mac setup | Cannot manage macOS system settings. Wrong abstraction. Setup scripts configure the host, not containers. | Native macOS tools (defaults, Homebrew) |
| Old Bash (macOS default) | macOS ships with Bash 3.2 (2007) due to GPL licensing. Missing associative arrays, many improvements. | Install Bash 5.x via Homebrew |
| Rosetta 2 for Homebrew | Performance penalty. Native Apple Silicon support exists since 2021. | Use native `/opt/homebrew` installation |

## Stack Patterns by Variant

**If you need multi-machine support (work laptop + personal):**
- Add machine-specific Brewfiles: `Brewfile.$(hostname -s)`
- Use environment variable: `export HOMEBREW_BUNDLE_FILE="~/dotfiles/Brewfile.$(hostname -s)"`
- Keep shared packages in base `Brewfile`
- Use Stow packages (directories) to organize: `stow -t ~ shared work-specific`

**If you need secrets (API keys, tokens):**
- DO NOT commit secrets to dotfiles repo
- Use `defaults write` for non-sensitive preferences
- Use macOS Keychain for sensitive data: `security add-generic-password`
- Or use chezmoi instead of Stow (adds encryption + templating)

**If you need version-specific runtimes:**
- Add mise to your stack
- Create `.mise.toml` in project directories
- Use `mise use node@20` for automatic version switching
- mise has no shim overhead (unlike asdf) - direct PATH manipulation

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|-----------------|-------|
| Homebrew 4.x | Apple Silicon (M1/M2/M3/M4) | Native support. Installs to `/opt/homebrew/`. Fully compatible. |
| Homebrew 4.x | macOS 13+ (Ventura) | Recommended. Works on 10.11+ but unsupported. |
| GNU Stow 2.4.x | Any macOS | Perl-based. Ships with macOS. Homebrew version recommended for bug fixes. |
| Gum 0.14.x | macOS 11+ | Single Go binary. No dependencies. Works on Intel and Apple Silicon. |
| mise 2026.x | macOS 11+ | Rust binary. Native Apple Silicon. Backward compatible with asdf plugins. |
| Bash 5.x | macOS 10.x+ | No conflicts. Installed to `/opt/homebrew/bin/bash`. Update `/etc/shells` to use as login shell. |

## Apple Silicon Specific Notes

All recommended tools have native Apple Silicon support:
- **Homebrew**: Installs to `/opt/homebrew/` (not `/usr/local/`). Add to PATH in `.zshrc`
- **Gum**: Native arm64 binary available
- **mise**: Native arm64 binary, better performance than asdf
- **Stow**: Perl script, architecture-agnostic

**Migration note:** If migrating from Intel Mac, `brew bundle dump` on old machine, `brew bundle install` on new machine. Homebrew handles architecture differences automatically.

## Idempotency Patterns

Critical for update mode. All recommended tools support idempotent operations:

**Homebrew Bundle:**
```bash
# Safe to run multiple times
brew bundle check || brew bundle install
brew bundle cleanup --force  # Remove packages not in Brewfile
```

**GNU Stow:**
```bash
# Safe to re-stow (updates existing symlinks)
stow -R -t ~ git zsh  # -R = restow (delete then stow again)
```

**mkdir and symlinks:**
```bash
# Idempotent directory creation
mkdir -p ~/.config/foo

# Idempotent symlink (use -f for files, -fn for directories)
ln -sf ~/dotfiles/file ~/.file
ln -sfn ~/dotfiles/dir ~/.dir  # -n prevents creating symlink inside directory
```

**defaults write:**
```bash
# Always safe to re-run (overwrites value)
defaults write com.apple.dock autohide -bool true
killall Dock  # Required to apply changes
```

## Security Considerations

**Homebrew Bundle:** Brewfile is Ruby code. Avoid arbitrary Ruby logic. Keep it declarative.

**mise vs asdf:** mise is more secure. asdf plugins run arbitrary shell code. mise prefers verified backends (aqua registry with Cosign/SLSA verification).

**defaults write:** Can break system if used incorrectly. Test each command individually before adding to automation. Always backup: `defaults read > backup.plist`.

**Stow:** Only creates symlinks. Cannot execute code. Safest dotfiles approach.

## Sources

### Official Documentation (HIGH confidence)
- [Homebrew Bundle Documentation](https://docs.brew.sh/Brew-Bundle-and-Brewfile) - Brew Bundle and Brewfile usage
- [chezmoi Comparison Table](https://www.chezmoi.io/comparison-table/) - Feature comparison of dotfiles tools
- [Gum GitHub Repository](https://github.com/charmbracelet/gum) - Interactive CLI tool documentation
- [mise Comparison to asdf](https://mise.jdx.dev/dev-tools/comparison-to-asdf.html) - mise vs asdf technical differences
- [Homebrew Installation Docs](https://docs.brew.sh/Installation) - Apple Silicon compatibility

### Community Resources (MEDIUM confidence)
- [Mac Setup Automation Best Practices](https://about.gitlab.com/blog/2020/04/17/dotfiles-document-and-automate-your-macbook-setup/) - GitLab dotfiles guide
- [Dotfiles Management Guide](https://blog.alyssaholland.me/dotfiles-management) - Modern dotfiles patterns
- [macOS Defaults Automation](https://emmer.dev/blog/automate-your-macos-defaults/) - defaults write best practices
- [Idempotent Bash Scripts](https://arslan.io/2019/07/03/how-to-write-idempotent-bash-scripts/) - Idempotency patterns
- [Homebrew Apple Silicon Guide (2026)](https://mac.install.guide/homebrew/index.html) - Latest compatibility info

### Ecosystem Discovery (MEDIUM confidence)
- [Dotfiles Tools Comparison](https://gbergatto.github.io/posts/tools-managing-dotfiles/) - Stow vs chezmoi vs yadm analysis
- [Hacker News: YADM vs Chezmoi Discussion](https://news.ycombinator.com/item?id=39975247) - Community preferences
- [Bash vs Python for Automation](https://cloudray.io/articles/bash-vs-python) - Language choice rationale
- [mise vs asdf Comparison](https://betterstack.com/community/guides/scaling-nodejs/mise-vs-asdf/) - Version manager analysis

---
*Stack research for: Mac Setup Automation and Dotfiles Management*
*Researched: 2026-02-01*
