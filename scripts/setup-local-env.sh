#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils/logging.sh"
source "$SCRIPT_DIR/utils/common.sh"

init_logger --script-name "$(basename "$0")"

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

SKIP_PRE_COMMIT=false

while [ $# -gt 0 ]; do
    case "$1" in
        --skip-pre-commit)
            SKIP_PRE_COMMIT=true
            ;;
        --)
            shift
            break
            ;;
        -*)
            log_error "Unknown option: $1"
            show_usage
            exit 2
            ;;
        *)
            log_error "Unexpected argument: $1"
            show_usage
            exit 2
            ;;
    esac
    shift
done

if [ $# -gt 0 ]; then
    log_error "Unexpected positional arguments: $*"
    exit 2
fi

log_info "🚀 Setting up development environment..."

python_version=$(python3 --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
required_version="3.13"

if [ "$(printf '%s\n' "$required_version" "$python_version" | sort -V | head -n1)" != "$required_version" ]; then
    log_error "Python 3.13+ is required. Found: $python_version"
    log_info "Consider using mise: curl https://mise.run | sh"
    exit 1
fi

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
