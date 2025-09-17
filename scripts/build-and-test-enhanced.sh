#!/bin/bash

# Enhanced Build and Test Script
# Supports both legacy and new Dockerfiles during transition

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

# Function to test if a file exists
file_exists() {
    [ -f "$1" ]
}

# Function to build and test Docker images
build_and_test_images() {
    local dockerfiles=("$@")
    local all_passed=true

    for dockerfile in "${dockerfiles[@]}"; do
        if file_exists "$dockerfile"; then
            local image_name="ats-pdf-generator"
            local tag
            tag=$(basename "$dockerfile" | sed 's/Dockerfile\.//' | sed 's/\.new$//')

            log_info "Building and testing $dockerfile"

            # Build the image
            if docker build -f "$dockerfile" -t "$image_name:$tag" . > /dev/null 2>&1; then
                log_success "Successfully built $image_name:$tag"

                # Test the image
                if [[ "$tag" == "dev" || "$tag" == "dev-new" ]]; then
                    # Test dev image
                    if docker run --rm "$image_name:$tag" bash -c "echo 'Dev image working'" > /dev/null 2>&1; then
                        log_success "Dev image test passed"
                    else
                        log_error "Dev image test failed"
                        all_passed=false
                    fi
                else
                    # Test production images
                    if docker run --rm "$image_name:$tag" --help > /dev/null 2>&1; then
                        log_success "Production image test passed"
                    else
                        log_error "Production image test failed"
                        all_passed=false
                    fi
                fi

                # Test /app/tmp directory
                if docker run --rm --entrypoint="" "$image_name:$tag" python3 -c "
import os
tmp_dir = '/app/tmp'
if not os.path.exists(tmp_dir):
    print('ERROR: /app/tmp does not exist')
    exit(1)
if not os.access(tmp_dir, os.W_OK):
    print('ERROR: /app/tmp is not writable')
    exit(1)
print('SUCCESS: /app/tmp exists and is writable')
" > /dev/null 2>&1; then
                    log_success "Permission test passed for $tag"
                else
                    log_error "Permission test failed for $tag"
                    all_passed=false
                fi
            else
                log_error "Failed to build $image_name:$tag"
                all_passed=false
            fi
        else
            log_warning "Dockerfile not found: $dockerfile"
        fi
    done

    if [ "$all_passed" = true ]; then
        return 0
    else
        return 1
    fi
}

# Main execution
main() {
    log_info "Starting enhanced build and test process..."

    # Check for new Dockerfiles first
    local new_dockerfiles=()
    local legacy_dockerfiles=()

    if file_exists "docker/Dockerfile.alpine.new"; then
        new_dockerfiles+=("docker/Dockerfile.alpine.new")
    fi

    if file_exists "docker/Dockerfile.optimized.new"; then
        new_dockerfiles+=("docker/Dockerfile.optimized.new")
    fi

    if file_exists "docker/Dockerfile.dev.new"; then
        new_dockerfiles+=("docker/Dockerfile.dev.new")
    fi

    # Check for legacy Dockerfiles
    if file_exists "docker/Dockerfile.alpine"; then
        legacy_dockerfiles+=("docker/Dockerfile.alpine")
    fi

    if file_exists "docker/Dockerfile.optimized"; then
        legacy_dockerfiles+=("docker/Dockerfile.optimized")
    fi

    if file_exists "docker/Dockerfile.dev"; then
        legacy_dockerfiles+=("docker/Dockerfile.dev")
    fi

    # Build and test new Dockerfiles if available
    if [ ${#new_dockerfiles[@]} -gt 0 ]; then
        log_info "Testing new Dockerfiles..."
        if build_and_test_images "${new_dockerfiles[@]}"; then
            log_success "All new Dockerfiles passed tests"
        else
            log_error "Some new Dockerfiles failed tests"
            exit 1
        fi
    fi

    # Build and test legacy Dockerfiles if available
    if [ ${#legacy_dockerfiles[@]} -gt 0 ]; then
        log_info "Testing legacy Dockerfiles..."
        if build_and_test_images "${legacy_dockerfiles[@]}"; then
            log_success "All legacy Dockerfiles passed tests"
        else
            log_error "Some legacy Dockerfiles failed tests"
            exit 1
        fi
    fi

    # Run the original build-and-test.sh for compatibility
    if file_exists "scripts/build-and-test.sh"; then
        log_info "Running legacy build-and-test.sh for compatibility..."
        if ./scripts/build-and-test.sh; then
            log_success "Legacy build-and-test.sh completed successfully"
        else
            log_error "Legacy build-and-test.sh failed"
            exit 1
        fi
    fi

    log_success "Enhanced build and test process completed successfully!"
}

# Run main function
main "$@"
