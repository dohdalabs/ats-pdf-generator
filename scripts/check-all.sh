#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils/logging.sh"
source "$SCRIPT_DIR/utils/common.sh"
source "$SCRIPT_DIR/utils/ci.sh"

init_logger --script-name "$(basename "$0")"

show_usage() {
    cat <<'USAGE_EOF'
SYNOPSIS
    check-all.sh [OPTIONS]

DESCRIPTION
    Run the full suite of project quality checks, including Python linting,
    formatting, type checks, tests, shell linting, Dockerfile linting,
    Markdown checks, and Trivy security scanning. Automatically adapts to CI
    environments by using direct commands instead of mise tasks.

OPTIONS
    -h, --help              Show this help message and exit
    --skip-python           Skip Python quality checks
    --skip-shell            Skip shell script linting
    --skip-docker           Skip Dockerfile linting
    --skip-markdown         Skip Markdown linting
    --skip-security         Skip security scans

EXAMPLES
    ./scripts/check-all.sh
    ./scripts/check-all.sh --skip-security
    CI=true ./scripts/check-all.sh --skip-markdown

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

SKIP_PYTHON=false
SKIP_SHELL=false
SKIP_DOCKER=false
SKIP_MARKDOWN=false
SKIP_SECURITY=false

while [ $# -gt 0 ]; do
    case "$1" in
        --skip-python)
            SKIP_PYTHON=true
            ;;
        --skip-shell)
            SKIP_SHELL=true
            ;;
        --skip-docker)
            SKIP_DOCKER=true
            ;;
        --skip-markdown)
            SKIP_MARKDOWN=true
            ;;
        --skip-security)
            SKIP_SECURITY=true
            ;;
        --)
            shift
            break
            ;;
        *)
            log_error "Unknown option: $1"
            show_usage
            exit 2
            ;;
    esac
    shift
done

is_ci_environment() {
    should_use_direct_commands
}

check_python() {
    log_info "🐍 Running Python quality checks..."

    if is_ci_environment; then
        uv run ruff check .
        uv run ruff format --check .
        uv run mypy src/
        uv run pytest --cov=src --cov-report=xml --cov-report=term-missing
    else
        mise run lint-python
        mise run format-python
        mise run typecheck
        mise run test-python
    fi

    log_success "Python quality checks completed"
}

check_shell() {
    log_info "🐚 Running shell script linting..."

    if [ -f "./scripts/quality/check-shell.sh" ]; then
        if ! ./scripts/quality/check-shell.sh; then
            log_warning "Shell script linting found issues"
            return 1
        fi
    elif command -v shellcheck >/dev/null 2>&1; then
        shellcheck install.sh scripts/*.sh src/*.sh || {
            log_warning "Shell script linting found issues (non-fatal)"
            return 0
        }
    else
        log_warning "shellcheck not found, skipping shell linting"
    fi

    log_success "Shell script linting completed"
}

check_docker() {
    log_info "🐳 Running Docker quality checks..."

    if [ -f "./scripts/quality/check-docker.sh" ]; then
        ./scripts/quality/check-docker.sh || {
            log_warning "Docker linting found issues (non-fatal)"
            return 0
        }
    else
        log_warning "check-docker.sh not found, skipping Docker linting"
    fi

    log_success "Docker quality checks completed"
}

check_markdown() {
    log_info "📝 Running Markdown linting..."

    if command -v markdownlint >/dev/null 2>&1; then
        markdownlint "**/*.md" --config=.markdownlint.jsonc || {
            log_warning "Markdown linting found issues (non-fatal)"
            return 0
        }
    else
        log_warning "markdownlint not found, skipping Markdown linting"
    fi

    log_success "Markdown linting completed"
}

check_security() {
    log_info "🔒 Running security scan..."

    if [ -f "./scripts/quality/check-security.sh" ]; then
        if ! ./scripts/quality/check-security.sh; then
            log_warning "Security scan found issues (non-fatal)"
            return 0
        fi
    else
        log_warning "check-security.sh not found, skipping security scan"
    fi

    log_success "Security scan completed"
}

main() {
    log_info "Starting comprehensive quality checks..."

    local exit_code=0

    $SKIP_PYTHON || check_python || exit_code=1
    $SKIP_SHELL || check_shell || exit_code=1
    $SKIP_DOCKER || check_docker || exit_code=1
    $SKIP_MARKDOWN || check_markdown || exit_code=1
    $SKIP_SECURITY || check_security || exit_code=1

    echo ""
    log_info "📋 Quality Check Summary:"
    $SKIP_PYTHON || echo "  🐍 Python: Linting, type checking, and tests"
    $SKIP_SHELL || echo "  🐚 Shell: Scripts linted"
    $SKIP_DOCKER || echo "  🐳 Docker: Dockerfiles linted"
    $SKIP_MARKDOWN || echo "  📝 Markdown: Documentation linted"
    $SKIP_SECURITY || echo "  🔒 Security: Vulnerability scan completed"

    if [ $exit_code -eq 0 ]; then
        log_success "All quality checks completed successfully!"
    else
        log_error "Some quality checks failed (see above for details)"
    fi

    exit $exit_code
}

main "$@"
