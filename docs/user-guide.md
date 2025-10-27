# User Guide

This guide walks you through installing ATS PDF Generator, preparing Markdown content, and producing ATS-friendly PDFs. If you just need a quick reminder, the [README](../README.md) covers the essentials. Come back here whenever you want deeper usage detail or tips for customizing your documents.

## Why This Tool Exists

Applicant Tracking Systems often fail to parse visually polished PDFs. ATS PDF Generator keeps the focus on your content—write in Markdown, then convert to a layout that both hiring managers and ATS software can process without surprises.

## System Requirements

- **Docker** (any recent version)
- **Operating systems**: macOS, Linux, or Windows via WSL2
- **Architectures**: x64, ARM64, or any platform supported by Docker

## Installation

```bash
# One-line install (requires Docker)
curl -sSL https://raw.githubusercontent.com/dohdalabs/ats-pdf-generator/main/install.sh | bash
```

The installer:

- Installs a stable release (v1.0.0) so behaviour is predictable
- Adds the `ats-pdf` CLI to your PATH
- Sets up a customization directory (`~/.ats-pdf/`) for optional CSS overrides

To update later, rerun the installer with `--update` or execute `ats-pdf update` if you already installed it.

## Converting Documents

```bash
# Convert a cover letter (default styling)
ats-pdf cover-letter.md -o cover-letter.pdf

# Convert a professional profile/resume summary
ats-pdf profile.md --type profile -o profile.pdf

# Convert from any directory
ats-pdf /path/to/document.md -o /path/to/output.pdf
```

## ATS Safety Validation

ATS PDF Generator automatically validates your Markdown documents to ensure they're compatible with Applicant Tracking Systems used by HR departments. This prevents common formatting issues that can cause your resume to be misread or rejected by ATS software.

### What Gets Validated

The validation system checks for:

**🚫 Critical Issues (Will Cause Problems):**

- Emojis and decorative Unicode characters
- Tables that ATS systems can't parse
- Multi-column layouts that scramble reading order
- Images containing critical information (ATS can't read text in images)

**⚠️ High Priority Issues (Should Fix):**

- Contact information without proper labels (`Email:`, `Phone:`)
- Phone numbers in non-standard formats
- URLs without `https://` protocol
- Obfuscated email addresses (`user [at] example [dot] com`)

**ℹ️ Medium Priority Issues (Consider Fixing):**

- Section headers that aren't ATS-friendly
- Date formats that may be ambiguous
- Bullet point styles that may not render correctly

**💡 Low Priority Suggestions:**

- Consistent terminology usage
- Optimal keyword placement
- Professional formatting standards

### Validation Process

When you run the converter, validation happens automatically:

```bash
ats-pdf resume.md -o resume.pdf
# ✓ Validation passed - converting to PDF
```

If issues are found, you'll see detailed error messages:

```bash
ats-pdf resume.md -o resume.pdf
# ❌ Validation failed!
# Line 5: Email address without proper label
#   Suggestion: Add 'Email:' label before the address
#
# Line 7: Phone number should use standard format
#   Suggestion: Use format: (555) 123-4567 or 555-123-4567
```

### Validation Reports

For detailed validation analysis, the system can generate comprehensive reports:

```bash
# Generate validation report
ats-pdf resume.md --validate-only --report validation_report.md
```

The report includes:

- Summary of all issues by severity level
- Specific line numbers and content
- Actionable suggestions for fixes
- Best practices for ATS compatibility

### Fixing Validation Issues

Most validation issues can be fixed by following the suggestions:

**Before:**

```markdown
user@example.com
(555) 123-4567
linkedin.com/in/user
```

**After:**

```markdown
Email: user@example.com
Phone: (555) 123-4567
LinkedIn: https://linkedin.com/in/user
```

**Common Fixes:**

- Add labels to contact information: `Email:`, `Phone:`, `LinkedIn:`
- Use standard phone formats: `(555) 123-4567` or `555-123-4567`
- Include `https://` in URLs: `https://github.com/username`
- Remove emojis and decorative characters
- Use standard section headers: `Professional Experience`, `Technical Skills`

Command options:

```text
ats-pdf [OPTIONS] <input_file>

Options:
  -o, --output FILE    Output PDF filename
  --type TYPE          Document type: cover-letter (default) or profile
  --title TITLE        Custom PDF document title
  --author AUTHOR      Custom author metadata
  --date DATE          Custom date metadata
  -h, --help           Show CLI usage
```

## Document Types

### Cover Letter (Default)

- Business-friendly layout with clear salutation and signature sections
- Keep content under ~400 words for best readability
- Special formatting helpers:
  - `<div class="salutation">Dear Hiring Manager,</div>`
  - `<div class="signature">Sincerely,<br>Your Name</div>`

### Professional Profile / Resume Summary

- Optimized for summary-style documents and quick scans
- Uses compact layout designed to stay ATS-friendly
- Supports a reusable header block for personal details

#### Profile Header Layout

Use a Pandoc fenced div to render the tight header defined in `templates/ats-profile.css`:

```markdown
::: {.resume-header}

# Your Name

**Title | Focus Areas**

**Email:** you@example.com | **Phone:** (000) 000-0000 | **Location:** City, ST

**LinkedIn:** linkedin.com/in/you | **GitHub:** github.com/you

:::
```

**Tips:**

- Keep labels (`Email`, `Phone`, etc.) in bold so the spacing stays consistent.
- When using an LLM to customize your resume, provide this block (and the [resume template](../templates/resume-markdown-template.md)) in your prompt so the generated Markdown preserves the structure.

## Examples & Templates

- `examples/sample-cover-letter.md` – full cover letter sample
- `examples/sample-profile.md` – professional profile using the header block
- `templates/resume-markdown-template.md` – reusable resume starter ideal for prompting an LLM

### Quick Preview

```bash
# Clone repo if you want the examples locally
git clone https://github.com/dohdalabs/ats-pdf-generator.git
cd ats-pdf-generator

# Generate PDFs for each example
ats-pdf examples/sample-cover-letter.md -o sample-cover-letter.pdf
ats-pdf examples/sample-profile.md --type profile -o sample-profile.pdf
```

## Customization

Want different fonts, colours, or spacing? Create `custom.css` either alongside your Markdown file or in `~/.ats-pdf/custom.css`. The converter automatically prefers custom CSS when present. The bundled CSS templates (under `templates/`) are great starting points.

## Manual Docker Usage

Prefer using Docker directly? Both Docker Hub and GHCR host the same multi-architecture image.

```bash
# Cover letter (Docker Hub)
docker run --rm -v $(pwd):/app dohdalabs/ats-pdf-generator:latest cover-letter.md -o output.pdf

# Professional profile (GitHub Container Registry)
docker run --rm -v $(pwd):/app ghcr.io/dohdalabs/ats-pdf-generator:latest profile.md -o profile.pdf --type profile
```

## Troubleshooting

- **Docker not running?** Start Docker Desktop (macOS/Windows) or ensure `docker ps` works.
- **Command not found (`ats-pdf`)?** Restart your shell so PATH changes from the installer are applied.
- **Markdown warnings?** Run `just format-markdown` or `pnpm dlx markdownlint-cli '**/*.md' --fix` to clean up formatting.
- **Need more automation help?** Check the [Development Guide](../DEVELOPMENT.md) for advanced workflows.

---
