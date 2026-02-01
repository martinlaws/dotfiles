# Phase 1: Foundation & Core Tools - Research

**Researched:** 2026-02-01
**Domain:** Mac setup automation, Homebrew installation, shell scripting, CLI tooling
**Confidence:** HIGH

## Summary

Phase 1 establishes the foundation for Mac setup automation on Apple Silicon and Intel Macs. The research focused on Homebrew installation mechanics, Xcode Command Line Tools automation, shell script best practices for idempotent operations, and beautiful CLI interface implementation using Gum.

The standard approach combines POSIX-compliant shell scripting with Homebrew's official installer, Gum for beautiful interfaces, and careful PATH configuration to handle Apple Silicon's `/opt/homebrew` vs Intel's `/usr/local` differences. The critical insight is that many setup scripts fail due to incorrect PATH configuration on Apple Silicon or assuming sudo prompts can be eliminated (they cannot without pre-configuration).

Key challenges include: Xcode CLT installation requires GUI interaction by default, Homebrew's NONINTERACTIVE mode only skips confirmations (not sudo prompts), and Apple Silicon requires explicit `eval "$(brew shellenv)"` configuration that differs by architecture.

**Primary recommendation:** Use bash (not sh/zsh exclusively), run with `sh setup` (not chmod +x), detect architecture with `uname -m`, install Homebrew with NONINTERACTIVE=1 to skip confirmations, configure PATH immediately with `eval "$(brew shellenv)"`, use Gum v0.17+ for progress indicators and styling, make all operations idempotent with proper existence checks using `command -v`, and structure the script to fail gracefully with clear error messages.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Homebrew | Latest | Package manager for macOS | Official macOS package manager, handles dependencies, supports Apple Silicon and Intel |
| Gum | v0.17.0+ | Beautiful CLI interfaces | Charmbracelet's official tool, provides spinners, styling, prompts without Go code |
| Bash | 3.2+ (macOS default) | Shell scripting | POSIX-compliant, available on all Macs, predictable behavior |
| Xcode CLT | Latest | Compiler toolchain | Required by Homebrew, provides git and build tools |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| GNU Stow | 2.3+ | Dotfiles symlink manager | Recommended for Phase 2+ dotfiles symlinking, simple and transparent |
| getopts | Built-in | Command-line argument parsing | For --verbose, --dry-run flags, POSIX-compliant |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Gum | Plain bash spinners | Manual spinner implementation is 50+ lines vs Gum's one-liner, harder to maintain |
| Bash | zsh | zsh not guaranteed on older macOS, bash more portable for setup scripts |
| Homebrew Bundle | Manual brew install | Bundle provides idempotent behavior, easier to maintain package lists |
| command -v | which | `which` is external command, not POSIX-compliant, `command -v` is built-in and reliable |

**Installation:**
```bash
# Homebrew (installed by setup script)
NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Gum (after Homebrew installed)
brew install gum

# Other tools via Brewfile
brew bundle install --file=path/to/Brewfile
```

## Architecture Patterns

### Recommended Project Structure
```
dotfiles/                    # Project root
├── setup                    # Entry point: sh setup
├── scripts/                 # Modular helper scripts
│   ├── lib/                # Reusable functions (optional)
│   │   ├── ui.sh           # Gum wrappers for consistent styling
│   │   ├── detect.sh       # Architecture/state detection
│   │   └── install.sh      # Installation helpers
│   ├── install-homebrew.sh # Homebrew installation logic
│   └── install-tools.sh    # CLI tools via Brewfile
├── config/                  # Configuration files
│   └── Brewfile            # Homebrew dependencies
└── dotfiles/               # Actual dotfiles (Phase 2+)
```

### Pattern 1: Idempotent Installation Checks
**What:** Check if tool exists before attempting installation, skip if present
**When to use:** Every installation step to enable safe re-runs
**Example:**
```bash
# Source: https://www.baeldung.com/linux/bash-script-check-program-exists
# POSIX-compliant existence check
if ! command -v brew >/dev/null 2>&1; then
    echo "Installing Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    echo "Homebrew already installed, skipping..."
fi
```

