#!/bin/bash

# Docker Build Script with Size Output
# Builds the dev container and shows the final image size

set -e

echo "🔨 Building Docker dev container..."

# Build the container
docker build --no-cache -f docker/Dockerfile.dev -t ats-pdf-generator:dev .

echo ""
echo "📦 Container image size:"
docker images ats-pdf-generator:dev --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}'

echo ""
echo "✅ Build completed successfully!"
