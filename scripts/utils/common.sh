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

# Get the directory of the current script
get_script_dir() {
    local script_path="${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}"
    cd "$(dirname "$script_path")" && pwd
}

# Get the project root directory
get_project_root() {
    local script_dir
    script_dir=$(get_script_dir)

    # Look for project root indicators starting from script directory
    local current_dir="$script_dir"
    while [[ "$current_dir" != "/" ]]; do
        if [[ -f "$current_dir/pyproject.toml" ]] || [[ -f "$current_dir/package.json" ]] || [[ -f "$current_dir/Cargo.toml" ]] || [[ -f "$current_dir/mise.toml" ]]; then
            echo "$current_dir"
            return 0
        fi
        current_dir=$(dirname "$current_dir")
    done

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

    local find_cmd="find . -name \"$pattern\" -type f"

    for dir in "${exclude_dirs[@]}"; do
        find_cmd+=" -not -path \"./$dir/*\""
    done

    find_cmd+=" -print0"

    eval "$find_cmd"
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

# Parse command line arguments
parse_args() {
    local -n args_ref="$1"
    shift

    # Initialize the associative array with default values
    # This prevents shellcheck warnings about unassigned variables
    args_ref["help"]=false
    args_ref["verbose"]=false
    args_ref["quiet"]=false
    args_ref["positional"]=()

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                args_ref["help"]=true
                shift
                ;;
            -v|--verbose)
                args_ref["verbose"]=true
                shift
                ;;
            -q|--quiet)
                args_ref["quiet"]=true
                shift
                ;;
            --*)
                # Long option
                local key="${1#--}"
                if [[ $# -gt 1 && $2 != --* && $2 != -* ]]; then
                    args_ref["$key"]="$2"
                    shift 2
                else
                    args_ref["$key"]=true
                    shift
                fi
                ;;
            -*)
                # Short option
                local key="${1#-}"
                if [[ $# -gt 1 && $2 != --* && $2 != -* ]]; then
                    args_ref["$key"]="$2"
                    shift 2
                else
                    args_ref["$key"]=true
                    shift
                fi
                ;;
            *)
                # Positional argument
                args_ref["positional"]+=("$1")
                shift
                ;;
        esac
    done
}
