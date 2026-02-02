#!/bin/bash
#
# State Management Library - JSON state file operations for tracking setup state

# State file locations
STATE_DIR="$HOME/.local/state/dotfiles"
STATE_FILE="$STATE_DIR/setup-state.json"

# Initialize state file if it doesn't exist
state_init() {
    mkdir -p "$STATE_DIR"

    if [ ! -f "$STATE_FILE" ]; then
        # Create initial JSON structure using jq
        jq -n '{
            "version": "1.0",
            "last_run": null,
            "phases": {},
            "packages": {
                "formulae": [],
                "casks": []
            },
            "backups": {
                "last_backup_dir": null
            }
        }' > "$STATE_FILE"
    fi
}

# Check if state file exists (for first-run detection)
state_exists() {
    [ -f "$STATE_FILE" ]
}

# Get last run timestamp
state_get_last_run() {
    if [ ! -f "$STATE_FILE" ]; then
        echo "never"
        return
    fi

    local last_run=$(jq -r '.last_run' "$STATE_FILE")
    if [ "$last_run" = "null" ]; then
        echo "never"
    else
        echo "$last_run"
    fi
}

# Set last run timestamp to now
state_set_last_run() {
    local TMP=$(mktemp)
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    jq --arg timestamp "$timestamp" '.last_run = $timestamp' "$STATE_FILE" > "$TMP" && mv "$TMP" "$STATE_FILE"
}

# Mark a phase as complete
state_set_phase_complete() {
    local phase="$1"
    local TMP=$(mktemp)
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    jq --arg phase "$phase" --arg timestamp "$timestamp" \
        '.phases[$phase].completed_at = $timestamp' \
        "$STATE_FILE" > "$TMP" && mv "$TMP" "$STATE_FILE"
}

# Get phase completion status
state_get_phase_status() {
    local phase="$1"

    if [ ! -f "$STATE_FILE" ]; then
        echo "not_completed"
        return
    fi

    local status=$(jq -r --arg phase "$phase" '.phases[$phase].completed_at // "not_completed"' "$STATE_FILE")
    echo "$status"
}

# Save current installed packages to state file
state_save_packages() {
    local TMP=$(mktemp)

    # Capture current formulae and casks as JSON arrays
    local formulae=$(brew list --formula 2>/dev/null | jq -R -s 'split("\n") | map(select(length > 0))')
    local casks=$(brew list --cask 2>/dev/null | jq -R -s 'split("\n") | map(select(length > 0))')

    # Update state file with package lists
    jq --argjson formulae "$formulae" --argjson casks "$casks" \
        '.packages.formulae = $formulae | .packages.casks = $casks' \
        "$STATE_FILE" > "$TMP" && mv "$TMP" "$STATE_FILE"
}

# Get saved packages from state file
state_get_packages() {
    if [ ! -f "$STATE_FILE" ]; then
        echo '{"formulae": [], "casks": []}'
        return
    fi

    jq '.packages' "$STATE_FILE"
}

# Export variables and functions
export STATE_DIR
export STATE_FILE
export -f state_init
export -f state_exists
export -f state_get_last_run
export -f state_set_last_run
export -f state_set_phase_complete
export -f state_get_phase_status
export -f state_save_packages
export -f state_get_packages
