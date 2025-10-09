# justfile - Task runner for ats-pdf-generator
# See: https://github.com/casey/just

# Set shell for all recipes
set shell := ["bash", "-uc"]

# Variables
export CI := env_var_or_default("CI", "false")
export UV_COMPILE_BYTECODE := "1"
export UV_CACHE_DIR := "~/.cache/uv"

# Show available recipes
@default:
    just --list

# ============================================================================
# Environment Setup
# ============================================================================

# Install all dependencies and setup dev environment
install:
    @echo "🚀 Installing dependencies..."
    uv sync --dev
    pnpm install
    pre-commit install
    pre-commit install --hook-type commit-msg
    @echo "✅ Development environment ready!"
    @echo ""
    @echo "Available commands:"
    @echo "  just --list              # Show all available tasks"
    @echo "  just ci                  # Run all quality checks (same as CI)"
    @echo "  just test                # Run tests"
    @echo "  just format              # Auto-fix formatting"

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

# Run Python tests with coverage
test-python:
    @echo "🧪 Running Python tests..."
    uv run pytest --cov=src --cov-report=xml --cov-report=term-missing

# Complete Python quality checks
check-python: lint-python check-format-python typecheck-python test-python

# ============================================================================
# Shell Script Quality Checks
# ============================================================================

# Lint shell scripts
lint-shell:
    @echo "🐚 Linting shell scripts..."
    -shellcheck scripts/*.sh 2>/dev/null || true
    @echo "✅ Shell linting completed (warnings non-fatal)"

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

    # Test Alpine image
    echo "Testing alpine image..."
    SHELL_CMD="ash -c"
    docker run --rm ats-pdf-generator:alpine --help >/dev/null
    docker run --rm --entrypoint="" ats-pdf-generator:alpine $SHELL_CMD 'test -d /app/tmp && test -w /app/tmp && echo "✅ /app/tmp exists and is writable"'
    echo "✅ alpine image passed all tests"

    # Test Standard image
    echo "Testing standard image..."
    SHELL_CMD="bash -c"
    docker run --rm ats-pdf-generator:standard --help >/dev/null
    docker run --rm --entrypoint="" ats-pdf-generator:standard $SHELL_CMD 'test -d /app/tmp && test -w /app/tmp && echo "✅ /app/tmp exists and is writable"'
    echo "✅ standard image passed all tests"

    # Test Dev image
    echo "Testing dev image..."
    SHELL_CMD="bash -c"
    docker run --rm ats-pdf-generator:dev bash -c "echo 'Dev image working'" >/dev/null
    docker run --rm --entrypoint="" ats-pdf-generator:dev $SHELL_CMD 'test -d /app/tmp && test -w /app/tmp && echo "✅ /app/tmp exists and is writable"'
    echo "✅ dev image passed all tests"

    echo "✅ All Docker tests passed!"

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
    @echo "📝 Linting Markdown files..."
    pnpm markdownlint '**/*.{md,mdc}' --config=.markdownlint.jsonc

# Format Markdown files
format-markdown:
    @echo "📝 Formatting Markdown files..."
    pnpm markdownlint '**/*.{md,mdc}' --config=.markdownlint.jsonc --fix

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

    # Run scan with SARIF output for GitHub Actions (includes secrets scanning)
    $TRIVY_CMD fs . --format sarif --output trivy-results.sarif --scanners vuln,secret --severity HIGH,CRITICAL --ignore-unfixed || {
        echo "⚠️  Security scan found issues (non-fatal)"
        exit 0
    }

    # Run vulnerability scan on dependencies
    echo "🔍 Scanning dependencies for vulnerabilities..."
    $TRIVY_CMD fs . --format table --scanners vuln --severity HIGH,CRITICAL --ignore-unfixed || {
        echo "⚠️  Vulnerability scan found issues (non-fatal)"
        exit 0
    }

    # Run secret scan on source code (exclude dependencies)
    echo "🔍 Scanning source code for secrets..."
    $TRIVY_CMD fs . --format table --scanners secret --severity HIGH,CRITICAL --skip-files "uv.lock,node_modules/,*.pyc,__pycache__/" || {
        echo "⚠️  Secret scan found issues (non-fatal)"
        exit 0
    }

    echo "✅ Security scan completed"

# ============================================================================
# Combined Quality Checks
# ============================================================================

# Run all linting checks
lint: lint-python lint-shell lint-markdown

# Run all formatting
format: format-python format-markdown

# Run all tests
test: test-python docker-test

# Run complete quality checks (what CI runs)
ci: lint check-format-python typecheck-python test security
    @echo ""
    @echo "✅ All CI checks passed!"

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
    if [ -z "{{output}}" ]; then
        ./scripts/convert-pdf.sh "{{input}}"
    else
        ./scripts/convert-pdf.sh "{{input}}" -o "{{output}}"
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
docker-shell:
    docker run --rm -it -v "$(pwd):/app" -w /app ats-pdf-generator:dev bash
