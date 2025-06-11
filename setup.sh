start=`date +%s`
bold=$(tput bold)
normal=$(tput sgr0)
red=`tput setaf 1`
green=`tput setaf 2`
reset=`tput sgr0`

fancy_echo() {
    echo
    echo "${bold}$1${normal}"
}

fancy_echo "👋 hey there! Let's get started"

fancy_echo "########## 🧹 QUICK HOUSEKEEPING ##########"

fancy_echo "Updating homebrew..."
brew update

sh -c "$(curl -fsSL https://starship.rs/install.sh)" -- --force

mkdir ~/.bin
mkdir ~/.config

ln -sf ~/dotfiles/vim/.vimrc ~/.vimrc
ln -sf ~/dotfiles/zsh/.zshrc ~/.zshrc
ln -sf ~/dotfiles/hyper/.hyper.js ~/.hyper.js
ln -sf ~/dotfiles/git/.gitconfig ~/.gitconfig
ln -sf ~/dotfiles/starship/starship.toml ~/.config/starship.toml


fancy_echo "########## 🤖 ALL THE APPS ##########"
fancy_echo "Do you wish to install the recommended apps (you can always delete anything you don't use) (${bold}${green}y${reset}/${bold}${red}n${reset})? "
read OptBrewCasks

if [ "$OptBrewCasks" != "${OptBrewCasks#[Yy]}" ] ;then
  fancy_echo "Installing homebrew casks"
  
  # Apps
  apps=(
    hyper
    cursor
    arc
    spotify
    figma
    gh
    raycast
    claude
    superwhisper
    nvm
  )
  echo "installing apps with Cask..."
  fancy_echo '✅ Installed casks'
else
  fancy_echo 👎
fi

echo "Cleaning up brew"
brew cleanup

fancy_echo "########## 💻 MAC SETTINGS ##########"
fancy_echo "Do you want to enable opinionated system settings (check out the source code to see what these do) (${bold}${green}y${reset}/${bold}${red}n${reset})? "
read OptSystemSettings

