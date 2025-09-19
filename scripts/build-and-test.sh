#!/bin/bash

# Build and Test Script
# Builds and tests Docker images using the new architecture

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
            tag=$(basename "$dockerfile" | sed 's/Dockerfile\.//')

            log_info "Building and testing $dockerfile"

            # Get git SHA for build argument
            local git_sha
            git_sha=$(git rev-parse HEAD 2>/dev/null || echo "unknown")

            # Build the image
            if docker build \
                --build-arg GIT_SHA="$git_sha" \
                --build-arg VENDOR="DohDa Labs" \
                -f "$dockerfile" \
                -t "$image_name:$tag" . > /dev/null 2>&1; then
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
    log_info "Starting build and test process..."

    # Array to store Dockerfile paths
    local dockerfiles=()

    # Check for Dockerfiles
    if file_exists "docker/Dockerfile.alpine"; then
        dockerfiles+=("docker/Dockerfile.alpine")
    fi

    if file_exists "docker/Dockerfile.optimized"; then
        dockerfiles+=("docker/Dockerfile.optimized")
    fi

    if file_exists "docker/Dockerfile.dev"; then
        dockerfiles+=("docker/Dockerfile.dev")
    fi

    # Build and test Dockerfiles
    if [ ${#dockerfiles[@]} -gt 0 ]; then
        log_info "Testing Docker images..."
        if build_and_test_images "${dockerfiles[@]}"; then
            log_success "All Docker images passed tests"
        else
            log_error "Some Docker images failed tests"
            exit 1
        fi
    else
        log_error "No Dockerfiles found in docker/ directory"
        exit 1
    fi

    log_success "Build and test process completed successfully!"
}

# Run main function
main "$@"
