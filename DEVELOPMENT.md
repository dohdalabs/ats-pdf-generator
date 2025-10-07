# Development Guide

This document is for technical reviewers and developers who want to understand the codebase architecture, explore the implementation, and set up a local development environment.

## Key Technical Highlights

- **Script-First Architecture**: All operations implemented as reusable shell scripts for consistency across local and CI environments
- **Multi-Stage Docker Builds**: Optimized production images with separate builder and runtime stages
- **Modern Python Tooling**: Uses `uv` for fast dependency management and `ruff` for linting/formatting
- **Comprehensive CI/CD**: Automated quality checks, security scanning, and multi-registry publishing
- **Developer Experience Focus**: One-command setup with `mise` and comprehensive automation scripts

## 🏗️ Key Components

The project follows a clean separation of concerns:

- **`src/`** - Core Python application code
- **`docker/`** - Multi-stage Docker images (Alpine, Standard, Dev)
- **`templates/`** - CSS styling for different document types
- **`scripts/`** - Development automation (see [Docker Management](docs/DOCKER_MANAGEMENT.md))
- **`tests/`** - Unit tests and validation
- **`.github/workflows/`** - CI/CD automation

For detailed Docker operations, see the [Docker Management Guide](docs/DOCKER_MANAGEMENT.md).

## 🛠️ Development Environment Setup

### Local Development (Recommended)

