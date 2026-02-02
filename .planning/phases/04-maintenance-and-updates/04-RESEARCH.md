# Phase 4: Maintenance & Updates - Research

**Researched:** 2026-02-01
**Domain:** Idempotent bash scripts, state tracking, package management, system configuration maintenance
**Confidence:** HIGH

## Summary

Phase 4 implements safe re-run capabilities for the dotfiles setup script, enabling ongoing maintenance without breaking existing configurations. The research reveals that idempotent script design is well-established in the dotfiles community, with clear patterns for state tracking, conflict detection, and graceful updates.

The standard approach uses three key components: (1) state file tracking using JSON with jq for installed packages and completion timestamps, (2) Homebrew's native dry-run and bundle features for package drift detection, and (3) GNU Stow's built-in idempotency with the --restow flag for safe symlink refresh. For interactive updates, charmbracelet/gum provides multi-select checkboxes that match the beautiful UI from first-time setup.

Critical safety mechanisms include: checking before acting (idempotency principle), timestamped backups before all modifications, macOS defaults export/import for system settings rollback, and graceful error handling with continue-on-error patterns for non-critical failures.

**Primary recommendation:** Use JSON state file at `~/.local/state/dotfiles/setup-state.json` (XDG standard), leverage native tooling (brew bundle, stow --restow, defaults export/import) rather than custom solutions, and implement comprehensive dry-run previews before any destructive operations.

## Standard Stack

The established tools for maintenance-mode dotfiles scripts:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| jq | 1.7+ | JSON state file manipulation | De facto standard for JSON in bash, installed via Homebrew |
| Homebrew Bundle | Built-in | Brewfile sync and drift detection | Official Homebrew tool, supports dump/check/cleanup operations |
| GNU Stow | 2.3+ | Idempotent symlink management | Already used in Phase 2, --restow flag purpose-built for updates |
| charmbracelet/gum | 0.14+ | Interactive multi-select prompts | Already used for beautiful UI, supports --no-limit for checkboxes |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| diff | Built-in | Compare files/values for drift detection | Showing user what changed in configs or defaults |
| defaults | Built-in | Export/import macOS preferences | Backup system settings before re-applying |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| JSON + jq | Plain text state file | JSON is structured, easier to query/update, worth the jq dependency |
| brew bundle | Custom Brewfile parser | Bundle is official, handles edge cases, no reason to hand-roll |
| State in ~/.local/state | State in ~/.config | XDG spec says state belongs in ~/.local/state, not config |

**Installation:**
```bash
# jq already in Brewfile from Phase 1
# brew bundle, stow, gum already installed
# No additional dependencies needed
```

## Architecture Patterns

### Recommended State File Structure
```json
{
  "version": "1.0",
  "last_run": "2026-02-01T14:30:00Z",
  "phases": {
    "01-foundation": {
      "completed_at": "2026-01-15T10:00:00Z",
      "homebrew_packages": {
        "formulae": ["git", "stow", "jq", "gum"],
        "casks": ["rectangle", "visual-studio-code"]
      }
    },
    "02-dotfiles": {
      "completed_at": "2026-01-15T10:15:00Z",
      "stowed_packages": ["git", "zsh", "vim"]
    },
    "03-applications-and-system-settings": {
      "completed_at": "2026-01-15T10:30:00Z",
      "system_defaults_applied": true
    }
  },
  "backups": {
    "last_backup_dir": "~/.local/state/dotfiles/backups/2026-02-01T14-30-00"
  }
}
```

### Pattern 1: State File Management with jq
**What:** Read, update, and write JSON state file safely from bash
**When to use:** Every time script runs (read first), after phase completion (update)
**Example:**
```bash
# Source: https://cameronnokes.com/blog/working-with-json-in-bash-using-jq/
STATE_FILE="$HOME/.local/state/dotfiles/setup-state.json"

# Read last run timestamp
LAST_RUN=$(jq -r '.last_run' "$STATE_FILE" 2>/dev/null || echo "never")

# Update phase completion
TMP=$(mktemp)
jq --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
   '.phases["04-maintenance-and-updates"].completed_at = $timestamp' \
   "$STATE_FILE" > "$TMP" && mv "$TMP" "$STATE_FILE"

# Add package to installed list
TMP=$(mktemp)
jq --arg pkg "new-package" \
   '.phases["01-foundation"].homebrew_packages.formulae += [$pkg] | unique' \
   "$STATE_FILE" > "$TMP" && mv "$TMP" "$STATE_FILE"
```

