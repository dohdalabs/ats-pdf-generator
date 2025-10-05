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



# Source utilities
source "$SCRIPT_DIR/../utils/logging.sh"
source "$SCRIPT_DIR/../utils/ci.sh"
source "$SCRIPT_DIR/../utils/common.sh"

# Initialize logger
init_logger --format "%d [%l] %m"

# Main Markdown quality check function
main() {
    local fix_mode=false

    # Check for --fix argument
    if [ "${1:-}" = "--fix" ]; then
        fix_mode=true
        log_info "📝 Running Markdown formatting (fix mode)..."
    else
        log_info "📝 Running Markdown quality checks..."
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

    # Find all Markdown files (including .mdc files)
    local markdown_files=()
    while IFS= read -r -d '' file; do
        markdown_files+=("$file")
    done < <(find . \( -name "*.md" -o -name "*.mdc" \) -type f -print0)

    if [ ${#markdown_files[@]} -eq 0 ]; then
        log_warning "No Markdown files (.md or .mdc) found to check"
        exit 0
    fi

    log_info "Found ${#markdown_files[@]} Markdown file(s) (.md and .mdc) to check"

    # Run markdownlint on all Markdown files using pnpm dlx
    local failed=0
    local cmd_args=()

    # Add config file if it exists
    if [ -n "$config_file" ]; then
        log_step "Using config file: $config_file"
        cmd_args+=("--config=$config_file")
    fi

    # Add --fix flag if in fix mode
    if [ "$fix_mode" = true ]; then
        cmd_args+=("--fix")
    fi

    # Run markdownlint (--dot flag includes dot-directories like .cursor/)
    if ! pnpm dlx markdownlint-cli '**/*.{md,mdc}' --dot "${cmd_args[@]}"; then
        if [ "$fix_mode" = true ]; then
            log_warning "Markdown formatting completed with issues (non-fatal)"
        else
            log_warning "Markdown linting found issues (non-fatal)"
        fi
        ((failed++))
    fi

    if [ $failed -eq 0 ]; then
        log_success "All Markdown files passed quality checks"
    else
        log_warning "Markdown files had issues (non-fatal)"
    fi
}

main "$@"
