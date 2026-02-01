#!/bin/bash
#
# System Settings Configuration
# Applies macOS system preferences with preview and customization
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source libraries
source "$SCRIPT_DIR/lib/ui.sh"

# Display header
ui_header "Configuring System Settings"

# Function to get current setting value
get_current_value() {
    local domain="$1"
    local key="$2"
    defaults read "$domain" "$key" 2>/dev/null || echo "not set"
}

# Show preview of all settings
show_settings_preview() {
    echo ""
    ui_section "System Settings to Apply:"
    echo ""

    echo "Dock:"
    echo "  • Auto-hide: enabled (instant show, fast animation)"
    echo "  • Auto-hide delay: 0 seconds"
    echo "  • Animation speed: 0.15 seconds"
    echo "  • Icon size: 36 pixels"
    echo ""

    echo "Finder:"
    echo "  • Show all file extensions"
    echo "  • Default to column view"
    echo "  • Don't create .DS_Store on network drives"
    echo "  • Show path bar"
    echo ""

    echo "Keyboard:"
    echo "  • Fast repeat rate (2)"
    echo "  • Short initial delay (15)"
    echo "  • Disable press-and-hold for key repeat"
    echo ""

    echo "Mouse/Trackpad:"
    echo "  • Maximum speed (3.0)"
    echo ""

    echo "Screenshots:"
    echo "  • Save to ~/Desktop/Screenshots"
    echo "  • PNG format"
    echo "  • No shadow"
    echo ""
}

# Apply Dock settings
apply_dock_settings() {
    ui_section "Applying Dock settings..."

    defaults write com.apple.dock autohide -bool true
    defaults write com.apple.dock autohide-delay -float 0
    defaults write com.apple.dock autohide-time-modifier -float 0.15
    defaults write com.apple.dock tilesize -int 36

    killall Dock
    ui_success "Dock settings applied"
}

# Apply Finder settings
apply_finder_settings() {
    ui_section "Applying Finder settings..."

    defaults write NSGlobalDomain AppleShowAllExtensions -bool true
    defaults write com.apple.finder FXPreferredViewStyle -string "clmv"
    defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
    defaults write com.apple.finder ShowPathbar -bool true

    killall Finder
    ui_success "Finder settings applied"
}

# Apply Keyboard settings
apply_keyboard_settings() {
    ui_section "Applying Keyboard settings..."

    defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
    defaults write NSGlobalDomain KeyRepeat -int 2
    defaults write NSGlobalDomain InitialKeyRepeat -int 15

    ui_success "Keyboard settings applied"
    ui_info "Note: You may need to log out and back in for keyboard settings to take full effect"
}

# Apply Mouse/Trackpad settings
apply_input_settings() {
    ui_section "Applying Mouse/Trackpad settings..."

    defaults write NSGlobalDomain com.apple.mouse.scaling -float 3.0
    defaults write NSGlobalDomain com.apple.trackpad.scaling -float 3.0

    ui_success "Mouse/Trackpad settings applied"
}

# Apply Screenshot settings
apply_screenshot_settings() {
    ui_section "Applying Screenshot settings..."

    mkdir -p "$HOME/Desktop/Screenshots"
    defaults write com.apple.screencapture location -string "$HOME/Desktop/Screenshots"
    defaults write com.apple.screencapture type -string "png"
    defaults write com.apple.screencapture disable-shadow -bool true

    killall SystemUIServer
    ui_success "Screenshot settings applied"
}

# Show preview
show_settings_preview

# Present multi-select with all items pre-selected
echo ""
ui_section "Select settings to apply (all recommended by default):"
echo ""

SETTINGS=$(gum choose --no-limit \
    --header "Select settings to apply (space to toggle, enter to confirm):" \
    --selected="Dock: Auto-hide with fast animations" \
    --selected="Finder: Extensions, column view, no network .DS_Store" \
    --selected="Keyboard: Fast repeat, no press-and-hold" \
    --selected="Mouse/Trackpad: Maximum speed" \
    --selected="Screenshots: PNG to ~/Desktop/Screenshots" \
    "Dock: Auto-hide with fast animations" \
    "Finder: Extensions, column view, no network .DS_Store" \
    "Keyboard: Fast repeat, no press-and-hold" \
    "Mouse/Trackpad: Maximum speed" \
    "Screenshots: PNG to ~/Desktop/Screenshots")

# Exit if no settings selected
if [ -z "$SETTINGS" ]; then
    ui_info "No settings selected. Exiting."
    exit 0
fi

echo ""

# Apply selected settings
while IFS= read -r setting; do
    case "$setting" in
        "Dock: Auto-hide with fast animations")
            apply_dock_settings
            ;;
        "Finder: Extensions, column view, no network .DS_Store")
            apply_finder_settings
            ;;
        "Keyboard: Fast repeat, no press-and-hold")
            apply_keyboard_settings
            ;;
        "Mouse/Trackpad: Maximum speed")
            apply_input_settings
            ;;
        "Screenshots: PNG to ~/Desktop/Screenshots")
            apply_screenshot_settings
            ;;
    esac
done <<< "$SETTINGS"

echo ""
ui_success "System settings configuration complete!"
