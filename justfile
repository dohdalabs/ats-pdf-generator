# justfile - Task runner for ats-pdf-generator
# See: https://github.com/casey/just

# Set shell for all recipes
set shell := ["bash", "-uc"]

# Variables
export CI := env_var_or_default("CI", "false")
export UV_COMPILE_BYTECODE := "1"
export UV_CACHE_DIR := "$HOME/.cache/uv"

# Show available recipes
@default:
    just --list

# ============================================================================
# Environment Setup
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
    echo "  just security            # Run security scan (warning mode)"
    echo "  just security-strict     # Run security scan (strict mode)"
    echo ""
    echo "Security scan modes:"
    echo "  • Warning mode (default): Security issues are reported but don't fail CI"
    echo "  • Strict mode: Security issues will fail CI and prevent merges"
    echo "  • Set CI_STRICT_SECURITY=true to enable strict mode globally"

# Install production dependencies only
install-prod:
    uv sync --frozen --no-dev

# Setup local environment (for non-mise users)
setup-local:
    ./scripts/setup-local-env.sh

# ============================================================================
# Python Quality Checks
# ============================================================================

# Lint Python code with ruff
lint-python:
    @echo "🔍 Linting Python code..."
    uv run ruff check .

# Check Python code formatting
check-format-python:
    @echo "🎨 Checking Python formatting..."
    uv run ruff format --check .

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

# Complete Python quality checks
check-python: lint-python check-format-python typecheck-python check-docstrings test-python security-python

# ============================================================================
# Shell Script Quality Checks
# ============================================================================

