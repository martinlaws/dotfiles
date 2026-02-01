#!/bin/bash
#
# UI Library - Gum wrapper functions for consistent styling
#
# Colors:
# - 212 (pink) - primary color
# - 196 (red) - errors
# - 10 (green) - success

# ANSI color codes for fallback
GREEN='\033[0;32m'
RED='\033[0;31m'
PINK='\033[38;5;212m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Main section header with double border
ui_header() {
    local text="$1"
    if command -v gum >/dev/null 2>&1; then
        gum style \
            --foreground 212 --border-foreground 212 --border double \
            --align center --width 60 --margin "1 2" --padding "2 4" \
            "$text"
    else
        echo ""
        echo -e "${PINK}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${PINK}  $text${NC}"
        echo -e "${PINK}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
    fi
}

# Subsection header with bold styling
ui_section() {
    local text="$1"
    if command -v gum >/dev/null 2>&1; then
        gum style --foreground 212 --bold "$text"
    else
        echo -e "${BOLD}${PINK}$text${NC}"
    fi
}

# Success message with checkmark
ui_success() {
    local text="$1"
    if command -v gum >/dev/null 2>&1; then
        gum style --foreground 10 "✓ $text"
    else
        echo -e "${GREEN}✓${NC} $text"
    fi
}

# Error message with X
ui_error() {
    local text="$1"
    if command -v gum >/dev/null 2>&1; then
        gum style --foreground 196 --bold "✗ $text"
    else
        echo -e "${BOLD}${RED}✗${NC} $text"
    fi
}

# Info message
ui_info() {
    local text="$1"
    if command -v gum >/dev/null 2>&1; then
        gum style --foreground 212 "$text"
    else
        echo -e "${PINK}$text${NC}"
    fi
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
        # Normal mode: use spinner if gum available
        if command -v gum >/dev/null 2>&1; then
            gum spin --spinner dot --title "$title" -- sh -c "$cmd"
        else
            echo "$title"
            eval "$cmd"
        fi
    fi
}

# Confirmation prompt
ui_confirm() {
    local question="$1"
    if command -v gum >/dev/null 2>&1; then
        gum confirm "$question"
    else
        echo -n "$question [y/N] "
        read -r response
        [[ "$response" =~ ^[Yy]$ ]]
    fi
}
