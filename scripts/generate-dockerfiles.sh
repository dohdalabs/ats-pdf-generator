#!/bin/bash
#
# Generate Dockerfiles Script
#
# SYNOPSIS
#     generate-dockerfiles.sh
#
# DESCRIPTION
#     Creates Dockerfiles with shared patterns and validates them before completion.
#     Generates Alpine and Standard Dockerfiles for the ATS PDF Generator project
#     with optimized multi-stage builds and proper security practices.
#
# OPTIONS
#     None
#
# PREREQUISITES
#     None (self-contained script)
#
# EXAMPLES
#     generate-dockerfiles.sh                    # Generate all Dockerfiles
#
# EXIT STATUS
#     0    All Dockerfiles generated and validated successfully
#     1    Generation or validation failed
#
# AUTHOR
#     Generated for ats-pdf-generator project
#
# SEE ALSO
#     validate-dockerfiles.sh(1), hadolint(1)

set -euo pipefail

# Show usage if help requested
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    cat << EOF
Generate Dockerfiles Script

SYNOPSIS
    $0 [--help|-h]

DESCRIPTION
    Creates Dockerfiles with shared patterns and validates them before completion.
    Generates Alpine and Standard Dockerfiles for the ATS PDF Generator project
    with optimized multi-stage builds and proper security practices.

OPTIONS
    --help, -h    Show this help message and exit

PREREQUISITES
    None (self-contained script)

EXAMPLES
    $0                    # Generate all Dockerfiles
    $0 --help            # Show this help

EXIT STATUS
    0    All Dockerfiles generated and validated successfully
    1    Generation or validation failed

AUTHOR
    Generated for ats-pdf-generator project

SEE ALSO
    validate-dockerfiles.sh(1), hadolint(1)
EOF
    exit 0
fi

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Print informational message with blue prefix
# Arguments: $1 - message to display
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Print success message with green prefix
# Arguments: $1 - message to display
log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Print error message with red prefix
# Arguments: $1 - message to display
log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Common Dockerfile header
cat > docker/Dockerfile.alpine.new << 'EOF'
# ATS Document Converter - Alpine Linux Version
# Ultra-minimal image using Alpine Linux

FROM python:3.13-alpine AS builder

# Set shell with pipefail for better error handling
SHELL ["/bin/sh", "-o", "pipefail", "-c"]

# Install build dependencies and uv
RUN apk add --no-cache \
    build-base \
    pkgconfig \
    cairo-dev \
    pango-dev \
    gdk-pixbuf-dev \
    libffi-dev \
    jpeg-dev \
    libpng-dev \
    freetype-dev \
    harfbuzz-dev \
    fribidi-dev \
    musl-dev \
    curl

# Install uv using the official installer (faster and more reliable)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:$PATH"

# Verify uv installation
RUN uv --version

# Set up project
WORKDIR /build
COPY pyproject.toml uv.lock ./
COPY src/ ./src/
RUN printf '# ATS PDF Generator\n\nConvert Markdown documents to ATS-optimized PDFs for job applications.\n' > README.md

# Create virtual environment and install dependencies using uv sync
RUN uv sync --frozen --no-dev

# Stage 2: Runtime stage
FROM python:3.13-alpine

# Set shell with pipefail for better error handling
SHELL ["/bin/sh", "-o", "pipefail", "-c"]

# Install runtime dependencies
RUN apk add --no-cache \
    pandoc \
    fontconfig \
    ttf-liberation \
    ttf-dejavu \
    ghostscript \
    cairo \
    pango \
    gdk-pixbuf \
    libffi \
    jpeg \
    libpng \
    freetype \
    harfbuzz \
    fribidi \
    fontconfig-dev \
    && fc-cache -fv

# Copy virtual environment from builder
COPY --from=builder /build/.venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

# Create app directory
WORKDIR /app

# Create directories for input/output (CRITICAL: This was missing in original!)
RUN mkdir -p /app/input /app/output /app/templates /app/css /app/tmp

# Create a non-root user
RUN adduser -D converter && \
    chown -R converter:converter /app

# Copy the Python script (WORKDIR is already set)
COPY --chown=converter:converter src/ats_pdf_generator/ats_converter.py ./

# Make the script executable
RUN chmod +x /app/ats_converter.py

# Verify the file exists and is executable
RUN ls -la /app/ats_converter.py

# Switch to non-root user
USER converter

