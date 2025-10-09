#!/bin/bash
set -euo pipefail

# Simple logging functions
log_info() {
    echo "INFO: $*"
}

log_error() {
    echo "ERROR: $*" >&2
}

log_success() {
    echo "SUCCESS: $*"
}

show_usage() {
    cat <<'USAGE_EOF'
SYNOPSIS
    setup-local-env.sh [OPTIONS]

DESCRIPTION
    Prepare a local development environment without relying on mise. The
    script verifies Python, installs uv, creates a virtual environment, syncs
    dependencies, and installs pre-commit hooks.

OPTIONS
    -h, --help              Show this help message and exit
    --skip-pre-commit       Skip installing pre-commit hooks

EXAMPLES
    ./scripts/setup-local-env.sh
    ./scripts/setup-local-env.sh --skip-pre-commit

For more information: https://github.com/dohdalabs/ats-pdf-generator
USAGE_EOF
}

ensure_timeout_available() {
    if command -v timeout >/dev/null 2>&1 || command -v gtimeout >/dev/null 2>&1; then
        return
    fi

    if [ "$(uname -s)" = "Darwin" ]; then
        if command -v brew >/dev/null 2>&1; then
            log_info "Installing coreutils (provides gtimeout)..."
            brew install coreutils
        else
            log_error "GNU timeout (coreutils) not found and Homebrew is unavailable. Install Homebrew from https://brew.sh and rerun."
            exit 1
        fi
    else
        log_error "GNU timeout (coreutils) not found. Install via your package manager (e.g., 'sudo apt install coreutils')."
        exit 1
    fi

    if ! command -v timeout >/dev/null 2>&1 && ! command -v gtimeout >/dev/null 2>&1; then
        log_error "GNU timeout installation failed. Install manually and rerun."
        exit 1
    fi
}

# Parse command line arguments
SHOW_HELP=false
SKIP_PRE_COMMIT=false
ARGS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            SHOW_HELP=true
            shift
            ;;
        --skip-pre-commit)
            SKIP_PRE_COMMIT=true
            shift
            ;;
        *)
            ARGS+=("$1")
            shift
            ;;
    esac
done

if [ "$SHOW_HELP" = true ]; then
    show_usage
    exit 0
fi

# Set remaining arguments
set -- "${ARGS[@]}"

log_info "🚀 Setting up development environment..."

python_version=$(python3 --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
required_version="3.13"

if [ "$(printf '%s\n' "$required_version" "$python_version" | sort -V | head -n1)" != "$required_version" ]; then
    log_error "Python 3.13+ is required. Found: $python_version"
    log_info "Consider using mise: curl https://mise.run | sh"
    exit 1
fi

ensure_timeout_available

if ! command -v uv >/dev/null 2>&1; then
    log_info "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    # shellcheck source=/dev/null
    source ~/.bashrc 2>/dev/null || source ~/.zshrc 2>/dev/null || true
fi

log_info "Installing dependencies..."
uv venv
# shellcheck source=/dev/null
source .venv/bin/activate
uv sync

if ! $SKIP_PRE_COMMIT; then
    log_info "Setting up pre-commit hooks..."
    pre-commit install
    pre-commit install --hook-type commit-msg
else
    log_warning "Skipping pre-commit installation"
fi

log_success "Development environment setup complete"
log_info ""
log_info "Available commands:"
log_info "  ruff check .                    # Run linting"
log_info "  ruff format .                   # Format code"
log_info "  mypy src/                       # Run type checking"
log_info "  pytest                          # Run tests"
log_info "  pre-commit run --all-files      # Run all pre-commit hooks"
log_info ""
log_info "Remember to activate the virtual environment:"
log_info "  source .venv/bin/activate"