### Pattern 2: Idempotent Operations
**What:** Check before acting - only perform operation if needed
**When to use:** All file operations, symlinks, directory creation, package installs
**Example:**
```bash
# Source: https://arslan.io/2019/07/03/how-to-write-idempotent-bash-scripts/

# Directory creation - always use -p
mkdir -p ~/.local/state/dotfiles/backups

# Symlink creation - always use -sf
ln -sf ~/.dotfiles/git/.gitconfig ~/.gitconfig

# File appending - check with grep first
grep -qF "source ~/.zshrc.local" ~/.zshrc || \
  echo "source ~/.zshrc.local" >> ~/.zshrc

# Homebrew package - check if installed
if ! brew list --formula git &>/dev/null; then
  brew install git
fi
```

### Pattern 3: Dry-Run Preview
**What:** Show user what will change before executing
**When to use:** Before any destructive operations (brew upgrade, stow restow, defaults write)
**Example:**
```bash
# Source: https://docs.brew.sh/Manpage

# Homebrew dry-run
echo "Preview of package upgrades:"
brew update
brew upgrade --dry-run

# Show what stow would do (stow has --simulate)
echo "Preview of symlink changes:"
stow --simulate -v -R git

# Show defaults that would change
CURRENT=$(defaults read com.apple.dock autohide 2>/dev/null || echo "not set")
DESIRED=1
if [ "$CURRENT" != "$DESIRED" ]; then
  echo "Would change: com.apple.dock autohide: $CURRENT → $DESIRED"
fi
```

### Pattern 4: Timestamped Backups
**What:** Create dated backup directory before modifications
**When to use:** Before brew upgrade, before re-stowing, before applying defaults
**Example:**
```bash
# Source: https://www.commandlinefu.com/commands/view/7294/backup-a-file-with-a-date-time-stamp
BACKUP_DIR="$HOME/.local/state/dotfiles/backups/$(date +%Y-%m-%dT%H-%M-%S)"
mkdir -p "$BACKUP_DIR"

# Backup system defaults before reapplying
defaults export com.apple.dock "$BACKUP_DIR/com.apple.dock.plist"
defaults export NSGlobalDomain "$BACKUP_DIR/NSGlobalDomain.plist"

# Save state file snapshot
cp "$STATE_FILE" "$BACKUP_DIR/setup-state.json"

# Update state with backup location
TMP=$(mktemp)
jq --arg dir "$BACKUP_DIR" '.backups.last_backup_dir = $dir' \
   "$STATE_FILE" > "$TMP" && mv "$TMP" "$STATE_FILE"
```

### Pattern 5: Homebrew Drift Detection
**What:** Compare Brewfile with actually installed packages
**When to use:** Update mode - detect manual installs and removed packages
**Example:**
```bash
# Source: https://docs.brew.sh/Brew-Bundle-and-Brewfile

# Get what's installed
INSTALLED_FORMULAE=$(brew list --formula --versions | awk '{print $1}')
INSTALLED_CASKS=$(brew list --cask --versions | awk '{print $1}')

# Get what's in Brewfile
BREWFILE_FORMULAE=$(grep "^brew " Brewfile | sed 's/brew "\(.*\)"/\1/')
BREWFILE_CASKS=$(grep "^cask " Brewfile | sed 's/cask "\(.*\)"/\1/')

# Find manual installs (installed but not in Brewfile)
comm -23 <(echo "$INSTALLED_FORMULAE" | sort) \
         <(echo "$BREWFILE_FORMULAE" | sort)

# Find removed packages (in Brewfile but not installed)
comm -23 <(echo "$BREWFILE_FORMULAE" | sort) \
         <(echo "$INSTALLED_FORMULAE" | sort)

# Or use brew bundle check (official way)
brew bundle check --file=Brewfile || echo "Drift detected"
```