### Pattern 2: Architecture Detection and PATH Configuration
**What:** Detect Apple Silicon vs Intel, configure Homebrew PATH accordingly
**When to use:** Immediately after Homebrew installation, before any brew commands
**Example:**
```bash
# Source: https://indiespark.org/software/detecting-apple-silicon-shell-script/
ARCH=$(uname -m)

if [ "$ARCH" = "arm64" ]; then
    # Apple Silicon
    BREW_PREFIX="/opt/homebrew"
else
    # Intel
    BREW_PREFIX="/usr/local"
fi

# Configure PATH for current session
eval "$($BREW_PREFIX/bin/brew shellenv)"

# Add to shell profile for future sessions
if ! grep -q "brew shellenv" ~/.zprofile; then
    echo 'eval "$('$BREW_PREFIX'/bin/brew shellenv)"' >> ~/.zprofile
fi
```

### Pattern 3: Gum Progress Indicators
**What:** Use Gum spin for unknown-duration tasks, style for section headers
**When to use:** Long-running operations (brew install), section separation
**Example:**
```bash
# Source: https://github.com/charmbracelet/gum/blob/main/README.md
# Spinner for long operation
gum spin --spinner dot --title "Installing CLI tools..." -- brew bundle install

# Section header with styling
gum style \
    --foreground 212 --border-foreground 212 --border double \
    --align center --width 50 --margin "1 2" --padding "2 4" \
    'Phase 1: Foundation & Core Tools'

# Confirmation prompt
gum confirm "Install Homebrew?" && install_homebrew || echo "Skipping Homebrew"
```

### Pattern 4: Error Handling Without set -e
**What:** Check exit codes explicitly, provide helpful error messages
**When to use:** Installation steps where partial failures are acceptable
**Example:**
```bash
# Source: https://arslan.io/2019/07/03/how-to-write-idempotent-bash-scripts/
# DON'T use set -e for setup scripts - you want controlled failure handling

install_tool() {
    local tool=$1

    if brew install "$tool" 2>/dev/null; then
        gum style --foreground 212 "✓ Installed $tool"
        return 0
    else
        if gum confirm "Failed to install $tool. Continue anyway?"; then
            return 0
        else
            gum style --foreground 196 "Setup cancelled by user"
            exit 1
        fi
    fi
}
```

### Pattern 5: Brewfile-Based Package Management
**What:** Declare all packages in a Brewfile, install idempotently with brew bundle
**When to use:** Installing multiple CLI tools and apps
**Example:**
```bash
# Source: https://docs.brew.sh/Brew-Bundle-and-Brewfile
# config/Brewfile
brew "git"
brew "nodejs"
brew "pnpm"
brew "gh"
brew "tree"
brew "gum"
brew "stow"

# Install with brew bundle (idempotent)
if brew bundle check --file=config/Brewfile >/dev/null 2>&1; then
    echo "All dependencies satisfied"
else
    brew bundle install --file=config/Brewfile
fi
```

### Anti-Patterns to Avoid
- **Using set -euo pipefail in setup scripts:** Too aggressive - you want controlled error handling, not immediate exit. Setup scripts need to handle partial failures gracefully.
- **Using sudo with Homebrew commands:** Homebrew explicitly forbids sudo, creates permission issues. Let Homebrew prompt for sudo when it needs it.
- **Assuming NONINTERACTIVE=1 eliminates sudo prompts:** It only skips confirmation prompts. Sudo password prompts still appear (by design).
- **Using which instead of command -v:** `which` is external command, not POSIX-compliant, may not exist on all systems.
- **Hardcoding /opt/homebrew or /usr/local:** Must detect architecture and use appropriate prefix.
- **Installing Xcode CLT manually with GUI automation:** Fragile, permission-dependent. Let Homebrew installer handle it or document manual step.
- **Not configuring PATH immediately:** Running `brew` commands will fail if PATH not set after installation.
- **Creating directories without -p flag:** `mkdir -p` is idempotent, plain `mkdir` fails if directory exists.
- **Creating symlinks without -f flag:** `ln -sf` is idempotent, plain `ln -s` fails if link exists.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Beautiful CLI prompts/styling | Custom ANSI escape codes, printf formatting | Gum (choose, confirm, style, spin) | Cross-terminal compatibility, edge cases in color support, spinner animation complexity |
| Command existence checking | Parse `which` output, check $PATH manually | `command -v` built-in | POSIX-compliant, handles aliases/functions, reliable exit codes |
| Homebrew PATH detection | Parse brew --prefix, hardcode paths | `eval "$(brew shellenv)"` | Official method, sets all variables (PATH, MANPATH, etc.), handles edge cases |
| Architecture detection | Parse system_profiler, check Rosetta | `uname -m` | Fast, reliable, returns arm64 or x86_64 directly |
| Package installation state | Parse brew list output, check files | `brew bundle check` | Handles dependencies, version constraints, cask vs formula differences |
| Argument parsing | Manual $1 $2 shifting, case statements | getopts built-in | Handles combined flags (-vf), error messages, POSIX-compliant |
| Symlink management | Custom shell loops, recursive functions | GNU Stow | Battle-tested, handles conflicts, --restow for updates, .stow-local-ignore |
| Idempotent file appending | Manual grep checks before echo >> | Check with grep -qF before appending | Prevents duplicate lines, handles partial matches |

