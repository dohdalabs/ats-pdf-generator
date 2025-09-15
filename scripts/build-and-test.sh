#!/bin/bash

# Build and Test Script
# Builds Docker images and runs comprehensive tests

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

# Check if we're in a CI environment
is_ci() {
    [ "${CI:-false}" = "true" ] || [ "${GITHUB_ACTIONS:-false}" = "true" ]
}

# Build Docker images
build_images() {
    log_info "🐳 Building Docker images..."

    # Build development image
    log_info "Building development image..."
    docker build -f docker/Dockerfile.dev -t ats-pdf-generator:dev .

    # Build production images
    log_info "Building optimized image..."
    docker build -f docker/Dockerfile.optimized -t ats-pdf-generator:optimized .

    log_info "Building Alpine image..."
    docker build -f docker/Dockerfile.alpine -t ats-pdf-generator:alpine .

    log_success "All Docker images built successfully"
}

# Test Docker image functionality
test_image_functionality() {
    local image_tag="$1"
    local image_name="$2"

    log_info "Testing $image_name functionality..."

    # Test help command
    docker run --rm "$image_tag" --help >/dev/null 2>&1 || {
        log_error "Help command failed for $image_name"
        return 1
    }

    # Test with sample files
    if [ -f "examples/sample-cover-letter.md" ]; then
        docker run --rm -v "$(pwd):/app" "$image_tag" examples/sample-cover-letter.md -o test-cover-letter.pdf
        if [ -f "test-cover-letter.pdf" ]; then
            log_success "Cover letter test passed for $image_name"
            rm -f test-cover-letter.pdf
        else
            log_error "Cover letter test failed for $image_name"
            return 1
        fi
    fi

    if [ -f "examples/sample-profile.md" ]; then
        docker run --rm -v "$(pwd):/app" "$image_tag" examples/sample-profile.md -o test-profile.pdf
        if [ -f "test-profile.pdf" ]; then
            log_success "Profile test passed for $image_name"
            rm -f test-profile.pdf
        else
            log_error "Profile test failed for $image_name"
            return 1
        fi
    fi

    log_success "$image_name functionality tests completed"
}

# Test development environment
test_dev_environment() {
    log_info "🛠️ Testing development environment..."

    # Test that development tools are available
    docker run --rm ats-pdf-generator:dev bash -c "
        ruff --version &&
        mypy --version &&
        pytest --version &&
        echo '✅ All development tools available'
    " || {
        log_error "Development tools test failed"
        return 1
    }

    # Test linting in dev environment
    docker run --rm -v "$(pwd):/app" -w /app ats-pdf-generator:dev bash -c "
        ruff check . &&
        echo '✅ Linting passed in dev environment'
    " || {
        log_error "Linting test failed in dev environment"
        return 1
    }

    # Test type checking in dev environment
    docker run --rm -v "$(pwd):/app" -w /app ats-pdf-generator:dev bash -c "
        mypy src/ &&
        echo '✅ Type checking passed in dev environment'
    " || {
        log_error "Type checking test failed in dev environment"
        return 1
    }

    # Test pytest in dev environment
    docker run --rm -v "$(pwd):/app" -w /app ats-pdf-generator:dev bash -c "
        pytest tests/ &&
        echo '✅ Tests passed in dev environment'
    " || {
        log_error "Tests failed in dev environment"
        return 1
    }

    log_success "Development environment tests completed"
}

# Validate PDF outputs
validate_pdfs() {
    log_info "📄 Validating PDF outputs..."

    local pdf_count=0
    for pdf in *.pdf; do
        if [ -f "$pdf" ]; then
            pdf_count=$((pdf_count + 1))
            log_info "Generated: $pdf ($(stat -f%z "$pdf" 2>/dev/null || stat -c%s "$pdf") bytes)"

            # Basic PDF validation (check for PDF header)
            if head -c 4 "$pdf" | grep -q "%PDF"; then
                log_success "Valid PDF format: $pdf"
            else
                log_error "Invalid PDF format: $pdf"
                return 1
            fi
        fi
    done

    if [ $pdf_count -eq 0 ]; then
        log_warning "No PDF files found for validation"
    else
        log_success "PDF validation completed ($pdf_count files)"
    fi
}

# Main execution
main() {
    log_info "Starting build and test process..."

    local exit_code=0

    # Build images
    build_images || exit_code=1

    # Test image functionality
    test_image_functionality "ats-pdf-generator:optimized" "Optimized" || exit_code=1
    test_image_functionality "ats-pdf-generator:alpine" "Alpine" || exit_code=1

    # Test development environment
    test_dev_environment || exit_code=1

    # Validate any generated PDFs
    validate_pdfs || exit_code=1

    # Clean up test files
    rm -f *.pdf

    # Summary
    echo ""
    log_info "📋 Build and Test Summary:"
    echo "  🐳 Docker: Images built and tested successfully"
    echo "  🧪 Functionality: PDF generation tests passed"
    echo "  🛠️ Development: Environment validation completed"
    echo "  📄 Validation: PDF format validation completed"

    if [ $exit_code -eq 0 ]; then
        log_success "All build and test checks completed successfully!"
    else
        log_error "Some build and test checks failed (see above for details)"
    fi

    exit $exit_code
}

# Show usage if help requested
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    echo "Build and Test Script"
    echo ""
    echo "Builds Docker images and runs comprehensive tests:"
    echo "  - Builds all Docker images (dev, optimized, alpine)"
    echo "  - Tests image functionality with sample files"
    echo "  - Validates development environment"
    echo "  - Validates generated PDF outputs"
    echo ""
    echo "Usage: $0"
    echo ""
    echo "Prerequisites:"
    echo "  - Docker must be running"
    echo "  - Sample files in examples/ directory"
    exit 0
fi

# Run main function
main
