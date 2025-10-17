# ATS PDF Generator

🎯 **Convert Markdown documents to ATS-optimized PDFs for job applications**

[![Build Status](https://github.com/dohdalabs/ats-pdf-generator/actions/workflows/ci.yml/badge.svg)](https://github.com/dohdalabs/ats-pdf-generator/actions/workflows/ci.yml)
[![Docker Pulls](https://img.shields.io/docker/pulls/dohdalabs/ats-pdf-generator)](https://hub.docker.com/r/dohdalabs/ats-pdf-generator)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub release](https://img.shields.io/github/release/dohdalabs/ats-pdf-generator.svg)](https://github.com/dohdalabs/ats-pdf-generator/releases)

A simple, easy-to-use tool that converts your Markdown content into clean, **ATS-compatible** PDFs—so you can stay focused on crafting great content without worrying about formatting quirks that can trip up automated tracking system parsers.

## Why This Tool Exists

I built this because I got tired of fighting with AI-generated PDFs that looked great to humans but confused Applicant Tracking Systems (ATS). You know the drill - you spend time crafting the perfect cover letter, export it as a PDF, and then wonder if the ATS can actually read it properly.

This tool solves that problem by focusing on what actually matters: **content that ATS systems can parse reliably**. Write your cover letters and professional profiles in Markdown (which is much easier to focus on content with), and let this tool handle creating PDFs that both humans and machines can read.

## What Makes This Different

- **Actually ATS-Friendly**: Uses fonts and layouts that tracking systems can parse
- **Content-First**: Write in Markdown so you can focus on your message, not formatting
- **No Font Surprises**: Standard fonts that work everywhere, every time
- **Simple**: One command, reliable output, no complex setup
- **Works Everywhere**: Same results whether you're on Mac, Linux, or Windows

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
- Perfect for LinkedIn exports or portfolio additions

## 📁 Examples

Complete, working examples are available in the [GitHub repository](https://github.com/dohdalabs/ats-pdf-generator/tree/main/examples):

- **[sample-cover-letter.md](https://github.com/dohdalabs/ats-pdf-generator/blob/main/examples/sample-cover-letter.md)** - Complete cover letter with styling classes
- **[sample-profile.md](https://github.com/dohdalabs/ats-pdf-generator/blob/main/examples/sample-profile.md)** - Professional profile example

To use these examples, download them directly:

### Option 1: Download individual files

```bash
# Download cover letter example
curl -O https://raw.githubusercontent.com/dohdalabs/ats-pdf-generator/main/examples/sample-cover-letter.md

# Download profile example
curl -O https://raw.githubusercontent.com/dohdalabs/ats-pdf-generator/main/examples/sample-profile.md

# Try them out
ats-pdf sample-cover-letter.md -o sample-cover-letter.pdf
ats-pdf sample-profile.md --type profile -o sample-profile.pdf
```

### Option 2: Clone the repository

```bash
git clone https://github.com/dohdalabs/ats-pdf-generator.git
cd ats-pdf-generator
ats-pdf examples/sample-cover-letter.md -o sample-cover-letter.pdf
```

## 📄 Formatting Your Documents

Write your content in standard Markdown. The tool includes special formatting for cover letters:

**Cover Letter Special Formatting:**

- `<div class="salutation">Dear [Name],</div>` - Properly formats the greeting
- `<div class="signature">Sincerely,<br>Your Name</div>` - Professional signature block

**Examples:**

- Cover letters: [sample-cover-letter.md](examples/sample-cover-letter.md)
- Professional profiles: [sample-profile.md](examples/sample-profile.md)

## 🎨 Customization

Want to change fonts, colors, or spacing? Create a `custom.css` file in your project directory or `~/.ats-pdf/` and the tool will automatically use it instead of the default styling.

The default styling is already ATS-optimized, so most users don't need to customize anything.

## 🐳 How It Works

The tool uses Docker to ensure consistent, ATS-optimized results:

- **No Setup Required**: Just install and use
- **Consistent Output**: Same results on any system
- **ATS Optimized**: Built-in fonts and formatting that work with tracking systems
- **Clean Operation**: No local dependencies or installation needed

## 💻 Supported Platforms

The tool works seamlessly across all major platforms:

- **macOS**: Intel (x64) and Apple Silicon (ARM64)
- **Linux**: x64, ARM64, and other architectures
- **Windows**: WSL2 (Windows Subsystem for Linux)
- **Cloud**: Any environment with Docker support

Docker automatically selects the correct architecture for your system, so you get optimal performance without any configuration.

## 📦 Installation Options

The ATS PDF Generator is available on two public registries for maximum availability:

### Docker Hub (Primary Registry)

```bash
# Latest standard version
docker pull dohdalabs/ats-pdf-generator:latest

# Specific version
docker pull dohdalabs/ats-pdf-generator:1.0.0
```

### GitHub Container Registry

```bash
# Latest version
docker pull ghcr.io/dohdalabs/ats-pdf-generator:latest

# Specific version
docker pull ghcr.io/dohdalabs/ats-pdf-generator:v1.0.0
```

> **Note**: Both registries provide the same image with multi-architecture support (linux/amd64, linux/arm64). Both are completely free for public repositories with unlimited downloads.

## 🛠️ Development

Want to customize or extend this tool for your own needs? Check out the [Development Guide](DEVELOPMENT.md) for setup instructions and how to build your own version.

## 🔄 Updates

The installed version is stable and won't change unexpectedly. To get the latest features and bug fixes:

```bash
# Update to latest version
ats-pdf update

# Or reinstall from scratch
curl -sSL https://raw.githubusercontent.com/dohdalabs/ats-pdf-generator/main/install.sh | bash -s -- --update
```

### Version Strategy

- **Installation**: Uses stable version (v1.0.0) for reliability
- **Updates**: Available on-demand with `ats-pdf update`
- **No Breaking Changes**: Updates maintain compatibility
- **Fast Downloads**: Subsequent uses benefit from cached images

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