**Key insight:** Setup script reliability comes from using battle-tested tools, not clever custom code. The macOS/Homebrew ecosystem has solved these problems - use their solutions.

## Common Pitfalls

### Pitfall 1: PATH Not Configured After Homebrew Installation
**What goes wrong:** Script installs Homebrew successfully, then immediately tries to run `brew` commands that fail with "command not found"
**Why it happens:** Homebrew installation doesn't automatically add itself to PATH in the current shell session. Only future shell sessions get the PATH.
**How to avoid:** Immediately after installation, run `eval "$(brew shellenv)"` to configure PATH for the current session. Don't rely on the installation script's output being followed.
**Warning signs:** "brew: command not found" errors immediately after successful Homebrew installation

### Pitfall 2: Apple Silicon vs Intel Path Hardcoding
**What goes wrong:** Script hardcodes `/usr/local` (Intel path), fails on Apple Silicon Macs where Homebrew installs to `/opt/homebrew`
**Why it happens:** Older setup scripts were written for Intel Macs. Developers forget that Apple Silicon is now standard (2023+).
**How to avoid:** Always use `uname -m` to detect architecture, construct path dynamically, or use `brew --prefix` after Homebrew is in PATH.
**Warning signs:** Script works on Intel test machine but fails on M1/M2/M3 Macs with path errors

### Pitfall 3: Assuming NONINTERACTIVE=1 Eliminates All Prompts
**What goes wrong:** Developer expects fully unattended installation, script still prompts for sudo password
**Why it happens:** NONINTERACTIVE=1 only skips confirmation prompts ("Press RETURN to continue"), not authentication prompts. This is intentional for security.
**How to avoid:** Document that sudo password will be required. For truly unattended scenarios, pre-configure sudoers (not recommended for personal machines).
**Warning signs:** Script hangs waiting for sudo password in automated environment

### Pitfall 4: Xcode Command Line Tools GUI Requirement
**What goes wrong:** Script attempts to automate `xcode-select --install` with AppleScript, fails due to accessibility permissions
**Why it happens:** macOS security prevents GUI automation without explicit permission. Scripts can't grant themselves permission.
**How to avoid:** Let Homebrew installer handle Xcode CLT installation (it prompts correctly), OR document manual installation as prerequisite, OR use the AppleScript approach only with clear permission setup instructions.
**Warning signs:** AppleScript errors about System Events access, installation dialogs appearing but not being clicked

### Pitfall 5: Using set -e in Setup Scripts
**What goes wrong:** Script exits immediately on first failure (like a single brew install failing), user left with partial setup
**Why it happens:** Developers treat `set -e` as "best practice" from CI/CD contexts, but setup scripts need different error handling
**How to avoid:** Use explicit exit code checks for critical steps. For non-critical steps (individual tool installations), ask user whether to continue on failure.
**Warning signs:** Script exits with no explanation when a single package fails to install, leaving system in incomplete state

### Pitfall 6: Not Making Operations Idempotent
**What goes wrong:** Re-running script fails with "directory exists", "file exists", or creates duplicate configuration entries
**Why it happens:** Commands like `mkdir`, `ln -s`, `echo >> file` fail or create duplicates when run multiple times
**How to avoid:** Always use `mkdir -p` (never plain mkdir), `ln -sf` (never plain ln -s), grep before appending to files
**Warning signs:** Script works perfectly on first run, fails on second run with file/directory exists errors

