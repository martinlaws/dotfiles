#!/bin/bash
#
# UI Library - Gum wrapper functions for consistent styling
#
# Colors:
# - 212 (pink) - primary color
# - 196 (red) - errors
# - 10 (green) - success

# Main section header with double border
ui_header() {
    local text="$1"
    gum style \
        --foreground 212 --border-foreground 212 --border double \
        --align center --width 60 --margin "1 2" --padding "2 4" \
        "$text"
}

# Subsection header with bold styling
ui_section() {
    local text="$1"
    gum style --foreground 212 --bold "$text"
}

# Success message with checkmark
ui_success() {
    local text="$1"
    gum style --foreground 10 "✓ $text"
}

# Error message with X
ui_error() {
    local text="$1"
    gum style --foreground 196 --bold "✗ $text"
}

# Info message
ui_info() {
    local text="$1"
    gum style --foreground 212 "$text"
}

# Spinner wrapper - handles VERBOSE mode
ui_spin() {
    local title="$1"
    shift
    local cmd="$@"

    if [ "$VERBOSE" = true ]; then
        # Verbose mode: show command and full output
        echo "Running: $cmd"
        eval "$cmd"
    else
        # Normal mode: use spinner
        gum spin --spinner dot --title "$title" -- sh -c "$cmd"
    fi
}

# Confirmation prompt
ui_confirm() {
    local question="$1"
    gum confirm "$question"
}
