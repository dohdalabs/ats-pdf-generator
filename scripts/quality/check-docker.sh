#!/usr/bin/env bash

# check-docker.sh
# Docker quality checks using hadolint

set -euo pipefail

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source utilities
source "$SCRIPT_DIR/../utils/logging.sh"
source "$SCRIPT_DIR/../utils/ci.sh"
source "$SCRIPT_DIR/../utils/common.sh"

# Initialize logger
init_logger --format "%d [%l] %m"

# Main Docker quality check function
main() {
    log_info "🐳 Running Docker quality checks..."

    # Check if hadolint is available
    if ! command -v hadolint >/dev/null 2>&1; then
        log_warning "hadolint not found, skipping Docker linting"
        log_info "To install hadolint:"
        log_info "  - Development: mise install (managed by mise.toml)"
        log_info "  - CI: Install via your CI environment"
        log_info "  - Manual: brew install hadolint (macOS) or download from GitHub releases"
        exit 0
    fi

    log_step "Running hadolint on Dockerfiles..."

    # Find all Dockerfiles
    local dockerfiles=()
    while IFS= read -r -d '' file; do
        dockerfiles+=("$file")
    done < <(find . -name "Dockerfile*" -type f -print0)

    if [ ${#dockerfiles[@]} -eq 0 ]; then
        log_warning "No Dockerfiles found to check"
        exit 0
    fi

    log_info "Found ${#dockerfiles[@]} Dockerfile(s) to check"

    # Run hadolint on all Dockerfiles
    local failed=0
    for dockerfile in "${dockerfiles[@]}"; do
        log_step "Checking $dockerfile..."
        if ! hadolint --ignore DL3008 --ignore DL3018 "$dockerfile"; then
            log_warning "Docker linting found issues in $dockerfile (non-fatal)"
            ((failed++))
        fi
    done

    if [ $failed -eq 0 ]; then
        log_success "All Dockerfiles passed quality checks"
    else
        log_warning "$failed Dockerfile(s) had issues (non-fatal)"
    fi
}

main "$@"
