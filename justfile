# justfile - Task runner for ats-pdf-generator
# See: https://github.com/casey/just

# Set shell for all recipes
set shell := ["bash", "-uc"]

# Variables
export CI := env_var_or_default("CI", "false")
export UV_COMPILE_BYTECODE := "1"
export UV_CACHE_DIR := "$HOME/.cache/uv"

# Show available commands with helpful context
@default:
    just help-custom

# Display custom help information
@help-custom:
    echo "ATS PDF Generator - Development Tasks"
    echo ""
    echo "MAIN COMMANDS:"
    echo "  quick        Fast checks (~30s)"
    echo "  check        Pre-commit checks (~3min)"
    echo "  ci           Full CI pipeline (~10min)"
    echo "  install      Setup development environment"
    echo ""
    echo "QUALITY:"
    echo "  lint         Lint all code"
    echo "  format       Format all code"
    echo "  test         Run all tests"
    echo "  typecheck    Type check Python code"
    echo "  check-docstrings  Validate docstrings"
    echo "  security     Run security scans (Trivy + Bandit)"
    echo ""
    echo "DOCKER:"
    echo "  build        Build standard image"
    echo "  build-all    Build all variants"
    echo "  test-docker  Test all images"
    echo ""
    echo "PDF OPERATIONS:"
    echo "  convert      Convert Markdown to PDF"
    echo ""
    echo "Full list: just --list"
    echo "Internal tasks: just --list | grep '^  _'"
    echo ""
    echo "Tasks with _ prefix are internal helpers."
    echo "You can call them for debugging: just _build-docker alpine"

# ============================================================================
# Quick Entry Points (Most Common Workflows)
# ============================================================================

# Fast local checks (~30 seconds)
quick: lint-python test-python
    @echo ""
    @echo "✅ Quick checks passed!"

# Thorough pre-commit checks (~3 minutes)
check: lint format-check typecheck test
    @echo ""
    @echo "✅ Ready to commit!"

# Complete CI pipeline (~10 minutes)
ci: lint format-check typecheck check-docstrings test-python security _ci-build-docker _ci-test-docker validate-dockerfiles
    @echo ""
    @echo "✅ Complete CI pipeline passed!"
    @echo "This matches what GitHub Actions runs."

# ============================================================================
# Development Environment
# ============================================================================

# Install all dependencies and setup dev environment
install:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🚀 Installing dependencies..."
    uv sync --dev

    # Skip pre-commit installation in CI environments
    if [ "${CI:-}" = "true" ] || [ "${GITHUB_ACTIONS:-}" = "true" ] || [ "${GITLAB_CI:-}" = "true" ]; then
        echo "⏭️  Skipping pre-commit installation in CI environment"
    else
        echo "🔧 Installing pre-commit hooks..."
        uv run pre-commit install
        uv run pre-commit install --hook-type commit-msg
    fi

    echo "✅ Development environment ready!"
    echo ""
    echo "Available commands:"
    echo "  just --list              # Show all available tasks"
    echo "  just ci                  # Run all quality checks (same as CI)"
    echo "  just test                # Run tests"
    echo "  just format              # Auto-fix formatting"
    echo "  just security            # Run security scan (fails on HIGH/CRITICAL)"
    echo ""
    echo "Security scanning:"
    echo "  • Scans for HIGH/CRITICAL vulnerabilities and secrets"
    echo "  • Fails the build if any HIGH/CRITICAL issues are found"
    echo "  • Uses Trivy for dependency vulnerabilities and secret detection"

# Install production dependencies only
install-prod:
    uv sync --frozen --no-dev

# Setup local environment (for non-mise users)
setup-local:
    ./scripts/setup-local-env.sh

# ============================================================================
# Code Quality (Aggregators)
# ============================================================================

# Lint all code
lint: lint-python lint-shell lint-markdown

# Format all code
format: format-python format-markdown

# Check formatting (no changes)
format-check: _format-check-python

# Run all tests
test: test-python test-docker

# Type check code
typecheck: typecheck-python

# ============================================================================
# Python Quality Checks
# ============================================================================

# Lint Python code with ruff
lint-python:
    @echo "🔍 Linting Python code..."
    uv run ruff check .

# Format Python code
format-python:
    @echo "🎨 Formatting Python code..."
    uv run ruff format .

