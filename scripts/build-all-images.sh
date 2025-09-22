#!/bin/bash

# Build All Images Script
# Builds all Docker images using the simplified Dockerfiles

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

# Function to build a Docker image
build_image() {
    local dockerfile="$1"
    local image_name="$2"
    local image_tag="$3"

    log_info "Building $image_name:$image_tag from $dockerfile"

    # Get git SHA for build argument
    local git_sha
    git_sha=$(git rev-parse HEAD 2>/dev/null || echo "unknown")

    if docker build \
        --build-arg GIT_SHA="$git_sha" \
        --build-arg VENDOR="DohDa Labs" \
        -f "$dockerfile" \
        -t "$image_name:$image_tag" . > /dev/null 2>&1; then
        log_success "Successfully built $image_name:$image_tag"
        return 0
    else
        log_error "Failed to build $image_name:$image_tag"
        return 1
    fi
}

# Function to test a Docker image
test_image() {
    local image_name="$1"
    local image_tag="$2"

    log_info "Testing $image_name:$image_tag"

    # Test 1: Image runs and shows help
    if [[ "$image_tag" != "dev" ]]; then
        if ! docker run --rm "$image_name:$image_tag" --help > /dev/null 2>&1; then
            log_error "Failed to run $image_name:$image_tag"
            return 1
        fi
    else
        # For dev image, just check that it can run bash
        if ! docker run --rm "$image_name:$image_tag" bash -c "echo 'Dev image working'" > /dev/null 2>&1; then
            log_error "Failed to run $image_name:$image_tag"
            return 1
        fi
    fi

    # Test 2: Check if /app/tmp directory exists and is writable
    if ! docker run --rm --entrypoint="" "$image_name:$image_tag" python3 -c "
import os
import tempfile
tmp_dir = '/app/tmp'
if not os.path.exists(tmp_dir):
    print('ERROR: /app/tmp does not exist')
    exit(1)
if not os.access(tmp_dir, os.W_OK):
    print('ERROR: /app/tmp is not writable')
    exit(1)
print('SUCCESS: /app/tmp exists and is writable')
" > /dev/null 2>&1; then
        log_error "Permission issue in $image_name:$image_tag - /app/tmp not accessible"
        return 1
    fi

    log_success "All tests passed for $image_name:$image_tag"
    return 0
}

# Main execution
main() {
    log_info "Starting Docker image build and test process..."

    local failed_builds=()
    local failed_tests=()

    # Build and test Alpine image
    if build_image "docker/Dockerfile.alpine" "ats-pdf-generator" "alpine"; then
        if ! test_image "ats-pdf-generator" "alpine"; then
            failed_tests+=("alpine")
        fi
    else
        failed_builds+=("alpine")
    fi

    # Build and test Standard image
    if build_image "docker/Dockerfile.standard" "ats-pdf-generator" "standard"; then
        if ! test_image "ats-pdf-generator" "standard"; then
            failed_tests+=("standard")
        fi
    else
        failed_builds+=("standard")
    fi

    # Build and test Dev image
    if build_image "docker/Dockerfile.dev" "ats-pdf-generator" "dev"; then
        if ! test_image "ats-pdf-generator" "dev"; then
            failed_tests+=("dev")
        fi
    else
        failed_builds+=("dev")
    fi

    # Summary
    echo
    if [ ${#failed_builds[@]} -eq 0 ] && [ ${#failed_tests[@]} -eq 0 ]; then
        log_success "All Docker images built and tested successfully!"
        log_info "Available images:"
        log_info "  - ats-pdf-generator:alpine (ultra-minimal)"
        log_info "  - ats-pdf-generator:optimized (Debian slim)"
        log_info "  - ats-pdf-generator:dev (development tools)"
        return 0
    else
        log_error "Some builds or tests failed:"
        if [ ${#failed_builds[@]} -gt 0 ]; then
            log_error "  Failed builds: ${failed_builds[*]}"
        fi
        if [ ${#failed_tests[@]} -gt 0 ]; then
            log_error "  Failed tests: ${failed_tests[*]}"
        fi
        return 1
    fi
}

# Run main function
main "$@"
