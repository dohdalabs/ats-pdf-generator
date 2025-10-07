#!/usr/bin/env bash

# logging.sh
# Advanced logging module for Bash scripts
# Based on: https://gist.github.com/GingerGraham/99af97eed2cd89cd047a2088947a5405

# Log level constants
LOG_LEVEL_EMERGENCY=0
LOG_LEVEL_ALERT=1
LOG_LEVEL_CRITICAL=2
LOG_LEVEL_ERROR=3
LOG_LEVEL_WARN=4
LOG_LEVEL_NOTICE=5
LOG_LEVEL_INFO=6
LOG_LEVEL_DEBUG=7

# Default configuration
LOG_LEVEL=${LOG_LEVEL:-$LOG_LEVEL_INFO}
LOG_FILE=""
LOG_FORMAT="%d [%l] [%s] %m"
LOG_UTC=false
LOG_QUIET=false
LOG_JOURNAL=false
LOG_TAG=""
LOG_SCRIPT_NAME=""
LOG_COLOR=true

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Initialize logger with options
init_logger() {
    local script_name=""
    script_name=$(basename "${BASH_SOURCE[1]:-unknown}")

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -l|--log|--logfile|--log-file|--file)
                LOG_FILE="$2"
                shift 2
                ;;
            -q|--quiet)
                LOG_QUIET=true
                shift
                ;;
            -v|--verbose|--debug)
                LOG_LEVEL=$LOG_LEVEL_DEBUG
                shift
                ;;
            -d|--level)
                case "$2" in
                    DEBUG|debug) LOG_LEVEL=$LOG_LEVEL_DEBUG ;;
                    INFO|info) LOG_LEVEL=$LOG_LEVEL_INFO ;;
                    NOTICE|notice) LOG_LEVEL=$LOG_LEVEL_NOTICE ;;
                    WARN|warn|WARNING|warning) LOG_LEVEL=$LOG_LEVEL_WARN ;;
                    ERROR|error) LOG_LEVEL=$LOG_LEVEL_ERROR ;;
                    CRITICAL|critical) LOG_LEVEL=$LOG_LEVEL_CRITICAL ;;
                    ALERT|alert) LOG_LEVEL=$LOG_LEVEL_ALERT ;;
                    EMERGENCY|emergency) LOG_LEVEL=$LOG_LEVEL_EMERGENCY ;;
                    [0-7]) LOG_LEVEL="$2" ;;
                    *) echo "Invalid log level: $2" >&2; return 1 ;;
                esac
                shift 2
                ;;
            -f|--format)
                LOG_FORMAT="$2"
                shift 2
                ;;
            -u|--utc)
                LOG_UTC=true
                shift
                ;;
            -j|--journal)
                LOG_JOURNAL=true
                shift
                ;;
            -t|--tag)
                LOG_TAG="$2"
                shift 2
                ;;
            --color|--colour)
                LOG_COLOR=true
                shift
                ;;
            --no-color|--no-colour)
                LOG_COLOR=false
                shift
                ;;
            --script-name)
                LOG_SCRIPT_NAME="$2"
                shift 2
                ;;
            *)
                echo "Unknown option: $1" >&2
                return 1
                ;;
        esac
    done

    # Set default tag if not provided
    if [[ -z "$LOG_TAG" ]]; then
        LOG_TAG="$script_name"
    fi

    if [[ -z "$LOG_SCRIPT_NAME" ]]; then
        echo "init_logger: --script-name is required" >&2
        return 1
    fi

    # Create log file directory if needed
    if [[ -n "$LOG_FILE" ]]; then
        local log_dir
        log_dir=$(dirname "$LOG_FILE")
        if [[ ! -d "$log_dir" ]]; then
            mkdir -p "$log_dir" || {
                echo "Failed to create log directory: $log_dir" >&2
                return 1
            }
        fi
    fi

    return 0
}

# Get timestamp
get_timestamp() {
    if [[ "$LOG_UTC" == "true" ]]; then
        date -u "+%Y-%m-%d %H:%M:%S"
    else
        date "+%Y-%m-%d %H:%M:%S"
    fi
}

# Get timezone
get_timezone() {
    if [[ "$LOG_UTC" == "true" ]]; then
        echo "UTC"
    else
        date "+%Z"
    fi
}

# Format log message
format_message() {
    local level="$1"
    local message="$2"
    local script_name

    if [[ -n "$LOG_TAG" ]]; then
        script_name="$LOG_TAG"
    elif [[ -n "$LOG_SCRIPT_NAME" ]]; then
        script_name="$LOG_SCRIPT_NAME"
    else
        script_name=$(basename "${BASH_SOURCE[2]:-unknown}")
    fi

    local formatted="$LOG_FORMAT"
    formatted="${formatted//%d/$(get_timestamp)}"
    formatted="${formatted//%l/$level}"
    formatted="${formatted//%s/$script_name}"
    formatted="${formatted//%m/$message}"
    formatted="${formatted//%z/$(get_timezone)}"

    echo "$formatted"
}

