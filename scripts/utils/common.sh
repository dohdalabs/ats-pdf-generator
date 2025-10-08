#!/usr/bin/env bash

# common.sh
# ----------------------------------------
# Shared Utility Functions for Bash Scripts
#
# This script provides common helper functions for use in other Bash scripts
# throughout the project. It is intended to be sourced (not executed directly)
# to provide consistent, reusable utilities such as:
#   - Determining the script or project root directory
#   - Checking for the existence of commands, files, or directories
#   - Ensuring directories exist
#
# Usage:
#   source ./scripts/utils/common.sh
#   # Now you can use functions like get_project_root, command_exists, etc.
#
# This script is used by other scripts in the scripts/ directory to avoid
# code duplication and ensure consistent behavior.
# ----------------------------------------

# shellcheck disable=SC2034
# Shared flag state used by parse_common_flags. Scripts sourcing this file
# should treat these as read-only outputs after invoking the parser.
COMMON_FLAG_SHOW_HELP=false
# shellcheck disable=SC2034
COMMON_FLAG_VERBOSE=false
# shellcheck disable=SC2034
COMMON_FLAG_QUIET=false
COMMON_FLAGS_REMAINING=()

# Get the directory of the current script
get_script_dir() {
    local script_path="${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}"
    (cd "$(dirname "$script_path")" && pwd)
}

# Get the project root directory
get_project_root() {
    local script_dir
    script_dir=$(get_script_dir)

    # Look for project root indicators starting from script directory
    local current_dir="$script_dir"
    local visited_dirs=()
    local max_depth=50  # Prevent infinite loops with reasonable depth limit

    while [[ "$current_dir" != "/" && ${#visited_dirs[@]} -lt $max_depth ]]; do
        # Check if we've already visited this directory (prevents cyclic symlink loops)
        if [[ ${#visited_dirs[@]} -gt 0 ]]; then
            for visited in "${visited_dirs[@]}"; do
                if [[ "$visited" == "$current_dir" ]]; then
                    echo "Error: Detected cyclic symlink in directory traversal at: $current_dir" >&2
                    return 1
                fi
            done
        fi

        # Add current directory to visited list
        visited_dirs+=("$current_dir")

        # Check for project root indicators
        if [[ -f "$current_dir/pyproject.toml" ]] || [[ -f "$current_dir/package.json" ]] || [[ -f "$current_dir/Cargo.toml" ]] || [[ -f "$current_dir/mise.toml" ]]; then
            echo "$current_dir"
            return 0
        fi

        # Move to parent directory
        local parent_dir
        parent_dir=$(dirname "$current_dir")

        # Safety check: if parent is same as current, we're stuck
        if [[ "$parent_dir" == "$current_dir" ]]; then
            echo "Error: Cannot traverse beyond directory: $current_dir" >&2
            return 1
        fi

        current_dir="$parent_dir"
    done

    # If we hit max depth, it's likely a symlink loop
    if [[ ${#visited_dirs[@]} -ge $max_depth ]]; then
        echo "Error: Maximum directory traversal depth reached (${max_depth}). Possible symlink loop." >&2
        echo "Traversed from: $script_dir" >&2
        return 1
    fi

    # If no project root found, this is an error condition
    echo "Error: Could not find project root from script location: $script_dir" >&2
    echo "Expected to find one of: pyproject.toml, package.json, Cargo.toml, or mise.toml" >&2
    return 1
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if a file exists and is readable
file_exists() {
    [[ -f "$1" && -r "$1" ]]
}

# Check if a directory exists and is readable
dir_exists() {
    [[ -d "$1" && -r "$1" ]]
}

# Create directory if it doesn't exist
ensure_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir" || {
            echo "Failed to create directory: $dir" >&2
            return 1
        }
    fi
}

# Get file extension
get_extension() {
    local filename="$1"
    echo "${filename##*.}"
}

# Get filename without extension
get_basename() {
    local filename="$1"
    echo "${filename%.*}"
}

# Check if running as root
is_root() {
    [[ $EUID -eq 0 ]]
}

# Check if running on macOS
is_macos() {
    [[ "$OSTYPE" == "darwin"* ]]
}

# Check if running on Linux
is_linux() {
    [[ "$OSTYPE" == "linux-gnu"* ]]
}

# Get operating system name
get_os() {
    if is_macos; then
        echo "macOS"
    elif is_linux; then
        echo "Linux"
    else
        echo "Unknown"
    fi
}

# Safe array append
array_append() {
    local -n arr="$1"
    local value="$2"
    arr+=("$value")
}

# Join array elements with delimiter
join_array() {
    local delimiter="$1"
    shift
    local array=("$@")
    local result=""

    for i in "${!array[@]}"; do
        if [[ $i -gt 0 ]]; then
            result+="$delimiter"
        fi
        result+="${array[$i]}"
    done

    echo "$result"
}

# Find files with pattern, excluding certain directories
find_files_exclude() {
    local pattern="$1"
    shift
    local exclude_dirs=("$@")

    local find_cmd=(find . -name "$pattern" -type f)

    for dir in "${exclude_dirs[@]}"; do
        find_cmd+=(-not -path "./$dir/*")
    done

    find_cmd+=(-print0)

    "${find_cmd[@]}"
}

# Retry a command with exponential backoff
retry() {
    local max_attempts="$1"
    local delay="$2"
    shift 2
    local command=("$@")

    local attempt=1
    while [[ $attempt -le $max_attempts ]]; do
        if "${command[@]}"; then
            return 0
        fi

        if [[ $attempt -lt $max_attempts ]]; then
            echo "Attempt $attempt failed, retrying in ${delay}s..." >&2
            sleep "$delay"
            delay=$((delay * 2))  # Exponential backoff
        fi

        ((attempt++))
    done

    echo "Command failed after $max_attempts attempts" >&2
    return 1
}

# Parse common flags shared across scripts
# Resets shared COMMON_FLAG_* variables, applies logging configuration, and
# returns the remaining positional arguments via COMMON_FLAGS_REMAINING.
# Usage: if ! parse_common_flags "$@"; then ...; fi
parse_common_flags() {
    COMMON_FLAG_SHOW_HELP=false
    COMMON_FLAG_VERBOSE=false
    COMMON_FLAG_QUIET=false
    COMMON_FLAGS_REMAINING=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                COMMON_FLAG_SHOW_HELP=true
                shift
                ;;
            -q|--quiet)
                COMMON_FLAG_QUIET=true
                LOG_QUIET=true
                shift
                ;;
            -v|--verbose)
                COMMON_FLAG_VERBOSE=true
                set_log_level debug >/dev/null 2>&1 || true
                shift
                ;;
            --log-level)
                if [[ $# -lt 2 ]]; then
                    echo "Missing value for --log-level" >&2
                    return 1
                fi
                if command -v set_log_level >/dev/null 2>&1; then
                    if ! set_log_level "$2" >/dev/null 2>&1; then
                        echo "Invalid log level: $2" >&2
                        return 1
                    fi
                else
                    LOG_LEVEL="$2"
                fi
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
            --)
                shift
                while [[ $# -gt 0 ]]; do
                    COMMON_FLAGS_REMAINING+=("$1")
                    shift
                done
                break
                ;;
            *)
                COMMON_FLAGS_REMAINING+=("$1")
                shift
                ;;
        esac
    done

    if [[ ${#COMMON_FLAGS_REMAINING[@]} -gt 0 ]]; then
        set -- "${COMMON_FLAGS_REMAINING[@]}"
        COMMON_FLAGS_REMAINING=("$@")
    else
        COMMON_FLAGS_REMAINING=()
    fi
    return 0
}