if [ "$OptSystemSettings" != "${OptSystemSettings#[Yy]}" ] ;then
  fancy_echo "Alright cowboy, updating system settings..."

  #"Disabling system-wide resume"
  defaults write NSGlobalDomain NSQuitAlwaysKeepsWindows -bool false

  #"Disabling automatic termination of inactive apps"
  defaults write NSGlobalDomain NSDisableAutomaticTermination -bool true

  #"Allow text selection in Quick Look"
  defaults write com.apple.finder QLEnableTextSelection -bool true

  #"Disabling OS X Gate Keeper"
  #"(You'll be able to install any app you want from here on, not just Mac App Store apps)"
  sudo spctl --master-disable
  sudo defaults write /var/db/SystemPolicy-prefs.plist enabled -string no
  defaults write com.apple.LaunchServices LSQuarantine -bool false

  #"Expanding the save panel by default"
  defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
  defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
  defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

  #"Automatically quit printer app once the print jobs complete"
  defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true

  #"Check for software updates daily, not just once per week"
  defaults write com.apple.SoftwareUpdate ScheduleFrequency -int 1

  #"Disable smart quotes and smart dashes as they are annoying when typing code"
  defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
  defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

  #"Enabling full keyboard access for all controls (e.g. enable Tab in modal dialogs)"
  defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

  #"Disabling press-and-hold for keys in favor of a key repeat"
  defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

  #"Setting trackpad & mouse speed to a reasonable number"
  defaults write -g com.apple.trackpad.scaling 5
  defaults write -g com.apple.mouse.scaling 5

  #"Enabling subpixel font rendering on non-Apple LCDs"
  defaults write NSGlobalDomain AppleFontSmoothing -int 2

  #"Showing icons for hard drives, servers, and removable media on the desktop"
  defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true

  #"Showing all filename extensions in Finder by default"
  defaults write NSGlobalDomain AppleShowAllExtensions -bool true

  #"Disabling the warning when changing a file extension"
  defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

  #"Use column view in all Finder windows by default"
  defaults write com.apple.finder FXPreferredViewStyle Clmv

  #"Avoiding the creation of .DS_Store files on network volumes"
  defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true

  #"Enabling snap-to-grid for icons on the desktop and in other icon views"
  /usr/libexec/PlistBuddy -c "Set :DesktopViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist
  /usr/libexec/PlistBuddy -c "Set :FK_StandardViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist
  /usr/libexec/PlistBuddy -c "Set :StandardViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist

  #"Setting the icon size of Dock items to 36 pixels for optimal size/screen-realestate"
  defaults write com.apple.dock tilesize -int 36

  #"Speeding up Mission Control animations and grouping windows by application"
  defaults write com.apple.dock expose-animation-duration -float 0.1
  defaults write com.apple.dock "expose-group-by-app" -bool true

  #"Setting Dock to auto-hide and removing the auto-hiding delay"
  defaults write com.apple.dock autohide -bool true
  defaults write com.apple.dock autohide-delay -float 0
  defaults write com.apple.dock autohide-time-modifier -float 0

  #"Enabling UTF-8 ONLY in Terminal.app and setting the Pro theme by default"
  defaults write com.apple.terminal StringEncodings -array 4
  defaults write com.apple.Terminal "Default Window Settings" -string "Pro"
  defaults write com.apple.Terminal "Startup Window Settings" -string "Pro"

  #"Preventing Time Machine from prompting to use new hard drives as backup volume"
  defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true

  #"Disable the sudden motion sensor as its not useful for SSDs"
  sudo pmset -a sms 0

  #"Speeding up wake from sleep to 24 hours from an hour"
  # http://www.cultofmac.com/221392/quick-hack-speeds-up-retina-macbooks-wake-from-sleep-os-x-tips/
  sudo pmset -a standbydelay 86400

  #"Disable annoying backswipe in Chrome"
  defaults write com.google.Chrome AppleEnableSwipeNavigateWithScrolls -bool false

  #"Setting screenshots location to ~/Desktop/Screenshots"
  mkdir ~/Desktop/Screenshots
  defaults write com.apple.screencapture location -string "$HOME/Desktop/Screenshots"

  #"Setting screenshot format to PNG"
  defaults write com.apple.screencapture type -string "png"

  #"Hiding Safari's bookmarks bar by default"
  defaults write com.apple.Safari ShowFavoritesBar -bool false

  #"Hiding Safari's sidebar in Top Sites"
  defaults write com.apple.Safari ShowSidebarInTopSites -bool false

  #"Disabling Safari's thumbnail cache for History and Top Sites"
  defaults write com.apple.Safari DebugSnapshotsUpdatePolicy -int 2

  #"Enabling Safari's debug menu"
  defaults write com.apple.Safari IncludeInternalDebugMenu -bool true

  #"Making Safari's search banners default to Contains instead of Starts With"
  defaults write com.apple.Safari FindOnPageMatchesWordStartsOnly -bool false

  #"Removing useless icons from Safari's bookmarks bar"
  defaults write com.apple.Safari ProxiesInBookmarksBar "()"

  #"Enabling the Develop menu and the Web Inspector in Safari"
  defaults write com.apple.Safari IncludeDevelopMenu -bool true
  defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
  defaults write com.apple.Safari "com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled" -bool true

  #"Adding a context menu item for showing the Web Inspector in web views"
  defaults write NSGlobalDomain WebKitDeveloperExtras -bool true

  #"Use `~/Downloads/Incomplete` to store incomplete downloads"
  defaults write org.m0k.transmission UseIncompleteDownloadFolder -bool true
  defaults write org.m0k.transmission IncompleteDownloadFolder -string "${HOME}/Downloads/Incomplete"

  # Don’t automatically rearrange Spaces based on most recent use
  defaults write com.apple.dock mru-spaces -bool false

  killall Finder
  fancy_echo '✅ Overwrote system settings'
else
  fancy_echo 👎
fi

runtime=$((($(date +%s)-$start)/60))
fancy_echo "############# ⏲ Total Setup Time ############# $runtime Minutes"
