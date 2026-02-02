#!/usr/bin/env bash
set -euo pipefail

# Re-apply macOS system settings with drift detection and type-aware comparison

# Set SCRIPT_DIR to repo root if not already set
SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"

# Source required libraries
. "$SCRIPT_DIR/scripts/lib/detect.sh"
. "$SCRIPT_DIR/scripts/lib/ui.sh"
. "$SCRIPT_DIR/scripts/lib/state.sh"
. "$SCRIPT_DIR/scripts/lib/backup.sh"
. "$SCRIPT_DIR/scripts/lib/logging.sh"

# Compare values with type normalization to avoid false positives
values_match() {
  local type="$1"
  local current="$2"
  local expected="$3"

  case "$type" in
    bool)
      # Normalize: true/1/TRUE -> 1, false/0/FALSE -> 0
      local curr_norm=$( [[ "$current" =~ ^(true|1|TRUE)$ ]] && echo "1" || echo "0" )
      local exp_norm=$( [[ "$expected" =~ ^(true|1|TRUE)$ ]] && echo "1" || echo "0" )
      [ "$curr_norm" = "$exp_norm" ]
      ;;
    int)
      # Compare as integers (handles "48" vs 48)
      [ "$current" -eq "$expected" ] 2>/dev/null
      ;;
    float)
      # Compare floats with awk (handles "0.15" vs 0.15)
      awk "BEGIN { exit !($current == $expected) }" 2>/dev/null
      ;;
    string)
      # Direct string comparison
      [ "$current" = "$expected" ]
      ;;
    *)
      # Default to string comparison
      [ "$current" = "$expected" ]
      ;;
  esac
}

update_system() {
  ui_section "Checking System Settings"

  # Define expected settings (same as configure-system.sh)
  # Format: "description|domain|key|type|value"
  SETTINGS=(
    "Dock autohide|com.apple.dock|autohide|bool|true"
    "Dock autohide delay|com.apple.dock|autohide-delay|float|0"
    "Dock autohide speed|com.apple.dock|autohide-time-modifier|float|0.15"
    "Dock icon size|com.apple.dock|tilesize|int|48"
    "Show file extensions|NSGlobalDomain|AppleShowAllExtensions|bool|true"
    "Disable press-and-hold|NSGlobalDomain|ApplePressAndHoldEnabled|bool|false"
    "Key repeat rate|NSGlobalDomain|KeyRepeat|int|2"
    "Key repeat delay|NSGlobalDomain|InitialKeyRepeat|int|15"
    "Finder column view|com.apple.finder|FXPreferredViewStyle|string|clmv"
  )

  # Check each setting for drift using type-aware comparison
  DRIFTED=()
  ui_info "Checking for settings drift..."
  echo ""

  for setting in "${SETTINGS[@]}"; do
    IFS='|' read -r desc domain key type value <<< "$setting"

    # Get current value
    CURRENT=$(defaults read "$domain" "$key" 2>/dev/null || echo "<not set>")

    # Compare using type-aware function
    if [ "$CURRENT" = "<not set>" ] || ! values_match "$type" "$CURRENT" "$value"; then
      echo "  $desc: $CURRENT -> $value"
      DRIFTED+=("$setting")
    fi
  done

  # If no drift, exit early
  if [ ${#DRIFTED[@]} -eq 0 ]; then
    ui_success "All system settings match expected values"
    return 0
  fi

  # Show drift summary and confirm
  echo ""
  ui_info "${#DRIFTED[@]} settings differ from expected values"

  if ! ui_confirm "Re-apply these settings?"; then
    ui_info "System settings update skipped"
    return 0
  fi

  # Backup current settings before changes
  backup_create_dir
  backup_defaults "com.apple.dock"
  backup_defaults "com.apple.finder"
  backup_defaults "NSGlobalDomain"
  ui_info "Backup saved to: $BACKUP_DIR"

  # Apply drifted settings
  for setting in "${DRIFTED[@]}"; do
    IFS='|' read -r desc domain key type value <<< "$setting"
    defaults write "$domain" "$key" "-$type" "$value"
    ui_success "Applied: $desc"
    log_info "Applied setting: $desc ($domain $key=$value)"
  done

  # Restart affected services
  ui_info "Restarting Dock and Finder..."
  killall Dock 2>/dev/null || true
  killall Finder 2>/dev/null || true
  ui_success "System settings updated"
  ui_info "Note: Some changes may require logout to take full effect"
}

# Run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  update_system
fi