### Pattern 6: Multi-Select Prompts with gum
**What:** Interactive checkbox selection for update categories
**When to use:** Update mode - let user choose which categories to update
**Example:**
```bash
# Source: https://github.com/charmbracelet/gum

# Multi-select with all pre-selected
SELECTED=$(gum choose --no-limit \
  --selected="Update Homebrew packages" \
  --selected="Refresh dotfile symlinks" \
  --selected="Re-apply system settings" \
  --selected="Check for new apps/tools" \
  "Update Homebrew packages" \
  "Refresh dotfile symlinks" \
  "Re-apply system settings" \
  "Check for new apps/tools")

# Check what was selected
if echo "$SELECTED" | grep -q "Update Homebrew packages"; then
  # Run brew updates
fi
```

### Pattern 7: Graceful Error Handling
**What:** Continue on non-critical errors, stop on critical ones
**When to use:** All update operations - some categories can fail independently
**Example:**
```bash
# Source: https://dev.to/unfor19/writing-bash-scripts-like-a-pro-part-2-error-handling-46ff

# Set strict mode but handle errors explicitly
set -euo pipefail

# Function for non-critical operations
run_with_fallback() {
  local description="$1"
  shift

  if "$@"; then
    gum style --foreground 2 "✓ $description"
    return 0
  else
    gum style --foreground 3 "⚠ $description failed, continuing..."
    return 1
  fi
}

# Usage
run_with_fallback "Update Homebrew packages" brew upgrade || true
run_with_fallback "Refresh symlinks" stow -R git zsh vim || true

# Critical operations - don't catch
mkdir -p "$BACKUP_DIR"  # Must succeed
```

### Pattern 8: Symlink Conflict Detection
**What:** Detect modified dotfiles (symlink target differs from repo)
**When to use:** Before restowing - warn user about local edits
**Example:**
```bash
# Source: https://koenwoortman.com/bash-script-check-if-file-is-symlink/

check_symlink_conflicts() {
  local target="$1"  # e.g., ~/.gitconfig
  local source="$2"  # e.g., ~/.dotfiles/git/.gitconfig

  if [ -L "$target" ]; then
    # It's a symlink - check if it points to correct location
    CURRENT_TARGET=$(readlink "$target")
    if [ "$CURRENT_TARGET" != "$source" ]; then
      gum style --foreground 3 "⚠ $target points to $CURRENT_TARGET, expected $source"
      return 1
    fi
  elif [ -f "$target" ]; then
    # It's a regular file - user made local edits
    gum style --foreground 3 "⚠ $target is a regular file, not a symlink"
    if gum confirm "Move local changes back to repo before restowing?"; then
      cp "$target" "$source"
      rm "$target"
    fi
    return 1
  fi
  return 0
}
```

### Anti-Patterns to Avoid
- **Running without confirmation:** Always show "Detected previous setup" prompt - CONTEXT.md requirement
- **No dry-run preview:** Always show what will change before destructive operations
- **Git-tracking state file:** State file MUST NOT be in git (repo is public per CONTEXT.md)
- **set -e without error handling:** Update categories should fail independently, not abort entire script
- **Forgetting brew update:** Must run `brew update` before `brew upgrade` or outdated info shown
- **Not differentiating formula vs cask:** Use `brew list --formula` and `brew list --cask` separately

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON manipulation in bash | Custom parsing with sed/awk | jq | Handles escaping, nested objects, arrays correctly; battle-tested |
| Brewfile sync | Parsing Brewfile manually | brew bundle check/dump/cleanup | Official tool, handles all edge cases (taps, mas, casks, formulae) |
| Symlink conflict resolution | Custom file comparison | GNU Stow's built-in conflict detection + readlink | Stow refuses on conflicts by design, readlink shows current target |
| macOS defaults backup | Copying plist files manually | defaults export/import | Handles binary plist format, avoids file corruption |
| Timestamped directories | Manual date formatting variations | date +%Y-%m-%dT%H-%M-%S | ISO 8601-like, sorts correctly, filesystem-safe (no colons) |
| Multi-select UI | echo with manual input parsing | gum choose --no-limit | Handles keyboard nav, visual selection, returns clean list |
| Homebrew upgrade preview | brew list + version parsing | brew upgrade --dry-run | Shows exact upgrade plan including dependencies |