### Pitfall 7: Forgetting brew bundle vs brew install Differences
**What goes wrong:** Using `brew install` in loop instead of Brewfile, or expecting `brew bundle` to work without Homebrew Bundle installed
**Why it happens:** Homebrew Bundle is bundled with Homebrew, but developers unfamiliar with it use manual loops instead
**How to avoid:** Use Brewfile + `brew bundle install` for all package installation. It's idempotent by default, handles failures gracefully.
**Warning signs:** Long loops of brew install commands, or script failing because bundle subcommand doesn't exist

## Code Examples

Verified patterns from official sources:

### Detecting and Installing Homebrew
```bash
# Source: https://docs.brew.sh/Installation
# Check if Homebrew exists (idempotent)
if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew not found, installing..."

    # Install with NONINTERACTIVE to skip confirmation prompts
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Configure PATH for current session based on architecture
    ARCH=$(uname -m)
    if [ "$ARCH" = "arm64" ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        eval "$(/usr/local/bin/brew shellenv)"
    fi

    # Verify installation
    if command -v brew >/dev/null 2>&1; then
        echo "Homebrew installed successfully"
    else
        echo "ERROR: Homebrew installation failed"
        exit 1
    fi
else
    echo "Homebrew already installed"
fi
```

### Installing Tools from Brewfile with Gum
```bash
# Source: https://docs.brew.sh/Brew-Bundle-and-Brewfile
# https://github.com/charmbracelet/gum/blob/main/README.md

BREWFILE="config/Brewfile"

if [ ! -f "$BREWFILE" ]; then
    echo "ERROR: Brewfile not found at $BREWFILE"
    exit 1
fi

# Check if all dependencies are satisfied
if brew bundle check --file="$BREWFILE" >/dev/null 2>&1; then
    gum style --foreground 212 "✓ All tools already installed"
else
    # Install with spinner
    gum spin --spinner dot --title "Installing CLI tools..." \
        -- brew bundle install --file="$BREWFILE"

    # Verify installation
    if brew bundle check --file="$BREWFILE" >/dev/null 2>&1; then
        gum style --foreground 212 "✓ All tools installed successfully"
    else
        gum style --foreground 196 "⚠ Some tools failed to install"
        brew bundle check --file="$BREWFILE"  # Show what's missing
    fi
fi
```

### Idempotent Shell Configuration
```bash
# Source: https://arslan.io/2019/07/03/how-to-write-idempotent-bash-scripts/
# Add brew shellenv to profile if not already present

SHELL_PROFILE="$HOME/.zprofile"
BREW_PREFIX=$(brew --prefix)
SHELLENV_LINE="eval \"\$($BREW_PREFIX/bin/brew shellenv)\""

# Check if already configured (exact match)
if ! grep -qF "$SHELLENV_LINE" "$SHELL_PROFILE" 2>/dev/null; then
    echo "Configuring Homebrew in $SHELL_PROFILE..."
    echo "$SHELLENV_LINE" >> "$SHELL_PROFILE"
else
    echo "Homebrew already configured in $SHELL_PROFILE"
fi
```

### Argument Parsing with getopts
```bash
# Source: https://www.baeldung.com/linux/bash-parse-command-line-arguments
# Parse --verbose and --dry-run flags

VERBOSE=false
DRY_RUN=false

while getopts "vnh" opt; do
    case $opt in
        v) VERBOSE=true ;;
        n) DRY_RUN=true ;;
        h)
            echo "Usage: sh setup [-v] [-n] [-h]"
            echo "  -v  Verbose mode (show commands being run)"
            echo "  -n  Dry-run mode (show what would be done)"
            echo "  -h  Show this help message"
            exit 0
            ;;
        *)
            echo "Invalid option. Use -h for help."
            exit 1
            ;;
    esac
done

# Use flags
if [ "$VERBOSE" = true ]; then
    echo "Running in verbose mode"
fi

if [ "$DRY_RUN" = true ]; then
    echo "DRY RUN: Would install Homebrew"
else
    # Actually install
    install_homebrew
fi
```

### Beautiful Section Headers with Gum
```bash
# Source: https://github.com/charmbracelet/gum/blob/main/README.md

# Main section header
gum style \
    --foreground 212 --border-foreground 212 --border double \
    --align center --width 60 --margin "1 2" --padding "2 4" \
    'Phase 1: Foundation & Core Tools'

# Subsection header
gum style --foreground 212 --bold "Installing Homebrew"

# Success message
gum style --foreground 212 "✓ Setup complete!"

# Error message
gum style --foreground 196 --bold "✗ Installation failed"

# Info message with emoji (balanced, not overwhelming)
gum style --foreground 212 "🍺 Homebrew installed successfully"
```

