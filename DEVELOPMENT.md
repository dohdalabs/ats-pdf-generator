# Development Guide

This document is for technical reviewers and developers who want to understand the codebase architecture, explore the implementation, and set up a local development environment. It focuses on the technical decisions, patterns, and setup rather than user-facing features.

## 🏗️ Project Structure

```
├── src/                        # Source code
│   ├── ats_converter.py        # Main Python converter
│   └── ats-document-converter.sh # Shell wrapper script
├── docker/                     # Docker configuration
│   ├── Dockerfile.optimized    # Production Docker image
│   ├── Dockerfile.alpine       # Minimal Docker image
│   └── Dockerfile.dev          # Development environment
├── templates/                  # CSS styling templates
│   ├── ats-cover-letter.css    # Cover letter styling
│   ├── ats-profile.css         # Profile styling
│   └── ats-document.css        # General document styling
├── examples/                   # Sample files
│   ├── sample-cover-letter.md  # Example cover letter
│   └── sample-profile.md       # Example profile
├── scripts/                      # Development and automation scripts
│   ├── quality-check.sh        # Comprehensive quality checks
│   ├── build-and-test.sh       # Build and test automation
│   ├── publish.sh              # Multi-registry publishing
│   ├── publish-image.sh        # Legacy multi-registry publishing
│   ├── convert-pdf.sh          # PDF conversion utility
│   ├── setup-local-env.sh      # Local environment setup
│   ├── build-dev-image.sh      # Docker image building
│   ├── setup-docker-auth.sh    # Registry authentication
│   └── check-summary.sh        # Quality check summary
├── tests/                       # Test suite
│   └── test_converter.py       # Unit tests
├── .github/                     # GitHub Actions workflows
│   └── workflows/              # CI/CD automation
│       ├── ci.yml              # Main CI pipeline
│       └── release.yml         # Release automation
├── install.sh                   # One-line installer script
├── pyproject.toml               # Python project configuration
├── mise.toml                    # mise configuration
├── .pre-commit-config.yaml      # Pre-commit hooks
└── README.md                    # User-focused documentation
```

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
# Install development dependencies and setup pre-commit
mise run install
mise exec pre-commit install
mise exec pre-commit install --hook-type commit-msg

# Run comprehensive quality checks (Python, Shell, Docker, Security)
mise run quality

# Build and test everything (Docker images, functionality tests)
mise run build-test

# Convert PDFs for testing
mise run convert examples/sample-profile.md

# Format code
mise run format

# Run individual checks
mise run lint
mise run test
```

**Note**: The commit-msg hook enforces [Conventional Commits](https://www.conventionalcommits.org/) format for better changelog generation.

## 🎯 Script-First Architecture

This project implements a **script-first approach** where all operations are implemented as reusable shell scripts that can be called by both local development tools (mise) and CI/CD systems (GitHub Actions). This architectural decision eliminates duplication and ensures consistent behavior across environments.

### Key Scripts

- **`scripts/quality-check.sh`**: Comprehensive quality checks (Python, Shell, Docker, Security)
- **`scripts/build-and-test.sh`**: Build all Docker images and run functionality tests
- **`scripts/publish.sh`**: Multi-registry publishing with authentication handling
- **`scripts/convert-pdf.sh`**: PDF conversion using Docker containers
- **`scripts/setup-local-env.sh`**: Local Python environment setup
- **`scripts/build-dev-image.sh`**: Build development Docker image
- **`scripts/setup-docker-auth.sh`**: Setup Docker registry authentication

### Architectural Benefits

- **Consistency**: Same scripts work locally and in CI environments
- **Maintainability**: Changes in one place affect all environments
- **Testability**: Scripts can be tested independently of CI/CD systems
- **Clarity**: Self-documenting with `--help` options for all scripts
- **Reduced Complexity**: GitHub Actions workflows are simple script calls

### Implementation Notes

The script-first approach was chosen to address the common problem of CI/CD logic becoming complex and environment-specific. By implementing all operations as standalone scripts, the project achieves better testability and reduces the cognitive load of maintaining separate local and CI workflows.

## 🧪 Testing

### Running Tests

```bash
# Run comprehensive quality checks (includes tests)
mise run quality

# Run just the tests
mise run test

# Run tests with coverage
pytest --cov=src tests/

# Run specific test file
pytest tests/test_converter.py

# Run tests with verbose output
pytest -v tests/

# Build and test everything (Docker images, functionality tests)
mise run build-test
```

### Test Structure

- `tests/test_converter.py` - Unit tests for the main converter
- `scripts/build-and-test.sh` - Integration tests for Docker builds and PDF generation
- `scripts/quality-check.sh` - Comprehensive quality checks including tests

## 🔧 Development Tools

### Code Quality

```bash
# Run comprehensive quality checks (Python, Shell, Docker, Security)
mise run quality

# Individual quality checks
mise run lint          # Lint Python code
mise run format        # Format code
mise run typecheck     # Type checking
mise run test          # Run tests
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

