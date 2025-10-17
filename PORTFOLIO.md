# ATS PDF Generator - Portfolio Overview

## TL;DR

Built a command-line tool that converts Markdown documents to ATS-optimized PDFs using Python and Docker. Demonstrates modern Python development practices, containerization, and CI/CD automation for a personal productivity tool.

## Problem Solved

Job seekers often struggle with Applicant Tracking Systems (ATS) that don't properly parse their resumes. I needed a reliable way to convert my Markdown-based documents into PDFs that would pass ATS screening while maintaining clean formatting. This tool solves my own workflow problem and could help other developers who maintain their resumes in Markdown.

## Technical Highlights

- **Just-Based Task Automation**: Unified command interface (`just ci`, `just quick`, `just check`) that works identically in local development and CI/CD environments
- **Modern Python Stack**: Python 3.13 with uv for fast dependency management and type hints for safety
- **Multi-Platform Containers**: Docker multi-stage builds supporting both Alpine (minimal) and Ubuntu (compatible)
- **Automated Quality Gates**: GitHub Actions with testing, linting, type checking, and security scanning
- **Developer Experience**: One-command setup with mise for environment management and comprehensive documentation
- **Security-First Approach**: Non-root containers, vulnerability scanning with Trivy, and secure build practices

## Key Challenges Addressed

- **CI/CD Consistency**: Eliminated the common problem of different behavior between local development and CI environments by implementing all operations as just recipes
- **Developer Experience**: Created unified command interface (`just ci`, `just quick`, `just check`) that reduces cognitive load and ensures consistent quality standards
- **Modern Python Tooling**: Evaluated and adopted cutting-edge tools (uv, mise, ruff) for faster development workflows
- **Cross-Platform Compatibility**: Solved the challenge of consistent environments across different development machines
- **Container Security**: Implemented security-first container practices with non-root users and vulnerability scanning
- **Maintainability**: Reduced CI/CD complexity by centralizing all automation logic in just recipes rather than duplicating YAML workflows

## Key Technologies

- **just**: Task runner providing unified command interface for all development operations
- **Python 3.13**: Latest Python with modern features and performance improvements
- **uv**: Fast Python package manager, chosen for speed over pip
- **Docker**: Multi-stage builds for both development and production images
- **GitHub Actions**: CI/CD for testing, building, and publishing containers
- **mise**: Python version management for consistent development environments
- **Type checking**: mypy for static type analysis
- **Linting**: ruff for fast Python linting and formatting

## Architecture & Implementation

**Just-Based Development Workflow**: The project's most significant architectural decision was implementing all operations as just recipes rather than duplicating logic between local development and CI/CD environments. This approach provides:

- **Unified Interface**: Commands like `just ci`, `just quick`, and `just check` work identically locally and in GitHub Actions
- **Reduced Complexity**: GitHub Actions workflows are simple just calls rather than complex YAML logic
- **Better Testability**: All automation can be tested locally before pushing to CI
- **Self-Documenting**: `just --list` provides clear documentation of available commands

**Multi-Stage Docker Strategy**: Implemented separate builder and runtime stages for both Alpine (minimal size) and Ubuntu (maximum compatibility) variants, achieving ~40% size reduction while maintaining security with non-root users.

**Modern Python Toolchain**: Adopted cutting-edge tools (uv, ruff, mise) for faster development cycles while maintaining comprehensive quality gates through automated testing, linting, type checking, and security scanning.

## Project Links

- **Repository**: [ATS PDF Generator](https://github.com/dohdalabs/ats-pdf-generator)
- **Documentation**: [README](README.md) | [Development Guide](DEVELOPMENT.md)
- **Docker Hub**: [dohdalabs/ats-pdf-generator](https://hub.docker.com/r/dohdalabs/ats-pdf-generator)
- **GitHub Container Registry**: [ghcr.io/dohdalabs/ats-pdf-generator](https://ghcr.io/dohdalabs/ats-pdf-generator)

---

*This project demonstrates practical application of modern Python development practices, containerization, and developer experience optimization. The just-based approach to CI/CD consistency is particularly noteworthy as it solves a common pain point in modern development workflows while showcasing how to build maintainable automation that works identically across local and cloud environments.*
