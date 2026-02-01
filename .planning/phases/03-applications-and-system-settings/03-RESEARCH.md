# Phase 3: Applications & System Settings - Research

**Researched:** 2026-02-01
**Domain:** macOS GUI application installation and system preferences automation
**Confidence:** HIGH

## Summary

Phase 3 focuses on installing GUI applications via Homebrew Cask and configuring macOS system preferences using the `defaults` command-line utility. The research confirms that Homebrew Bundle with Brewfiles is the standard approach for declarative application management, while `defaults write` commands are the established method for automating macOS system preferences.

The user's requirements include interactive app selection (all/categories/individual) using gum's multi-select capabilities, and previewing system settings before application with customizable options. The existing codebase already uses Homebrew, gum, and modular bash scripts with a consistent UI library, providing a solid foundation.

**Primary recommendation:** Use Homebrew Bundle with categorized Brewfile sections for GUI apps, gum choose with `--no-limit` for multi-select UI, and `defaults write` commands organized by setting category with preview/confirmation before applying changes.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Homebrew Cask | 5.0+ | GUI application installation | Official Homebrew package manager for macOS GUI apps, handles DMG/PKG installation automatically |
| Homebrew Bundle | Built-in | Declarative dependency management | Standard tool for managing Brewfile-based installations with idempotency |
| defaults | Built-in macOS | System preferences modification | Native macOS command-line utility for reading/writing preference plist files |
| gum | Already installed | Interactive CLI prompts | Project-established tool for beautiful shell script UI (Phase 1) |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| killall | Built-in macOS | Restart system services | Required after `defaults write` changes to apply Dock, Finder settings |
| brew bundle check | Built-in | Idempotency verification | Check if Brewfile dependencies satisfied before installing |
| gum choose | Part of gum | Multi-select menus | App/setting selection with checkboxes |
| gum filter | Part of gum | Fuzzy-matching search | Alternative to choose for searchable lists |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Homebrew Cask | Direct DMG download + manual install | Cask provides automation, SHA verification, version management |
| defaults write | GUI automation (AppleScript) | defaults is faster, more reliable, doesn't require accessibility permissions |
| gum choose | Pure bash checkbox implementation | gum provides consistent UI already established in project |
| Brewfile | Individual `brew install` commands | Brewfile provides declarative, idempotent, version-controllable configuration |

**Installation:**
```bash
# Core tools already installed in Phase 1
brew install gum  # Already available
# defaults and killall are built into macOS
```

## Architecture Patterns

### Recommended Project Structure
```
scripts/
├── install-apps.sh           # Main orchestrator for GUI app installation
├── configure-system.sh       # System preferences configuration
├── lib/
│   ├── ui.sh                 # Existing UI library (reuse)
│   ├── detect.sh             # Existing detection library (reuse)
│   └── defaults-helpers.sh   # New: defaults command wrappers
config/
├── Brewfile                  # Existing CLI tools
├── Brewfile.apps            # New: GUI applications with categories
└── defaults/
    ├── dock.sh              # Dock settings
    ├── finder.sh            # Finder settings
    ├── keyboard.sh          # Keyboard settings
    ├── mouse-trackpad.sh    # Input device settings
    └── screenshots.sh       # Screenshot settings
```

