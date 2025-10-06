#!/usr/bin/env bash

# check-python.sh
#
# Runs all Python quality checks for the project, including:
#   - Linting (ruff)
#   - Code formatting (ruff format)
#   - Type checking (mypy)
#   - Testing (pytest with coverage)
#
# Usage:
#   ./scripts/quality/check-python.sh
#
# Intended for both local development and CI environments.
# - Locally, uses mise tasks for consistency with project tooling.
# - In CI, runs commands directly for detailed error output.
#
# Prerequisites:
#   - Python virtual environment must be set up with 'uv sync'
#   - All dependencies installed via 'uv'
#   - Recommended: Use 'mise' to manage Python version and tools

set -euo pipefail

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to show usage
show_usage() {
    cat << 'USAGE_EOF'
SYNOPSIS
    check-python.sh [OPTIONS]

DESCRIPTION
    Python Quality Check Script for ATS PDF Generator.
    This script runs all Python quality checks for the project, including:
    - Linting (ruff)
    - Code formatting (ruff format)
    - Type checking (mypy)
    - Testing (pytest with coverage)

OPTIONS
    -h, --help              Show this help message and exit

EXAMPLES
    # Run all Python quality checks
    ./scripts/quality/check-python.sh

    # Show help
    ./scripts/quality/check-python.sh --help

Requirements:
    - Python virtual environment must be set up with 'uv sync'
    - All dependencies installed via 'uv'
    - Recommended: Use 'mise' to manage Python version and tools

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
init_logger --script-name "$(basename "$0")"

# Main Python quality check function
main() {
    # Get list of files to check (if any provided)
    local files_to_check=("$@")

    if [ ${#files_to_check[@]} -eq 0 ]; then
        log_info "🐍 Running Python quality checks on all files..."
        files_to_check=(".")
    else
        log_info "🐍 Running Python quality checks on specific files: ${files_to_check[*]}"
    fi

    # Check if UV is available
    if ! command -v uv >/dev/null 2>&1; then
        log_error "UV not found. Please install UV or run 'mise install'"
        exit 1
    fi

    # Check if virtual environment exists
    if [ ! -d ".venv" ]; then
        log_error "Virtual environment not found. Please run 'uv sync' first"
        exit 1
    fi

    if is_ci; then
        # In CI, use direct commands for better error reporting
        log_step "Running ruff linting..."
        uv run ruff check "${files_to_check[@]}"

        log_step "Checking code formatting..."
        uv run ruff format --check "${files_to_check[@]}"

        # For type checking and tests, we still run on the whole project
        # as they need the full context
        log_step "Running type checking..."
        uv run mypy src/

        log_step "Running tests..."
        uv run pytest --cov=src --cov-report=xml --cov-report=term-missing
    else
        # Local development, use mise tasks
        log_step "Running linting via mise..."
        mise run lint-python

        log_step "Checking formatting via mise..."
        mise run format-python

        log_step "Running type checking via mise..."
        mise run typecheck

        log_step "Running tests via mise..."
        mise run test
    fi

    log_success "Python quality checks completed"
}

main "$@"
