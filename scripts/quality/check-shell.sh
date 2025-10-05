#!/usr/bin/env bash

# check-shell.sh
# Shell script quality checks using shellcheck

set -euo pipefail

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to show usage
show_usage() {
    cat << 'USAGE_EOF'
SYNOPSIS
    check-shell.sh [OPTIONS]

DESCRIPTION
    Shell Script Quality Check Script for ATS PDF Generator.
    This script runs shellcheck on all shell scripts in the project and validates
    that each script has proper help documentation with required sections.
    It ensures consistent shell script quality and documentation standards.

    Scripts can be exempted from help validation by:
    1. Adding "# pre-commit: skip-help-validation" comment in the script
    2. Adding the script name to .pre-commit-shell-skip-help.txt file
    3. Being a utility script (common.sh, logging.sh, ci.sh)

OPTIONS
    -h, --help              Show this help message and exit

EXAMPLES
    # Run shell script quality checks
    ./scripts/quality/check-shell.sh

    # Show help
    ./scripts/quality/check-shell.sh --help

Requirements:
    - shellcheck must be installed (managed by mise.toml)
    - All shell scripts should have proper help documentation

For more information: https://github.com/dohdalabs/ats-pdf-generator
USAGE_EOF
}

# Check if help is requested
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    show_usage
    exit 0
fi


# Source utilities
source "$SCRIPT_DIR/../utils/logging.sh"
source "$SCRIPT_DIR/../utils/ci.sh"
source "$SCRIPT_DIR/../utils/common.sh"

# Initialize logger
init_logger --format "%d [%l] %m"

# Validate a single script's help options
validate_script_help() {
    local script="$1"
    local script_name
    script_name=$(basename "$script")

    # Ensure script path is properly resolved
    if [[ "$script" != /* ]] && [[ "$script" != ./* ]]; then
        script="./$script"
    fi

    local errors=0

    # Check if script is executable
    if [ ! -x "$script" ]; then
        log_warning "$script_name: Script is not executable"
        ((errors++))
    fi

    # Check if script has shebang
    if ! head -1 "$script" | grep -q "^#!"; then
        log_warning "$script_name: Missing shebang line"
        ((errors++))
    fi

    # Check if script has a comment indicating it should skip help validation
    if grep -q "# pre-commit: skip-help-validation" "$script" 2>/dev/null; then
        log_info "$script_name: Skipping help validation (marked with # pre-commit: skip-help-validation)"
        return 0
    fi

    # Check if script is in a configuration file of scripts to skip
    if [ -f ".pre-commit-shell-skip-help.txt" ]; then
        if grep -q "^$(basename "$script")$" ".pre-commit-shell-skip-help.txt" 2>/dev/null; then
            log_info "$script_name: Skipping help validation (listed in .pre-commit-shell-skip-help.txt)"
            return 0
        fi
    fi

    # Skip utility scripts that are meant to be sourced, not executed
    if [[ "$script_name" =~ ^(common|logging|ci)\.sh$ ]]; then
        log_info "$script_name: Skipping utility script (meant to be sourced)"
        return 0
    fi

    # Check if script has --help option
    if ! grep -q "help\|-h" "$script"; then
        log_warning "$script_name: No help option found"
        ((errors++))
        return $errors
    fi

    # Test --help option works
    if ! "$script" --help > /dev/null 2>&1; then
        log_warning "$script_name: --help option failed"
        ((errors++))
    fi

    # Test -h option works
    if ! "$script" -h > /dev/null 2>&1; then
        log_warning "$script_name: -h option failed"
        ((errors++))
    fi

    # Check help text quality
    local help_output
    help_output=$("$script" --help 2>&1)

    # Check for required sections in help text
    local required_sections=("SYNOPSIS" "DESCRIPTION" "OPTIONS" "EXAMPLES")
    for section in "${required_sections[@]}"; do
        if ! echo "$help_output" | grep -q "$section"; then
            log_warning "$script_name: Help text missing required section: $section"
            ((errors++))
        fi
    done

    # Check help text is not empty
    if [ ${#help_output} -lt 100 ]; then
        log_warning "$script_name: Help text is too short (less than 100 characters)"
        ((errors++))
    fi

    # Check for proper error handling
    if ! grep -q "set -euo pipefail\|set -e" "$script"; then
        log_warning "$script_name: Script may lack proper error handling"
    fi

    if [ $errors -eq 0 ]; then
        return 0
    else
        return $errors
    fi
}

# Main shell quality check function
main() {
    # Get list of files to check (if any provided)
    local files_to_check=("$@")
    local shell_files=()

    if [ ${#files_to_check[@]} -eq 0 ]; then
        log_info "🐚 Running shell script quality checks on all files..."
        # Find and check all shell scripts (excluding build directories)
        local exclude_dirs=(".venv" "node_modules" ".git" "build" "dist")
        while IFS= read -r -d '' file; do
            shell_files+=("$file")
        done < <(find_files_exclude "*.sh" "${exclude_dirs[@]}")
    else
        log_info "🐚 Running shell script quality checks on specific files: ${files_to_check[*]}"
        # Filter to only shell scripts from the provided files
        for file in "${files_to_check[@]}"; do
            if [[ "$file" =~ \.(sh|bash)$ ]]; then
                shell_files+=("$file")
            fi
        done
    fi

    # Check if shellcheck is available
    if ! command -v shellcheck >/dev/null 2>&1; then
        log_warning "shellcheck not found, skipping shell linting"
        log_info "To install shellcheck:"
        log_info "  - Development: mise install (managed by mise.toml)"
        log_info "  - CI: Install via your CI environment"
        log_info "  - Manual: brew install shellcheck (macOS) or apt-get install shellcheck (Ubuntu)"
        exit 0
    fi

    if [ ${#shell_files[@]} -eq 0 ]; then
        log_warning "No shell scripts found to check"
        exit 0
    fi

    log_info "Found ${#shell_files[@]} shell script(s) to check"

    # Run shellcheck on all shell files
    local failed=0
    local failed_files=()

    # Temporarily disable exit on error to check all files
    set +e
    for file in "${shell_files[@]}"; do
        log_step "Checking $file..."
        if ! shellcheck --severity=warning "$file"; then
            log_warning "Shell script linting found issues in $file"
            failed_files+=("$file")
            ((failed++))
        fi
    done
    # Re-enable exit on error
    set -e

    # Validate script help options
    log_step "Validating script help options..."
    local help_failed=0
    local help_failed_files=()

    # Temporarily disable exit on error to check all files
    set +e
    for file in "${shell_files[@]}"; do
        log_step "Validating help options for $file..."
        if ! validate_script_help "$file"; then
            log_warning "Script help validation found issues in $file"
            help_failed_files+=("$file")
            ((help_failed++))
        fi
    done
    # Re-enable exit on error
    set -e

    # Combine results
    local total_failed=$((failed + help_failed))

    if [ $total_failed -eq 0 ]; then
        log_success "All shell scripts passed quality checks (shellcheck + help validation)"
        exit 0
    else
        log_warning "$total_failed shell script(s) had issues:"
        if [ $failed -gt 0 ]; then
            log_warning "Shellcheck issues:"
            for file in "${failed_files[@]}"; do
                log_warning "  - $file"
            done
        fi
        if [ $help_failed -gt 0 ]; then
            log_warning "Help validation issues:"
            for file in "${help_failed_files[@]}"; do
                log_warning "  - $file"
            done
        fi
        exit 1
    fi
}

main "$@"
