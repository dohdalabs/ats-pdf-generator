#!/bin/bash

# Development setup script for contributors who don't use mise
# This is an alternative to using mise for development

set -e

echo "🚀 Setting up development environment..."

# Check if Python 3.13+ is available
python_version=$(python3 --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
required_version="3.13"

if [ "$(printf '%s\n' "$required_version" "$python_version" | sort -V | head -n1)" != "$required_version" ]; then
    echo "❌ Python 3.13+ is required. Found: $python_version"
    echo "💡 Consider using mise: curl https://mise.run | sh"
    exit 1
fi

# Check if uv is available
if ! command -v uv &> /dev/null; then
    echo "📦 Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    # shellcheck source=/dev/null
    source ~/.bashrc 2>/dev/null || source ~/.zshrc 2>/dev/null || true
fi

# Create virtual environment and install dependencies
echo "📦 Installing dependencies..."
uv venv
source .venv/bin/activate
uv pip install .[dev]

# Setup pre-commit
echo "🔧 Setting up pre-commit hooks..."
pre-commit install
pre-commit install --hook-type commit-msg

echo "✅ Development environment setup complete!"
echo ""
echo "Available commands:"
echo "  ruff check .                    # Run linting"
echo "  ruff format .                   # Format code"
echo "  mypy src/                       # Run type checking"
echo "  pytest                          # Run tests"
echo "  pre-commit run --all-files      # Run all pre-commit hooks"
echo ""
echo "💡 Remember to activate the virtual environment:"
echo "   source .venv/bin/activate"