### Image Architecture

The project uses multi-stage Docker builds to create optimized production images:

| Variant | Size | Base | Architecture | Use Case |
|---------|------|------|--------------|----------|
| `optimized` | ~577MB | Python 3.13-slim | Multi-stage build | **Production** - Best compatibility |
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
mise run build-test

# Manual builds (if needed)
docker build -f docker/Dockerfile.optimized -t ats-pdf-generator:optimized .
docker build -f docker/Dockerfile.alpine -t ats-pdf-generator:alpine .
docker build -f docker/Dockerfile.dev -t ats-pdf-generator:dev .
```

### Development with Docker

```bash
# Build development container
docker build -f docker/Dockerfile.dev -t ats-pdf-generator:dev .

# Run development shell
docker run -it --rm -v $(PWD):/app -w /app ats-pdf-generator:dev bash
```

### Docker Compose for Development

The project includes Docker Compose files for easy development and testing:

```bash
# Start development environment
docker-compose -f docker/docker-compose.yml --profile dev up -d

# Start optimized development environment
docker-compose -f docker/docker-compose.optimized.yml --profile dev up -d

# Run a conversion using compose
docker-compose -f docker/docker-compose.yml run --rm ats-converter input.md -o output.pdf

# Stop development environment
docker-compose -f docker/docker-compose.yml down
```

**Available Services:**
- `ats-converter`: Production service for document conversion
- `ats-converter-dev`: Development service with debug mode enabled
- `ats-converter-optimized`: Optimized production service
- `ats-converter-alpine`: Minimal Alpine-based service

**Note**: For most development tasks, use the convenience scripts instead:
```bash
mise run convert examples/sample-profile.md  # PDF conversion
mise run build-test                         # Build and test everything
```

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

The project uses `uv` for dependency management, chosen for its speed and reliability in Docker environments. This decision was made after experiencing issues with pip's dependency resolution in multi-stage builds.

## 🚀 Release Process

### Version Management

The project uses [Semantic Versioning](https://semver.org/):

1. **Patch releases** (1.0.1): Bug fixes
2. **Minor releases** (1.1.0): New features, backward compatible
3. **Major releases** (2.0.0): Breaking changes

### Release Checklist

- [ ] Update version in `pyproject.toml`
- [ ] Update `CHANGELOG.md` with new features/fixes
- [ ] Test all functionality thoroughly (run `mise run quality` and `mise run build-test`)
- [ ] Update documentation if needed
- [ ] Create git tag: `git tag v1.2.3`
- [ ] Push tag: `git push origin v1.2.3`
- [ ] GitHub Actions automatically builds and publishes Docker images using `scripts/publish.sh`

### Automated Release Process

Once a tag is pushed, GitHub Actions will:
1. **Build and Push Multi-Platform Images**:
   - Builds both `Dockerfile.optimized` and `Dockerfile.alpine` variants
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
- **Quality Checks**: Runs `scripts/quality-check.sh` (Python, Shell, Docker, Security)
- **Build & Test**: Runs `scripts/build-and-test.sh` (Docker builds, functionality tests)
- **Publish**: Runs `scripts/publish.sh` on main branch pushes

### Release Workflow (`release.yml`)
- **Multi-Registry Publishing**: Uses `scripts/publish.sh` for Docker Hub and GitHub Container Registry
- **Release Creation**: Automatically creates GitHub releases with changelog
- **Docker Hub Updates**: Updates repository description and README

### CI/CD Architecture Decisions

**Script-First Approach**: All CI/CD logic is implemented in shell scripts rather than YAML, making it easier to test locally and maintain consistency across environments.

**Multi-Registry Publishing**: Images are published to both Docker Hub and GitHub Container Registry to provide redundancy and different access patterns.

**Automated Release Management**: Uses conventional commits and automated changelog generation to reduce manual release overhead.

**When checks run:**
- ✅ **Quality & Build**: On push to main/develop branches and pull requests
- ✅ **Publish**: On push to main branch (latest images)
- ✅ **Release**: On tag pushes (v*) with versioned images
- ✅ **Pre-commit hooks**: Local development

## 🎯 Technical Decisions & Trade-offs

### Architecture Choices

**WeasyPrint vs LaTeX**: Chose WeasyPrint for better CSS control and consistent rendering across platforms, at the cost of some LaTeX typography features.

**Multi-stage Docker builds**: Optimized for production image size and security, but increased build complexity.

**Script-first CI/CD**: Improved maintainability and testability, but required more upfront script development.

**uv vs pip**: Faster dependency resolution and better Docker compatibility, but newer tool with smaller ecosystem.

### Implementation Trade-offs

**Bullet Point Handling**: Implemented custom preprocessing to handle various bullet formats, trading simplicity for user convenience.

**CSS Template System**: Separate CSS files for different document types, increasing maintainability but requiring more files.

**Docker Image Variants**: Multiple image variants (optimized, alpine) provide flexibility but increase maintenance overhead.

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