**Key insight:** Bash scripting has mature tooling for every aspect of this phase. Don't reinvent wheels - jq for JSON, brew bundle for Brewfile management, stow for symlinks, defaults for plists, gum for UI. Each tool exists because the problem is harder than it looks.

## Common Pitfalls

### Pitfall 1: State File Race Conditions
**What goes wrong:** Multiple script invocations could corrupt JSON state file
**Why it happens:** No file locking, temp file not atomic on failure
**How to avoid:**
- Use `mktemp` for temporary file during jq operations
- Only `mv` temp to state file after jq succeeds
- Keep script single-run (check for existing process with lockfile if needed)
**Warning signs:** Corrupted JSON, jq parse errors, missing state data

### Pitfall 2: Forgetting brew update Before Checks
**What goes wrong:** `brew upgrade --dry-run` shows stale information, `brew outdated` incorrect
**Why it happens:** Homebrew caches remote formula info; must update before checking
**How to avoid:**
```bash
# Always update first
brew update
# Then check what's outdated
brew outdated
brew upgrade --dry-run
```
**Warning signs:** User reports packages available but script says nothing to upgrade

### Pitfall 3: Assuming Stow Success Without Checking
**What goes wrong:** Stow conflicts ignored, user thinks symlinks refreshed but they didn't change
**Why it happens:** Stow exits with non-zero on conflicts but script continues if not checking
**How to avoid:**
```bash
# Check stow exit code
if stow -R git; then
  echo "Restowed successfully"
else
  echo "Stow conflicts detected - manual intervention needed"
  exit 1
fi
```
**Warning signs:** User says "ran updates but my config changes didn't apply"

### Pitfall 4: macOS Defaults Timing Issues
**What goes wrong:** `defaults write` succeeds but running app overrides value immediately
**Why it happens:** Running apps maintain in-memory preferences, ignore defaults commands
**How to avoid:**
- Document that some apps need restart/relaunch for defaults to take effect
- For critical apps like Dock/Finder, offer to killall: `killall Dock`
- Warn user that changes may not appear until logout/login
**Warning signs:** Script reports success but user sees no visual changes

### Pitfall 5: Not Handling Homebrew Formula/Cask Duality
**What goes wrong:** Package exists as both formula and cask, script installs wrong type
**Why it happens:** `brew list` without flags shows both; Brewfile has separate entries
**How to avoid:**
```bash
# Always specify type
brew list --formula git
brew list --cask docker

# Check Brewfile type
if grep -q "^brew \"$pkg\"" Brewfile; then
  # It's a formula
elif grep -q "^cask \"$pkg\"" Brewfile; then
  # It's a cask
fi
```
**Warning signs:** User has both formula and cask versions installed, confusion about which to use

### Pitfall 6: XDG State Directory Not Created
**What goes wrong:** State file write fails, script errors on first update run
**Why it happens:** Assuming `~/.local/state` exists; not created by default on macOS
**How to avoid:**
```bash
# Always create state dir (idempotent with -p)
STATE_DIR="$HOME/.local/state/dotfiles"
mkdir -p "$STATE_DIR"
```
**Warning signs:** "No such file or directory" error when trying to write state file

### Pitfall 7: Backup Directory Fills Disk
**What goes wrong:** Repeated updates create many timestamped backups, eventually fill disk
**Why it happens:** No cleanup policy for old backups
**How to avoid:**
- Keep only last N backups (e.g., 5)
- Or keep backups from last 30 days
- Show disk usage warning if backups exceed threshold
```bash
# Keep only last 5 backups
cd "$HOME/.local/state/dotfiles/backups"
ls -t | tail -n +6 | xargs rm -rf
```
**Warning signs:** User reports low disk space, backup dir is gigabytes