# Get color for log level
get_color() {
    case "$1" in
        DEBUG) echo "$CYAN" ;;
        INFO) echo "$BLUE" ;;
        NOTICE) echo "$GREEN" ;;
        WARN|WARNING) echo "$YELLOW" ;;
        ERROR) echo "$RED" ;;
        CRITICAL) echo "$PURPLE" ;;
        ALERT|EMERGENCY|FATAL) echo "$WHITE" ;;
        SENSITIVE) echo "$GREEN" ;;
        *) echo "$NC" ;;
    esac
}

# Core logging function
log_message() {
    local level="$1"
    local level_num="$2"
    local message="$3"
    local console_only="${4:-false}"
    local no_file="${5:-false}"

    # Check if we should log this level
    if [[ $level_num -gt $LOG_LEVEL ]]; then
        return 0
    fi

    local formatted
    formatted=$(format_message "$level" "$message")

    # Console output
    if [[ "$LOG_QUIET" != "true" || "$console_only" == "true" ]]; then
        if [[ "$LOG_COLOR" == "true" && -t 1 ]]; then
            local color
            color=$(get_color "$level")
            echo -e "${color}${formatted}${NC}"
        else
            echo "$formatted"
        fi
    fi

    # File output
    if [[ -n "$LOG_FILE" && "$no_file" != "true" ]]; then
        echo "$formatted" >> "$LOG_FILE"
    fi

    # Journal output
    if [[ "$LOG_JOURNAL" == "true" && "$no_file" != "true" ]]; then
        local priority
        case "$level" in
            DEBUG) priority="debug" ;;
            INFO) priority="info" ;;
            NOTICE) priority="notice" ;;
            WARN|WARNING) priority="warning" ;;
            ERROR) priority="err" ;;
            CRITICAL) priority="crit" ;;
            ALERT) priority="alert" ;;
            EMERGENCY|FATAL) priority="emerg" ;;
            *) priority="info" ;;
        esac

        if command -v logger >/dev/null 2>&1; then
            logger -t "$LOG_TAG" -p "$priority" "$message"
        fi
    fi
}

# Logging functions
log_debug() {
    log_message "DEBUG" $LOG_LEVEL_DEBUG "$1"
}

log_info() {
    log_message "INFO" $LOG_LEVEL_INFO "$1"
}

log_notice() {
    log_message "NOTICE" $LOG_LEVEL_NOTICE "$1"
}

log_warn() {
    log_message "WARN" $LOG_LEVEL_WARN "$1"
}

log_error() {
    log_message "ERROR" $LOG_LEVEL_ERROR "$1"
}

log_critical() {
    log_message "CRITICAL" $LOG_LEVEL_CRITICAL "$1"
}

log_alert() {
    log_message "ALERT" $LOG_LEVEL_ALERT "$1"
}

log_emergency() {
    log_message "EMERGENCY" $LOG_LEVEL_EMERGENCY "$1"
}

# Alias for backward compatibility
log_fatal() {
    log_message "FATAL" $LOG_LEVEL_EMERGENCY "$1"
}

log_init() {
    log_message "INIT" -1 "$1" # Using -1 to ensure it always shows
}

# Function for sensitive logging - console only, never to file or journal
log_sensitive() {
    log_message "SENSITIVE" $LOG_LEVEL_INFO "$1" "true" "true"
}

# Runtime configuration functions
set_log_level() {
    case "$1" in
        DEBUG|debug) LOG_LEVEL=$LOG_LEVEL_DEBUG ;;
        INFO|info) LOG_LEVEL=$LOG_LEVEL_INFO ;;
        NOTICE|notice) LOG_LEVEL=$LOG_LEVEL_NOTICE ;;
        WARN|warn|WARNING|warning) LOG_LEVEL=$LOG_LEVEL_WARN ;;
        ERROR|error) LOG_LEVEL=$LOG_LEVEL_ERROR ;;
        CRITICAL|critical) LOG_LEVEL=$LOG_LEVEL_CRITICAL ;;
        ALERT|alert) LOG_LEVEL=$LOG_LEVEL_ALERT ;;
        EMERGENCY|emergency) LOG_LEVEL=$LOG_LEVEL_EMERGENCY ;;
        [0-7]) LOG_LEVEL="$1" ;;
        *) echo "Invalid log level: $1" >&2; return 1 ;;
    esac
}

set_timezone_utc() {
    LOG_UTC="$1"
}

set_log_format() {
    LOG_FORMAT="$1"
}

set_journal_logging() {
    LOG_JOURNAL="$1"
}

set_journal_tag() {
    LOG_TAG="$1"
}

# Convenience functions for common use cases
log_success() {
    log_info "✅ $1"
}

log_step() {
    log_info "🔍 $1"
}

log_warning() {
    log_warn "⚠️  $1"
}

# Only execute initialization if this script is being run directly
# If it's being sourced, the sourcing script should call init_logger
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script is designed to be sourced by other scripts, not executed directly."
    echo "Usage: source logging.sh"
    exit 1
fi
