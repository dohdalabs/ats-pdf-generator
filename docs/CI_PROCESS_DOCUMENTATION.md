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
CI_STRICT_SECURITY: true          # Enables strict security scanning (fails on HIGH/CRITICAL)
```

## Jobs Overview

The CI pipeline consists of 3 main jobs:

1. **quality** - Code quality, linting checks, and security scanning (integrated)
2. **docker-test** - Docker image building and testing
3. **publish** - Image publishing to registries (main branch only)

**Note:** Security scanning is now integrated into the quality job rather than running as a separate job, making the pipeline more efficient and providing faster feedback on security issues.

---

## Job 1: Quality Checks (`quality`)

**Purpose**: Ensures code quality, style consistency, proper formatting, and security scanning across the codebase.

### Quality Job Steps

#### 1. Checkout Code (Quality)

- **Action**: `actions/checkout@v5`
- **Purpose**: Downloads the repository code to the CI runner
- **Why needed**: Provides access to source code for all subsequent steps

#### 2. Install Just

- **Action**: `extractions/setup-just@v3`
- **Purpose**: Installs the Just task runner
- **Why needed**: Just is used to execute the unified CI pipeline commands

#### 3. Extract Python Version

- **Script**: `./scripts/extract-versions.sh python`
- **Purpose**: Dynamically extracts Python version from mise.toml
- **Why needed**: Ensures consistent Python version across all environments

#### 4. Set up Python

- **Action**: `actions/setup-python@v6`
- **Python Version**: Dynamically extracted from mise.toml
- **Purpose**: Installs the specified Python version
- **Why needed**: Ensures consistent Python environment across all environments

#### 5. Install UV

- **Action**: `astral-sh/setup-uv@v1`
- **Version**: Latest
- **Purpose**: Installs UV package manager with caching enabled
- **Why needed**: UV is used for fast Python dependency management and virtual environment handling

#### 6. Extract Node.js Version

- **Script**: `./scripts/extract-versions.sh node`
- **Purpose**: Dynamically extracts Node.js version from mise.toml
- **Why needed**: Ensures consistent Node.js version for frontend tools

#### 7. Set up Node.js

- **Action**: `actions/setup-node@v4`
- **Node.js Version**: Dynamically extracted from mise.toml
- **Purpose**: Installs the specified Node.js version
- **Why needed**: Required for frontend tooling and pnpm

#### 8. Extract pnpm Version

- **Script**: `./scripts/extract-versions.sh pnpm`
- **Purpose**: Dynamically extracts pnpm version from mise.toml
- **Why needed**: Ensures consistent pnpm version for package management

#### 9. Install pnpm

- **Action**: `pnpm/action-setup@v4`
- **Version**: Dynamically extracted from mise.toml
- **Purpose**: Installs pnpm package manager
- **Why needed**: Required for frontend dependency management

#### 10. Extract hadolint Version

- **Script**: `./scripts/extract-versions.sh hadolint`
- **Purpose**: Dynamically extracts hadolint version from mise.toml
- **Why needed**: Ensures consistent hadolint version for Dockerfile linting

#### 11. Install System Dependencies

- **Tools Installed**:
  - `shellcheck`: Shell script linting
  - `hadolint`: Dockerfile linting (with checksum verification)
- **Purpose**: Installs system-level tools needed for quality checks
- **Why needed**: Ensures all linting tools are available with security verification

#### 12. Install mise

- **Action**: `jdx/mise-action@v3`
- **Version**: 2025.10.6
- **Purpose**: Installs mise for development environment management
- **Why needed**: Required for consistent tool version management

#### 13. Install Project Dependencies

- **Command**: `just install`
- **Purpose**: Installs all project dependencies using the unified Just interface
- **Why needed**: Sets up the complete development environment for quality checks

#### 14. Run CI Checks

- **Command**: `just ci`
- **Purpose**: Executes all quality checks including integrated security scanning
- **Why needed**: Centralized quality validation that includes linting, formatting, type checking, testing, and security scanning

**High-Level Overview of Tasks Performed by `just ci`:**

- **Python Code Quality:** Runs `ruff` for linting and formatting, and `mypy` for static type checking.
- **Python Tests:** Executes the test suite using `pytest` to ensure code correctness.
- **Security Scanning:** Invokes `trivy` to scan for HIGH/CRITICAL vulnerabilities in dependencies and secrets in source code.
- **Docker Build & Test:** Builds and tests Docker images to ensure containerization works correctly.
- **Dockerfile Validation:** Uses `hadolint` to validate Dockerfiles against best practices and common mistakes.

All these checks are run in sequence, and the pipeline will fail if any check does not pass, ensuring code quality and security before merging or deployment. Security scanning is now integrated into the quality job, providing faster feedback on security issues.

---

## Job 2: Docker Image Testing (`docker-test`)

**Purpose**: Tests Docker image building, functionality, and validates Dockerfiles.

### Docker Test Job Steps

#### 1. Checkout Code (Docker Test)

- **Action**: `actions/checkout@v5`
- **Purpose**: Provides access to Dockerfiles and build scripts
- **Why needed**: Required for building and testing Docker images

#### 2. Install Just (Docker Test)

- **Action**: `extractions/setup-just@v3`
- **Purpose**: Installs the Just task runner
- **Why needed**: Just is used to execute the unified Docker workflow commands

#### 3. Install mise (Docker Test)

- **Action**: `jdx/mise-action@v3`
- **Version**: 2025.10.6
- **Purpose**: Installs mise for development environment management
- **Why needed**: Required for consistent tool version management

#### 4. Set up Docker Buildx (Docker Test)

- **Action**: `docker/setup-buildx-action@v3`
- **Purpose**: Enables advanced Docker build features and multi-platform builds
- **Why needed**: Provides enhanced build capabilities and better caching

#### 5. Build and Test Docker Images

- **Commands**:
  - `just docker-build-ci`
  - `just docker-test-ci`
- **Purpose**: Builds all Docker image variants and runs comprehensive tests
- **Why needed**: Validates that new changes don't break Docker image functionality

#### 6. Extract hadolint Version

- **Script**: `./scripts/extract-versions.sh hadolint`
- **Purpose**: Dynamically extracts hadolint version from mise.toml
- **Why needed**: Ensures consistent hadolint version for Dockerfile validation

#### 7. Validate Dockerfiles

- **Command**: `just docker-validate`
- **Purpose**: Downloads hadolint with checksum verification and validates Dockerfiles
- **Why needed**: Ensures Dockerfiles follow best practices and are syntactically correct

---

## Job 3: Publish (`publish`)

**Purpose**: Publishes Docker images to container registries (Docker Hub and GitHub Container Registry).

### Publish Job Conditions

- **Runs on**: Main branch pushes only
- **Dependencies**: Requires `quality` and `docker-test` jobs to complete successfully

### Publish Job Steps

#### 1. Checkout Code (Publish)

- **Action**: `actions/checkout@v5`
- **Purpose**: Provides access to Dockerfiles and build context
- **Why needed**: Required for building final production images

#### 2. Install Just (Publish)

- **Action**: `extractions/setup-just@v3`
- **Purpose**: Installs the Just task runner
- **Why needed**: Just is used to execute the unified publish commands

#### 3. Install mise (Publish)

- **Action**: `jdx/mise-action@v3`
- **Version**: 2025.10.6
- **Purpose**: Installs mise for development environment management
- **Why needed**: Required for consistent tool version management

#### 4. Set up Docker Buildx (Publish)

- **Action**: `docker/setup-buildx-action@v3`
- **Purpose**: Enables multi-platform builds for production images
- **Why needed**: Ensures images work on multiple architectures

#### 5. Log in to Docker Hub

- **Action**: `docker/login-action@v3`
- **Credentials**: Uses `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` secrets
- **Purpose**: Authenticates with Docker Hub for image publishing
- **Why needed**: Required to push images to Docker Hub registry

#### 6. Log in to GitHub Container Registry

- **Action**: `docker/login-action@v3`
- **Registry**: `ghcr.io`
- **Credentials**: Uses GitHub actor and token
- **Purpose**: Authenticates with GitHub Container Registry
- **Why needed**: Required to push images to GitHub's container registry

#### 7. Publish Docker Images

- **Command**: `just publish latest`
- **Purpose**: Publishes production-ready images to both registries using unified Just interface
- **Why needed**: Makes the application available for deployment and use

---

## Key Features and Optimizations

### 1. **Parallel Execution**

- Quality and Docker testing jobs run in parallel
- Publishing only runs on main branch after both quality and docker-test complete

### 2. **Dynamic Version Management**

- Tool versions extracted dynamically from mise.toml
- Ensures consistent versions across all environments
- Python, Node.js, pnpm, and hadolint versions managed centrally

### 3. **Integrated Security Scanning**

- Security scanning integrated into quality job for faster feedback
- Trivy scans for HIGH/CRITICAL vulnerabilities and secrets
- Fails build immediately on security issues (CI_STRICT_SECURITY: true)

### 4. **Unified Task Management**

- All CI operations use Just task runner for consistency
- Single interface for local development and CI
- Simplified maintenance and debugging

### 5. **Registry Publishing**

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

- Security scanning is now integrated into the quality job
- Check Trivy output for HIGH/CRITICAL vulnerabilities and secrets
- Review security issues in the quality job logs
- Ensure CI_STRICT_SECURITY environment variable is set to true

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