# Lint shell scripts
lint-shell:
    @echo "🐚 Linting shell scripts..."
    -shellcheck -x scripts/*.sh 2>/dev/null || true
    @echo "✅ Shell linting completed (warnings non-fatal)"
    @echo "ℹ️  Note: SC1091 warnings about utils/ files are expected and non-fatal"

# ============================================================================
# Docker Operations
# ============================================================================

# Build a specific Docker image variant
docker-build variant="standard":
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

# Build all Docker image variants
docker-build-all:
    @echo "🔨 Building all Docker images..."
    just docker-build alpine
    just docker-build standard
    just docker-build dev
    @echo "✅ All images built successfully!"

# Build Docker images based on branch (CI optimization)
docker-build-ci:
    #!/usr/bin/env bash
    set -euo pipefail

    # Check if we're on main branch
    if [ "${GITHUB_REF:-}" = "refs/heads/main" ] || [ "$(git branch --show-current 2>/dev/null || echo 'unknown')" = "main" ]; then
        echo "🔨 Building all Docker images (main branch detected)..."
        just docker-build-all
    else
        echo "🔨 Building standard Docker image only (non-main branch)..."
        just docker-build standard
    fi

# Test a specific Docker image
docker-test-image variant:
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

# Test all Docker images
docker-test:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🧪 Testing all Docker images..."

    # Test each image variant using the centralized docker-test-image recipe
    just docker-test-image alpine
    just docker-test-image standard
    just docker-test-image dev

    echo "✅ All Docker tests passed!"

# Test Docker images based on branch (CI optimization)
docker-test-ci:
    #!/usr/bin/env bash
    set -euo pipefail

    # Check if we're on main branch
    if [ "${GITHUB_REF:-}" = "refs/heads/main" ] || [ "$(git branch --show-current 2>/dev/null || echo 'unknown')" = "main" ]; then
        echo "🧪 Testing all Docker images (main branch detected)..."
        just docker-test
    else
        echo "🧪 Testing standard Docker image only (non-main branch)..."
        just docker-test-image standard
    fi

# Validate Dockerfiles with hadolint
docker-validate:
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
    @docker images ats-pdf-generator --format "table {{{{.Repository}}}}\t{{{{.Tag}}}}\t{{{{.Size}}}}\t{{{{.CreatedSince}}}}" 2>/dev/null || echo "No images found. Run 'just docker-build-all' to create them."

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

# Run security scan with Trivy
security:
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

    # Check if strict security mode is enabled
    if [ "${CI_STRICT_SECURITY:-false}" = "true" ]; then
        echo "🔒 Running in STRICT security mode - failures will stop CI"
        SECURITY_MODE="strict"
    else
        echo "🔒 Running in WARNING security mode - failures are non-fatal"
        SECURITY_MODE="warning"
    fi

    # Run scan with SARIF output for GitHub Actions (includes secrets scanning)
    if [ "$SECURITY_MODE" = "strict" ]; then
        $TRIVY_CMD fs . --format sarif --output trivy-results.sarif --scanners vuln,secret --severity HIGH,CRITICAL --ignore-unfixed
    else
        $TRIVY_CMD fs . --format sarif --output trivy-results.sarif --scanners vuln,secret --severity HIGH,CRITICAL --ignore-unfixed || {
            echo "⚠️  Security scan found issues (non-fatal)"
            exit 0
        }
    fi

    # Run vulnerability scan on dependencies
    echo "🔍 Scanning dependencies for vulnerabilities..."
    if [ "$SECURITY_MODE" = "strict" ]; then
        $TRIVY_CMD fs . --format table --scanners vuln --severity HIGH,CRITICAL --ignore-unfixed
    else
        $TRIVY_CMD fs . --format table --scanners vuln --severity HIGH,CRITICAL --ignore-unfixed || {
            echo "⚠️  Vulnerability scan found issues (non-fatal)"
            exit 0
        }
    fi

    # Run secret scan on source code (exclude dependencies)
    echo "🔍 Scanning source code for secrets..."
    if [ "$SECURITY_MODE" = "strict" ]; then
        $TRIVY_CMD fs . --format table --scanners secret --severity HIGH,CRITICAL --skip-files "uv.lock,node_modules/,*.pyc,__pycache__/"
    else
        $TRIVY_CMD fs . --format table --scanners secret --severity HIGH,CRITICAL --skip-files "uv.lock,node_modules/,*.pyc,__pycache__/" || {
            echo "⚠️  Secret scan found issues (non-fatal)"
            exit 0
        }
    fi

    echo "✅ Security scan completed"

# Run security scan in strict mode (failures will stop CI)
security-strict:
    #!/usr/bin/env bash
    CI_STRICT_SECURITY=true just security

# ============================================================================
# Combined Quality Checks
# ============================================================================

# Run all linting checks
lint: lint-python lint-shell lint-markdown

# Run all formatting
format: format-python format-markdown

# Run all tests
test: test-python docker-test

# Run quick quality checks (fast local development)
quick-check: lint check-format-python typecheck-python test-python security
    @echo ""
    @echo "✅ Quick checks passed!"

# Run complete CI pipeline (same as GitHub Actions)
ci: lint check-format-python typecheck-python test-python security docker-build-ci docker-test-ci docker-validate
    @echo ""
    @echo "✅ Complete CI pipeline passed!"
    @echo "This matches what GitHub Actions runs."

# ============================================================================
# Publishing & Deployment
# ============================================================================

# Publish Docker image to registries
publish version="latest":
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🚀 Publishing version: {{version}}"

    # Build standard image
    just docker-build standard

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
convert input output="":
    #!/usr/bin/env bash
    set -euo pipefail

    # Validate input parameter is not empty
    if [ -z "{{input}}" ]; then
        echo "Error: Input parameter is required and cannot be empty" >&2
        exit 1
    fi

    # Set default output if not provided
    if [ -z "{{output}}" ]; then
        # Remove .md extension and add .pdf
        INPUT_BASE="{{input}}"
        OUTPUT_FILE="${INPUT_BASE%.md}.pdf"
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

    # Run conversion in Docker container
    docker run --rm \
        -v "$RESOLVED_INPUT_DIR:/app/input" \
        -w /app \
        ats-pdf-generator:dev \
        bash -c "source .venv/bin/activate && python src/ats_pdf_generator/ats_converter.py input/$INPUT_FILENAME -o input/$OUTPUT_BASENAME"

    echo "✅ PDF generated: $OUTPUT_FILE"

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
docker-shell:
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
