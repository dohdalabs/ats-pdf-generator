# ATS PDF Generator

🎯 **Convert Markdown documents to ATS-optimized PDFs for job applications**

[![Build Status](https://github.com/dohdalabs/ats-pdf-generator/actions/workflows/ci.yml/badge.svg)](https://github.com/dohdalabs/ats-pdf-generator/actions/workflows/ci.yml)
[![Docker Pulls](https://img.shields.io/docker/pulls/dohdalabs/ats-pdf-generator)](https://hub.docker.com/r/dohdalabs/ats-pdf-generator)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub release](https://img.shields.io/github/release/dohdalabs/ats-pdf-generator.svg)](https://github.com/dohdalabs/ats-pdf-generator/releases)

ATS PDF Generator converts Markdown cover letters and professional profiles into clean, ATS-friendly PDFs. Keep writing in Markdown; we’ll handle the formatting that recruiters and Applicant Tracking Systems can parse reliably.

For a full walkthrough (examples, profile layout tips, customization, and manual Docker usage) see the [User Guide](docs/user-guide.md).

**For developers:** See the [Development Guide](DEVELOPMENT.md) for technical details and local setup.

## 🚀 Quick Start

### System Requirements

- **Docker**: Any recent version (automatically detected during installation)
- **Operating System**: macOS, Linux, or Windows with WSL2
- **Architecture**: x64, ARM64, or other Docker-supported architectures

### Simple One-Line Installation

```bash
# Install the utility (requires Docker)
curl -sSL https://raw.githubusercontent.com/dohdalabs/ats-pdf-generator/main/install.sh | bash
```

**Installation Details:**

- Installs a stable version (v1.0.0) for reliable operation
- Creates the `ats-pdf` command in your PATH
- Sets up customization directory for styling options
- No breaking changes between updates

## 📋 Usage

```bash
# Convert a cover letter
ats-pdf cover-letter.md -o output.pdf

# Convert a professional profile
ats-pdf profile.md --type profile -o profile.pdf

# Convert from any directory
ats-pdf /path/to/your/document.md -o /path/to/output.pdf
```

**Command Options:**

```bash
ats-pdf [OPTIONS] <input_file>

Options:
  -o, --output FILE    Output PDF filename
  --type TYPE         Document type (cover-letter, profile)
  --title TITLE       PDF document title
  --author AUTHOR     PDF document author
  --date DATE         PDF document date
  -h, --help          Show help message
```

### Manual Docker Usage (Alternative)

```bash
# Convert a cover letter (Docker Hub)
docker run --rm -v $(pwd):/app dohdalabs/ats-pdf-generator:latest cover-letter.md -o output.pdf

# Convert a professional profile (GitHub Container Registry)
docker run --rm -v $(pwd):/app ghcr.io/dohdalabs/ats-pdf-generator:latest profile.md -o profile.pdf
```

## 📝 Document Types

### Cover Letter (Default)

- Optimized for standard business correspondence
- Validates for proper salutations
- Recommends keeping under 400 words
- Professional formatting suitable for any industry

### Professional Profile

- Optimized for summary/overview documents
- Validates for profile structure
- Clean, readable layout
- Supports compact resume header with structured contact information (see [User Guide](docs/user-guide.md#professional-profile-header))
- Perfect for LinkedIn exports or portfolio additions

## 📁 Examples

Complete, working examples are available in the [GitHub repository](https://github.com/dohdalabs/ats-pdf-generator/tree/main/examples):

- **[sample-cover-letter.md](https://github.com/dohdalabs/ats-pdf-generator/blob/main/examples/sample-cover-letter.md)** - Complete cover letter with styling classes
- **[sample-profile.md](https://github.com/dohdalabs/ats-pdf-generator/blob/main/examples/sample-profile.md)** - Professional profile example
- **[resume-markdown-template.md](https://github.com/dohdalabs/ats-pdf-generator/blob/main/templates/resume-markdown-template.md)** - Starter template for profile-style resumes (great context to share with an LLM)

To use these examples, download them directly:

> Looking for installation details, advanced formatting, or manual Docker commands? Head over to the [User Guide](docs/user-guide.md).

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔗 Related Projects

- [Pandoc](https://github.com/jgm/pandoc) - Universal document converter
- [WeasyPrint](https://github.com/Kozea/WeasyPrint) - HTML/CSS to PDF library
- [Resume.md](https://github.com/mikepqr/resume.md) - Markdown resume generator

## 💡 Support

### Documentation

- [Examples](examples/) - Sample input and output files

---

### Made with ❤️ for job seekers worldwide

If this tool helped you land your dream job, consider ⭐ starring the repository!
