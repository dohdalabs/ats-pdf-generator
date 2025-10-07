#!/usr/bin/env bash

# check-security.sh
# Security checks using trivy

set -euo pipefail

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source utilities
source "$SCRIPT_DIR/../utils/logging.sh"
source "$SCRIPT_DIR/../utils/ci.sh"
source "$SCRIPT_DIR/../utils/common.sh"

# Initialize logger
init_logger --script-name "$(basename "$0")"

# Display usage information
show_usage() {
    cat <<'USAGE_EOF'
SYNOPSIS
    check-security.sh [OPTIONS]

DESCRIPTION
    Run a Trivy filesystem scan against the current repository using the
    project's recommended settings. Uses Docker for local development and
    direct binary for CI environments.

OPTIONS
    -h, --help              Show this help message and exit

EXAMPLES
    ./scripts/quality/check-security.sh
    ./scripts/quality/check-security.sh --help

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

# Main security check function
main() {
    log_info "🔒 Running security checks..."

    if is_ci; then
        # In CI, use direct trivy binary (should be installed by CI)
        if ! command -v trivy >/dev/null 2>&1; then
            log_error "trivy not found in CI environment"
            exit 1
        fi

        log_step "Running trivy filesystem scan (CI mode)..."

        # Set cache directory for better performance
        export TRIVY_CACHE_DIR="${TRIVY_CACHE_DIR:-$HOME/.cache/trivy}"
        mkdir -p "$TRIVY_CACHE_DIR"

        # Run trivy filesystem scan with optimized settings (include dev dependencies)
        if ! trivy fs . --cache-dir "$TRIVY_CACHE_DIR" --format table --severity HIGH,CRITICAL --include-dev-deps; then
            log_error "Security scan found HIGH/CRITICAL vulnerabilities"
            log_info "Review the trivy output above for security vulnerabilities"
            exit 1
        fi
    else
        # Local development, use Docker
        log_step "Running trivy filesystem scan (Docker mode)..."

        # Check if Docker is available
        if ! command -v docker >/dev/null 2>&1; then
            log_warning "Docker not found, skipping security checks"
            log_info "To run security checks locally:"
            log_info "  - Install Docker: https://docs.docker.com/get-docker/"
            log_info "  - Or install trivy directly: curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh"
            exit 0
        fi

        # Run trivy via Docker with volume mounting for cache (include dev dependencies)
        if ! docker run --rm \
            -v "$(pwd):/workspace" \
            -v "$HOME/.cache/trivy:/root/.cache/trivy" \
            -w /workspace \
            aquasec/trivy:0.67.0 \
            fs . --format table --severity HIGH,CRITICAL --include-dev-deps; then
            log_error "Security scan found HIGH/CRITICAL vulnerabilities"
            log_info "Review the trivy output above for security vulnerabilities"
            exit 1
        fi
    fi

    log_success "Security checks completed - no critical issues found"
}

main "$@"
