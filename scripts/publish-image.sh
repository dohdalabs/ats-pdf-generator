#!/bin/bash
# Multi-Registry Docker Build and Push Script
# Builds and pushes the ATS PDF Generator to multiple public registries

set -euo pipefail

# Configuration
IMAGE_NAME="ats-pdf-generator"
VERSION="${1:-latest}"
PROJECT_NAME="ats-pdf-generator"

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

# Check if Docker is running
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker is not running. Please start Docker and try again."
        exit 1
    fi
}

# Build the Docker image
build_image() {
    log_info "Building Docker image: ${IMAGE_NAME}:${VERSION}"

    # Build the standard image
    if docker build -f docker/Dockerfile.standard -t "${IMAGE_NAME}:${VERSION}" .; then
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
    fi
}


# Main execution
main() {
    log_info "Starting multi-registry build and push process"
    log_info "Version: ${VERSION}"
    log_info "Image: ${IMAGE_NAME}"

    # Check prerequisites
    check_docker

    # Build the image
    build_image

    # Tag for all registries
    tag_images

    # Push to each registry
    log_info "Starting push to all registries..."

    push_dockerhub
    push_ghcr

    log_success "Multi-registry push completed!"

    # Display pull commands
    echo ""
    log_info "Pull commands for users:"
    echo "  Docker Hub:        docker pull dohdalabs/${IMAGE_NAME}:${VERSION}"
    echo "  GitHub Registry:   docker pull ghcr.io/dohdalabs/${PROJECT_NAME}:${VERSION}"
}

# Show usage if help requested or no arguments
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ] || [ $# -eq 0 ]; then
    echo "Multi-Registry Docker Build and Push Script"
    echo ""
    echo "Builds and pushes the ATS PDF Generator to multiple public registries:"
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
    echo "Prerequisites:"
    echo "  - Docker must be running"
    echo "  - Authenticated to Docker Hub: docker login"
    echo "  - Authenticated to GitHub: echo \$GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin"
    exit 0
fi

# Run main function
main
