#!/usr/bin/env bash

# check-markdown.sh
# ----------------------------------------
# Markdown Quality & Formatting Script
#
# This script runs markdownlint on all Markdown files (.md and .mdc) in the project
# to check for style and formatting issues. It is intended to be used
# as part of your local development workflow or in CI to ensure
# consistent Markdown quality across the codebase.
#
# Usage:
#   ./scripts/quality/check-markdown.sh         # Lint Markdown files
#   ./scripts/quality/check-markdown.sh --fix   # Auto-fix formatting issues
#
# Requirements:
#   - Node.js and pnpm must be installed (see mise.toml for managed setup)
#   - markdownlint is installed via pnpm
#
# This script is invoked by pre-commit and can be run manually.
# ----------------------------------------

set -euo pipefail

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to show usage
show_usage() {
    cat << 'USAGE_EOF'
SYNOPSIS
    check-markdown.sh [OPTIONS]

DESCRIPTION
    Markdown Quality & Formatting Script for ATS PDF Generator.
    This script runs markdownlint on all Markdown files (.md and .mdc) in the project
    to check for style and formatting issues. It is intended to be used
    as part of your local development workflow or in CI to ensure
    consistent Markdown quality across the codebase.

OPTIONS
    -h, --help              Show this help message and exit
    --fix                   Auto-fix formatting issues where possible

EXAMPLES
    # Lint Markdown files
    ./scripts/quality/check-markdown.sh

    # Auto-fix formatting issues
    ./scripts/quality/check-markdown.sh --fix

    # Show help
    ./scripts/quality/check-markdown.sh --help

Requirements:
    - Node.js and pnpm must be installed (see mise.toml for managed setup)
    - markdownlint is installed via pnpm

For more information: https://github.com/dohdalabs/ats-pdf-generator
USAGE_EOF
}

# Source utilities
source "$SCRIPT_DIR/../utils/logging.sh"
source "$SCRIPT_DIR/../utils/ci.sh"
source "$SCRIPT_DIR/../utils/common.sh"

if ! parse_common_flags "$@"; then
    show_usage
    exit 2
fi

if [ ${#COMMON_FLAGS_REMAINING[@]} -gt 0 ]; then
    set -- "${COMMON_FLAGS_REMAINING[@]}"
else
    set --
fi

if [ "$COMMON_FLAG_SHOW_HELP" = true ]; then
    show_usage
    exit 0
fi

# Initialize logger
init_logger --script-name "$(basename "$0")"

# Main Markdown quality check function
main() {
    local fix_mode=false
    local files_to_check=()

    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --fix)
                fix_mode=true
                shift
                ;;
            --)
                shift
                while [ $# -gt 0 ]; do
                    files_to_check+=("$1")
                    shift
                done
                break
                ;;
            -*)
                log_error "Unknown option: $1"
                show_usage
                exit 2
                ;;
            *)
                files_to_check+=("$1")
                shift
                ;;
        esac
    done

    local checking_specific=true
    if [ ${#files_to_check[@]} -eq 0 ]; then
        checking_specific=false
        files_to_check=("**/*.md" "**/*.mdc")
    fi

    if [ "$checking_specific" = false ]; then
        if [ "$fix_mode" = true ]; then
            log_info "📝 Running Markdown formatting (fix mode) on all files..."
        else
            log_info "📝 Running Markdown quality checks on all files..."
        fi
    else
        if [ "$fix_mode" = true ]; then
            log_info "📝 Running Markdown formatting (fix mode) on specific files: ${files_to_check[*]}"
        else
            log_info "📝 Running Markdown quality checks on specific files: ${files_to_check[*]}"
        fi
    fi

    # Check if pnpm is available (for markdownlint-cli)
    if ! command -v pnpm >/dev/null 2>&1; then
        log_warning "pnpm not found, skipping Markdown linting"
        log_info "To install Node.js and pnpm:"
        log_info "  - Development: mise install (managed by mise.toml)"
        log_info "  - CI: Install Node.js and pnpm in your CI environment"
        log_info "  - Manual: Install Node.js from https://nodejs.org/ and pnpm from https://pnpm.io/"
        exit 0
    fi

    log_step "Running markdownlint on Markdown files..."

    # Check if markdownlint config exists
    local config_file=".markdownlint.jsonc"
    if [ ! -f "$config_file" ]; then
        log_warning "Markdownlint config file not found: $config_file"
        log_info "Running markdownlint without config file"
        config_file=""
    fi

    # Use provided files or find all Markdown files
    local markdown_files=()
    if [ "$checking_specific" = false ]; then
        # Find all Markdown files (including .mdc files), excluding node_modules and other build directories
        while IFS= read -r -d '' file; do
            markdown_files+=("$file")
        done < <(find . \( -name "*.md" -o -name "*.mdc" \) -type f -not -path "./node_modules/*" -not -path "./.git/*" -not -path "./.venv/*" -not -path "./htmlcov/*" -not -path "./tmp/*" -print0)
    else
        # Use provided files, filtering for markdown files
        for file in "${files_to_check[@]}"; do
            if [[ "$file" =~ \.(md|mdc)$ ]]; then
                markdown_files+=("$file")
            fi
        done
    fi

    if [ ${#markdown_files[@]} -eq 0 ]; then
        log_warning "No Markdown files (.md or .mdc) found to check"
        exit 0
    fi

    log_info "Found ${#markdown_files[@]} Markdown file(s) (.md and .mdc) to check"

    # Run markdownlint on all Markdown files using pnpm dlx
    local failed=0
    local cmd_args=()
    local ignore_args=()

    # Only include --dot when scanning entire repo (not needed for explicit files)
    if [ "$checking_specific" = false ]; then
        cmd_args+=("--dot")
    fi

    # Add config file if it exists
    if [ -n "$config_file" ]; then
        log_step "Using config file: $config_file"
        cmd_args+=("--config=$config_file")
    fi

    # Add --fix flag if in fix mode
    if [ "$fix_mode" = true ]; then
        cmd_args+=("--fix")
    fi

    # When checking specific files, bypass .markdownlintignore (which may ignore tmp/)
    if [ "$checking_specific" = true ]; then
        ignore_args+=("--ignore-path" "/dev/null")
    fi

    # Determine execution mode based on --fix (stdin not supported with --fix)
    if [ "$fix_mode" = true ]; then
        for file in "${markdown_files[@]}"; do
            log_info "Formatting $file..."
            if ! pnpm exec markdownlint "${ignore_args[@]}" "${cmd_args[@]}" "$file" >/dev/null 2>&1; then
                log_warning "Markdown formatting completed with issues (non-fatal)"
                failed=1
            fi
        done
    else
        for file in "${markdown_files[@]}"; do
            log_info "Checking $file..."
            if ! pnpm exec markdownlint "${ignore_args[@]}" "${cmd_args[@]}" "$file" >/dev/null 2>&1; then
                log_warning "Markdown linting found issues (non-fatal)"
                failed=1
            fi
        done
    fi

    if [ $failed -eq 0 ]; then
        log_success "All Markdown files passed quality checks"
    else
        log_warning "Markdown files had issues (non-fatal)"
    fi
}

main "$@"
