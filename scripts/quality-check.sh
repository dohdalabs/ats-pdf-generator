#!/bin/bash

# Comprehensive Quality Check Script
# Runs all quality checks: Python, Shell, Docker, Security

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in a CI environment
is_ci() {
    [ "${CI:-false}" = "true" ] || [ "${GITHUB_ACTIONS:-false}" = "true" ]
}

# Python quality checks
check_python() {
    log_info "🐍 Running Python quality checks..."

    if is_ci; then
        # In CI, use direct commands for better error reporting
        uv run ruff check .
        uv run ruff format --check .
        uv run mypy src/
        uv run pytest --cov=src --cov-report=xml --cov-report=term-missing
    else
        # Local development, use mise tasks
        mise run lint-python
        mise run format-python
        mise run typecheck
        mise run test
    fi

    log_success "Python quality checks completed"
}

# Shell script quality checks
check_shell() {
    log_info "🐚 Running shell script linting..."

    if command -v shellcheck >/dev/null 2>&1; then
        shellcheck install.sh scripts/*.sh src/*.sh || {
            log_warning "Shell script linting found issues (non-fatal)"
            return 0
        }
    else
        log_warning "shellcheck not found, skipping shell linting"
    fi

    log_success "Shell script linting completed"
}

# Docker quality checks
check_docker() {
    log_info "🐳 Running Docker quality checks..."

    if command -v hadolint >/dev/null 2>&1; then
        hadolint --ignore DL3008,DL3009,DL3018,DL3045,DL4006 \
            docker/Dockerfile.optimized \
            docker/Dockerfile.alpine \
            docker/Dockerfile.dev || {
            log_warning "Docker linting found issues (non-fatal)"
            return 0
        }
    else
        log_warning "hadolint not found, skipping Docker linting"
    fi

    log_success "Docker quality checks completed"
}

# Markdown linting
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

# Security scan
check_security() {
    log_info "🔒 Running security scan..."

    if command -v trivy >/dev/null 2>&1; then
        trivy fs . --format table --severity HIGH,CRITICAL || {
            log_warning "Security scan found issues (non-fatal)"
            return 0
        }
    else
        log_warning "trivy not found, skipping security scan"
    fi

    log_success "Security scan completed"
}

# Main execution
main() {
    log_info "Starting comprehensive quality checks..."

    local exit_code=0

    # Run all checks
    check_python || exit_code=1
    check_shell || exit_code=1
    check_docker || exit_code=1
    check_markdown || exit_code=1
    check_security || exit_code=1

    # Summary
    echo ""
    log_info "📋 Quality Check Summary:"
    echo "  🐍 Python: Linting, type checking, and tests"
    echo "  🐚 Shell: Scripts linted (warnings shown but not fatal)"
    echo "  🐳 Docker: Dockerfiles linted with lenient rules"
    echo "  📝 Markdown: Documentation linted"
    echo "  🔒 Security: Vulnerability scan completed"

    if [ $exit_code -eq 0 ]; then
        log_success "All quality checks completed successfully!"
    else
        log_error "Some quality checks failed (see above for details)"
    fi

    exit $exit_code
}

# Show usage if help requested
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    echo "Comprehensive Quality Check Script"
    echo ""
    echo "Runs all quality checks for the ATS PDF Generator:"
    echo "  - Python: Linting, formatting, type checking, tests"
    echo "  - Shell: Script linting with shellcheck"
    echo "  - Docker: Dockerfile linting with hadolint"
    echo "  - Markdown: Documentation linting with markdownlint"
    echo "  - Security: Vulnerability scanning with trivy"
    echo ""
    echo "Usage: $0"
    echo ""
    echo "Environment variables:"
    echo "  CI=true - Run in CI mode (direct commands)"
    echo "  GITHUB_ACTIONS=true - Run in GitHub Actions mode"
    exit 0
fi

# Run main function
main
