# CI Process Documentation

## Overview

This document provides a comprehensive breakdown of the CI (Continuous Integration) process for the ATS PDF Generator project. The CI workflow is defined in `.github/workflows/ci.yml` and consists of multiple jobs that run in parallel and sequence to ensure code quality, security, and proper deployment.

## Workflow Triggers

The CI process is triggered on:

- **Push to main branch**: Full CI pipeline including security scans and publishing
- **Pull requests to main branch**: Quality checks and Docker testing (no publishing)

## Environment Variables

```yaml
CI: true                           # Indicates CI environment
UV_COMPILE_BYTECODE: 1            # Optimizes Python bytecode compilation
UV_CACHE_DIR: ~/.cache/uv         # UV package manager cache location
UV_INDEX_STRATEGY: unsafe-best-match  # UV package resolution strategy
```

## Jobs Overview

The CI pipeline consists of 6 main jobs:

1. **quality** - Code quality and linting checks
2. **docker-test** - Docker image building and testing
3. **security-scan** - Vulnerability scanning (conditional)
4. **security-scan-summary** - Security scan results summary
5. **publish** - Image publishing to registries (main branch only)
6. **summary** - Final CI summary

---

## Job 1: Quality Checks (`quality`)

**Purpose**: Ensures code quality, style consistency, and proper formatting across the codebase.

### Quality Job Steps

#### 1. Checkout Code (Quality)

- **Action**: `actions/checkout@v5`
- **Purpose**: Downloads the repository code to the CI runner
- **Why needed**: Provides access to source code for all subsequent steps

#### 2. Set up Python

- **Action**: `actions/setup-python@v6`
- **Python Version**: 3.13
- **Purpose**: Installs the specified Python version
- **Why needed**: Ensures consistent Python environment across all environments

#### 3. Install UV

- **Action**: `astral-sh/setup-uv@v1`
- **Version**: Latest
- **Purpose**: Installs UV package manager
- **Why needed**: UV is used for fast Python dependency management and virtual environment handling

#### 4. Cache UV Dependencies

- **Action**: `actions/cache@v4`
- **Cache Paths**:
  - `~/.cache/uv` (UV package cache)
  - `.venv` (Virtual environment)
- **Cache Key**: Based on OS, UV lock file, and pyproject.toml hashes
- **Purpose**: Speeds up builds by reusing downloaded packages and virtual environments
- **Why needed**: Significantly reduces build times by avoiding re-downloading dependencies

#### 5. Show UV Version Info

- **Purpose**: Displays UV and Python versions for debugging
- **Output**: UV version, Python version, cache directory location
- **Why needed**: Helps troubleshoot version-related issues

#### 6. Install Dependencies

- **Command**: `uv sync --dev`
- **Purpose**: Installs all project dependencies including development tools
- **Why needed**: Sets up the complete development environment for quality checks

#### 7. Install Additional Tools

- **Tools Installed**:
  - `shellcheck`: Shell script linting
  - `hadolint`: Dockerfile linting
  - `trivy`: Security vulnerability scanner
  - `markdownlint-cli`: Markdown linting
- **Purpose**: Installs all tools needed for comprehensive code quality checks
- **Why needed**: Ensures all linting and security tools are available

#### 8. Run Quality Checks

- **Script**: `./scripts/quality-check.sh`
- **Purpose**: Executes all quality checks (linting, formatting, type checking)
- **Why needed**: Centralized quality validation that can be run locally and in CI

**High-Level Overview of Tasks Performed by `quality-check.sh`:**

- **Python Code Quality:** Runs `ruff` for linting and formatting, and `mypy` for static type checking.
- **Python Tests:** Executes the test suite using `pytest` to ensure code correctness.
- **Shell Script Linting:** Uses `shellcheck` to analyze shell scripts for common errors and best practices.
- **Markdown Linting:** Runs `markdownlint-cli` to check Markdown files for style and formatting issues.
- **Dockerfile Linting:** Uses `hadolint` to validate Dockerfiles against best practices and common mistakes.
- **Security Scanning:** Invokes `trivy` to scan for vulnerabilities in dependencies and Docker images (if applicable).

All these checks are run in sequence, and the script will fail if any check does not pass, ensuring code quality before merging or deployment.

---

## Job 2: Docker Image Testing (`docker-test`)

**Purpose**: Tests Docker image building, functionality, and validates Dockerfiles.

### Docker Test Job Steps

#### 1. Checkout Code (Docker Test)

- **Action**: `actions/checkout@v5`
- **Purpose**: Provides access to Dockerfiles and build scripts
- **Why needed**: Required for building and testing Docker images

#### 2. Set up Docker Buildx (Docker Test)

