#!/bin/bash

# Generate Dockerfiles Script
# Creates optimized Dockerfiles with shared patterns to reduce duplication

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
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

# Common Dockerfile header for optimized
cat > docker/Dockerfile.optimized.new << 'EOF'
# ATS Document Converter - Optimized Version
# Debian slim-based image with minimal dependencies

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

log_success "Generated Optimized Dockerfile"

log_info "Generated new Dockerfiles with shared patterns:"
log_info "  - docker/Dockerfile.alpine.new"
log_info "  - docker/Dockerfile.optimized.new"
log_info "  - docker/Dockerfile.dev.new (already created)"

log_info "Next steps:"
log_info "  1. Test the new Dockerfiles"
log_info "  2. Replace old Dockerfiles if tests pass"
log_info "  3. Update build scripts to use new files"
