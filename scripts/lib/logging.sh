#!/bin/bash
#
# Logging Library - Write detailed logs to file while keeping UI clean

# Log file locations
LOG_DIR="$HOME/.local/state/dotfiles/logs"
LOG_FILE="$LOG_DIR/setup-$(date +%Y-%m-%d).log"

# Initialize logging (create directory and session header)
log_init() {
    mkdir -p "$LOG_DIR"
    echo "" >> "$LOG_FILE"
    echo "========================================" >> "$LOG_FILE"
    echo "Session started: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
    echo "========================================" >> "$LOG_FILE"
}

# Log info message (to file only)
log_info() {
    echo "[INFO] $(date '+%H:%M:%S') $*" >> "$LOG_FILE"
}

# Log error message (to file only)
log_error() {
    echo "[ERROR] $(date '+%H:%M:%S') $*" >> "$LOG_FILE"
}

# Log debug message (to file only)
log_debug() {
    echo "[DEBUG] $(date '+%H:%M:%S') $*" >> "$LOG_FILE"
}

# Run command and log output to file (keeps terminal clean)
log_cmd() {
    local desc="$1"
    shift

    log_info "Running: $*"

    if output=$("$@" 2>&1); then
        log_info "Success: $desc"
        echo "$output" >> "$LOG_FILE"
        return 0
    else
        log_error "Failed: $desc"
        echo "$output" >> "$LOG_FILE"
        return 1
    fi
}

# Get current log file path
log_get_file() {
    echo "$LOG_FILE"
}

# Export variables and functions
export LOG_DIR
export LOG_FILE
export -f log_init
export -f log_info
export -f log_error
export -f log_debug
export -f log_cmd
export -f log_get_file