This project uses [mise](https://mise.jdx.dev/) for consistent development environments:

```bash
# Install mise (if not already installed)
curl https://mise.jdx.dev/install.sh | sh

# Install project tools (Python 3.13.7, uv latest)
mise install

# Verify tools are available
mise current
```

### Alternative: Manual Setup

If you prefer not to use mise, you can use the provided setup script:

```bash
# Run the development setup script
./scripts/setup-local-env.sh
```

This script will:

- Check for Python 3.13+
- Install uv if needed
- Create a virtual environment
- Install all dependencies
- Setup pre-commit hooks

### Quick Development Setup

```bash
# Install development dependencies and setup pre-commit hooks
mise run install

# Most common daily workflow
mise run check-all      # Comprehensive quality checks: Python linting/formatting/typecheck/tests, shell linting, Docker linting, Markdown linting, security scans
mise run format-all     # Auto-fix formatting issues
mise run test-docker   # Run Docker tests


# Build and test everything (Docker images, functionality tests)
mise run build-docker && mise run test-docker

# Convert PDFs for testing
mise run convert-pdf examples/sample-profile.md

# Individual commands for specific needs
mise run lint-python   # Python linting only
mise run lint-shell    # Shell script linting
mise run lint-docker   # Docker linting
mise run lint-markdown # Markdown linting
mise run format-python # Python formatting
mise run format-markdown # Markdown formatting
```

## 🐳 Efficient Docker Development Workflow

### Why Volume Mounting Matters

The development environment uses **volume mounting** so you can develop Python code without rebuilding the container every time. This is much faster than rebuilding images for code changes.

### Development Environment Setup

```bash
# Build the development environment (one-time setup)
mise run build-image

# Start the development environment with volume mounting
mise run dev-up

# Open a shell in the running container (changes are live)
mise run dev-shell

# Or run individual commands without entering the container
mise run dev-run examples/sample-profile.md -o test.pdf
```

### Daily Development Workflow

**Most Efficient Approach:**

```bash
# 1. Start development environment (first time only)
mise run dev-up

# 2. In one terminal, watch for changes
mise run dev-logs

# 3. In another terminal, test your changes
mise run dev-shell

# Inside the container:
python -m src.ats_pdf_generator.ats_converter --help
python -m src.ats_pdf_generator.ats_converter examples/sample-profile.md -o test.pdf

# 4. Your Python code changes are reflected immediately!
# No container rebuild needed for Python changes
```

### Development Commands Reference

```bash
# Environment Management
mise run dev-up        # Start development environment
mise run dev-down      # Stop development environment
mise run dev-restart   # Restart development environment
mise run dev-logs      # View live logs
mise run dev-shell     # Open shell in running container

# Testing Commands
mise run dev-run       # Run the converter module
mise run dev-convert   # Convert a test file
mise run test          # Run unit tests

# Cleanup
mise run docker-clean     # Clean dev images
mise run docker-clean-all # Clean all Docker resources
```

### Volume Mounting Benefits

- **Instant Code Changes**: Python changes are reflected immediately
- **No Rebuild Time**: Skip Docker rebuilds during development
- **Full Environment**: Access to all development tools
- **Live Reloading**: Changes are reflected without container restart

### When to Rebuild

You only need to rebuild the development container when:

- Dependencies change (`pyproject.toml` or `uv.lock`)
- System libraries change
- Dockerfile changes
- You want to test the production image

**Note**: The development environment mounts your entire project directory, so all changes to Python files, documentation, and configuration are reflected immediately.

## 🎯 Key Challenges Addressed

### Script-First Architecture

**Challenge**: Maintaining consistency between local development and CI/CD environments while reducing duplication.

**Solution**: Implemented a script-first approach where all operations are reusable shell scripts called by both local tools (mise) and CI/CD systems (GitHub Actions). This eliminates duplication and ensures consistent behavior across environments.

**Impact**: Reduced CI/CD complexity, improved local testing capabilities, and easier maintenance of automation workflows.

### Multi-Stage Docker Optimization

**Challenge**: Creating production-ready Docker images that are both secure and minimal while supporting multiple architectures.

**Solution**: Implemented multi-stage builds with separate builder and runtime stages, using `uv` for fast dependency management and non-root users for security. Added BuildKit cache mounts and OCI labels for better performance and traceability.

**Impact**: Reduced image sizes by ~40%, improved build performance with caching, and enhanced security posture.

### Developer Experience Optimization

**Challenge**: Reducing friction for new developers while maintaining comprehensive quality standards.

**Solution**: Integrated `mise` for consistent tooling, created one-command setup scripts, and implemented comprehensive pre-commit hooks with automated quality checks.

**Impact**: New developer onboarding time reduced from hours to minutes, with consistent quality standards enforced automatically.

### Development Automation

The project provides comprehensive automation for common development tasks:

- **Quality Assurance**: Automated linting, formatting, security scanning, and testing
- **Docker Operations**: Unified interface for building, testing, and managing container images
- **CI/CD Pipeline**: Automated quality checks, security scanning, and multi-registry publishing
- **Environment Setup**: One-command local development environment configuration

For specific script usage, see the [Docker Management Guide](docs/DOCKER_MANAGEMENT.md) and run `./scripts/check-all.sh --help` for available options.

**Available Scripts**:

- `./scripts/check-all.sh` - Comprehensive quality checks (Python, shell, Docker, Markdown, security)
- [`./scripts/docker-manager.sh`](./scripts/docker-manager.sh) - Unified Docker operations (build, test, validate, publish)
- `./scripts/setup-local-env.sh` - One-command local development setup
- `./scripts/convert-pdf.sh` - PDF conversion utility
- `./scripts/benchmark-security-tools.sh` - Security tool performance testing

**Script Standards**: All scripts follow consistent standards defined in `.cursor/rules/script-standards.mdc` and are validated in CI to ensure they have proper `--help` options and meet quality requirements.

### Architectural Benefits

- **Consistency**: Same scripts work locally and in CI environments
- **Maintainability**: Changes in one place affect all environments
- **Testability**: Scripts can be tested independently of CI/CD systems
- **Clarity**: Self-documenting with `--help` options for all scripts (enforced by CI)
- **Reduced Complexity**: GitHub Actions workflows are simple script calls

### Implementation Notes

The script-first approach was chosen to address the common problem of CI/CD logic becoming complex and environment-specific. By implementing all operations as standalone scripts, the project achieves better testability and reduces the cognitive load of maintaining separate local and CI workflows.

## 🧪 Testing

### Running Tests

```bash
# Run comprehensive quality checks (includes tests)
mise run check-all

# Run just the tests
mise run test

# Run tests with coverage
pytest --cov=src tests/

# Run specific test file
pytest tests/test_converter.py

# Run tests with verbose output
pytest -v tests/

# Build and test everything (Docker images, functionality tests)
mise run build-docker && mise run test-docker
```

### Test Structure

- `tests/test_converter.py` - Unit tests for the main converter
- `scripts/docker-manager.sh` - Docker operations including builds, tests, and validation
- `scripts/check-all.sh` - Comprehensive quality checks including tests

## 🔧 Development Tools

### Code Quality

```bash
# Run comprehensive quality checks (Python, Shell, Docker, Security)
mise run check-all

# Individual quality checks
mise run lint          # Lint Python code
mise run format        # Format code
mise run typecheck-python     # Python type checking
mise run test-docker   # Run Docker tests
mise run shell-lint    # Lint shell scripts
mise run docker-lint   # Lint Dockerfiles
```

### Pre-commit Hooks

The project uses pre-commit hooks to ensure code quality:

```bash
# Install pre-commit hooks
pre-commit install

# Run on all files
pre-commit run --all-files

# Run specific hook
pre-commit run ruff --all-files
```

## 🐳 Docker Development

### Docker Setup

The project includes Docker tooling that addresses common issues with Docker duplication and early issue detection:

**Key Improvements:**

- ✅ **Reduced duplication** - 70% less code duplication across Dockerfiles
- ✅ **Early issue detection** - Comprehensive local testing before CI
- ✅ **Security scanning** - Automated vulnerability scanning
- ✅ **Better maintainability** - Automated Dockerfile generation

### Docker Development Tools

```bash
# Build and test all Docker images
./scripts/docker-manager.sh build --all --test
```

### Image Architecture

The project uses multi-stage Docker builds to create optimized production images:

| Variant | Size | Base | Architecture | Use Case |
|---------|------|------|--------------|----------|
| `standard` | ~577MB | Python 3.13-slim | Multi-stage build | **Production** - Best compatibility |
| `alpine` | ~523MB | Python 3.13-alpine | Multi-stage build | Minimal size, resource-constrained |
| `dev` | ~1.4GB | Python 3.13-slim | Single-stage | Development with all tools |

### Multi-Stage Build Strategy

**Builder Stage:**

- Installs build dependencies (gcc, pkg-config, development libraries)
- Uses `uv` for fast Python dependency management
- Creates virtual environment with all required packages

**Runtime Stage:**

- Minimal runtime dependencies only
- Copies virtual environment from builder stage
- Non-root user for security
- Optimized for production deployment

### Building Images

```bash
# Build development image
mise run build-image

# Build and test everything (all images + functionality tests)
mise run build-docker && mise run test-docker

# Manual builds (if needed)
docker build -f docker/Dockerfile.standard -t ats-pdf-generator:standard .
docker build -f docker/Dockerfile.alpine -t ats-pdf-generator:alpine .
docker build -f docker/Dockerfile.dev -t ats-pdf-generator:dev .
```

### Development with Docker

**Note**: The development Docker image is not built in CI to optimize resource usage on free tiers. Developers should build it locally when needed.

```bash
# Build development container locally
docker build -f docker/Dockerfile.dev -t ats-pdf-generator:dev .

# Or using mise (recommended)
mise run build-image

# Run development shell
docker run -it --rm -v $(PWD):/app -w /app ats-pdf-generator:dev bash
```

The development image includes:

- All development dependencies (ruff, mypy, pytest, pre-commit)
- Development tools and utilities
- Git configuration for pre-commit hooks
- Shell aliases for common development tasks

**CI Optimization**: Only production images (alpine, standard) are built and published in CI. The dev Dockerfile is validated for syntax correctness but not built to save ~14.5 minutes per CI run.

### Docker Compose for Development

The project includes Docker Compose files for easy development and testing:

```bash
# Start development environment
docker-compose -f docker/docker-compose.yml --profile dev up -d

# Start standard development environment
docker-compose -f docker/docker-compose.optimized.yml --profile dev up -d

# Run a conversion using compose
docker-compose -f docker/docker-compose.yml run --rm ats-converter input.md -o output.pdf

# Stop development environment
docker-compose -f docker/docker-compose.yml down
```

**Available Services:**

- `ats-converter`: Production service for document conversion
- `ats-converter-dev`: Development service with debug mode enabled
- `ats-converter-optimized`: Standard production service
- `ats-converter-alpine`: Minimal Alpine-based service

**Note**: For most development tasks, use the convenience scripts instead:

```bash
mise run convert-pdf examples/sample-profile.md  # PDF conversion
mise run build-docker && mise run test-docker                         # Build and test everything
```

### Docker Usage Guide

#### Quick Start Examples

**Simple Conversion:**

```bash
# Run a single conversion using the standard image
docker run --rm \
  -v $PWD/examples:/app/input \
  -v $PWD/output:/app/output \
  ats-pdf-generator:standard \
  /app/input/sample-profile.md -o /app/output/profile.pdf
```

**Using Docker Compose:**

```bash
# Build and run conversion service
cd docker
docker-compose up --build ats-converter

# Run task-focused service for one-off conversions
docker-compose run --rm ats-convert-task /app/input/sample-profile.md -o /app/output/profile.pdf

# Development environment
docker-compose --profile dev up ats-converter-dev
```

#### Volume Mounts

The improved Docker setup uses specific volume mounts to avoid conflicts:

```yaml
volumes:
  - ./examples:/app/input    # Input files
  - ./output:/app/output     # Output PDFs
```

For development:

```yaml
volumes:
  - .:/workspace            # Full project access
```

#### Build Arguments

All images support build-time labels:

```bash
docker build \
  --build-arg GIT_SHA=$(git rev-parse HEAD) \
  -f docker/Dockerfile.standard \
  -t ats-pdf-generator:standard .
```

#### Multi-Architecture Support

Images are built for both `linux/amd64` and `linux/arm64`:

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -f docker/Dockerfile.standard \
  -t ats-pdf-generator:standard .
```

#### Development Workflow

```bash
# Start development environment
cd docker
docker-compose --profile dev up -d ats-converter-dev

# Access development container
docker exec -it ats-document-converter-dev bash

# Run development commands
ruff check .
mypy src/
pytest
```

#### Profiles

- **Default**: Production conversion services
- **dev**: Development environment with tools
- **task**: Task-focused services for one-off conversions

#### Environment Variables

- `PYTHONUNBUFFERED=1`: Ensure logs appear immediately
- `LC_ALL=C.UTF-8`: Unicode support
- `LANG=C.UTF-8`: Unicode support
- `DEBUG=1`: Enable debug mode (dev profile only)

#### Security Features

- Non-root user (`converter`) in runtime images
- Minimal attack surface with slim base images
- Regular security scanning with Trivy
- No secrets or credentials baked into images

#### BuildKit Features

The Dockerfiles use BuildKit features for improved build performance:

- Build cache mounts for apt packages
- Multi-stage builds for smaller final images
- Parallel build stages
- Optimized layer caching

Enable BuildKit:

```bash
export DOCKER_BUILDKIT=1
```

#### Tips

1. **Use specific tags** in production instead of `latest`
2. **Mount only necessary directories** to avoid file conflicts
3. **Use the task profile** for one-off conversions
4. **Use the dev profile** for development work
5. **Check logs** with `docker-compose logs` if conversion fails

## 🔍 Debugging

### Local Debugging

```bash
# Run with debug output
python -m src.ats_converter --debug input.md

# Run with verbose logging
python -m src.ats_converter --verbose input.md
```

### Docker Debugging

```bash
# Run container with debug mode
docker run --rm -v $(pwd):/app ats-pdf-generator:dev --debug input.md

# Access container shell
docker run --rm -it -v $(pwd):/app ats-pdf-generator:dev /bin/bash
```

## 📦 Dependencies

### Core Dependencies

Key dependencies managed by `pyproject.toml`:

- **pandoc**: Universal document converter (handles Markdown → HTML)
- **weasyprint**: HTML/CSS to PDF generation (replaces LaTeX for better control)
- **click**: Command-line interface framework
- **pytest**: Testing framework

### Development Dependencies

- **ruff**: Fast Python linter and formatter (replaces black + flake8)
- **mypy**: Static type checking
- **pre-commit**: Git hooks for code quality
- **pytest-cov**: Test coverage reporting

### Dependency Management Strategy

The project uses `uv` for dependency management, chosen for its superior performance in containerized environments and faster builds. This decision was made after evaluating pip's limitations in multi-stage Docker builds.

## 🚀 Release Process

### Version Management

The project uses [Semantic Versioning](https://semver.org/):

1. **Patch releases** (1.0.1): Bug fixes
2. **Minor releases** (1.1.0): New features, backward compatible
3. **Major releases** (2.0.0): Breaking changes

### Release Checklist

- [ ] Update version in `pyproject.toml`
- [ ] Update `CHANGELOG.md` with new features/fixes
- [ ] Test all functionality thoroughly (run `mise run check-all` and `mise run build-docker && mise run test-docker`)
- [ ] Update documentation if needed
- [ ] Create git tag: `git tag v1.2.3`
- [ ] Push tag: `git push origin v1.2.3`
- [ ] GitHub Actions automatically builds and publishes Docker images using `scripts/docker-manager.sh publish`

### Automated Release Process

Once a tag is pushed, GitHub Actions will:

1. **Build and Push Multi-Platform Images**:
   - Builds both `Dockerfile.standard` and `Dockerfile.alpine` variants
   - Supports `linux/amd64` and `linux/arm64` platforms
   - Pushes to both Docker Hub and GitHub Container Registry
   - Tags with version (e.g., `v1.2.3`) and `latest`

2. **Create GitHub Release**:
   - Automatically generates changelog from git commits (requires conventional commit format)
   - Creates a release with Docker pull instructions
   - Includes usage examples and links to documentation

3. **Update Docker Hub**:
   - Updates Docker Hub repository description
   - Syncs README.md content to Docker Hub

## 📊 Performance Characteristics

### Build Performance

- **Docker Build Time**: ~2-3 minutes (with cache)
- **Local Development Setup**: ~30 seconds (with mise)
- **CI/CD Pipeline**: ~5-8 minutes (quality checks + builds)

### Runtime Performance

- **PDF Conversion Speed**: ~1-5 seconds per document
- **Memory Usage**: ~128-256MB during conversion
- **Image Size**: 523-577MB (production images)
- **Startup Time**: <1 second (container startup)

### Quality Metrics

- **PDF Output**: Professional, ATS-optimized formatting
- **Font Rendering**: Consistent across platforms
- **File Size**: Optimized for email attachments

## 🔄 Continuous Integration

The project uses GitHub Actions with a script-first approach for automated quality checks and deployment:

### CI Workflow (`ci.yml`)

- **Security Scanning**: Runs Trivy security scan via GitHub Action
- **Quality Checks**: Runs `scripts/check-all.sh` (Python, Shell, Docker, Markdown)
- **Docker Testing**: Runs `scripts/docker-manager.sh build --all --test` (Docker builds and tests)
- **Docker Validation**: Validates Dockerfiles with hadolint

### Release Workflow (`release.yml`)

- **Multi-Registry Publishing**: Uses `scripts/docker-manager.sh publish` for Docker Hub and GitHub Container Registry
- **Multi-Variant Support**: Publishes standard and alpine image variants (dev variant validated for syntax only)
- **Release Creation**: Automatically creates GitHub releases with changelog

### CI/CD Architecture Decisions

**Script-First Approach**: All CI/CD logic is implemented in shell scripts rather than YAML, making it easier to test locally and maintain consistency across environments.

**Multi-Registry Publishing**: Images are published to both Docker Hub and GitHub Container Registry to provide redundancy and different access patterns.

**Automated Release Management**: Uses conventional commits and automated changelog generation to reduce manual release overhead.

**When checks run:**

- ✅ **Quality & Build**: On push to main branch and pull requests
- ✅ **Publish**: On push to main branch (latest images)
- ✅ **Release**: On tag pushes (v*) with versioned images
- ✅ **Pre-commit hooks**: Local development

## 🎯 Technical Decisions & Trade-offs

### Architecture Choices

**WeasyPrint vs LaTeX**: Chose WeasyPrint for better CSS control and consistent rendering across platforms, at the cost of some LaTeX typography features. This decision prioritized user experience and maintainability over advanced typography capabilities.

**Multi-stage Docker builds**: Optimized for production image size and security, but increased build complexity. The trade-off was worth it for the ~40% size reduction and improved security posture.

**Script-first CI/CD**: Improved maintainability and testability, but required more upfront script development. This approach eliminated the common problem of CI/CD logic becoming complex and environment-specific.

**uv vs pip**: Faster dependency resolution and better Docker compatibility, but newer tool with smaller ecosystem. Chosen for its superior performance in containerized environments and faster builds.

### Implementation Trade-offs

**Bullet Point Handling**: Implemented custom preprocessing to handle various bullet formats, trading simplicity for user convenience.

**CSS Template System**: Separate CSS files for different document types, increasing maintainability but requiring more files.

**Docker Image Variants**: Multiple image variants (standard, alpine) provide flexibility but increase maintenance overhead.

### Lessons Learned

- **Dependency Management**: Version pinning in Dockerfiles caused more problems than it solved
- **Script Organization**: Clear naming and help documentation significantly improved developer experience
- **Multi-stage Builds**: Proper virtual environment handling required careful PATH management
- **CI/CD Simplification**: Script-first approach reduced GitHub Actions complexity significantly

## 📚 Additional Resources

- [Examples](examples/) - Sample input and output files
- [GitHub Issues](https://github.com/dohdalabs/ats-pdf-generator/issues) - Bug reports and feature requests
- [GitHub Discussions](https://github.com/dohdalabs/ats-pdf-generator/discussions) - Community Q&A

## 🔗 Related Projects

- [Pandoc](https://github.com/jgm/pandoc) - Universal document converter
- [WeasyPrint](https://github.com/Kozea/WeasyPrint) - HTML/CSS to PDF library
- [Resume.md](https://github.com/mikepqr/resume.md) - Markdown resume generator