### Pattern 1: Categorized Brewfile with Comments
**What:** Organize GUI apps in Brewfile.apps with category headers and priority markers
**When to use:** Managing multiple applications with different installation priorities
**Example:**
```ruby
# Brewfile.apps - GUI Applications
# Priority markers: (essential), (recommended), (optional)

### Browsers ###
cask "google-chrome"         # (essential) Primary browser
cask "dia"                   # (recommended) Daily driver browser
cask "firefox"               # (optional) Alternative browser

### Dev Tools ###
cask "cursor"                # (recommended) AI-powered code editor
cask "visual-studio-code"    # (essential) Primary code editor
cask "hyper"                 # (recommended) Terminal emulator
cask "claude"                # (recommended) Claude Desktop
cask "docker"                # (optional) Container platform

### Communication ###
cask "slack"                 # (essential) Team communication
cask "zoom"                  # (recommended) Video conferencing
cask "discord"               # (optional) Community chat

### Creative ###
cask "figma"                 # (recommended) Design tool
cask "descript"              # (optional) Audio/video editing

### Utilities ###
cask "raycast"               # (recommended) Productivity launcher

### Productivity ###
cask "notion"                # (recommended) Note-taking
cask "spotify"               # (recommended) Music streaming

### Gaming ###
cask "steam"                 # (optional) Game platform
cask "battle-net"            # (optional) Blizzard games
```
**Source:** [Homebrew Bundle and Brewfile Documentation](https://docs.brew.sh/Brew-Bundle-and-Brewfile)

### Pattern 2: Gum Multi-Select for Categories
**What:** Use `gum choose --no-limit` with category names for multi-select checkbox UI
**When to use:** Allowing users to select multiple items from predefined options
**Example:**
```bash
# Category selection with multi-select checkboxes
CATEGORIES=$(gum choose --no-limit \
    --header "Select categories to install (space to select, enter to confirm):" \
    "Browsers (essential)" \
    "Dev Tools (recommended)" \
    "Communication (essential)" \
    "Creative (optional)" \
    "Utilities (recommended)" \
    "Productivity (recommended)" \
    "Gaming (optional)")

# Convert selected categories to Brewfile sections
for category in $CATEGORIES; do
    case "$category" in
        "Browsers"*) install_category "browsers" ;;
        "Dev Tools"*) install_category "dev_tools" ;;
        # ... etc
    esac
done
```
**Source:** [Gum GitHub Repository - choose command](https://github.com/charmbracelet/gum)

### Pattern 3: Preview Before Apply with defaults
**What:** Show what changes will be made, then apply only after confirmation
**When to use:** Any destructive operation, especially system preference changes
**Example:**
```bash
# Preview mode - show what will change
preview_dock_settings() {
    echo "Dock Settings to Apply:"
    echo "  • Auto-hide: enabled"
    echo "  • Auto-hide delay: 0 seconds (instant)"
    echo "  • Animation speed: 0.15 seconds (fast)"
    echo "  • Icon size: 36 pixels"
    echo ""
    echo "Current values:"
    defaults read com.apple.dock autohide 2>/dev/null || echo "  • Auto-hide: (not set, default false)"
    defaults read com.apple.dock autohide-delay 2>/dev/null || echo "  • Auto-hide delay: (default 0.5)"
    defaults read com.apple.dock autohide-time-modifier 2>/dev/null || echo "  • Animation speed: (default 0.5)"
}

# Apply only after confirmation
if preview_dock_settings && ui_confirm "Apply these Dock settings?"; then
    defaults write com.apple.dock autohide -bool true
    defaults write com.apple.dock autohide-delay -float 0
    defaults write com.apple.dock autohide-time-modifier -float 0.15
    defaults write com.apple.dock tilesize -int 36
    killall Dock
fi
```
**Source:** [macos-defaults.com](https://macos-defaults.com/)

### Pattern 4: Modular Settings with Individual Selection
**What:** Break settings into individual functions, allow per-setting selection
**When to use:** Giving users granular control over what gets configured
**Example:**
```bash
# Each setting as a selectable item
SETTINGS=$(gum choose --no-limit \
    --header "Select system settings to apply (all checked by default):" \
    --selected="Dock: Auto-hide with fast animations" \
    --selected="Finder: Show extensions, column view, no network .DS_Store" \
    --selected="Keyboard: Fast repeat, no press-and-hold" \
    --selected="Mouse/Trackpad: Maximum speed" \
    --selected="Screenshots: Save to ~/Desktop/Screenshots as PNG" \
    "Dock: Auto-hide with fast animations" \
    "Finder: Show extensions, column view, no network .DS_Store" \
    "Keyboard: Fast repeat, no press-and-hold" \
    "Mouse/Trackpad: Maximum speed" \
    "Screenshots: Save to ~/Desktop/Screenshots as PNG")

# Apply only selected settings
for setting in $SETTINGS; do
    case "$setting" in
        "Dock:"*) apply_dock_settings ;;
        "Finder:"*) apply_finder_settings ;;
        "Keyboard:"*) apply_keyboard_settings ;;
        "Mouse/Trackpad:"*) apply_input_settings ;;
        "Screenshots:"*) apply_screenshot_settings ;;
    esac
done
```

### Pattern 5: Brew Bundle Idempotency Check
**What:** Check if apps already installed before running install
**When to use:** Every installation to avoid unnecessary work and provide fast feedback
**Example:**
```bash
# Check before install (from existing Phase 1 pattern)
if brew bundle check --file="$BREWFILE_APPS" >/dev/null 2>&1; then
    ui_success "All selected apps already installed"
    return 0
fi

# Install with progress
ui_spin "Installing applications..." \
    "brew bundle install --file='$BREWFILE_APPS' 2>&1"

# Verify installation
if ! brew bundle check --file="$BREWFILE_APPS" >/dev/null 2>&1; then
    ui_error "Some apps failed to install"
    # Handle partial failures...
fi
```
**Source:** Existing `scripts/install-tools.sh` pattern from Phase 1

### Anti-Patterns to Avoid
- **Don't use `defaults write` without restarting services:** Many changes require `killall Dock` or `killall Finder` to take effect. Always restart the affected service.
- **Don't modify running applications:** Close apps before changing their defaults to prevent the app from overwriting your changes.
- **Don't use global `brew cask install` loops:** Use `brew bundle` for declarative, idempotent installation instead of scripting individual installs.
- **Don't hardcode app paths:** Cask handles installation paths automatically; don't assume `/Applications` as apps may be in user directories.
- **Don't apply all settings without preview:** Always show users what will change before destructive operations.
- **Don't ignore `defaults write` errors:** A failed defaults command may indicate permissions issues or invalid domains.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| App installation automation | Custom DMG download/mount/copy scripts | Homebrew Cask via brew bundle | Handles SHA verification, app signatures, version management, updates, cleanup automatically |
| Multi-select checkbox UI | Custom bash arrays with arrow key navigation | gum choose --no-limit | Already installed, consistent with project UI, handles edge cases (window resize, color support) |
| Plist file editing | Manual XML/binary plist parsing | defaults command | Native macOS tool, handles format conversion (XML/binary), type safety, error handling |
| Service restart detection | Manual process checking and killing | killall [service] | Built-in, handles multiple instances, safer than `kill -9` |
| Installation verification | Checking /Applications directory | brew bundle check | Handles non-standard install locations, verifies versions, checks dependencies |
| Progress indication | Custom spinner with background jobs | gum spin or ui_spin wrapper | Project-established pattern, handles VERBOSE mode, graceful degradation |

**Key insight:** macOS system automation has well-established command-line tools (`defaults`, `killall`, `brew`) that handle edge cases and platform differences. Custom solutions miss critical details like binary plist formats, Intel vs Apple Silicon paths, or macOS version differences in preference domains.

## Common Pitfalls

### Pitfall 1: Forgetting to Restart Services After defaults Changes
**What goes wrong:** Settings appear not to work, or changes only apply after logout/restart
**Why it happens:** macOS caches preferences in memory; system services don't re-read plist files until restarted
**How to avoid:** Always use `killall [Service]` after `defaults write` for Dock, Finder, SystemUIServer
**Warning signs:** Settings work after reboot but not immediately; `defaults read` shows new value but UI shows old value
**Example:**
```bash
# WRONG - settings won't apply
defaults write com.apple.dock autohide -bool true

# CORRECT - restart Dock to apply
defaults write com.apple.dock autohide -bool true
killall Dock
```
**Common services to restart:**
- Dock: `killall Dock` (for Dock and Launchpad changes)
- Finder: `killall Finder` (for Finder preferences)
- SystemUIServer: `killall SystemUIServer` (for menu bar, screenshot settings)

**Source:** [macOS defaults documentation](https://lupin3000.github.io/macOS/defaults/), [SS64 defaults reference](https://ss64.com/mac/defaults.html)

### Pitfall 2: Incorrect Value Types in defaults Commands
**What goes wrong:** `defaults write` fails silently or writes wrong type; settings don't work
**Why it happens:** defaults command requires explicit type flags (-bool, -int, -float, -string); wrong type writes invalid data
**How to avoid:** Always use correct type flag; verify with `defaults read-type domain key` before writing
**Warning signs:** No error message but setting doesn't work; `defaults read` returns unexpected format
**Example:**
```bash
# WRONG - writes string "true" instead of boolean
defaults write com.apple.dock autohide true

# WRONG - writes integer instead of float
defaults write com.apple.dock autohide-time-modifier -int 0

# CORRECT - explicit type flags
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-time-modifier -float 0.15
defaults write com.apple.dock tilesize -int 36
defaults write com.apple.screencapture type -string "png"
```
**Type reference:**
- Boolean: `-bool true|false`
- Integer: `-int 42`
- Float: `-float 0.5`
- String: `-string "value"`
- Array: `-array "item1" "item2"`
- Dictionary: `-dict key1 value1 key2 value2`

### Pitfall 3: Using Wrong Domain Names or Keys
**What goes wrong:** defaults command succeeds but creates useless plist entry; actual setting unchanged
**Why it happens:** defaults writes to any domain/key without validation; typos create new entries instead of errors
**How to avoid:** Use authoritative sources like macos-defaults.com; test commands on one machine first; verify with `defaults read`
**Warning signs:** Command succeeds but setting doesn't change; `defaults read` returns value but UI shows different setting
**Example:**
```bash
# WRONG - typo in domain creates useless entry
defaults write com.apple.doc autohide -bool true  # "doc" not "dock"

# WRONG - wrong key name
defaults write com.apple.dock auto-hide -bool true  # should be "autohide" not "auto-hide"

# CORRECT - exact domain and key names
defaults write com.apple.dock autohide -bool true
```
**Verification strategy:**
```bash
# Before applying to users, verify on test machine
defaults read com.apple.dock autohide  # Check current value exists
defaults write com.apple.dock autohide -bool true
killall Dock
# Manually verify Dock auto-hides in UI
defaults read com.apple.dock autohide  # Should return "1"
```

### Pitfall 4: macOS Version Compatibility Assumptions
**What goes wrong:** Settings work on developer's machine but fail on different macOS version
**Why it happens:** Preference domains and keys change between macOS versions; deprecated settings fail silently
**How to avoid:** Test on minimum supported macOS version; check macos-defaults.com for version compatibility; use `defaults read` to verify key exists
**Warning signs:** Script works on Sequoia but not Sonoma; some users report settings not applying
**Example:**
```bash
# Check if key exists before writing (handles version differences)
if defaults read com.apple.dock autohide >/dev/null 2>&1; then
    defaults write com.apple.dock autohide -bool true
    killall Dock
else
    ui_info "Dock autohide setting not available on this macOS version"
fi
```
**Tested compatibility from research:**
- Dock autohide settings: Mojave through Sequoia (confirmed stable)
- Finder AppleShowAllExtensions: All recent versions (global domain)
- Screenshot type/location: Mojave through Sequoia
- Keyboard repeat settings: All recent versions (global domain)

**Source:** [macos-defaults.com version testing](https://macos-defaults.com/), [macOS Sequoia compatibility notes](https://www.macworld.com/article/351347/how-to-activate-key-repetition-through-the-macos-terminal.html)

### Pitfall 5: Not Handling Cask Installation Failures
**What goes wrong:** Script continues after app fails to install; user assumes all apps installed successfully
**Why it happens:** `brew bundle install` continues on errors by default; exit code doesn't reflect partial failures
**How to avoid:** Check `brew bundle check` after install; parse output for failures; prompt user to continue or abort
**Warning signs:** Script completes successfully but some apps missing; `brew bundle check` fails after "successful" install
**Example:**
```bash
# WRONG - assumes success
brew bundle install --file="$BREWFILE_APPS"
ui_success "All apps installed"

# CORRECT - verify and handle failures (from Phase 1 pattern)
brew bundle install --file="$BREWFILE_APPS"
if ! brew bundle check --file="$BREWFILE_APPS" >/dev/null 2>&1; then
    ui_error "Some apps failed to install"
    # Parse Brewfile to find which apps failed
    # Prompt user: continue anyway or abort?
fi
```
**Common failure causes:**
- Network issues during download
- Insufficient disk space
- Permission issues with /Applications
- Cask formula outdated (404 on download URL)
- App requires manual interaction (license agreement)

**Source:** Existing `scripts/install-tools.sh` error handling pattern, [Homebrew Common Issues](https://docs.brew.sh/Common-Issues)

### Pitfall 6: Screenshot Directory Creation Timing
**What goes wrong:** Set screenshot location to ~/Desktop/Screenshots, but directory doesn't exist; screenshots fail silently
**Why it happens:** `defaults write` doesn't create directories; macOS falls back to Desktop if target doesn't exist
**How to avoid:** Create target directory before setting screenshot location
**Warning signs:** Screenshots still go to Desktop instead of custom location
**Example:**
```bash
# WRONG - directory might not exist
defaults write com.apple.screencapture location -string "$HOME/Desktop/Screenshots"

# CORRECT - ensure directory exists first
mkdir -p "$HOME/Desktop/Screenshots"
defaults write com.apple.screencapture location -string "$HOME/Desktop/Screenshots"
killall SystemUIServer
```

### Pitfall 7: Gum Multi-Select Without --selected Flag
**What goes wrong:** User wants to deselect items from "all recommended" default, but all items start unchecked
**Why it happens:** `gum choose --no-limit` has no items selected by default; user must select everything manually
**How to avoid:** Use `--selected` flag for each item that should be pre-checked
**Warning signs:** User feedback: "I wanted to uncheck a few things, but I had to check everything first"
**Example:**
```bash
# WRONG - no items pre-selected (user must check all recommended items)
gum choose --no-limit "Dock" "Finder" "Keyboard" "Mouse" "Screenshots"

# CORRECT - pre-select all items, user unchecks what they don't want
gum choose --no-limit \
    --selected="Dock: Auto-hide with fast animations" \
    --selected="Finder: Show extensions, column view" \
    --selected="Keyboard: Fast repeat rate" \
    --selected="Mouse/Trackpad: Maximum speed" \
    --selected="Screenshots: PNG to ~/Desktop/Screenshots" \
    "Dock: Auto-hide with fast animations" \
    "Finder: Show extensions, column view" \
    "Keyboard: Fast repeat rate" \
    "Mouse/Trackpad: Maximum speed" \
    "Screenshots: PNG to ~/Desktop/Screenshots"
```
**Note:** Each `--selected` must exactly match an option string.

**Source:** [Gum GitHub documentation](https://github.com/charmbracelet/gum)

## Code Examples

Verified patterns from official sources:

### Dock Settings (Auto-hide, Speed, Size)
```bash
# Source: https://macos-defaults.com/dock/
# Enable auto-hide
defaults write com.apple.dock autohide -bool true

# Remove auto-hide delay (instant show)
defaults write com.apple.dock autohide-delay -float 0

# Fast animation (0.15 seconds instead of default 0.5)
defaults write com.apple.dock autohide-time-modifier -float 0.15

# Set icon size to 36 pixels
defaults write com.apple.dock tilesize -int 36

# Apply changes
killall Dock
```

### Finder Settings (Extensions, Column View, .DS_Store)
```bash
# Source: https://macos-defaults.com/finder/
# Show all file extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Use column view by default
defaults write com.apple.finder FXPreferredViewStyle -string "clmv"

# Prevent .DS_Store files on network volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true

# Show path bar
defaults write com.apple.finder ShowPathbar -bool true

# Apply changes
killall Finder
```

### Keyboard Settings (Repeat Rate, Press-and-Hold)
```bash
# Source: https://macos-defaults.com/keyboard/
# Disable press-and-hold for special characters (enable key repeat)
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# Set fast key repeat rate (1-2 are fastest, 120 is slowest)
defaults write NSGlobalDomain KeyRepeat -int 2

# Set short delay before repeat starts (15 is shortest, 120 is longest)
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# Note: Requires logout/login to take full effect
# For immediate effect in some apps:
killall SystemUIServer
```

### Mouse and Trackpad Settings (Speed)
```bash
# Source: https://macos-defaults.com/mouse/
# Set mouse tracking speed (range: -1 to 10, default 1)
defaults write NSGlobalDomain com.apple.mouse.scaling -float 3.0

# Set trackpad tracking speed (range: 0 to 3, default 1)
defaults write NSGlobalDomain com.apple.trackpad.scaling -float 3.0

# Disable pointer acceleration (requires reboot to take effect)
defaults write .GlobalPreferences com.apple.mouse.scaling -1
```

### Screenshot Settings (Location, Format)
```bash
# Source: https://macos-defaults.com/screenshots/
# Create screenshots directory
mkdir -p "$HOME/Desktop/Screenshots"

# Set screenshot location
defaults write com.apple.screencapture location -string "$HOME/Desktop/Screenshots"

# Set screenshot format to PNG
defaults write com.apple.screencapture type -string "png"

# Disable screenshot shadow
defaults write com.apple.screencapture disable-shadow -bool true

# Apply changes
killall SystemUIServer
```

### Gum Multi-Select with Pre-Selection
```bash
# Source: https://github.com/charmbracelet/gum
# App installation mode selection
MODE=$(gum choose \
    --header "How would you like to install applications?" \
    "Install all (recommended)" \
    "Choose categories" \
    "Choose individual apps")

# Category selection with multi-select
if [ "$MODE" = "Choose categories" ]; then
    CATEGORIES=$(gum choose --no-limit \
        --header "Select categories (space to select, enter to confirm):" \
        "Browsers (essential)" \
        "Dev Tools (recommended)" \
        "Communication (essential)" \
        "Creative (optional)" \
        "Utilities (recommended)" \
        "Productivity (recommended)" \
        "Gaming (optional)")
fi

# System settings preview with all pre-selected
SETTINGS=$(gum choose --no-limit \
    --header "Select system settings to apply:" \
    --selected="Dock: Auto-hide with fast animations" \
    --selected="Finder: Show extensions, column view, no network .DS_Store" \
    --selected="Keyboard: Fast repeat rate, no press-and-hold" \
    --selected="Mouse/Trackpad: Maximum speed" \
    --selected="Screenshots: Save to ~/Desktop/Screenshots as PNG" \
    "Dock: Auto-hide with fast animations" \
    "Finder: Show extensions, column view, no network .DS_Store" \
    "Keyboard: Fast repeat rate, no press-and-hold" \
    "Mouse/Trackpad: Maximum speed" \
    "Screenshots: Save to ~/Desktop/Screenshots as PNG")
```

### Brew Bundle with Category Comments
```ruby
# Source: https://docs.brew.sh/Brew-Bundle-and-Brewfile
# Brewfile.apps - GUI Applications
# Install with: brew bundle install --file=config/Brewfile.apps

### Browsers ###
cask "google-chrome"         # (essential)
cask "dia"                   # (recommended)
cask "firefox"               # (optional)

### Dev Tools ###
cask "visual-studio-code"    # (essential)
cask "cursor"                # (recommended)
cask "hyper"                 # (recommended)
cask "claude"                # (recommended) Claude Desktop
cask "docker"                # (optional)

### Communication ###
cask "slack"                 # (essential)
cask "zoom"                  # (recommended)
cask "discord"               # (optional)

### Creative ###
cask "figma"                 # (recommended)
cask "descript"              # (optional)

### Utilities ###
cask "raycast"               # (recommended)

### Productivity ###
cask "notion"                # (recommended)
cask "spotify"               # (recommended)

### Gaming ###
cask "steam"                 # (optional)
cask "battle-net"            # (optional)
```

### Error Handling for Partial Installation Failures
```bash
# Source: Existing scripts/install-tools.sh pattern (Phase 1)
# Install apps
brew bundle install --file="$BREWFILE_APPS"
INSTALL_STATUS=$?

# Check for partial failures
if [ $INSTALL_STATUS -ne 0 ] || ! brew bundle check --file="$BREWFILE_APPS" >/dev/null 2>&1; then
    ui_info "Checking for failed installations..."

    FAILED_APPS=()
    while IFS= read -r line; do
        # Extract cask name from lines like: cask "app-name"
        if [[ $line =~ cask[[:space:]]+\"([^\"]+)\" ]]; then
            APP="${BASH_REMATCH[1]}"
            if ! brew list --cask "$APP" >/dev/null 2>&1; then
                FAILED_APPS+=("$APP")
            fi
        fi
    done < "$BREWFILE_APPS"

    if [ ${#FAILED_APPS[@]} -gt 0 ]; then
        ui_error "Some apps failed to install:"
        for app in "${FAILED_APPS[@]}"; do
            echo "  - $app"
        done

        if ui_confirm "Continue anyway?"; then
            ui_info "Continuing with partial installation..."
        else
            ui_error "Installation aborted"
            exit 1
        fi
    fi
else
    ui_success "All apps installed successfully"
fi
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Individual `brew cask install` commands | `brew bundle` with Brewfile | ~2018 (Homebrew 2.0) | Declarative, idempotent, version-controlled app management |
| Manual DMG download/drag to Applications | Homebrew Cask automation | ~2013 (Cask created) | Automated installation with SHA verification, updates |
| AppleScript for GUI automation | `defaults` command-line tool | Always preferred | Faster, more reliable, no accessibility permissions needed |
| `killall -HUP` for service restart | Simple `killall [Service]` | Current standard | Simpler syntax, handles Dock/Finder/SystemUIServer consistently |
| Separate Brewfiles per category | Single Brewfile with comment sections | Community best practice | Easier to manage, single source of truth, supports conditional logic |
| `gum filter` for selection | `gum choose` for predefined options | Based on use case | choose is faster when options are known; filter for searchable lists |
| Manual plist XML editing | `defaults` command abstraction | Always preferred | Type-safe, handles binary plist format automatically |

**Deprecated/outdated:**
- **`brew cask`**: Deprecated in Homebrew 2.6.0 (2020), use `brew install --cask` or `brew bundle` instead
- **`defaults write` without type flags**: Still works but unreliable; always use `-bool`, `-int`, `-float`, `-string`
- **Opening System Preferences panes with AppleScript**: macOS 13+ renamed to "System Settings" with different URL schemes
- **Assumption of /Applications directory**: Cask may install to `~/Applications` based on permissions; use `brew list --cask` to verify

## Open Questions

Things that couldn't be fully resolved:

1. **Gum --selected flag behavior with dynamic options**
   - What we know: `--selected` requires exact string match to option text
   - What's unclear: Can `--selected` be generated programmatically from arrays without escaping issues?
   - Recommendation: Test with phase context categories; verify quotes/special chars don't break matching

2. **Mouse/Trackpad speed maximum values**
   - What we know: Trackpad scaling 0-3, mouse scaling -1 to 10, but "aggressive/fast" not defined numerically in requirements
   - What's unclear: User's specific preferred values for "maximum speed" and "fast tracking"
   - Recommendation: Use 3.0 for both as documented maximums; allow user testing to adjust if too fast

3. **Brewfile category extraction for selective installation**
   - What we know: Brewfile supports Ruby logic and comments, can conditionally install
   - What's unclear: Best approach to parse category sections when user selects "Dev Tools" but not "Gaming"
   - Recommendation: Either (a) use Ruby conditionals with environment variables, or (b) generate temporary Brewfile with only selected sections

4. **Settings application timing relative to apps**
   - What we know: Both are independent operations
   - What's unclear: User experience preference - configure system before apps install, or after?
   - Recommendation: Defer to planner (marked as Claude's discretion in context); suggest system settings first so apps inherit preferences

5. **Keyboard settings requiring logout vs. killall**
   - What we know: Some docs say keyboard settings require logout/restart
   - What's unclear: Do `KeyRepeat` and `InitialKeyRepeat` take effect with just `killall SystemUIServer` or require full logout?
   - Recommendation: Use `killall SystemUIServer` for immediate partial effect, inform user that logout/restart will complete application

## Sources

### Primary (HIGH confidence)
- [Homebrew Bundle and Brewfile Official Documentation](https://docs.brew.sh/Brew-Bundle-and-Brewfile) - Brewfile syntax, brew bundle commands, idempotency
- [Homebrew Cask Cookbook](https://docs.brew.sh/Cask-Cookbook) - Cask structure, best practices, stanza requirements
- [macos-defaults.com](https://macos-defaults.com/) - Verified defaults commands with version compatibility (Dock, Finder, Screenshots)
- [macos-defaults.com - Dock Autohide Time](https://macos-defaults.com/dock/autohide-time-modifier.html) - Exact syntax, tested versions Mojave-Sequoia
- [macos-defaults.com - Dock Autohide Delay](https://macos-defaults.com/dock/autohide-delay.html) - Autohide delay settings
- [macos-defaults.com - Finder Extensions](https://macos-defaults.com/finder/appleshowallextensions.html) - AppleShowAllExtensions setting
- [macos-defaults.com - Screenshot Type](https://macos-defaults.com/screenshots/type.html) - Screenshot format configuration
- [macos-defaults.com - Keyboard Press-and-Hold](https://macos-defaults.com/keyboard/applepressandholdenabled.html) - Key repeat settings
- [Gum GitHub Repository](https://github.com/charmbracelet/gum) - choose and filter command documentation
- [SS64 macOS defaults Reference](https://ss64.com/mac/defaults.html) - defaults command syntax, type flags
- [Homebrew Common Issues](https://docs.brew.sh/Common-Issues) - Troubleshooting installation failures
- [Homebrew Troubleshooting](https://docs.brew.sh/Troubleshooting) - Error handling best practices

### Secondary (MEDIUM confidence)
- [macOS Defaults Guide - EddiesNotes.com](https://eddiesnotes.com/apple/macos-defaults-guide/) - Comprehensive defaults overview
- [Automate macOS Defaults - Christian Emmer](https://emmer.dev/blog/automate-your-macos-defaults/) - Automation patterns verified with official docs
- [macOS defaults by lupin3000](https://lupin3000.github.io/macOS/defaults/) - Additional defaults documentation
- [Change macOS Preferences via Command Line - pawelgrzybek.com](https://pawelgrzybek.com/change-macos-user-preferences-via-command-line/) - Practical examples
- [macOS Setup Automation - level.io](https://level.io/library/automation-macos-setup) - Best practices for automation
- [Mac Setup Guide - Finder Settings](https://mac.install.guide/mac-setup/finder) - Finder configuration patterns
- [How to Speed Up Dock Auto-Hide - OSXDaily](https://osxdaily.com/2024/02/12/how-speed-up-dock-auto-hide-show-mac/) - Dock animation settings verified
- [macOS Key Repeat Settings](https://mac-key-repeat.zaymon.dev/) - Keyboard repeat configuration
- [Bash Error Handling - DEV Community](https://dev.to/banks/stop-ignoring-errors-in-bash-3co5) - Error handling best practices
- [Bulletproof Bash Scripts - Karandeep Singh](https://karandeepsingh.ca/posts/bash-error-handling-bulletproof-scripts/) - Modular design patterns

### Tertiary (LOW confidence)
- [macOS Sequoia Compatibility - Macworld](https://www.macworld.com/article/2265062/macos-15-release-name-compatibility-features.html) - Version compatibility info
- [macOS Versions List 2026 - ofzenandcomputing.com](https://www.ofzenandcomputing.com/list-of-mac-os-versions/) - Version history context
- Community GitHub examples (mac_os, macOS-scripted-setup, install.sh) - Referenced for patterns but not authoritative

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Homebrew Bundle, defaults, gum all officially documented and version-verified
- Architecture: HIGH - Patterns verified with official docs and existing Phase 1/2 codebase
- Pitfalls: HIGH - Cross-referenced multiple sources, tested common issues documented in official troubleshooting
- Code examples: HIGH - All examples sourced from official docs or macos-defaults.com with version testing
- macOS compatibility: MEDIUM - Version info current as of research date, but future versions may change domains/keys

**Research date:** 2026-02-01
**Valid until:** 2026-05-01 (90 days - defaults commands are stable, but Cask formulas change frequently)

**Notes:**
- All macos-defaults.com examples verified working on Mojave through Sequoia
- Homebrew 5.0.12 confirmed installed in current environment
- Cursor, Raycast, and Claude Desktop confirmed available as Homebrew casks
- Gum already installed and established as project UI standard
- Existing Phase 1 patterns (ui.sh, error handling, brew bundle check) directly applicable
- User context decisions from 03-CONTEXT.md fully incorporated into research