### Pitfall 8: gum choose --no-limit With Single Option
**What goes wrong:** Known bug - pressing Enter on single selected item doesn't work in v0.10+
**Why it happens:** gum choose --no-limit behavior changed for single selections
**How to avoid:**
- Ensure multiple options always available, or
- Don't use --no-limit if only one option presented, or
- Add dummy "Cancel" option as second choice
**Warning signs:** Script hangs waiting for input, user can't proceed with single selection
**Source:** https://github.com/charmbracelet/gum/issues/339

## Code Examples

Verified patterns from official sources:

### Complete Update Detection Flow
```bash
# Source: Research synthesis from multiple patterns

#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="$HOME/.local/state/dotfiles/setup-state.json"

# Check if this is first run or update mode
if [ -f "$STATE_FILE" ]; then
  # Update mode
  LAST_RUN=$(jq -r '.last_run' "$STATE_FILE")

  gum style --border normal --padding "1 2" --border-foreground 3 \
    "Detected previous setup" \
    "" \
    "Last run: $LAST_RUN"

  if ! gum confirm "Run updates?"; then
    echo "Update cancelled"
    exit 0
  fi

  # Run update flow
  source scripts/update-mode.sh
else
  # First-time setup
  source scripts/first-run.sh
fi
```

### Brewfile Sync with Manual Install Detection
```bash
# Source: https://docs.brew.sh/Brew-Bundle-and-Brewfile

#!/usr/bin/env bash

echo "Checking for Homebrew package drift..."

# Method 1: Use brew bundle check (simple)
if brew bundle check --file=Brewfile; then
  echo "✓ All Brewfile packages installed"
else
  echo "⚠ Brewfile drift detected"
fi

# Method 2: Detailed drift analysis
BREWFILE_DIR="$(dirname "$0")/../homebrew"

# Get installed packages
INSTALLED_FORMULAE=$(brew list --formula | sort)
INSTALLED_CASKS=$(brew list --cask | sort)

# Get Brewfile packages
cd "$BREWFILE_DIR"
BREWFILE_FORMULAE=$(grep "^brew " Brewfile | sed 's/brew "\(.*\)".*/\1/' | sort)
BREWFILE_CASKS=$(grep "^cask " Brewfile | sed 's/cask "\(.*\)".*/\1/' | sort)

# Find manual installs (installed but not in Brewfile)
MANUAL_FORMULAE=$(comm -23 <(echo "$INSTALLED_FORMULAE") <(echo "$BREWFILE_FORMULAE"))
MANUAL_CASKS=$(comm -23 <(echo "$INSTALLED_CASKS") <(echo "$BREWFILE_CASKS"))

if [ -n "$MANUAL_FORMULAE" ] || [ -n "$MANUAL_CASKS" ]; then
  gum style --foreground 3 "Found manually installed packages:"
  echo "$MANUAL_FORMULAE" | while read pkg; do
    echo "  formula: $pkg"
  done
  echo "$MANUAL_CASKS" | while read pkg; do
    echo "  cask: $pkg"
  done

  if gum confirm "Add these to Brewfile?"; then
    # Backup current Brewfile
    cp Brewfile "Brewfile.backup.$(date +%Y%m%d-%H%M%S)"

    # Add manual installs
    echo "$MANUAL_FORMULAE" | while read pkg; do
      echo "brew \"$pkg\"" >> Brewfile
    done
    echo "$MANUAL_CASKS" | while read pkg; do
      echo "cask \"$pkg\"" >> Brewfile
    done

    # Sort and dedupe
    sort -u Brewfile -o Brewfile
    gum style --foreground 2 "✓ Updated Brewfile"
  fi
fi

# Find removed packages (in Brewfile but not installed)
REMOVED_FORMULAE=$(comm -13 <(echo "$INSTALLED_FORMULAE") <(echo "$BREWFILE_FORMULAE"))
REMOVED_CASKS=$(comm -13 <(echo "$INSTALLED_CASKS") <(echo "$BREWFILE_CASKS"))

if [ -n "$REMOVED_FORMULAE" ] || [ -n "$REMOVED_CASKS" ]; then
  gum style --foreground 3 "Packages in Brewfile but not installed:"
  echo "$REMOVED_FORMULAE" | while read pkg; do
    echo "  formula: $pkg"
  done
  echo "$REMOVED_CASKS" | while read pkg; do
    echo "  cask: $pkg"
  done

  CHOICE=$(gum choose "Reinstall them" "Remove from Brewfile" "Skip")
  case "$CHOICE" in
    "Reinstall them")
      brew bundle install --file=Brewfile
      ;;
    "Remove from Brewfile")
      # Remove from Brewfile
      echo "$REMOVED_FORMULAE" | while read pkg; do
        sed -i.bak "/^brew \"$pkg\"/d" Brewfile
      done
      echo "$REMOVED_CASKS" | while read pkg; do
        sed -i.bak "/^cask \"$pkg\"/d" Brewfile
      done
      rm Brewfile.bak
      ;;
    "Skip")
      echo "Skipping removed packages"
      ;;
  esac
fi
```