- **Action**: `docker/setup-buildx-action@v3`
- **Purpose**: Enables advanced Docker build features and multi-platform builds
- **Why needed**: Provides enhanced build capabilities and better caching

#### 3. Test Existing Docker Images

- **Script**: `./scripts/test-docker-images.sh`
- **Purpose**: Tests currently committed Docker images for functionality
- **Why needed**: Ensures existing images work correctly before making changes

#### 4. Build and Test New Docker Images

- **Script**: `./scripts/build-all-images.sh`
- **Purpose**: Builds all Docker image variants and runs comprehensive tests
- **Why needed**: Validates that new changes don't break Docker image functionality

#### 5. Install hadolint

- **Purpose**: Installs hadolint for Dockerfile validation
- **Method**: Downloads binary from GitHub releases
- **Why needed**: Required for the Dockerfile validation step

#### 6. Generate and Validate Dockerfiles

- **Script**: `./scripts/generate-dockerfiles.sh`
- **Purpose**: Generates new Dockerfiles and validates them with hadolint
- **Why needed**: Ensures Dockerfiles follow best practices and are syntactically correct

---

## Job 3: Security Scan (`security-scan`)

**Purpose**: Performs comprehensive security vulnerability scanning on Docker images.

### Security Scan Conditions

- **Runs on**: Push to main branch OR when Docker files or dependencies change
- **Dependencies**: Requires `quality` and `docker-test` jobs to complete first
- **Permissions**: Read contents, write security events, read actions

### Security Scan Matrix Strategy

- **Images Scanned**: `alpine` and `standard` variants
- **Purpose**: Tests both Docker image variants for vulnerabilities

### Security Scan Job Steps

#### 1. Checkout Code (Security Scan)

- **Action**: `actions/checkout@v5`
- **Purpose**: Provides access to Dockerfiles and build context
- **Why needed**: Required for building images to scan

#### 2. Set up Docker Buildx (Security Scan)

- **Action**: `docker/setup-buildx-action@v3`
- **Configuration**: Uses stable buildkit with host networking
- **Purpose**: Optimized Docker build setup for security scanning
- **Why needed**: Provides consistent, reliable builds for security analysis

#### 3. Build Image for Scanning

- **Action**: `docker/build-push-action@v6`
- **Purpose**: Builds Docker image specifically for vulnerability scanning
- **Platforms**:
  - Alpine: `linux/amd64` only
  - Standard: `linux/amd64,linux/arm64`
- **Caching**: Uses GitHub Actions cache for build optimization
- **Why needed**: Creates the image that will be scanned for vulnerabilities

#### 4. Cache Trivy Vulnerability Database

- **Action**: `actions/cache@v4`
- **Cache Path**: `~/.cache/trivy`
- **Cache Key**: Based on image type, Dockerfiles, and dependency files
- **Purpose**: Speeds up vulnerability scanning by caching the vulnerability database
- **Why needed**: Trivy's vulnerability database is large and takes time to download

#### 5. Run Trivy Vulnerability Scanner

- **Action**: `aquasecurity/trivy-action@master`
- **Format**: SARIF (Static Analysis Results Interchange Format)
- **Severity Levels**: CRITICAL, HIGH, MEDIUM, LOW
- **Output**: `trivy-results-{image}.sarif`
- **Purpose**: Scans Docker image for known vulnerabilities
- **Why needed**: Identifies security issues that need to be addressed

#### 6. Check SARIF File Creation

- **Purpose**: Verifies that the vulnerability scan results were properly generated
- **Why needed**: Ensures scan results are available for upload and review

#### 7. Upload Scan Results to GitHub Security Tab

- **Action**: `github/codeql-action/upload-sarif@v3`
- **Condition**: Only on main branch pushes with valid SARIF files
- **Purpose**: Makes vulnerability results visible in GitHub's Security tab
- **Why needed**: Provides centralized security issue tracking and management

---

## Job 4: Security Scan Summary (`security-scan-summary`)

**Purpose**: Provides a summary of security scan results and verifies file generation.

### Security Summary Job Steps

#### 1. Check SARIF Files Exist

- **Purpose**: Verifies that security scan results were properly generated
- **Checks**: Looks for `trivy-results-alpine.sarif` and `trivy-results-standard.sarif`
- **Why needed**: Ensures security scanning completed successfully and results are available

---

## Job 5: Publish (`publish`)

**Purpose**: Publishes Docker images to container registries (Docker Hub and GitHub Container Registry).

### Publish Job Conditions

- **Runs on**: Main branch pushes only
- **Dependencies**: Requires all previous jobs to complete successfully

### Publish Job Steps

#### 1. Checkout Code (Publish)

