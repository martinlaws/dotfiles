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
    printf "${GREEN}✓${NC} Xcode Command Line Tools already installed at:\n"
    xcode-select -p
else
    echo "Installing Xcode Command Line Tools automatically..."
    echo ""

    # Create the trigger file that makes softwareupdate list CLT
    TRIGGER_FILE="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
    sudo touch "$TRIGGER_FILE"

    # Find the CLT package name from softwareupdate
    echo "Finding Command Line Tools package..."
    CLT_PACKAGE=$(softwareupdate --list 2>&1 | grep -o "Command Line Tools for Xcode-[0-9.]*" | head -1)

    if [ -z "$CLT_PACKAGE" ]; then
        # Fallback: try alternate pattern
        CLT_PACKAGE=$(softwareupdate --list 2>&1 | grep -o "\* Label: Command Line Tools.*" | sed 's/\* Label: //' | head -1)
    fi

    if [ -z "$CLT_PACKAGE" ]; then
        # If still not found, clean up and fall back to interactive
        sudo rm -f "$TRIGGER_FILE"
        echo ""
        printf "${YELLOW}Could not find Command Line Tools package automatically.${NC}\n"
        echo "Falling back to interactive installation..."
        echo ""
        xcode-select --install 2>/dev/null
        echo ""
        echo "Please complete the installation dialog, then press RETURN to continue..."
        read -r
    else
        echo "Installing: $CLT_PACKAGE"
        echo ""
        echo "This may take several minutes..."
        echo ""

        # Install CLT via softwareupdate (runs silently)
        if sudo softwareupdate --install "$CLT_PACKAGE" --verbose; then
            printf "${GREEN}✓${NC} Xcode Command Line Tools installed successfully\n"
        else
            printf "${RED}✗${NC} softwareupdate installation failed\n"
            echo ""
            echo "Falling back to interactive installation..."
            xcode-select --install 2>/dev/null
            echo ""
            echo "Please complete the installation dialog, then press RETURN to continue..."
            read -r
        fi

        # Clean up trigger file
        sudo rm -f "$TRIGGER_FILE"
    fi

    # Verify installation
    if is_xcode_clt_installed; then
        printf "${GREEN}✓${NC} Xcode Command Line Tools verified at:\n"
        xcode-select -p
    else
        printf "${RED}✗${NC} Xcode Command Line Tools not detected\n"
        echo ""
        echo "Installation may not have completed successfully."
        echo "Please run: xcode-select --install"
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
        ui_success "Homebrew already installed"
    else
        printf "${GREEN}✓${NC} Homebrew already installed\n"
    fi

    brew --version

    # Ensure shell profile is configured even if Homebrew was already installed
    SHELL_PROFILE="$HOME/.zprofile"
    SHELLENV_LINE="eval \"\$($BREW_PREFIX/bin/brew shellenv)\""

    # Create .zprofile if it doesn't exist
    if [ ! -f "$SHELL_PROFILE" ]; then
        touch "$SHELL_PROFILE"
    fi

    if ! grep -q "brew shellenv" "$SHELL_PROFILE" 2>/dev/null; then
        echo ""
        echo "Configuring Homebrew in $SHELL_PROFILE..."
        echo "$SHELLENV_LINE" >> "$SHELL_PROFILE"
        printf "${GREEN}✓${NC} Shell profile updated\n"
    fi
else
    echo "Installing Homebrew to: $BREW_PREFIX"
    echo ""
    printf "${YELLOW}Note:${NC} You will be prompted for your password when needed\n"
    echo ""

    # Install Homebrew
    if /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
        echo ""
        printf "${GREEN}✓${NC} Homebrew installation complete\n"

        # Configure PATH for current session
        eval "$($BREW_PREFIX/bin/brew shellenv)"

        # Verify Homebrew is now available
        if command -v brew >/dev/null 2>&1; then
            printf "${GREEN}✓${NC} Homebrew verified in PATH\n"
            brew --version
        else
            printf "${RED}✗${NC} Homebrew installation succeeded but not found in PATH\n"
            echo "This is unexpected. Please check your installation."
            exit 1
        fi

        # Add to shell profile for future sessions
        SHELL_PROFILE="$HOME/.zprofile"
        SHELLENV_LINE="eval \"\$($BREW_PREFIX/bin/brew shellenv)\""

        # Create .zprofile if it doesn't exist
        if [ ! -f "$SHELL_PROFILE" ]; then
            touch "$SHELL_PROFILE"
        fi

        if ! grep -q "brew shellenv" "$SHELL_PROFILE" 2>/dev/null; then
            echo ""
            echo "Configuring Homebrew in $SHELL_PROFILE..."
            echo "$SHELLENV_LINE" >> "$SHELL_PROFILE"
            printf "${GREEN}✓${NC} Shell profile updated\n"
        else
            echo ""
            printf "${GREEN}✓${NC} Homebrew already configured in shell profile\n"
        fi

        # Install gum immediately for subsequent UI
        echo ""
        echo "Installing Gum for beautiful CLI interface..."
        if brew install gum; then
            printf "${GREEN}✓${NC} Gum installed successfully\n"
        else
            printf "${YELLOW}⚠${NC} Gum installation failed (will fall back to plain output)\n"
        fi

    else
        echo ""
        printf "${RED}✗${NC} Homebrew installation failed\n"
        echo ""
        echo "You can try again by re-running this script, or install manually:"
        echo "  Visit: https://brew.sh"
        exit 1
    fi
fi

echo ""
printf "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
printf "${GREEN}  Homebrew setup complete!${NC}\n"
printf "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
echo ""
