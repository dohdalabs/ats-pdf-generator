# ATS PDF Generator - Portfolio Overview

## TL;DR
Built a command-line tool that converts Markdown documents to ATS-optimized PDFs using Python and Docker. Demonstrates modern Python development practices, containerization, and CI/CD automation for a personal productivity tool.

## Problem Solved
Job seekers often struggle with Applicant Tracking Systems (ATS) that don't properly parse their resumes. I needed a reliable way to convert my Markdown-based documents into PDFs that would pass ATS screening while maintaining clean formatting. This tool solves my own workflow problem and could help other developers who maintain their resumes in Markdown.

## Technical Highlights
- **Modern Python Stack**: Python 3.13 with uv for fast dependency management and type hints for safety
- **Multi-Platform Containers**: Docker multi-stage builds supporting both Alpine (minimal) and Ubuntu (compatible)
- **Automated Quality Gates**: GitHub Actions with testing, linting, type checking, and security scanning
- **Developer Experience**: One-command setup with mise for environment management and comprehensive documentation
- **Security-First Approach**: Non-root containers, vulnerability scanning with Trivy, and secure build practices

## Key Challenges Addressed

- **Modern Python Tooling**: Evaluated and adopted cutting-edge tools (uv, mise, ruff) for faster development workflows
- **Cross-Platform Compatibility**: Solved the challenge of consistent environments across different development machines
- **Container Security**: Implemented security-first container practices with non-root users and vulnerability scanning
- **Developer Experience**: Created one-command setup and quality gates to reduce friction for contributors
- **CI/CD Complexity**: Balanced automation power with build speed for a personal project context

## Key Technologies
- **Python 3.13**: Latest Python with modern features and performance improvements
- **uv**: Fast Python package manager, chosen for speed over pip
- **Docker**: Multi-stage builds for both development and production images
- **GitHub Actions**: CI/CD for testing, building, and publishing containers
- **mise**: Python version management for consistent development environments
- **Type checking**: mypy for static type analysis
- **Linting**: ruff for fast Python linting and formatting

## Project Links
- **Repository**: [ATS PDF Generator](https://github.com/dohdalabs/ats-pdf-generator)
- **Documentation**: [README](README.md) | [Development Guide](DEVELOPMENT.md)
- **Docker Hub**: [dohdalabs/ats-pdf-generator](https://hub.docker.com/r/dohdalabs/ats-pdf-generator)
- **GitHub Container Registry**: [ghcr.io/dohdalabs/ats-pdf-generator](https://ghcr.io/dohdalabs/ats-pdf-generator)

---

*This project demonstrates practical application of modern Python development practices and containerization. It's a solid example of building tools that solve real problems while exploring current best practices in the Python ecosystem.*