- **Action**: `actions/checkout@v5`
- **Purpose**: Provides access to Dockerfiles and build context
- **Why needed**: Required for building final production images

#### 2. Set up Docker Buildx (Publish)

- **Action**: `docker/setup-buildx-action@v3`
- **Purpose**: Enables multi-platform builds for production images
- **Why needed**: Ensures images work on multiple architectures

#### 3. Log in to Docker Hub

- **Action**: `docker/login-action@v3`
- **Credentials**: Uses `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` secrets
- **Purpose**: Authenticates with Docker Hub for image publishing
- **Why needed**: Required to push images to Docker Hub registry

#### 4. Log in to GitHub Container Registry

- **Action**: `docker/login-action@v3`
- **Registry**: `ghcr.io`
- **Credentials**: Uses GitHub actor and token
- **Purpose**: Authenticates with GitHub Container Registry
- **Why needed**: Required to push images to GitHub's container registry

#### 5. Publish Standard Images

- **Action**: `docker/build-push-action@v6`
- **Image**: Standard variant only (Alpine is not published)
- **Platforms**: `linux/amd64,linux/arm64`
- **Tags**:
  - `dohdalabs/ats-pdf-generator:latest`
  - `dohdalabs/ats-pdf-generator:{git-sha}`
  - `ghcr.io/{owner}/ats-pdf-generator:latest`
  - `ghcr.io/{owner}/ats-pdf-generator:{git-sha}`
- **Caching**: Reuses layers from security scan builds
- **Purpose**: Publishes production-ready images to both registries
- **Why needed**: Makes the application available for deployment and use

---

## Job 6: Summary (`summary`)

**Purpose**: Provides a final summary of all CI job results.

### Summary Job Steps

#### 1. Generate Summary

- **Purpose**: Displays a summary of all completed CI checks
- **Output**: Lists completion status of quality, Docker, security, and publishing jobs
- **Why needed**: Provides clear visibility into CI pipeline results

---

## Key Features and Optimizations

### 1. **Parallel Execution**

- Quality and Docker testing jobs run in parallel
- Security scanning runs after both complete
- Publishing only runs on main branch

### 2. **Caching Strategy**

- UV dependencies cached based on lock file and pyproject.toml
- Docker build layers cached using GitHub Actions cache
- Trivy vulnerability database cached to speed up scans

### 3. **Conditional Execution**

- Security scans only run when relevant files change
- Publishing only occurs on main branch pushes
- Summary always runs regardless of other job results

### 4. **Multi-Platform Support**

- Standard images built for both AMD64 and ARM64
- Alpine images built for AMD64 only (size optimization)

### 5. **Security Integration**

- SARIF results uploaded to GitHub Security tab
- Comprehensive vulnerability scanning with Trivy
- Security issues tracked and managed centrally

### 6. **Registry Publishing**

- Images published to both Docker Hub and GitHub Container Registry
- Multiple tags for versioning and latest releases
- Proper authentication and permissions handling

---

## Troubleshooting Common Issues

### 1. **Quality Check Failures**

- Check shellcheck, hadolint, or markdownlint output
- Ensure all scripts follow coding standards
- Verify Python dependencies are properly specified

### 2. **Docker Build Failures**

- Check Dockerfile syntax and best practices
- Verify all required files are present in build context
- Ensure base images are available and accessible

### 3. **Security Scan Issues**

- Check if Trivy database download completed
- Verify SARIF file generation
- Review vulnerability reports in GitHub Security tab

### 4. **Publishing Failures**

- Verify Docker Hub and GitHub Container Registry credentials
- Check registry permissions and quotas
- Ensure images built successfully before publishing

---

## Future Improvements

### 1. **Performance Optimizations**

- Implement more granular caching strategies
- Optimize build times with better layer caching
- Consider using build cache from previous runs

### 2. **Security Enhancements**

- Add software composition analysis (SCA)
- Implement container image signing
- Add runtime security scanning

### 3. **Monitoring and Alerting**

- Add notifications for failed builds
- Implement metrics collection for build times
- Set up monitoring for published image usage

### 4. **Testing Improvements**

- Add integration tests for published images
- Implement automated rollback capabilities
- Add performance benchmarking

---

## Related Documentation

- [Development Workflow](.cursor/rules/development-workflow.mdc)
- [Docker Distribution Guide](docs/DOCKER_DISTRIBUTION.md)
- [Security Tools Installation Guide](tmp/SECURITY_TOOLS_INSTALLATION_GUIDE.md)
- [CI Resource Optimization Plan](tmp/CI_RESOURCE_OPTIMIZATION_PLAN.md)

---

*This documentation is maintained as part of the CI improvement process and should be updated when the CI workflow changes.*
