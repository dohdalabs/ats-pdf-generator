# Docker Distribution Guide

This guide provides a comprehensive overview of the ATS PDF Generator's Docker distribution strategy. It covers everything from using pre-built images to contributing to the project, including multi-registry publishing, development workflows, and maintenance procedures.

## Why Multi-Registry?

The ATS PDF Generator is published to two public registries to ensure maximum availability and reach:

1. **Docker Hub** - Primary registry for general distribution
2. **GitHub Container Registry (ghcr.io)** - Integrated with GitHub for development workflows

**Technical Benefits:**

- **Cost-effective** - Both registries provide free public repositories
- **Redundancy** - Multiple distribution points reduce single points of failure
- **Performance** - Users can pull from geographically closer registries
- **Vendor independence** - No dependency on a single registry provider

## Registry Information

### Docker Hub (Primary)

- **Repository**: `dohdalabs/ats-pdf-generator`
- **URL**: <https://hub.docker.com/r/dohdalabs/ats-pdf-generator>
- **Pull Command**: `docker pull dohdalabs/ats-pdf-generator:latest`
- **Best For**: General users, broad compatibility

### GitHub Container Registry (Development)

- **Repository**: `ghcr.io/dohdalabs/ats-pdf-generator`
- **URL**: <https://github.com/dohdalabs/ats-pdf-generator/pkgs/container/ats-pdf-generator>
- **Pull Command**: `docker pull ghcr.io/dohdalabs/ats-pdf-generator:latest`
- **Best For**: Developers, CI/CD workflows, GitHub integration

## For End Users: Getting Started

### Option 1: Using Pre-built Images (Recommended)

```bash
# Docker Hub
docker run --rm -v $(pwd):/app/input -v $(pwd)/output:/app/output \
  dohdalabs/ats-pdf-generator:latest \
  --input /app/input/sample-profile.md --output /app/output/profile.pdf

# GitHub Container Registry
docker run --rm -v $(pwd):/app/input -v $(pwd)/output:/app/output \
  ghcr.io/dohdalabs/ats-pdf-generator:latest \
  --input /app/input/sample-profile.md --output /app/output/profile.pdf
```

### Option 2: Using Docker Compose

```bash
# Clone the repository
git clone https://github.com/dohdalabs/ats-pdf-generator.git
cd ats-pdf-generator

# Run with Docker Compose
docker-compose -f docker/docker-compose.yml up ats-converter
```

## For Contributors: Development and Extension

### Prerequisites

- Docker and Docker Compose
- Git
- Python 3.11+ (for local development)
- [uv](https://docs.astral.sh/uv/) package manager

### Local Development Setup

```bash
# Clone and setup
git clone https://github.com/dohdalabs/ats-pdf-generator.git
cd ats-pdf-generator

# Install dependencies using mise (recommended)
mise install

# Or using uv directly
uv sync

# Run tests
mise run test
# or
uv run pytest

# Build and test locally
mise run build-test
# or
docker build -f docker/Dockerfile.standard -t ats-pdf-generator:local .
```

### Development Workflow

For detailed development workflow instructions, see the [Development Guide](DEVELOPMENT.md).

**Key Points for Maintainers:**

- All changes go through pull requests with automated testing
- Main branch is protected and triggers automated publishing
- Use `mise run check-all` locally before submitting PRs

## For Maintainers: Publishing and Release Management

### Automated Publishing (GitHub Actions)

The project follows **trunk-based development** and uses GitHub Actions to automatically build and push to both registries on:

- **Push to `main`** - Publishes as `latest` tag (protected branch)
- **Tagged releases** (e.g., `v1.0.0`) - Publishes as versioned tags
- **Pull requests** - Build and test only, no publishing
- **Feature branches** - Build and test only, no publishing

### Manual Publishing

Use the provided script to build and push to both registries:

```bash
# Build and push as 'latest'
./scripts/docker-push-multi-registry.sh

# Build and push with specific version
./scripts/docker-push-multi-registry.sh 1.0.0
```

### Authentication Setup

1. **Docker Hub Authentication**:

   ```bash
   docker login
   ```

2. **GitHub Container Registry Authentication**:

   ```bash
   echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin
   ```

## Technical Architecture

### Image Tagging Strategy

- `latest` - Latest stable release from main branch
- `v1.0.0` - Specific version tags for releases
- `main` - Latest from main branch (automatically updated)

### Multi-Architecture Support

Images are built for:

- `linux/amd64` - Intel/AMD 64-bit
- `linux/arm64` - ARM 64-bit (Apple Silicon, ARM servers)

### Registry Configuration Details

#### Docker Hub Setup

1. Create account at <https://hub.docker.com>
2. Create repository: `dohdalabs/ats-pdf-generator`
3. Generate access token in account settings
4. Add to GitHub Secrets: `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`

#### GitHub Container Registry Setup

1. Repository automatically available for GitHub repositories
2. Uses `GITHUB_TOKEN` (automatically provided)
3. No additional setup required

## Security and Best Practices

### Image Security

- Multi-stage builds to minimize attack surface and image size
- Non-root user execution
- Minimal runtime dependencies
- Regular base image updates
- Vulnerability scanning in CI/CD

### Registry Security

- Authentication required for all pushes
- Least-privilege tokens in GitHub Actions
- Access token rotation
- Public repository policy (no sensitive data)

## Troubleshooting

### Common Issues

1. **Authentication Failures**:
   - Verify credentials are correct
   - Check token permissions
   - Ensure Docker is logged in

2. **Build Failures**:
   - Check Docker daemon is running
   - Verify Dockerfile syntax
   - Check available disk space

3. **Push Failures**:
   - Verify registry permissions
   - Check network connectivity
   - Ensure repository exists

### Getting Help

- Check the [Issues](https://github.com/dohdalabs/ats-pdf-generator/issues) page
- Review [Development Guide](DEVELOPMENT.md)

## Multi-Registry Strategy Rationale

This multi-registry approach addresses several technical and operational requirements:

### Technical Considerations

- Redundancy to avoid single points of failure
- Performance optimization through geographic distribution
- Multi-architecture support (linux/amd64 and linux/arm64)
- CI/CD integration with GitHub Actions

### Operational Considerations

- Cost-effective (free for public repositories)
- No vendor lock-in or deprecation concerns
- Broad ecosystem compatibility
- Simplified maintenance and setup

### Registry Comparison

| Feature | Docker Hub | GitHub Container Registry |
|---------|------------|---------------------------|
| Cost | Free for public | Free for public |
| Visibility | Broad | GitHub ecosystem |
| Setup | Manual | Automatic with GitHub |
| Rate Limits | None for public | None for public |
| CI/CD | Standard | Native integration |

This approach balances technical requirements with operational constraints.
