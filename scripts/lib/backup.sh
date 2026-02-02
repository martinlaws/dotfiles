#!/bin/bash
#
# Backup Utilities Library - Timestamped backup creation and management

# shellcheck source=scripts/lib/state.sh
if [ -f "$(dirname "${BASH_SOURCE[0]}")/state.sh" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/state.sh"
fi

# Backup directory location
BACKUP_BASE_DIR="$HOME/.local/state/dotfiles/backups"

# Create timestamped backup directory
backup_create_dir() {
    local timestamp=$(date +%Y-%m-%dT%H-%M-%S)
    BACKUP_DIR="$BACKUP_BASE_DIR/$timestamp"

    mkdir -p "$BACKUP_DIR"

    # Update state file with last backup directory
    if [ -f "$STATE_FILE" ]; then
        local TMP=$(mktemp)
        jq --arg dir "$BACKUP_DIR" '.backups.last_backup_dir = $dir' "$STATE_FILE" > "$TMP" && mv "$TMP" "$STATE_FILE"
    fi

    export BACKUP_DIR
    echo "$BACKUP_DIR"
}

# Cleanup old backups (keep only last 5)
backup_cleanup_old() {
    if [ ! -d "$BACKUP_BASE_DIR" ]; then
        return
    fi

    # Count number of backups
    local count=$(ls -1 "$BACKUP_BASE_DIR" 2>/dev/null | wc -l | tr -d ' ')

    # Only cleanup if more than 5 backups exist
    if [ "$count" -gt 5 ]; then
        (cd "$BACKUP_BASE_DIR" && ls -t | tail -n +6 | xargs rm -rf)
    fi
}

# Backup macOS defaults domain to plist file
backup_defaults() {
    local domain="$1"

    if [ -z "$domain" ]; then
        echo "Error: domain required" >&2
        return 1
    fi

    if [ -z "$BACKUP_DIR" ]; then
        echo "Error: BACKUP_DIR not set (call backup_create_dir first)" >&2
        return 1
    fi

    # Try to export defaults, handle gracefully if domain doesn't exist
    if defaults read "$domain" >/dev/null 2>&1; then
        defaults export "$domain" "$BACKUP_DIR/$domain.plist" 2>/dev/null || true
    fi
}

# Backup current state file
backup_state() {
    if [ -z "$BACKUP_DIR" ]; then
        echo "Error: BACKUP_DIR not set (call backup_create_dir first)" >&2
        return 1
    fi

    if [ -f "$STATE_FILE" ]; then
        cp "$STATE_FILE" "$BACKUP_DIR/setup-state.json"
    fi
}

# Get most recent backup directory
backup_get_last_dir() {
    if [ ! -d "$BACKUP_BASE_DIR" ]; then
        return
    fi

    ls -t "$BACKUP_BASE_DIR" 2>/dev/null | head -n 1 | xargs -I {} echo "$BACKUP_BASE_DIR/{}"
}

# Export variables and functions
export BACKUP_BASE_DIR
export -f backup_create_dir
export -f backup_cleanup_old
export -f backup_defaults
export -f backup_state
export -f backup_get_last_dir