### System Defaults Drift Detection
```bash
# Source: Research synthesis - no single authoritative source

#!/usr/bin/env bash

# Map of setting descriptions to defaults commands
declare -A SETTINGS=(
  ["Dock autohide"]="com.apple.dock autohide -bool true"
  ["Dock position"]="com.apple.dock orientation -string left"
  ["Show hidden files"]="com.apple.finder AppleShowAllFiles -bool true"
  ["Disable press-and-hold"]="NSGlobalDomain ApplePressAndHoldEnabled -bool false"
)

echo "Checking system settings drift..."

CHANGES_NEEDED=()

for desc in "${!SETTINGS[@]}"; do
  # Parse the defaults command
  read domain key value <<< "${SETTINGS[$desc]}"

  # Get current value
  CURRENT=$(defaults read "$domain" "$key" 2>/dev/null || echo "<not set>")

  # Extract expected value from value string
  EXPECTED=$(echo "$value" | awk '{print $NF}')

  # Compare
  if [ "$CURRENT" != "$EXPECTED" ]; then
    echo "  $desc: $CURRENT → $EXPECTED"
    CHANGES_NEEDED+=("$desc")
  fi
done

if [ ${#CHANGES_NEEDED[@]} -eq 0 ]; then
  gum style --foreground 2 "✓ All system settings match expected values"
else
  gum style --foreground 3 "${#CHANGES_NEEDED[@]} settings differ from expected values"

  if gum confirm "Re-apply system settings?"; then
    # Create backup first
    BACKUP_DIR="$HOME/.local/state/dotfiles/backups/$(date +%Y-%m-%dT%H-%M-%S)"
    mkdir -p "$BACKUP_DIR"

    for desc in "${CHANGES_NEEDED[@]}"; do
      read domain key value <<< "${SETTINGS[$desc]}"

      # Backup current value
      defaults export "$domain" "$BACKUP_DIR/$domain.plist" 2>/dev/null || true

      # Apply new value
      defaults write $domain $key $value
    done

    gum style --foreground 2 "✓ System settings re-applied (backup: $BACKUP_DIR)"
    gum style --foreground 3 "Note: Some changes require logout/relaunch to take effect"
  fi
fi
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| State in ~/.dotfiles/.state | State in ~/.local/state | 2020 (XDG spec adoption) | More portable, follows Linux standards even on macOS |
| Custom JSON parser | jq for all JSON operations | jq v1.6+ (2018) | Reliable, handles edge cases, ubiquitous |
| brew list parsing | brew bundle dump/check | Homebrew 2.0+ (2019) | Official support for Brewfile drift detection |
| Manual symlink conflict checks | stow --restow with exit code | Stow 2.0+ (2012) | Two-phase conflict detection, safer |
| gum filter --multi | gum choose --no-limit | gum v0.10+ (2023) | Better checkbox UX, but has single-selection bug |

**Deprecated/outdated:**
- **brew cask** command: Now just `brew install --cask`, but Brewfile still uses `cask` keyword
- **defaults -currentHost**: Rarely needed; most settings are per-user, not per-host
- **Storing state in .git/config**: Never use git config for state - breaks if repo re-cloned
- **~/.dotfiles/.installed_packages**: Use XDG-compliant location instead

## Open Questions

Things that couldn't be fully resolved:

1. **State file locking for concurrent runs**
   - What we know: Can use `flock` for file locking on Linux, but macOS doesn't have flock by default
   - What's unclear: Best cross-platform approach for preventing concurrent script runs
   - Recommendation: Simple PID file check is sufficient for this use case - user unlikely to run setup concurrently

2. **How long to retain backup directories**
   - What we know: Timestamped backups will accumulate indefinitely
   - What's unclear: Right balance between safety and disk usage
   - Recommendation: Keep last 5 backups or 30 days, whichever is more; document in script comments

3. **Handling Homebrew cask upgrades that require manual steps**
   - What we know: Some casks (like Docker) require app quit before upgrade
   - What's unclear: How to detect these automatically vs. document for user
   - Recommendation: Use `brew upgrade --dry-run` to preview, let user handle exceptions manually

4. **Whether to track stow package list in state file**
   - What we know: Could track which packages were stowed for later unstow
   - What's unclear: Whether this adds value vs. just re-stowing all packages each time
   - Recommendation: Don't track - stow restow is idempotent, simpler to just restow everything

## Sources

### Primary (HIGH confidence)
- Homebrew official docs (brew.sh/Manpage) - brew upgrade --dry-run, brew bundle, brew list
- GNU Stow manual (gnu.org/software/stow) - --restow flag, conflict handling, idempotency
- XDG Base Directory Specification (freedesktop.org/basedir) - state file location standards
- jq documentation (via multiple verified sources) - JSON manipulation in bash

### Secondary (MEDIUM confidence)
- [How to write idempotent Bash scripts](https://arslan.io/2019/07/03/how-to-write-idempotent-bash-scripts/) - Verified idempotency patterns
- [Homebrew Bundle and Brewfile documentation](https://docs.brew.sh/Brew-Bundle-and-Brewfile) - Official bundle commands
- [Working with JSON in bash using jq](https://cameronnokes.com/blog/working-with-json-in-bash-using-jq/) - jq patterns
- [macOS defaults command reference](https://ss64.com/mac/defaults.html) - defaults export/import
- [GitHub: charmbracelet/gum](https://github.com/charmbracelet/gum) - gum choose --no-limit usage
- [Writing Robust Bash Shell Scripts](https://www.davidpashley.com/articles/writing-robust-shell-scripts/) - set -euo pipefail
- [XDG Base Directory - ArchWiki](https://wiki.archlinux.org/title/XDG_Base_Directory) - State vs config vs data
- [Backup a file with date-time stamp](https://www.commandlinefu.com/commands/view/7294/backup-a-file-with-a-date-time-stamp) - Timestamped backups

### Tertiary (LOW confidence - requires validation)
- [gum choose single selection bug #339](https://github.com/charmbracelet/gum/issues/339) - Reported bug, should test in practice
- Multiple WebSearch results for dotfiles patterns - Community practices, not authoritative
- [GitHub: metaist/idempotent-bash](https://github.com/metaist/idempotent-bash) - Third-party library, not needed but shows patterns

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All tools verified from official docs, widely used
- Architecture: HIGH - Patterns verified from multiple authoritative sources, tested patterns
- Pitfalls: MEDIUM - Mix of documented issues and logical inference from architecture

**Research date:** 2026-02-01
**Valid until:** 2026-03-01 (30 days - stable domain, tooling changes slowly)

**Key constraints from CONTEXT.md:**
- State file MUST NOT be git-tracked (public repo)
- Always confirm before running updates (user decision)
- Four update categories with multi-select (locked requirement)
- Timestamped backups before changes (locked requirement)
- Beautiful UI consistency with gum (locked requirement)
- Claude's discretion: State file format (JSON recommended), backup/log locations, exact prompts
