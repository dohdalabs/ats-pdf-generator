#!/bin/bash
#
# Docker Manager - Unified Docker Operations
#
# SYNOPSIS
#     docker-manager.sh <command> [options]
#
# DESCRIPTION
#     Unified script for all Docker operations including building, testing,
#     validating, and generating Docker images and files. Provides a clean,
#     intuitive interface for Docker management tasks.
#
# COMMANDS
#     build [--all|--alpine|--standard|--dev] [--no-cache] [--test]
#         Build Docker images. Default builds all images.
#         --all: Build all images (default)
#         --alpine: Build only Alpine image
#         --standard: Build only Standard image
#         --dev: Build only Dev image
#         --no-cache: Build without cache
#         --test: Run tests after building
#
#     test [--all|--alpine|--standard|--dev]
#         Test existing Docker images. Default tests all images.
#
#     validate [dockerfile...]
#         Validate Dockerfiles using hadolint. If no files specified,
#         validates all Dockerfiles in docker/ directory.
#
#
#     clean [--all|--alpine|--standard|--dev]
#         Remove Docker images. Default removes all project images.
#
#     info
#         Show information about available images and their sizes.
#
# OPTIONS
#     --help, -h    Show this help message and exit
#     --verbose, -v Enable verbose output
#     --quiet, -q   Suppress non-error output
#
# EXAMPLES
#     docker-manager.sh build --all --test          # Build and test all images
#     docker-manager.sh build --dev --no-cache      # Build dev image without cache
#     docker-manager.sh test --alpine               # Test only Alpine image
#     docker-manager.sh validate                    # Validate all Dockerfiles
#     docker-manager.sh clean --all                 # Remove all project images
#     docker-manager.sh info                        # Show image information
#
# EXIT STATUS
#     0    Command completed successfully
#     1    Command failed or invalid arguments
#
# AUTHOR
#     Generated for ats-pdf-generator project
#
# SEE ALSO
#     validate-dockerfiles.sh(1), hadolint(1)

set -euo pipefail

# Source utility scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/utils/common.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/utils/logging.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/utils/ci.sh"

# Get project root using utility function
PROJECT_ROOT=$(get_project_root)

# Configuration
IMAGE_NAME="ats-pdf-generator"
PROJECT_NAME="ats-pdf-generator"

# Registry configurations for publishing
REGISTRIES=(
    "docker.io/dohdalabs/${IMAGE_NAME}"
    "ghcr.io/dohdalabs/${PROJECT_NAME}"
)


# Show usage information
show_usage() {
    cat << EOF
Docker Manager - Unified Docker Operations

SYNOPSIS
    $0 <command> [options]

DESCRIPTION
    Unified script for all Docker operations including building, testing,
    validating, and generating Docker images and files. Provides a clean,
    intuitive interface for Docker management tasks.

COMMANDS
    build [--all|--alpine|--standard|--dev] [--no-cache] [--test]
        Build Docker images. Default builds all images.
        --all: Build all images (default)
        --alpine: Build only Alpine image
        --standard: Build only Standard image
        --dev: Build only Dev image
        --no-cache: Build without cache
        --test: Run tests after building

    test [--all|--alpine|--standard|--dev]
        Test existing Docker images. Default tests all images.

    validate [dockerfile...]
        Validate Dockerfiles using hadolint. If no files specified,
        validates all Dockerfiles in docker/ directory.

    publish [VERSION] [--no-build] [--no-push] [--no-test] [--no-latest] [--tag-latest]
        Build, tag, and publish Docker images to multiple registries.
        VERSION: Image version/tag (default: latest)
        --no-build: Skip building, use existing image
        --no-push: Skip pushing to registries
        --no-test: Skip testing published images
        --no-latest: Skip tagging images with 'latest'
        --tag-latest: Force tagging images with 'latest'
        Publishes to: Docker Hub and GitHub Container Registry

    clean [--all|--alpine|--standard|--dev]
        Remove Docker images. Default removes all project images.

    info
        Show information about available images and their sizes.

OPTIONS
    --help, -h    Show this help message and exit
    --verbose, -v Enable verbose output
    --quiet, -q   Suppress non-error output

EXAMPLES
    $0 build --all --test          # Build and test all images
    $0 build --dev --no-cache      # Build dev image without cache
    $0 test --alpine               # Test only Alpine image
    $0 validate                    # Validate all Dockerfiles
    $0 publish 1.0.0               # Build and publish version 1.0.0
    $0 publish --no-build --no-test # Publish existing image without building/testing
    $0 clean --all                 # Remove all project images
    $0 info                        # Show image information

EXIT STATUS
    0    Command completed successfully
    1    Command failed or invalid arguments

AUTHOR
    Generated for ats-pdf-generator project

SEE ALSO
    validate-dockerfiles.sh(1), hadolint(1)
EOF
}