### Confirmation Prompts for Failures
```bash
# Source: https://github.com/charmbracelet/gum/blob/main/README.md

install_tool() {
    local tool=$1

    if brew install "$tool" 2>&1 | grep -q "already installed"; then
        echo "✓ $tool already installed"
        return 0
    elif brew install "$tool"; then
        echo "✓ Installed $tool"
        return 0
    else
        # Failed - ask user
        if gum confirm "Failed to install $tool. Continue anyway?"; then
            echo "⚠ Skipping $tool"
            return 0
        else
            echo "✗ Setup cancelled by user"
            exit 1
        fi
    fi
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Hardcode /usr/local | Detect architecture with uname -m | 2020 (Apple Silicon release) | Scripts must handle both /opt/homebrew and /usr/local |
| Separate cask install | cask commands integrated into brew | 2020 (Homebrew 2.6.0) | `brew install --cask` vs old `brew cask install` |
| Manual spinner implementation | Use Gum for UI | 2022+ (Gum maturity) | 50+ lines of spinner code → 1 line gum spin |
| xcode-select --install with GUI automation | Let Homebrew handle it | Ongoing | Fewer permission issues, more reliable |
| Separate .bash_profile and .zshrc | Use .zprofile for zsh | 2019 (macOS Catalina, zsh default) | .zprofile is zsh equivalent of .bash_profile |
| brew bundle dump without --describe | Add --describe flag | Recent | Brewfiles now include package descriptions for documentation |
| which command | command -v | Long-standing best practice | Built-in, POSIX-compliant, more reliable |

**Deprecated/outdated:**
- **brew cask install:** Deprecated in favor of `brew install --cask` (but Brewfile uses `cask "name"` syntax)
- **.bash_profile for zsh:** Use .zprofile on macOS Catalina+ (zsh default since 2019)
- **~/Library/Scripts/ for user scripts:** While still valid, modern approach is to keep scripts in project repository (~/dotfiles/scripts/)
- **Manual Xcode CLT installation with AppleScript:** Fragile, better to let Homebrew handle or document as manual prerequisite

## Open Questions

Things that couldn't be fully resolved:

1. **Xcode Command Line Tools Silent Installation**
   - What we know: `xcode-select --install` requires GUI interaction. AppleScript automation exists but requires accessibility permissions that can't be granted programmatically.
   - What's unclear: Whether recent macOS versions (Sonoma/Sequoia 2025+) have added any new non-interactive installation methods.
   - Recommendation: Phase 1 should either (a) let Homebrew prompt for Xcode CLT installation as a prerequisite, or (b) document manual `xcode-select --install` as step 0 before running setup script. Don't attempt GUI automation.

2. **Optimal Brewfile Location**
   - What we know: Common locations are root (`./Brewfile`) or `config/Brewfile`. Some use `~/.Brewfile` globally.
   - What's unclear: Which provides best balance of discoverability vs organization for this project structure.
   - Recommendation: Use `config/Brewfile` for Phase 1 (better organization), can revisit if global Brewfile becomes useful later.

3. **Dry-Run Mode Value Proposition**
   - What we know: Dry-run modes are common in CI/CD tools. For setup scripts, idempotency provides similar safety (re-running is safe).
   - What's unclear: Whether dry-run adds value for this use case, or if it's complexity for limited benefit.
   - Recommendation: Defer dry-run mode to later phases if user requests it. Phase 1 focus on core functionality and idempotency.

4. **Script Structure: Monolithic vs Modular**
   - What we know: CONTEXT.md defers this to Claude's discretion. Monolithic (single setup script) is simpler. Modular (scripts/lib/) is more maintainable.
   - What's unclear: At what complexity level does modular become worth the overhead.
   - Recommendation: Start modular from Phase 1. Create `scripts/` directory with separate scripts for Homebrew installation and tool installation. This establishes good patterns for later phases which will need more modularity.

5. **Verbose Flag Implementation**
   - What we know: User wants `--verbose` flag to show commands being run, default to showing results only.
   - What's unclear: Whether "show commands" means (a) echo command before running, (b) show full command output instead of spinner, or (c) both.
   - Recommendation: Implement as: default mode uses gum spinners and shows results only. Verbose mode shows full command output (no spinners) with commands echoed before execution. Use `set -x` when verbose enabled.

## Sources

### Primary (HIGH confidence)
- [Homebrew Official Installation Documentation](https://docs.brew.sh/Installation) - Installation process, NONINTERACTIVE flag, architecture-specific paths
- [Homebrew Brew Bundle and Brewfile Documentation](https://docs.brew.sh/Brew-Bundle-and-Brewfile) - Brewfile syntax, brew bundle commands
- [Homebrew Common Issues](https://docs.brew.sh/Common-Issues) - PATH configuration, Apple Silicon issues, permission errors
- [Gum GitHub Repository](https://github.com/charmbracelet/gum) - Latest release (v0.17.0, Sep 2025), command reference
- [Gum README Documentation](https://github.com/charmbracelet/gum/blob/main/README.md) - Command examples, usage patterns
- [Baeldung: Check if Program Exists in Bash](https://www.baeldung.com/linux/bash-script-check-program-exists) - command -v best practices
- [How to Write Idempotent Bash Scripts](https://arslan.io/2019/07/03/how-to-write-idempotent-bash-scripts/) - mkdir -p, ln -sf, grep checks

### Secondary (MEDIUM confidence)
- [What I Wish I Knew About Homebrew - DEV Community](https://dev.to/leonwong282/what-i-wish-i-knew-about-homebrew-before-wasting-2-hours-troubleshooting-3don) - Common mistakes, Apple Silicon PATH issues
- [Mac Install Guide: Homebrew 2026](https://mac.install.guide/homebrew/3) - Step-by-step installation, brew shellenv configuration
- [Mac Install Guide: Xcode Command Line Tools 2026](https://mac.install.guide/commandlinetools/) - Installation methods, best practices
- [Install Xcode CLT Without Prompt - GitHub Gist](https://gist.github.com/brysgo/9007731) - AppleScript automation approach
- [Medium: Managing Dotfiles with GNU Stow](https://medium.com/quick-programming/managing-dotfiles-with-gnu-stow-9b04c155ebad) - Stow best practices
- [Detecting Apple Silicon from Shell Script - Indie Spark](https://indiespark.org/software/detecting-apple-silicon-shell-script/) - uname -m for architecture detection
- [Baeldung: Parse Command Line Arguments](https://www.baeldung.com/linux/bash-parse-command-line-arguments) - getopts usage
- [Homebrew NONINTERACTIVE Discussion](https://github.com/orgs/Homebrew/discussions/3199) - NONINTERACTIVE limitations (sudo prompts remain)

### Tertiary (LOW confidence)
- [Web search: Bash script best practices 2026] - General patterns, verified against primary sources
- [Web search: Mac setup script common mistakes] - Community experiences, cross-referenced with official docs

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Homebrew and Gum are official, well-documented tools with verified version info
- Architecture: HIGH - Patterns verified against official Homebrew docs and community best practices
- Pitfalls: HIGH - Common issues documented in Homebrew official docs and multiple community sources
- Xcode CLT automation: MEDIUM - AppleScript approach exists but has known limitations, no official silent method confirmed
- Dry-run implementation: LOW - Limited resources specific to setup script dry-run patterns

**Research date:** 2026-02-01
**Valid until:** 2026-03-01 (30 days - Homebrew and tooling relatively stable, but macOS updates could affect Xcode CLT behavior)

## Critical Path Dependencies

For Phase 1 implementation, these research findings are critical:

1. **Architecture detection MUST happen first:** Use `uname -m`, not hardcoded paths
2. **PATH configuration MUST happen immediately after Homebrew install:** `eval "$(brew shellenv)"` before any brew commands
3. **Use command -v for all existence checks:** Not which, not parsing $PATH
4. **Use Brewfile + brew bundle:** Not manual loops of brew install commands
5. **Gum v0.17.0+ for consistent UI:** spin for progress, style for sections, confirm for user decisions
6. **Idempotency is non-negotiable:** All operations must be safe to re-run (mkdir -p, ln -sf, grep before append)
7. **Error handling via explicit checks:** Not set -e, because partial failures need user decision
8. **Shell profile is .zprofile for zsh:** Not .bash_profile (macOS default is zsh since 2019)
