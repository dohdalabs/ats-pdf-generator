#!/bin/bash

# Docker Build Script with Size Output
# Builds the dev container and shows the final image size

set -e

echo "🔨 Building Docker dev container..."

# Get git SHA for build argument
GIT_SHA=$(git rev-parse HEAD 2>/dev/null || echo "unknown")

# Build the container
docker build --no-cache \
  --build-arg GIT_SHA="$GIT_SHA" \
  --build-arg VENDOR="DohDa Labs" \
  -f docker/Dockerfile.dev \
  -t ats-pdf-generator:dev .

echo ""
echo "📦 Container image size:"
docker images ats-pdf-generator:dev --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}'

echo ""
echo "✅ Build completed successfully!"