# Check if Docker is available
check_docker() {
    if ! command_exists docker; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi

    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running"
        exit 1
    fi
}

# Get git SHA for build arguments
get_git_sha() {
    git rev-parse HEAD 2>/dev/null || echo "unknown"
}

# Build a Docker image
build_image() {
    local dockerfile="$1"
    local image_name="$2"
    local image_tag="$3"
    local no_cache="${4:-false}"

    log_info "Building $image_name:$image_tag from $dockerfile"

    local git_sha
    git_sha=$(get_git_sha)

    local build_args=(
        --build-arg "GIT_SHA=$git_sha"
        --build-arg "VENDOR=DohDa Labs"
        -f "$dockerfile"
        -t "$image_name:$image_tag"
    )

    if [ "$no_cache" = true ]; then
        build_args+=(--no-cache)
    fi

    build_args+=(.)

    log_debug "Running: docker build ${build_args[*]}"

    if docker build "${build_args[@]}" > /dev/null 2>&1; then
        log_success "Successfully built $image_name:$image_tag"
        return 0
    else
        log_error "Failed to build $image_name:$image_tag"
        return 1
    fi
}

# Test a Docker image
test_image() {
    local image_name="$1"
    local image_tag="$2"

    log_info "Testing $image_name:$image_tag"

    # Test 1: Image runs and shows help (skip for dev image)
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
tmp_dir = '/app/tmp'
if not os.path.exists(tmp_dir):
    print('ERROR: /app/tmp does not exist')
    exit(1)
if not os.access(tmp_dir, os.W_OK):
    print('ERROR: /app/tmp is not writable')
    exit(1)
print('SUCCESS: /app/tmp exists and is writable')
"; then
        log_error "Permission issue in $image_name:$image_tag - /app/tmp not accessible"
        return 1
    fi

    # Test 3: For dev image, check development tools
    if [[ "$image_tag" == "dev" ]]; then
        if ! docker run --rm "$image_name:$image_tag" bash -c "
source /app/.venv/bin/activate
ruff --version > /dev/null && mypy --version > /dev/null && pytest --version > /dev/null
" > /dev/null 2>&1; then
            log_error "Development tools not available in $image_name:$image_tag"
            return 1
        fi
    fi

    log_success "All tests passed for $image_name:$image_tag"
    return 0
}

