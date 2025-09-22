#!/bin/bash

# Test Docker Images Script
# Ensures all Docker images build and work correctly before CI

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

# Test function for Docker images
test_docker_image() {
    local image_name="$1"
    local image_tag="$2"
    local test_name="$3"

    log_info "Testing $test_name ($image_name:$image_tag)"

    # Test 1: Image builds successfully
    if ! docker build -t "$image_name:$image_tag" -f "docker/$test_name" \
        --build-arg GIT_SHA="test-build" \
        --build-arg VENDOR="Test Build" \
        . 2>&1; then
        log_error "Failed to build $test_name"
        return 1
    fi

    # Test 2: Image runs and shows help (skip for dev image)
    if [[ "$test_name" != "Dockerfile.dev" ]]; then
        if ! docker run --rm "$image_name:$image_tag" --help > /dev/null 2>&1; then
            log_error "Failed to run $test_name"
            return 1
        fi
    else
        # For dev image, just check that it can run bash
        if ! docker run --rm "$image_name:$image_tag" bash -c "echo 'Dev image working'" > /dev/null 2>&1; then
            log_error "Failed to run $test_name"
            return 1
        fi
    fi

    # Test 3: Check if /app/tmp directory exists and is writable
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
        log_error "Permission issue in $test_name - /app/tmp not accessible"
        return 1
    fi

    # Test 4: For dev image, check if development tools are available
    if [[ "$test_name" == "Dockerfile.dev" ]]; then
        if ! docker run --rm "$image_name:$image_tag" bash -c "
source /app/.venv/bin/activate
ruff --version > /dev/null && mypy --version > /dev/null && pytest --version > /dev/null
" > /dev/null 2>&1; then
            log_error "Development tools not available in $test_name"
            return 1
        fi
    fi

    log_success "$test_name passed all tests"
    return 0
}

# Main test function
main() {
    log_info "Starting Docker image tests..."

    local failed_tests=0

    # Test Alpine image
    if ! test_docker_image "ats-pdf-generator" "alpine" "Dockerfile.alpine"; then
        ((failed_tests++))
    fi

    # Test Standard image
    if ! test_docker_image "ats-pdf-generator" "standard" "Dockerfile.standard"; then
        ((failed_tests++))
    fi

    # Test Dev image
    if ! test_docker_image "ats-pdf-generator" "dev" "Dockerfile.dev"; then
        ((failed_tests++))
    fi

    # Summary
    if [ $failed_tests -eq 0 ]; then
        log_success "All Docker images passed tests!"
        exit 0
    else
        log_error "$failed_tests Docker image(s) failed tests"
        exit 1
    fi
}

# Run main function
main "$@"
