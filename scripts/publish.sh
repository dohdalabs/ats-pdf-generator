#!/bin/bash

# Publish Script
# Handles building and publishing Docker images to multiple registries

set -euo pipefail

# Configuration
IMAGE_NAME="ats-pdf-generator"
PROJECT_NAME="ats-pdf-generator"
VERSION="${1:-latest}"

# Registry configurations
REGISTRIES=(
    "docker.io/dohdalabs/${IMAGE_NAME}"
    "ghcr.io/dohdalabs/${PROJECT_NAME}"
)

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

# Check if Docker is running
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker is not running. Please start Docker and try again."
        exit 1
    fi
    log_success "Docker is running"
}

# Build the Docker image
build_image() {
    log_info "Building Docker image: ${IMAGE_NAME}:${VERSION}"

    # Get git SHA for build argument
    local git_sha
    git_sha=$(git rev-parse HEAD 2>/dev/null || echo "unknown")

    # Build the standard image
    if docker build \
        --build-arg GIT_SHA="$git_sha" \
        --build-arg VENDOR="DohDa Labs" \
        -f docker/Dockerfile.standard \
        -t "${IMAGE_NAME}:${VERSION}" .; then
        log_success "Image built successfully: ${IMAGE_NAME}:${VERSION}"
    else
        log_error "Failed to build image"
        exit 1
    fi
}

# Tag image for each registry
tag_images() {
    log_info "Tagging image for multiple registries..."

    for registry in "${REGISTRIES[@]}"; do
        log_info "Tagging for registry: ${registry}"
        docker tag "${IMAGE_NAME}:${VERSION}" "${registry}:${VERSION}"

        # Also tag as latest if this is not a specific version
        if [ "${VERSION}" = "latest" ]; then
            docker tag "${IMAGE_NAME}:${VERSION}" "${registry}:latest"
        fi
    done

    log_success "All images tagged successfully"
}

# Push to Docker Hub
push_dockerhub() {
    local registry="docker.io/dohdalabs/${IMAGE_NAME}"
    log_info "Pushing to Docker Hub: ${registry}"

    if docker push "${registry}:${VERSION}"; then
        log_success "Successfully pushed to Docker Hub"
    else
        log_warning "Failed to push to Docker Hub (check authentication)"
        return 1
    fi
}

# Push to GitHub Container Registry
push_ghcr() {
    local registry="ghcr.io/dohdalabs/${PROJECT_NAME}"
    log_info "Pushing to GitHub Container Registry: ${registry}"

    if docker push "${registry}:${VERSION}"; then
        log_success "Successfully pushed to GitHub Container Registry"
    else
        log_warning "Failed to push to GitHub Container Registry (check authentication)"
        return 1
    fi
}

# Test the published image
test_published_image() {
    local registry="$1"
    log_info "Testing published image: ${registry}:${VERSION}"

    # Pull and test the image
    if docker pull "${registry}:${VERSION}"; then
        # Test basic functionality
        docker run --rm "${registry}:${VERSION}" --help >/dev/null 2>&1 || {
            log_error "Published image test failed for ${registry}"
            return 1
        }
        log_success "Published image test passed for ${registry}"
    else
        log_error "Failed to pull published image from ${registry}"
        return 1
    fi
}

# Main execution
main() {
    log_info "Starting publish process"
    log_info "Version: ${VERSION}"
    log_info "Image: ${IMAGE_NAME}"

    # Check prerequisites
    check_docker

    # Build the image
    build_image

    # Tag for all registries
    tag_images

    # Push to each registry (only if not in CI or if explicitly requested)
    if [ "${PUSH:-true}" = "true" ]; then
        log_info "Starting push to all registries..."

        local push_exit_code=0
        push_dockerhub || push_exit_code=1
        push_ghcr || push_exit_code=1

        if [ $push_exit_code -eq 0 ]; then
            log_success "Multi-registry push completed!"

            # Test published images
            log_info "Testing published images..."
            test_published_image "docker.io/dohdalabs/${IMAGE_NAME}" || push_exit_code=1
            test_published_image "ghcr.io/dohdalabs/${PROJECT_NAME}" || push_exit_code=1

            if [ $push_exit_code -eq 0 ]; then
                # Display pull commands
                echo ""
                log_info "Pull commands for users:"
                echo "  Docker Hub:        docker pull dohdalabs/${IMAGE_NAME}:${VERSION}"
                echo "  GitHub Registry:   docker pull ghcr.io/dohdalabs/${PROJECT_NAME}:${VERSION}"
            fi
        else
            log_error "Some registry pushes failed"
            exit 1
        fi
    else
        log_info "Push skipped (PUSH=false or not in CI environment)"
        log_info "Images are built and tagged locally"
    fi
}

# Show usage if help requested
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    echo "Publish Script for ATS PDF Generator"
    echo ""
    echo "Builds and publishes Docker images to multiple registries:"
    echo "  - Docker Hub (docker.io/dohdalabs/ats-pdf-generator)"
    echo "  - GitHub Container Registry (ghcr.io/dohdalabs/ats-pdf-generator)"
    echo ""
    echo "Usage: $0 [VERSION]"
    echo ""
    echo "Examples:"
    echo "  $0                    # Build and push as 'latest'"
    echo "  $0 1.0.0             # Build and push as '1.0.0'"
    echo "  $0 v1.0.0            # Build and push as 'v1.0.0'"
    echo ""
    echo "Environment variables:"
    echo "  PUSH=true            # Enable pushing to registries (default: true)"
    echo "  CI=true              # Run in CI mode"
    echo ""
    echo "Prerequisites:"
    echo "  - Docker must be running"
    echo "  - Authenticated to Docker Hub: docker login"
    echo "  - Authenticated to GitHub: echo \$GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin"
    exit 0
fi

# Run main function
main