# Build command
cmd_build() {
    local build_all=true
    local build_alpine=false
    local build_standard=false
    local build_dev=false
    local no_cache=false
    local run_tests=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --all)
                build_all=true
                shift
                ;;
            --alpine)
                build_all=false
                build_alpine=true
                shift
                ;;
            --standard)
                build_all=false
                build_standard=true
                shift
                ;;
            --dev)
                build_all=false
                build_dev=true
                shift
                ;;
            --no-cache)
                no_cache=true
                shift
                ;;
            --test)
                run_tests=true
                shift
                ;;
            *)
                log_error "Unknown build option: $1"
                return 1
                ;;
        esac
    done

    check_docker

    local failed_builds=()
    local failed_tests=()
    local image_name="ats-pdf-generator"

    # Build Alpine image
    if [ "$build_all" = true ] || [ "$build_alpine" = true ]; then
        if file_exists "$PROJECT_ROOT/docker/Dockerfile.alpine"; then
            if build_image "$PROJECT_ROOT/docker/Dockerfile.alpine" "$image_name" "alpine" "$no_cache"; then
                if [ "$run_tests" = true ] && ! test_image "$image_name" "alpine"; then
                    failed_tests+=("alpine")
                fi
            else
                failed_builds+=("alpine")
            fi
        else
            log_warning "Dockerfile.alpine not found"
        fi
    fi

    # Build Standard image
    if [ "$build_all" = true ] || [ "$build_standard" = true ]; then
        if file_exists "$PROJECT_ROOT/docker/Dockerfile.standard"; then
            if build_image "$PROJECT_ROOT/docker/Dockerfile.standard" "$image_name" "standard" "$no_cache"; then
                if [ "$run_tests" = true ] && ! test_image "$image_name" "standard"; then
                    failed_tests+=("standard")
                fi
            else
                failed_builds+=("standard")
            fi
        else
            log_warning "Dockerfile.standard not found"
        fi
    fi

    # Build Dev image
    if [ "$build_all" = true ] || [ "$build_dev" = true ]; then
        if file_exists "$PROJECT_ROOT/docker/Dockerfile.dev"; then
            if build_image "$PROJECT_ROOT/docker/Dockerfile.dev" "$image_name" "dev" "$no_cache"; then
                if [ "$run_tests" = true ] && ! test_image "$image_name" "dev"; then
                    failed_tests+=("dev")
                fi
            else
                failed_builds+=("dev")
            fi
        else
            log_warning "Dockerfile.dev not found"
        fi
    fi

    # Summary
    echo
    if [ ${#failed_builds[@]} -eq 0 ] && [ ${#failed_tests[@]} -eq 0 ]; then
        log_success "All Docker images built successfully!"
        if [ "$run_tests" = true ]; then
            log_success "All tests passed!"
        fi
        return 0
    else
        if [ ${#failed_builds[@]} -gt 0 ]; then
            log_error "Failed builds: ${failed_builds[*]}"
        fi
        if [ ${#failed_tests[@]} -gt 0 ]; then
            log_error "Failed tests: ${failed_tests[*]}"
        fi
        return 1
    fi
}

# Test command
cmd_test() {
    local test_all=true
    local test_alpine=false
    local test_standard=false
    local test_dev=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --all)
                test_all=true
                shift
                ;;
            --alpine)
                test_all=false
                test_alpine=true
                shift
                ;;
            --standard)
                test_all=false
                test_standard=true
                shift
                ;;
            --dev)
                test_all=false
                test_dev=true
                shift
                ;;
            *)
                log_error "Unknown test option: $1"
                return 1
                ;;
        esac
    done

    check_docker

    local failed_tests=()
    local image_name="ats-pdf-generator"

    # Test Alpine image
    if [ "$test_all" = true ] || [ "$test_alpine" = true ]; then
        if docker images "$image_name:alpine" --format "{{.Repository}}" | grep -q "$image_name"; then
            if ! test_image "$image_name" "alpine"; then
                failed_tests+=("alpine")
            fi
        else
            log_warning "Image $image_name:alpine not found"
        fi
    fi

    # Test Standard image
    if [ "$test_all" = true ] || [ "$test_standard" = true ]; then
        if docker images "$image_name:standard" --format "{{.Repository}}" | grep -q "$image_name"; then
            if ! test_image "$image_name" "standard"; then
                failed_tests+=("standard")
            fi
        else
            log_warning "Image $image_name:standard not found"
        fi
    fi

    # Test Dev image
    if [ "$test_all" = true ] || [ "$test_dev" = true ]; then
        if docker images "$image_name:dev" --format "{{.Repository}}" | grep -q "$image_name"; then
            if ! test_image "$image_name" "dev"; then
                failed_tests+=("dev")
            fi
        else
            log_warning "Image $image_name:dev not found"
        fi
    fi

    # Summary
    echo
    if [ ${#failed_tests[@]} -eq 0 ]; then
        log_success "All Docker image tests passed!"
        return 0
    else
        log_error "Failed tests: ${failed_tests[*]}"
        return 1
    fi
}

# Validate command
cmd_validate() {
    local dockerfiles=("$@")

    # If no files specified, find all Dockerfiles
    if [ ${#dockerfiles[@]} -eq 0 ]; then
        while IFS= read -r -d '' file; do
            dockerfiles+=("$file")
        done < <(find "$PROJECT_ROOT/docker" -name "Dockerfile.*" -print0 2>/dev/null)

        if [ ${#dockerfiles[@]} -eq 0 ]; then
            log_error "No Dockerfiles found in docker/ directory"
            return 1
        fi
    fi

    # Check if hadolint is available
    if ! command_exists hadolint; then
        log_error "hadolint not found. Please install it using:"
        log_error "  - Development: mise install (managed by mise.toml)"
        log_error "  - CI: Install via your CI environment"
        log_error "  - Manual: brew install hadolint (macOS) or download from GitHub releases"
        return 1
    fi

    # Shared hadolint arguments (mirrors scripts/quality/check-docker.sh)
    local hadolint_common_args=(--ignore DL3008 --ignore DL3018)

    # Validate each Dockerfile directly
    local total_failed=0
    for dockerfile in "${dockerfiles[@]}"; do
        if ! file_exists "$dockerfile"; then
            log_error "Dockerfile not found: $dockerfile"
            ((total_failed++))
            continue
        fi

        log_info "Validating $dockerfile with hadolint..."

        if hadolint "${hadolint_common_args[@]}" "$dockerfile"; then
            log_success "$dockerfile passed hadolint analysis"
        else
            log_error "$dockerfile failed hadolint analysis"
            ((total_failed++))
        fi
        echo ""
    done

    # Summary
    if [ $total_failed -eq 0 ]; then
        log_success "All Dockerfiles passed static analysis! ✅"
        return 0
    else
        log_error "$total_failed Dockerfile(s) failed validation"
        return 1
    fi
}


# Clean command
cmd_clean() {
    local clean_all=true
    local clean_alpine=false
    local clean_standard=false
    local clean_dev=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --all)
                clean_all=true
                shift
                ;;
            --alpine)
                clean_all=false
                clean_alpine=true
                shift
                ;;
            --standard)
                clean_all=false
                clean_standard=true
                shift
                ;;
            --dev)
                clean_all=false
                clean_dev=true
                shift
                ;;
            *)
                log_error "Unknown clean option: $1"
                return 1
                ;;
        esac
    done

    check_docker

    local image_name="ats-pdf-generator"
    local removed_count=0

    # Remove Alpine image
    if [ "$clean_all" = true ] || [ "$clean_alpine" = true ]; then
        if docker images "$image_name:alpine" --format "{{.Repository}}" | grep -q "$image_name"; then
            log_info "Removing $image_name:alpine"
            docker rmi "$image_name:alpine" > /dev/null 2>&1 && ((removed_count++))
        fi
    fi

    # Remove Standard image
    if [ "$clean_all" = true ] || [ "$clean_standard" = true ]; then
        if docker images "$image_name:standard" --format "{{.Repository}}" | grep -q "$image_name"; then
            log_info "Removing $image_name:standard"
            docker rmi "$image_name:standard" > /dev/null 2>&1 && ((removed_count++))
        fi
    fi

    # Remove Dev image
    if [ "$clean_all" = true ] || [ "$clean_dev" = true ]; then
        if docker images "$image_name:dev" --format "{{.Repository}}" | grep -q "$image_name"; then
            log_info "Removing $image_name:dev"
            docker rmi "$image_name:dev" > /dev/null 2>&1 && ((removed_count++))
        fi
    fi

    if [ $removed_count -gt 0 ]; then
        log_success "Removed $removed_count image(s)"
    else
        log_info "No images to remove"
    fi
}

# Info command
cmd_info() {
    check_docker

    local image_name="ats-pdf-generator"

    log_info "Docker image information:"
    echo

    # Check for project images
    local found_images=false
    for tag in alpine standard dev; do
        if docker images "$image_name:$tag" --format "{{.Repository}}" | grep -q "$image_name"; then
            found_images=true
            echo "📦 $image_name:$tag"
            docker images "$image_name:$tag" --format "  Size: {{.Size}}"
            docker images "$image_name:$tag" --format "  Created: {{.CreatedSince}}"
            echo
        fi
    done

    if [ "$found_images" = false ]; then
        log_info "No project images found. Run 'docker-manager.sh build' to create images."
    fi

    # Show available Dockerfiles
    log_info "Available Dockerfiles:"
    for dockerfile in "$PROJECT_ROOT/docker"/Dockerfile.*; do
        if file_exists "$dockerfile"; then
            local basename_file
            basename_file=$(basename "$dockerfile")
            echo "  📄 $basename_file"
        fi
    done
}


# Tag image for each registry
tag_for_registries() {
    local image_name="$1"
    local version="$2"
    local tag_latest="${3:-${TAG_LATEST:-true}}"

    log_info "Tagging image for multiple registries..."

    for registry in "${REGISTRIES[@]}"; do
        log_info "Tagging for registry: ${registry}"
        docker tag "${image_name}:${version}" "${registry}:${version}"

        # Also tag as latest when enabled and version is not already latest
        if [ "${tag_latest}" = true ] && [ "${version}" != "latest" ]; then
            log_info "Tagging ${registry}:latest"
            docker tag "${image_name}:${version}" "${registry}:latest"
        else
            if [ "${tag_latest}" != true ]; then
                log_info "Skipping latest tag for ${registry} (TAG_LATEST=${tag_latest})"
            else
                log_info "Version already latest; skipping duplicate tag for ${registry}"
            fi
        fi
    done

    log_success "All images tagged successfully"
}

# Push to Docker Hub
push_dockerhub() {
    local registry="docker.io/dohdalabs/${IMAGE_NAME}"
    local version="$1"

    log_info "Pushing to Docker Hub: ${registry}"

    if docker push "${registry}:${version}"; then
        log_success "Successfully pushed to Docker Hub"
        return 0
    else
        log_warning "Failed to push to Docker Hub (check authentication)"
        return 1
    fi
}

# Push to GitHub Container Registry
push_ghcr() {
    local registry="ghcr.io/dohdalabs/${PROJECT_NAME}"
    local version="$1"

    log_info "Pushing to GitHub Container Registry: ${registry}"

    if docker push "${registry}:${version}"; then
        log_success "Successfully pushed to GitHub Container Registry"
        return 0
    else
        log_warning "Failed to push to GitHub Container Registry (check authentication)"
        return 1
    fi
}

# Test the published image
test_published_image() {
    local registry="$1"
    local version="$2"

    log_info "Testing published image: ${registry}:${version}"

    # Pull and test the image
    if docker pull "${registry}:${version}"; then
        # Test basic functionality
        docker run --rm "${registry}:${version}" --help >/dev/null 2>&1 || {
            log_error "Published image test failed for ${registry}"
            return 1
        }
        log_success "Published image test passed for ${registry}"
        return 0
    else
        log_error "Failed to pull published image from ${registry}"
        return 1
    fi
}

# Publish command
cmd_publish() {
    local version="latest"
    local push_enabled="${PUSH:-true}"
    local build_image="${BUILD:-true}"
    local test_published="${TEST:-true}"
    local tag_latest="${TAG_LATEST:-true}"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                echo "Publish command for ATS PDF Generator"
                echo ""
                echo "Builds and publishes Docker images to multiple registries:"
                echo "  - Docker Hub (docker.io/dohdalabs/ats-pdf-generator)"
                echo "  - GitHub Container Registry (ghcr.io/dohdalabs/ats-pdf-generator)"
                echo ""
                echo "Usage: $0 publish [VERSION] [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --no-build    Skip building, use existing image"
                echo "  --no-push     Skip pushing to registries"
                echo "  --no-test     Skip testing published images"
                echo "  --no-latest   Skip tagging images with 'latest'"
                echo "  --tag-latest  Force tagging images with 'latest'"
                echo "  --version=V   Set version to V"
                echo ""
                echo "Examples:"
                echo "  $0 publish                    # Build and publish as 'latest'"
                echo "  $0 publish 1.0.0             # Build and publish as '1.0.0'"
                echo "  $0 publish --no-build --no-test # Publish existing image"
                echo ""
                echo "Environment variables:"
                echo "  PUSH=true     Enable pushing to registries (default: true)"
                echo "  BUILD=true    Enable building image (default: true)"
                echo "  TEST=true     Enable testing published images (default: true)"
                echo "  TAG_LATEST=true  Tag images with 'latest' (default: true)"
                echo ""
                echo "Prerequisites:"
                echo "  - Docker must be running"
                echo "  - Authenticated to Docker Hub: docker login"
                echo "  - Authenticated to GitHub: echo \$GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin"
                return 0
                ;;
            --no-build)
                build_image=false
                shift
                ;;
            --no-push)
                push_enabled=false
                shift
                ;;
            --no-test)
                test_published=false
                shift
                ;;
            --no-latest)
                tag_latest=false
                shift
                ;;
            --tag-latest)
                tag_latest=true
                shift
                ;;
            --version=*)
                version="${1#*=}"
                shift
                ;;
            *)
                if [[ ! "$1" =~ ^-- ]]; then
                    version="$1"
                fi
                shift
                ;;
        esac
    done

    check_docker

    log_info "Starting publish process"
    log_info "Version: ${version}"
    log_info "Image: ${IMAGE_NAME}"
    log_info "Build: ${build_image}"
    log_info "Push: ${push_enabled}"
    log_info "Test: ${test_published}"
    log_info "Tag latest: ${tag_latest}"

    # Build the image if requested
    if [ "$build_image" = true ]; then
        log_info "Building Docker image: ${IMAGE_NAME}:${version}"

        local git_sha
        git_sha=$(get_git_sha)

        if docker build \
            --build-arg GIT_SHA="$git_sha" \
            --build-arg VENDOR="DohDa Labs" \
            -f "$PROJECT_ROOT/docker/Dockerfile.standard" \
            -t "${IMAGE_NAME}:${version}" .; then
            log_success "Image built successfully: ${IMAGE_NAME}:${version}"
        else
            log_error "Failed to build image"
            return 1
        fi
    else
        # Check if image exists
        if ! docker images "${IMAGE_NAME}:${version}" --format "{{.Repository}}" | grep -q "${IMAGE_NAME}"; then
            log_error "Image ${IMAGE_NAME}:${version} not found. Use --build or build the image first."
            return 1
        fi
    fi

    # Tag for all registries
    tag_for_registries "${IMAGE_NAME}" "${version}" "${tag_latest}"

    # Push to each registry if enabled
    if [ "$push_enabled" = true ]; then
        log_info "Starting push to all registries..."

        local push_exit_code=0
        push_dockerhub "${version}" || push_exit_code=1
        push_ghcr "${version}" || push_exit_code=1

        if [ $push_exit_code -eq 0 ]; then
            log_success "Multi-registry push completed!"

            # Test published images if enabled
            if [ "$test_published" = true ]; then
                log_info "Testing published images..."
                test_published_image "docker.io/dohdalabs/${IMAGE_NAME}" "${version}" || push_exit_code=1
                test_published_image "ghcr.io/dohdalabs/${PROJECT_NAME}" "${version}" || push_exit_code=1
            fi

            if [ $push_exit_code -eq 0 ]; then
                # Display pull commands
                echo ""
                log_info "Pull commands for users:"
                echo "  Docker Hub:        docker pull dohdalabs/${IMAGE_NAME}:${version}"
                echo "  GitHub Registry:   docker pull ghcr.io/dohdalabs/${PROJECT_NAME}:${version}"
            fi
        else
            log_error "Some registry pushes failed"
            return 1
        fi
    else
        log_info "Push skipped (PUSH=false or --no-push specified)"
        log_info "Images are built and tagged locally"
    fi
}

# Main function
main() {
    # Initialize logger
    init_logger --script-name "$(basename "$0")"

    # Parse global options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_usage
                exit 0
                ;;
            --verbose|-v)
                set_log_level DEBUG
                shift
                ;;
            --quiet|-q)
                # shellcheck disable=SC2034 # LOG_QUIET is used by logging.sh utility
                LOG_QUIET=true
                shift
                ;;
            *)
                break
                ;;
        esac
    done

    # Check if command is provided
    if [ $# -eq 0 ]; then
        log_error "No command specified"
        echo
        show_usage
        exit 1
    fi

    local command="$1"
    shift

    # Execute command
    case "$command" in
        build)
            cmd_build "$@"
            ;;
        test)
            cmd_test "$@"
            ;;
        validate)
            cmd_validate "$@"
            ;;
        publish)
            cmd_publish "$@"
            ;;
        clean)
            cmd_clean "$@"
            ;;
        info)
            cmd_info "$@"
            ;;
        *)
            log_error "Unknown command: $command"
            echo
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
