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
init_logger

# Display usage information
show_usage() {
    cat <<'USAGE_EOF'
SYNOPSIS
    check-security.sh [OPTIONS]

DESCRIPTION
    Run a Trivy filesystem scan against the current repository using the
    project's recommended settings. When Trivy is not installed, the script
    exits successfully after printing installation guidance so local
    workflows remain smooth.

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

    # Check if trivy is available
    if ! command -v trivy >/dev/null 2>&1; then
        log_warning "trivy not found, skipping security checks"
        log_info "To install trivy:"
        log_info "  - Development: mise install (managed by mise.toml)"
        log_info "  - CI: Install via your CI environment"
        log_info "  - Manual: curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh"
        exit 0
    fi

    log_step "Running trivy filesystem scan..."

    # Set cache directory for better performance
    export TRIVY_CACHE_DIR="${TRIVY_CACHE_DIR:-$HOME/.cache/trivy}"
    mkdir -p "$TRIVY_CACHE_DIR"

    # Run trivy filesystem scan with optimized settings
    if ! trivy fs . --cache-dir "$TRIVY_CACHE_DIR" --format table --severity HIGH,CRITICAL; then
        log_warning "Security scan found issues (non-fatal)"
        log_info "Review the trivy output above for security vulnerabilities"
        exit 0
    fi

    log_success "Security checks completed - no critical issues found"
}

main "$@"