# Set the entrypoint
ENTRYPOINT ["python3", "/app/ats_converter.py"]

# Default command (can be overridden)
CMD ["--help"]
EOF

log_success "Generated Alpine Dockerfile"

# Common Dockerfile header for standard
cat > docker/Dockerfile.standard.new << 'EOF'
# ATS Document Converter - Standard Version
# Debian slim-based image with standard dependencies

FROM python:3.13-slim AS builder

# Set shell with pipefail for better error handling
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install build dependencies and uv
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    pkg-config \
    libcairo2-dev \
    libpango1.0-dev \
    libgdk-pixbuf-xlib-2.0-dev \
    libffi-dev \
    libjpeg-dev \
    libpng-dev \
    libfreetype6-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install uv using the official installer (faster and more reliable)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:$PATH"

# Verify uv installation
RUN uv --version

# Set up project
WORKDIR /build
COPY pyproject.toml uv.lock ./
COPY src/ ./src/
RUN printf '# ATS PDF Generator\n\nConvert Markdown documents to ATS-optimized PDFs for job applications.\n' > README.md

# Create virtual environment and install dependencies using uv sync
RUN uv sync --frozen --no-dev

# Stage 2: Runtime stage
FROM python:3.13-slim

# Set shell with pipefail for better error handling
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    pandoc \
    fonts-liberation \
    fonts-noto-color-emoji \
    fonts-dejavu-core \
    ghostscript \
    libcairo2 \
    libpango-1.0-0 \
    libgdk-pixbuf-xlib-2.0-0 \
    libffi8 \
    libjpeg62-turbo \
    libpng16-16 \
    libfreetype6 \
    libharfbuzz0b \
    libfribidi0 \
    libpangoft2-1.0-0 \
    libpangocairo-1.0-0 \
    libgobject-2.0-0 \
    libglib-2.0-0 \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Copy virtual environment from builder
COPY --from=builder /build/.venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

# Create app directory
WORKDIR /app

# Create directories for input/output (CRITICAL: This was missing in original!)
RUN mkdir -p /app/input /app/output /app/templates /app/css /app/tmp

# Create a non-root user
RUN useradd -m -s /bin/bash converter && \
    chown -R converter:converter /app

# Copy the Python script (WORKDIR is already set)
COPY --chown=converter:converter src/ats_pdf_generator/ats_converter.py ./

# Make the script executable
RUN chmod +x /app/ats_converter.py

# Verify the file exists and is executable
RUN ls -la /app/ats_converter.py

# Switch to non-root user
USER converter

# Set the entrypoint
ENTRYPOINT ["python3", "/app/ats_converter.py"]

# Default command (can be overridden)
CMD ["--help"]
EOF

log_success "Generated Standard Dockerfile"

# Validate the generated Dockerfiles using hadolint
log_info "Validating generated Dockerfiles with hadolint..."

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if validate-dockerfiles.sh script exists
if [ ! -f "$SCRIPT_DIR/validate-dockerfiles.sh" ]; then
    log_error "validate-dockerfiles.sh script not found in $SCRIPT_DIR. Cannot validate Dockerfiles."
    exit 1
fi

# Collect generated Dockerfiles to validate
validation_files=()
if [ -f "docker/Dockerfile.alpine.new" ]; then
    validation_files+=("docker/Dockerfile.alpine.new")
fi
if [ -f "docker/Dockerfile.standard.new" ]; then
    validation_files+=("docker/Dockerfile.standard.new")
fi
if [ -f "docker/Dockerfile.dev.new" ]; then
    validation_files+=("docker/Dockerfile.dev.new")
fi

# Run the validation script with specific files
if [ ${#validation_files[@]} -gt 0 ]; then
    if ! "$SCRIPT_DIR/validate-dockerfiles.sh" "${validation_files[@]}"; then
        log_error "Dockerfile validation failed"
        exit 1
    fi
else
    log_warning "No generated Dockerfiles found to validate"
fi

log_success "All generated Dockerfiles passed validation!"

log_info "Generated new Dockerfiles with shared patterns:"
log_info "  - docker/Dockerfile.alpine.new"
log_info "  - docker/Dockerfile.standard.new"
log_info "  - docker/Dockerfile.dev.new (if exists)"

log_info "Next steps:"
log_info "  1. Test the new Dockerfiles"
log_info "  2. Replace old Dockerfiles if tests pass"
log_info "  3. Update build scripts to use new files"
