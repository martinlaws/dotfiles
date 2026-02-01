#!/bin/bash
#
# Homebrew and Xcode CLT Installation
#
# This script installs Xcode Command Line Tools (prerequisite) and Homebrew
# with proper Apple Silicon / Intel path configuration.

# Source detection library
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/lib/detect.sh
. "$SCRIPT_DIR/scripts/lib/detect.sh"

# Color codes for pre-gum output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

#
# Xcode Command Line Tools Installation
#

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Xcode Command Line Tools"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if is_xcode_clt_installed; then
    echo -e "${GREEN}✓${NC} Xcode Command Line Tools already installed, skipping..."
    xcode-select -p
else
    echo "Installing Xcode Command Line Tools..."
    echo ""

    # Try non-interactive installation first
    echo "Attempting automatic installation..."

    # Create temporary file that triggers CLT install
    touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress

    # Find the Command Line Tools package
    PROD=$(softwareupdate -l 2>/dev/null | grep -B 1 "Command Line Tools" | grep -E "^\*" | sed 's/^[* ]*//' | head -1)

    if [ -n "$PROD" ]; then
        echo "Found: $PROD"
        echo "This may take several minutes and will require your password..."
        echo ""

        # Install the package
        if sudo softwareupdate -i "$PROD" --verbose; then
            rm /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
            echo ""
            echo -e "${GREEN}✓${NC} Xcode Command Line Tools installed successfully"
        else
            rm /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
            echo ""
            echo -e "${YELLOW}⚠${NC} Automatic installation failed"
            echo "Falling back to interactive installation..."
            echo ""
            xcode-select --install
            echo ""
            echo "Please complete the installation dialog, then press RETURN to continue."
            read -r
        fi
    else
        rm /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
        echo ""
        echo -e "${YELLOW}⚠${NC} Could not find Command Line Tools package"
        echo "Falling back to interactive installation..."
        echo ""
        xcode-select --install
        echo ""
        echo "Please complete the installation dialog, then press RETURN to continue."
        read -r
    fi

    # Verify installation
    if is_xcode_clt_installed; then
        echo ""
        echo -e "${GREEN}✓${NC} Xcode Command Line Tools verified"
        xcode-select -p
    else
        echo ""
        echo -e "${RED}✗${NC} Xcode Command Line Tools installation failed"
        echo ""
        echo "Manual installation steps:"
        echo "  1. Run: xcode-select --install"
        echo "  2. Complete the installation dialog"
        echo "  3. Run this script again"
        exit 1
    fi
fi

#
# Homebrew Installation
#

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Homebrew Package Manager"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if is_homebrew_installed; then
    # Source UI library if gum is available
    if command -v gum >/dev/null 2>&1; then
        # shellcheck source=scripts/lib/ui.sh
        . "$SCRIPT_DIR/scripts/lib/ui.sh"
        ui_success "Homebrew already installed, skipping..."
    else
        echo -e "${GREEN}✓${NC} Homebrew already installed, skipping..."
    fi

    brew --version
else
    echo "Installing Homebrew to: $BREW_PREFIX"
    echo ""
    echo -e "${YELLOW}Note:${NC} Your password may be required for system directories"
    echo ""

    # Install Homebrew
    if NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
        echo ""
        echo -e "${GREEN}✓${NC} Homebrew installation complete"

        # Configure PATH for current session
        eval "$($BREW_PREFIX/bin/brew shellenv)"

        # Verify Homebrew is now available
        if command -v brew >/dev/null 2>&1; then
            echo -e "${GREEN}✓${NC} Homebrew verified in PATH"
            brew --version
        else
            echo -e "${RED}✗${NC} Homebrew installation succeeded but not found in PATH"
            echo "This is unexpected. Please check your installation."
            exit 1
        fi

        # Add to shell profile for future sessions
        SHELL_PROFILE="$HOME/.zprofile"
        SHELLENV_LINE="eval \"\$($BREW_PREFIX/bin/brew shellenv)\""

        if ! grep -qF "$SHELLENV_LINE" "$SHELL_PROFILE" 2>/dev/null; then
            echo ""
            echo "Configuring Homebrew in $SHELL_PROFILE..."
            echo "$SHELLENV_LINE" >> "$SHELL_PROFILE"
            echo -e "${GREEN}✓${NC} Shell profile updated"
        else
            echo ""
            echo -e "${GREEN}✓${NC} Homebrew already configured in shell profile"
        fi

        # Install gum immediately for subsequent UI
        echo ""
        echo "Installing Gum for beautiful CLI interface..."
        if brew install gum; then
            echo -e "${GREEN}✓${NC} Gum installed successfully"
        else
            echo -e "${YELLOW}⚠${NC} Gum installation failed (will fall back to plain output)"
        fi

    else
        echo ""
        echo -e "${RED}✗${NC} Homebrew installation failed"
        echo ""
        echo "You can try again by re-running this script, or install manually:"
        echo "  Visit: https://brew.sh"
        exit 1
    fi
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Homebrew setup complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
