#!/bin/bash
# Registry Setup Script for ATS PDF Generator
# Sets up authentication for multiple Docker registries

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

# Check if Docker is running
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker is not running. Please start Docker and try again."
        exit 1
    fi
    log_success "Docker is running"
}

# Setup Docker Hub authentication
setup_dockerhub() {
    log_info "Setting up Docker Hub authentication..."

    if docker login --help | grep -q "username"; then
        echo "Please enter your Docker Hub credentials:"
        docker login
        log_success "Docker Hub authentication configured"
    else
        log_warning "Docker login not available. Please run 'docker login' manually."
    fi
}

# Setup GitHub Container Registry authentication
setup_ghcr() {
    log_info "Setting up GitHub Container Registry authentication..."

    if [ -n "${GITHUB_TOKEN:-}" ]; then
        echo "$GITHUB_TOKEN" | docker login ghcr.io -u "$GITHUB_USERNAME" --password-stdin
        log_success "GitHub Container Registry authentication configured"
    else
        log_warning "GITHUB_TOKEN not found. Please set GITHUB_TOKEN and GITHUB_USERNAME environment variables."
        log_info "You can create a token at: https://github.com/settings/tokens"
        log_info "Required scopes: read:packages, write:packages, delete:packages"
    fi
}


# Test registry access
test_registries() {
    log_info "Testing registry access..."

    # Test Docker Hub
    if docker pull hello-world:latest >/dev/null 2>&1; then
        log_success "Docker Hub access confirmed"
        docker rmi hello-world:latest >/dev/null 2>&1 || true
    else
        log_warning "Docker Hub access test failed"
    fi

    # Test GitHub Container Registry (if authenticated)
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        log_info "GitHub Container Registry access test skipped (requires specific repository)"
    fi

}

# Main execution
main() {
    log_info "Setting up multi-registry authentication for ATS PDF Generator"

    # Check prerequisites
    check_docker

    # Setup each registry
    setup_dockerhub
    setup_ghcr

    # Test access
    test_registries

    log_success "Registry setup completed!"

    echo ""
    log_info "Next steps:"
    echo "1. Build and push your image: ./scripts/docker-push-multi-registry.sh"
    echo "2. Check the Registry Setup Guide: docs/REGISTRY_SETUP.md"
    echo ""
    log_info "Registry URLs:"
    echo "  Docker Hub:        https://hub.docker.com/r/dohdalabs/ats-pdf-generator"
    echo "  GitHub Registry:   https://github.com/dohdalabs/ats-pdf-generator/pkgs/container/ats-pdf-generator"
}

# Show usage if help requested
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    echo "Registry Setup Script for ATS PDF Generator"
    echo ""
    echo "This script sets up authentication for multiple Docker registries:"
    echo "  - Docker Hub"
    echo "  - GitHub Container Registry (ghcr.io)"
    echo ""
    echo "Prerequisites:"
    echo "  - Docker must be running"
    echo "  - For GitHub: Set GITHUB_TOKEN and GITHUB_USERNAME environment variables"
    echo ""
    echo "Usage: $0"
    exit 0
fi

# Run main function
main