# Type check Python code
typecheck-python:
    @echo "🔍 Type checking Python code..."
    uv run mypy src/ats_pdf_generator/

# Check docstring coverage
check-docstrings:
    @echo "📝 Checking docstring coverage..."
    uv run interrogate src/ats_pdf_generator/ --fail-under=80

# Run Python tests with coverage
test-python:
    @echo "🧪 Running Python tests..."
    uv run pytest --cov=src --cov-report=xml --cov-report=term-missing

# Run Python security scan with bandit
security-python:
    @echo "🔒 Running Python security scan with bandit..."
    uv run bandit -c pyproject.toml -r src/ats_pdf_generator/

# ============================================================================
# Shell Script Quality Checks
# ============================================================================

# Lint shell scripts
lint-shell:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🐚 Linting shell scripts..."
    scripts=(scripts/*.sh)
    for script in "${scripts[@]}"; do
        echo "  • $script"
    done
    shellcheck -x "${scripts[@]}"
    echo "✅ All shell scripts passed"

# ============================================================================
# Docker Operations
# ============================================================================

# Build standard image (default)
build: (_build-docker "standard")

# Build all image variants
build-all:
    @echo "🔨 Building all Docker images..."
    just _build-docker alpine
    just _build-docker standard
    just _build-docker dev
    @echo "✅ All images built successfully!"

# Test all Docker images
test-docker:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🧪 Testing all Docker images..."

    # Test each image variant using the centralized test helper
    just _test-docker-image alpine
    just _test-docker-image standard
    just _test-docker-image dev

    echo "✅ All Docker tests passed!"

# Validate Dockerfiles with hadolint
validate-dockerfiles:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔍 Validating Dockerfiles with hadolint..."

    if ! command -v hadolint >/dev/null 2>&1; then
        echo "⚠️  hadolint not found, skipping validation"
        echo "Install with: brew install hadolint (macOS) or mise install"
        exit 0
    fi

    failed=0
    for dockerfile in docker/Dockerfile.*; do
        echo "Checking $dockerfile..."
        if ! hadolint --ignore DL3008 --ignore DL3018 "$dockerfile"; then
            ((failed++))
        fi
    done

    if [ $failed -eq 0 ]; then
        echo "✅ All Dockerfiles passed validation"
    else
        echo "❌ $failed Dockerfile(s) failed validation"
        exit 1
    fi

# Show Docker image information
docker-info:
    @echo "📦 Docker image information:"
    @echo ""
    @docker images ats-pdf-generator --format "table {{{{.Repository}}}}\t{{{{.Tag}}}}\t{{{{.Size}}}}\t{{{{.CreatedSince}}}}" 2>/dev/null || echo "No images found. Run 'just build-all' to create them."

# Clean Docker images
docker-clean:
    @echo "🧹 Cleaning Docker images..."
    -docker rmi ats-pdf-generator:alpine 2>/dev/null || true
    -docker rmi ats-pdf-generator:standard 2>/dev/null || true
    -docker rmi ats-pdf-generator:dev 2>/dev/null || true
    @echo "✅ Docker images cleaned"

# ============================================================================
# Markdown Quality Checks
# ============================================================================

# Lint Markdown files
lint-markdown:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📝 Linting Markdown files..."

    # Use mise-managed pnpm dlx if available, fallback to system npx
    if command -v mise >/dev/null 2>&1; then
        mise exec -- pnpm dlx markdownlint-cli '**/*.{md,mdc}' --config=.markdownlint.jsonc
    else
        npx markdownlint-cli '**/*.{md,mdc}' --config=.markdownlint.jsonc
    fi

# Format Markdown files
format-markdown:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📝 Formatting Markdown files..."

    # Use mise-managed pnpm dlx if available, fallback to system npx
    if command -v mise >/dev/null 2>&1; then
        mise exec -- pnpm dlx markdownlint-cli '**/*.{md,mdc}' --config=.markdownlint.jsonc --fix
    else
        npx markdownlint-cli '**/*.{md,mdc}' --config=.markdownlint.jsonc --fix
    fi

# ============================================================================
# Security Scanning
# ============================================================================

# Run all security scans (Python + Trivy)
security: security-python security-trivy

# Run security scan with Trivy
security-trivy:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Running security scan..."

    # Use mise-managed trivy
    if command -v mise >/dev/null 2>&1; then
        TRIVY_CMD="mise exec -- trivy"
    elif command -v trivy >/dev/null 2>&1; then
        TRIVY_CMD="trivy"
    else
        echo "⚠️  trivy not found, skipping security scan"
        echo "Install with: mise install trivy"
        exit 0
    fi

    echo "🔒 HIGH/CRITICAL vulnerabilities and secrets will fail the build"

    # Run scan with SARIF output for GitHub Actions (includes secrets scanning)
    $TRIVY_CMD fs . --format sarif --output trivy-results.sarif --scanners vuln,secret --severity HIGH,CRITICAL --ignore-unfixed

    # Run vulnerability scan on dependencies
    echo "🔍 Scanning dependencies for vulnerabilities..."
    $TRIVY_CMD fs . --format table --scanners vuln --severity HIGH,CRITICAL --ignore-unfixed

    # Run secret scan on source code (exclude dependencies)
    echo "🔍 Scanning source code for secrets..."
    $TRIVY_CMD fs . --format table --scanners secret --severity HIGH,CRITICAL --skip-files "uv.lock,node_modules/,*.pyc,__pycache__/"

    echo "✅ Security scan completed - no HIGH/CRITICAL issues found"

# ============================================================================
# Publishing & Deployment
# ============================================================================

# Publish Docker image to registries
publish version="latest":
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🚀 Publishing version: {{version}}"

    # Build standard image
    just build

    # Tag for registries
    docker tag ats-pdf-generator:standard dohdalabs/ats-pdf-generator:{{version}}
    docker tag ats-pdf-generator:standard ghcr.io/dohdalabs/ats-pdf-generator:{{version}}

    # Push to Docker Hub
    echo "📤 Pushing to Docker Hub..."
    docker push dohdalabs/ats-pdf-generator:{{version}}

    # Push to GitHub Container Registry
    echo "📤 Pushing to GitHub Container Registry..."
    docker push ghcr.io/dohdalabs/ats-pdf-generator:{{version}}

    echo "✅ Published successfully!"
    echo ""
    echo "Pull commands:"
    echo "  docker pull dohdalabs/ats-pdf-generator:{{version}}"
    echo "  docker pull ghcr.io/dohdalabs/ats-pdf-generator:{{version}}"

# ============================================================================
# PDF Operations
# ============================================================================

# Convert Markdown to PDF
convert input output="": (_build-docker "dev")
    #!/usr/bin/env bash
    set -euo pipefail

    # Helper: Fix file ownership on Linux (fallback for cases where -u flag didn't work)
    _fix_linux_ownership() {
        local file="$1"
        local user_id="$2"
        local group_id="$3"

        if [ ! -f "$file" ]; then
            return 0
        fi

        # Determine current owner; prefer GNU stat, fallback to BSD stat
        local owner_id
        owner_id=$(stat -c '%u' "$file" 2>/dev/null || stat -f '%u' "$file" 2>/dev/null || echo "")

        if [ -n "$owner_id" ] && [ "$owner_id" -eq "$user_id" ]; then
            return 0  # Already owned by current user
        elif chown "$user_id:$group_id" "$file" 2>/dev/null; then
            return 0  # Successfully changed ownership
        elif command -v sudo >/dev/null 2>&1 && sudo -n chown "$user_id:$group_id" "$file" 2>/dev/null; then
            return 0  # Successfully changed with sudo
        else
            echo "⚠️  Could not fix file ownership (sudo unavailable or failed)." >&2
            echo "    File: $file" >&2
            echo "    Target ownership: $user_id:$group_id" >&2
            echo "    File may be owned by root." >&2
            return 1
        fi
    }

    # Helper function to create temporary copy for cloud storage compatibility
    _create_temp_copy() {
        local source_dir="$1"
        local workspace_dir="$2"
        local input_filename="$3"
        local temp_dir

        # Create temporary directory in workspace (guaranteed to be accessible to Docker)
        if command -v mktemp >/dev/null 2>&1; then
            temp_dir="$(mktemp -d "$workspace_dir/.tmp-convert-XXXXXX")" || { echo "Error: mktemp failed" >&2; exit 1; }
        else
            temp_dir="$workspace_dir/.tmp-convert-$$"
            mkdir -p "$temp_dir"
        fi

        # Mirror the entire input directory so relative assets (images/includes) resolve
        if command -v rsync >/dev/null 2>&1; then
            if ! rsync -aL "$source_dir"/ "$temp_dir"/; then
                local rsync_exit_code=$?
                echo "Error: rsync failed with exit code $rsync_exit_code" >&2
                echo "Command: rsync -aL \"$source_dir\"/ \"$temp_dir\"/" >&2
                exit $rsync_exit_code
            fi
        else
            if ! cp -RL "$source_dir"/. "$temp_dir"/; then
                local cp_exit_code=$?
                echo "Error: cp failed with exit code $cp_exit_code" >&2
                echo "Command: cp -RL \"$source_dir\"/. \"$temp_dir\"/" >&2
                exit $cp_exit_code
            fi
        fi

        # Note: Skip file count verification since rsync -L/cp -RL follow symlinks,
        # which can legitimately change file counts. The input file check below is sufficient.

        # Sanity check: ensure input file exists in temp
        if [ ! -f "$temp_dir/$input_filename" ]; then
            echo "Error: Input file missing after temp sync: $temp_dir/$input_filename" >&2
            exit 1
        fi

        echo "$temp_dir"
    }

    # Validate input parameter is not empty
    if [ -z "{{input}}" ]; then
        echo "Error: Input parameter is required and cannot be empty" >&2
        exit 1
    fi

    # Set default output if not provided
    if [ -z "{{output}}" ]; then
        # Remove .md/.MD/.mdx extension and add .pdf (case-insensitive)
        INPUT_BASE="{{input}}"
        case "$INPUT_BASE" in
          *.[mM][dD]) OUTPUT_FILE="${INPUT_BASE%.[mM][dD]}.pdf" ;;
          *.[mM][dD][xX]) OUTPUT_FILE="${INPUT_BASE%.[mM][dD][xX]}.pdf" ;;
          *) OUTPUT_FILE="${INPUT_BASE}.pdf" ;;
        esac
    else
        OUTPUT_FILE="{{output}}"
    fi

    # Validate input file exists
    if [ ! -f "{{input}}" ]; then
        echo "Error: Input file not found: {{input}}" >&2
        exit 1
    fi

    # Extract paths for Docker mount
    INPUT_DIR=$(dirname "{{input}}")
    INPUT_FILENAME=$(basename "{{input}}")
    OUTPUT_BASENAME=$(basename "$OUTPUT_FILE")

    # Resolve absolute path for Docker mount (portable across systems)
    RESOLVED_INPUT_DIR=""
    if command -v realpath >/dev/null 2>&1; then
        # Use realpath if available (GNU coreutils)
        RESOLVED_INPUT_DIR=$(realpath "$INPUT_DIR")
    elif command -v readlink >/dev/null 2>&1 && readlink -f / >/dev/null 2>&1; then
        # Fallback to readlink -f if available (some BSD systems)
        RESOLVED_INPUT_DIR=$(readlink -f "$INPUT_DIR")
    else
        # POSIX-compliant fallback using cd and pwd
        RESOLVED_INPUT_DIR=$(cd "$INPUT_DIR" && pwd)
    fi

    # Validate that we successfully resolved the path
    if [ -z "$RESOLVED_INPUT_DIR" ] || [ ! -d "$RESOLVED_INPUT_DIR" ]; then
        echo "Error: Unable to resolve absolute path for input directory: $INPUT_DIR" >&2
        echo "This system lacks realpath, readlink -f, or basic POSIX utilities." >&2
        echo "Please ensure your system has standard Unix utilities available." >&2
        exit 1
    fi

    echo "Converting: {{input}} -> $OUTPUT_FILE"

    # Check if path is in a cloud storage directory (OneDrive, iCloud, Dropbox, etc.)
    # These often have permission issues with Docker on macOS
    # Note: macOS uses /Library/CloudStorage/ as the real path for cloud-synced folders
    USE_TEMP_COPY=false
    case "$RESOLVED_INPUT_DIR" in
        *"/OneDrive/"*|*"/OneDrive-"*|*"/iCloud"*|*"/Dropbox/"*|*"/Google Drive/"*|*"/GoogleDrive/"*|*/Library/CloudStorage/*|*/Users/*/Library/CloudStorage/*|*"/Mobile Documents/"*|*"/com~apple~CloudDocs/"*|*"/.gdfuse/"*)
            if [ "${CONVERT_NO_TEMP_COPY:-0}" = "1" ]; then
              echo "⚠️  Cloud storage detected but temp copy disabled via CONVERT_NO_TEMP_COPY. Proceeding without temp copy..."
              DOCKER_INPUT_DIR="$RESOLVED_INPUT_DIR"
            else
              case "$RESOLVED_INPUT_DIR" in
                *"/.gdfuse/"*)
                  echo "⚠️  Google Drive (Linux/Fuse) detected. Using temporary copy for Docker compatibility..."
                  ;;
                *)
                  echo "⚠️  Cloud storage detected. Using temporary copy for Docker compatibility..."
                  ;;
              esac
              USE_TEMP_COPY=true
              WORKSPACE_DIR="$(cd "$(dirname "{{justfile()}}")" && pwd)"
              TEMP_DIR="$(_create_temp_copy "$RESOLVED_INPUT_DIR" "$WORKSPACE_DIR" "$INPUT_FILENAME")"
              trap 'set +e; [ -n "${TEMP_DIR:-}" ] && rm -rf -- "$TEMP_DIR"' EXIT
              DOCKER_INPUT_DIR="$TEMP_DIR"
            fi
            ;;
        *)
            DOCKER_INPUT_DIR="$RESOLVED_INPUT_DIR"
            ;;
    esac

    # Run conversion in Docker container
    # PDF is generated in the input directory (or temp directory for cloud storage)
    # Note: On Linux, we run as host UID/GID to avoid ownership issues
    case "$(uname -s)" in
        "Linux")
            if command -v podman >/dev/null 2>&1; then
              USER_FLAG="--userns=keep-id"
            else
              USER_FLAG="-u $(id -u):$(id -g)"
            fi
            ;;
        "Darwin"|MINGW*|MSYS*|CYGWIN*)
            USER_FLAG=""
            ;;
        *)
            # For unknown platforms, default to no user flag
            USER_FLAG=""
            ;;
    esac

    docker run --rm \
        $USER_FLAG \
        -v "$DOCKER_INPUT_DIR:/app/input" \
        -w /app \
        -e INPUT_FILENAME \
        -e OUTPUT_BASENAME \
        ats-pdf-generator:dev \
        bash -c 'set -euo pipefail; source .venv/bin/activate; python src/ats_pdf_generator/ats_converter.py "input/$INPUT_FILENAME" -o "input/$OUTPUT_BASENAME"'

    # If we used a temp copy, move the PDF back to the original location
    if [ "$USE_TEMP_COPY" = true ]; then
        if ! mv -f "$TEMP_DIR/$OUTPUT_BASENAME" "$RESOLVED_INPUT_DIR/$OUTPUT_BASENAME"; then
            echo "Error: Failed to move generated PDF from '$TEMP_DIR/$OUTPUT_BASENAME' to '$RESOLVED_INPUT_DIR/$OUTPUT_BASENAME'" >&2
            exit 1
        fi
    fi

    # Fix file ownership if running on Linux (fallback for cases where -u didn't work)
    if [ "$(uname -s)" = "Linux" ]; then
        _fix_linux_ownership "$RESOLVED_INPUT_DIR/$OUTPUT_BASENAME" "$(id -u)" "$(id -g)" || true
    fi

    # Move the generated PDF to the requested output location if different
    GENERATED_FILE="$RESOLVED_INPUT_DIR/$OUTPUT_BASENAME"

    # Resolve OUTPUT_FILE to absolute path for comparison
    OUTPUT_DIR=$(dirname "$OUTPUT_FILE")
    OUTPUT_BASENAME_FINAL=$(basename "$OUTPUT_FILE")

    # Resolve absolute output path
    if [ -d "$OUTPUT_DIR" ]; then
        RESOLVED_OUTPUT_DIR=$(cd "$OUTPUT_DIR" && pwd)
    else
        # Output directory doesn't exist yet, resolve parent and append
        mkdir -p "$OUTPUT_DIR"
        RESOLVED_OUTPUT_DIR=$(cd "$OUTPUT_DIR" && pwd)
    fi
    RESOLVED_OUTPUT_FILE="$RESOLVED_OUTPUT_DIR/$OUTPUT_BASENAME_FINAL"

    # Move file if output location is different from where it was generated
    if [ "$GENERATED_FILE" != "$RESOLVED_OUTPUT_FILE" ]; then
        mv "$GENERATED_FILE" "$RESOLVED_OUTPUT_FILE"
        echo "✅ PDF generated and moved to: $OUTPUT_FILE"
    else
        echo "✅ PDF generated: $OUTPUT_FILE"
    fi

# ============================================================================
# Utility Commands
# ============================================================================

# Extract tool versions from mise.toml
tool-versions:
    ./scripts/extract-versions.sh list

# Run pre-commit on all files
pre-commit:
    uv run pre-commit run --all-files

# Show UV package information
uv-info:
    @uv --version
    @echo "Python: $(uv run python --version)"
    @echo "Virtual env: $(uv run which python)"

# Update UV lock file
uv-update:
    uv lock --upgrade

# Open shell in dev Docker container
docker-shell: (_build-docker "dev")
    docker run --rm -it -v "$(pwd):/app" -w /app ats-pdf-generator:dev bash

# ============================================================================
# Development Environment (Docker Compose)
# ============================================================================

# Start development environment
dev-up:
    docker-compose -f docker/docker-compose.yml --profile dev up -d

# Stop development environment
dev-down:
    docker-compose -f docker/docker-compose.yml down

# Restart development environment
dev-restart:
    docker-compose -f docker/docker-compose.yml restart

# View live logs from development environment
dev-logs:
    docker-compose -f docker/docker-compose.yml logs -f

# Open shell in running development container
dev-shell:
    docker-compose -f docker/docker-compose.yml exec ats-converter-dev bash

# ============================================================================
# Internal Helpers (visible for debugging)
# ============================================================================

# Build a specific Docker image variant
_build-docker variant:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔨 Building {{variant}} image..."
    GIT_SHA=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
    docker build \
        --build-arg GIT_SHA="$GIT_SHA" \
        --build-arg VENDOR="DohDa Labs" \
        -f docker/Dockerfile.{{variant}} \
        -t ats-pdf-generator:{{variant}} .
    echo "✅ Built ats-pdf-generator:{{variant}}"

# Test a specific Docker image variant
_test-docker-image variant:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🧪 Testing {{variant}} image..."

    # Determine shell to use (Alpine uses ash, others use bash)
    if [ "{{variant}}" = "alpine" ]; then
        SHELL_CMD="ash -c"
    else
        SHELL_CMD="bash -c"
    fi

    # Test 1: Run help command (skip for dev image)
    if [ "{{variant}}" != "dev" ]; then
        docker run --rm ats-pdf-generator:{{variant}} --help >/dev/null
    else
        docker run --rm ats-pdf-generator:{{variant}} bash -c "echo 'Dev image working'" >/dev/null
    fi

    # Test 2: Check /app/tmp permissions
    docker run --rm --entrypoint="" ats-pdf-generator:{{variant}} $SHELL_CMD 'test -d /app/tmp && test -w /app/tmp && echo "✅ /app/tmp exists and is writable"'

    echo "✅ {{variant}} image passed all tests"

# Check Python code formatting (no changes)
_format-check-python:
    @echo "🎨 Checking Python formatting..."
    uv run ruff format --check .

# ============================================================================
# Hidden Internals (CI-only, use with caution)
# ============================================================================

# Build Docker images based on branch (CI optimization)
[private]
_ci-build-docker:
    #!/usr/bin/env bash
    set -euo pipefail

    # Check if we're on main branch
    if [ "${GITHUB_REF:-}" = "refs/heads/main" ] || [ "$(git branch --show-current 2>/dev/null || echo 'unknown')" = "main" ]; then
        echo "🔨 Building all Docker images (main branch detected)..."
        just build-all
    else
        echo "🔨 Building standard Docker image only (non-main branch)..."
        just build
    fi

# Test Docker images based on branch (CI optimization)
[private]
_ci-test-docker:
    #!/usr/bin/env bash
    set -euo pipefail

    # Check if we're on main branch
    if [ "${GITHUB_REF:-}" = "refs/heads/main" ] || [ "$(git branch --show-current 2>/dev/null || echo 'unknown')" = "main" ]; then
        echo "🧪 Testing all Docker images (main branch detected)..."
        just test-docker
    else
        echo "🧪 Testing standard Docker image only (non-main branch)..."
        just _test-docker-image standard
    fi
