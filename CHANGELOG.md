# Changelog

<!-- markdownlint-disable MD024 -->

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Initial open source release preparation
- Multi-architecture Docker builds (AMD64, ARM64)
- GitHub Actions CI/CD pipeline
- Comprehensive documentation
- Contributing guidelines
- Security scanning integration

## [1.0.0] - 2025-01-XX

### Added

- ATS-optimized PDF generation from Markdown
- Docker-based conversion tool
- Support for cover letters and professional profiles
- WeasyPrint-based PDF engine for high-quality output
- Multi-stage Docker builds for optimized image sizes
- Alpine Linux variant for minimal footprint
- Sample templates and examples
- CSS styling for professional document formatting
- Automatic bullet point conversion (• to -)
- Command-line interface with multiple options

### Features

- **Document Types**:
  - Cover letters with business letter formatting
  - Professional profiles with structured layouts
  - Custom PDF metadata support

- **Docker Images**:
  - Optimized variant: 577MB (Ubuntu Slim based)
  - Alpine variant: 523MB (Alpine Linux based)
  - Multi-architecture support (AMD64, ARM64)

- **ATS Optimization**:
  - Standard fonts for maximum compatibility
  - High contrast text (black on white)
  - Simple layouts that don't confuse ATS systems
  - Selectable text for proper content extraction
  - Optimized typography for human and machine reading

- **Developer Experience**:
  - Simple command-line interface
  - Docker Compose support
  - Comprehensive error handling
  - Detailed documentation and examples

### Technical Details

- Based on Pandoc for document conversion
- WeasyPrint for PDF generation
- Python 3.11 runtime
- Multi-stage Docker builds
- Non-root container execution
- Resource-optimized configurations

### Documentation

- Comprehensive README with quick start guide
- User guide with detailed instructions
- Docker optimization documentation
- Sample files and templates
- Troubleshooting guides

## [Historical] - Pre-1.0.0

### Development History

- Initial development as internal tool
- Docker image optimization (3GB → 577MB reduction)
- WeasyPrint integration for PDF generation
- ATS compatibility research and implementation
- Template development and testing
