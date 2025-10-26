#!/usr/bin/env python3
"""
ATS Document Converter

A robust and developer-friendly tool for converting Markdown documents
into ATS-optimized PDFs. It uses Pandoc and WeasyPrint for high-quality
output, with a focus on simplicity and content-first authoring.
"""

# Standard library
import os
import subprocess
import sys
from pathlib import Path

# Third-party
import click

# First-party
from ats_pdf_generator.validator import Severity, validate_document


class ATSGeneratorError(Exception):
    """Base exception for ATS PDF Generator."""


class ValidationError(ATSGeneratorError):
    """Input validation failed."""


class FileOperationError(ATSGeneratorError):
    """File operation failed."""


class ConversionError(ATSGeneratorError):
    """PDF conversion failed."""


def _create_fallback_css(css_path: Path) -> None:
    """Create a fallback CSS file with basic styling.

    Args:
        css_path: Path where the fallback CSS file should be created.

    Raises:
        FileOperationError: If the CSS file cannot be created.
    """
    fallback_content = """/* Fallback CSS for ATS PDF Generator */
body {
    font-family: Arial, sans-serif;
    font-size: 12pt;
    line-height: 1.4;
    margin: 1in;
    color: #000;
}

h1, h2, h3, h4, h5, h6 {
    font-weight: bold;
    margin-top: 1em;
    margin-bottom: 0.5em;
}

h1 { font-size: 18pt; }
h2 { font-size: 16pt; }
h3 { font-size: 14pt; }

p {
    margin-bottom: 0.5em;
    text-align: justify;
}

ul, ol {
    margin-bottom: 0.5em;
    padding-left: 1.5em;
}

li {
    margin-bottom: 0.25em;
}

strong, b {
    font-weight: bold;
}

em, i {
    font-style: italic;
}

/* Ensure proper page breaks */
.page-break {
    page-break-before: always;
}

/* Basic table styling */
table {
    border-collapse: collapse;
    width: 100%;
    margin-bottom: 1em;
}

th, td {
    border: 1px solid #000;
    padding: 0.25em;
    text-align: left;
}

th {
    background-color: #f0f0f0;
    font-weight: bold;
}
"""
    try:
        css_path.parent.mkdir(parents=True, exist_ok=True)
        css_path.write_text(fallback_content, encoding="utf-8")
    except OSError as e:
        raise FileOperationError(f"Cannot create CSS file {css_path}: {e}") from e


def _determine_css_file(document_type: str, custom_css: str | None) -> str:
    """Determine the appropriate CSS file.

    Priority:
    1. Custom CSS if provided and exists.
    2. Document type-specific CSS.
    3. Fallback CSS if no other options are available.

    Args:
        document_type: The type of document ('cover-letter' or 'profile').
        custom_css: Path to a custom CSS file.

    Returns:
        Path to the appropriate CSS file (guaranteed to exist).

    Raises:
        FileOperationError: If CSS templates directory can't be created.
        ValidationError: If custom CSS file is not found.
    """
    if custom_css:
        if not Path(custom_css).exists():
            raise ValidationError(f"Custom CSS file not found: {custom_css}")
        return custom_css

    css_map = {
        "cover-letter": "templates/ats-cover-letter.css",
        "profile": "templates/ats-profile.css",
    }
    css_path = Path(css_map.get(document_type, "templates/ats-cover-letter.css"))

    if not css_path.exists():
        fallback_css = Path("templates/ats-fallback.css")
        _create_fallback_css(fallback_css)
        return str(fallback_css)

    return str(css_path)


def _preprocess_markdown(input_path: Path, output_path: Path) -> None:
    """Preprocess markdown file to convert custom bullets to standard list items.

    Args:
        input_path: Path to the source markdown file.
        output_path: Path to the preprocessed markdown file.

    Raises:
        FileOperationError: If file processing fails.
    """
    try:
        with (
            input_path.open("r", encoding="utf-8") as f_in,
            output_path.open("w", encoding="utf-8") as f_out,
        ):
            for line in f_in:
                stripped = line.lstrip()
                if stripped.startswith(("• ", "* ")):
                    indent = line[: len(line) - len(stripped)]
                    content = stripped[2:]
                    f_out.write(f"{indent}- {content}")
                else:
                    f_out.write(line)
    except OSError as e:
        raise FileOperationError(f"Failed to preprocess file {input_path}: {e}") from e


def _validate_input_file(file_path: str) -> None:
    """Validate input file exists and is readable.

    Args:
        file_path: Path to the input file.

    Raises:
        ValidationError: If file validation fails.
        FileOperationError: If file cannot be accessed.
    """
    path = Path(file_path)
    if not path.exists():
        raise ValidationError(f"Input file does not exist: {file_path}")
    if not path.is_file():
        raise ValidationError(f"Input path is not a file: {file_path}")
    if not os.access(path, os.R_OK):
        raise FileOperationError(f"Cannot read input file: {file_path}")


def _generate_validation_report(violations: list, input_file: str) -> str:
    """Generate a comprehensive validation report.

    Args:
        violations: List of validation violations.
        input_file: Path to the input file being validated.

    Returns:
        Formatted validation report string.
    """
    from datetime import datetime

    # Count violations by severity
    critical_count = sum(1 for v in violations if v.severity == Severity.CRITICAL)
    high_count = sum(1 for v in violations if v.severity == Severity.HIGH)
    medium_count = sum(1 for v in violations if v.severity == Severity.MEDIUM)
    low_count = sum(1 for v in violations if v.severity == Severity.LOW)

    # Determine overall status
    if critical_count > 0:
        status = "FAIL"
    elif high_count > 0:
        status = "WARNING"
    else:
        status = "PASS"

    report_lines = [
        "# ATS Safety Verification Report",
        "",
        f"## Document: {Path(input_file).name}",
        f"**Verification Date:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
        f"**Overall Status:** {status}",
        "",
        "---",
        "",
        "## Summary",
        f"- Critical Issues: {critical_count}",
        f"- High Severity Issues: {high_count}",
        f"- Medium Severity Issues: {medium_count}",
        f"- Low Severity Issues: {low_count}",
        "",
        "---",
        "",
    ]

    # Group violations by severity
    critical_violations = [v for v in violations if v.severity == Severity.CRITICAL]
    high_violations = [v for v in violations if v.severity == Severity.HIGH]
    medium_violations = [v for v in violations if v.severity == Severity.MEDIUM]
    low_violations = [v for v in violations if v.severity == Severity.LOW]

    # Add violation details
    if critical_violations:
        report_lines.extend(["## Critical Issues (Must Fix)", ""])
        for violation in critical_violations:
            report_lines.extend(
                [
                    f"### {violation.violation_type} at line {violation.line_number}",
                    "",
                    f"**Severity:** {violation.severity.value}",
                    "",
                    f"**Found:** {violation.found_text}",
                    "",
                    f"**Issue:** {violation.message}",
                    "",
                    f"**Suggestion:** {violation.suggestion}",
                    "",
                    f"**Example:** {violation.line_content}",
                    "",
                ]
            )

    if high_violations:
        report_lines.extend(["## High Severity Issues (Should Fix)", ""])
        for violation in high_violations:
            report_lines.extend(
                [
                    f"### {violation.violation_type} at line {violation.line_number}",
                    "",
                    f"**Severity:** {violation.severity.value}",
                    "",
                    f"**Found:** {violation.found_text}",
                    "",
                    f"**Issue:** {violation.message}",
                    "",
                    f"**Suggestion:** {violation.suggestion}",
                    "",
                    f"**Example:** {violation.line_content}",
                    "",
                ]
            )

    if medium_violations:
        report_lines.extend(["## Medium Severity Issues (Consider Fixing)", ""])
        for violation in medium_violations:
            report_lines.extend(
                [
                    f"### {violation.violation_type} at line {violation.line_number}",
                    "",
                    f"**Severity:** {violation.severity.value}",
                    "",
                    f"**Found:** {violation.found_text}",
                    "",
                    f"**Issue:** {violation.message}",
                    "",
                    f"**Suggestion:** {violation.suggestion}",
                    "",
                    f"**Example:** {violation.line_content}",
                    "",
                ]
            )

    if low_violations:
        report_lines.extend(["## Low Severity Issues (Optional)", ""])
        for violation in low_violations:
            report_lines.extend(
                [
                    f"### {violation.violation_type} at line {violation.line_number}",
                    "",
                    f"**Severity:** {violation.severity.value}",
                    "",
                    f"**Found:** {violation.found_text}",
                    "",
                    f"**Issue:** {violation.message}",
                    "",
                    f"**Suggestion:** {violation.suggestion}",
                    "",
                    f"**Example:** {violation.line_content}",
                    "",
                ]
            )

    report_lines.extend(
        [
            "---",
            "",
            "## Recommendations",
            "For best ATS compatibility:",
            "- Use standard fonts (Arial, Calibri, Times New Roman)",
            "- Avoid tables, columns, and complex layouts",
            "- Use standard section headers",
            "- Include relevant keywords naturally",
            "- Use standard date formats (Month YYYY - Month YYYY)",
            "- Avoid emojis, special characters, and creative formatting",
        ]
    )

    return "\n".join(report_lines)


def _print_violations_summary(violations: list) -> None:
    """Print a summary of violations to the console.

    Args:
        violations: List of validation violations.
    """
    if not violations:
        click.secho("✅ No ATS compatibility issues found!", fg="green", bold=True)
        return

    # Count violations by severity
    critical_count = sum(1 for v in violations if v.severity == Severity.CRITICAL)
    high_count = sum(1 for v in violations if v.severity == Severity.HIGH)
    medium_count = sum(1 for v in violations if v.severity == Severity.MEDIUM)
    low_count = sum(1 for v in violations if v.severity == Severity.LOW)

    # Print summary
    click.secho("\n📊 ATS Validation Summary:", fg="blue", bold=True)
    if critical_count > 0:
        click.secho(f"  🔴 Critical Issues: {critical_count}", fg="red")
    if high_count > 0:
        click.secho(f"  🟡 High Severity Issues: {high_count}", fg="yellow")
    if medium_count > 0:
        click.secho(f"  🟠 Medium Severity Issues: {medium_count}", fg="yellow")
    if low_count > 0:
        click.secho(f"  🔵 Low Severity Issues: {low_count}", fg="blue")

    # Print detailed violations
    click.secho("\n📋 Detailed Issues:", fg="blue", bold=True)
    for violation in violations:
        if violation.severity == Severity.CRITICAL:
            color = "red"
            icon = "🔴"
        elif violation.severity == Severity.HIGH:
            color = "yellow"
            icon = "🟡"
        elif violation.severity == Severity.MEDIUM:
            color = "yellow"
            icon = "🟠"
        else:
            color = "blue"
            icon = "🔵"

        click.secho(
            f"  {icon} Line {violation.line_number}: {violation.message}", fg=color
        )
        click.secho(f"     💡 {violation.suggestion}", fg="cyan")


@click.command(
    help="Convert Markdown documents to ATS-optimized PDFs.",
    context_settings={"help_option_names": ["-h", "--help"]},
)
@click.argument(
    "input_file",
    type=click.Path(exists=True, dir_okay=False, readable=True, resolve_path=True),
)
@click.option(
    "-o",
    "--output",
    "output_file",
    type=click.Path(writable=True, resolve_path=True),
    help="Output PDF filename. Defaults to input filename with .pdf extension.",
)
@click.option(
    "--type",
    "document_type",
    type=click.Choice(["cover-letter", "profile"], case_sensitive=False),
    default="cover-letter",
    show_default=True,
    help="Specifies the document type for styling.",
)
@click.option(
    "--css", "custom_css", type=click.Path(), help="Path to a custom CSS file."
)
@click.option("--title", help="PDF document title.")
@click.option("--author", help="PDF document author.")
@click.option("--date", help="PDF document date (e.g., '2023-10-26').")
@click.option(
    "--pdf-engine", default="weasyprint", show_default=True, help="PDF engine to use."
)
@click.option(
    "--validate-only",
    is_flag=True,
    help="Only validate the document for ATS compatibility without converting to PDF.",
)
@click.option(
    "--validation-report",
    type=click.Path(writable=True, resolve_path=True),
    help="Save detailed validation report to a file.",
)
@click.option(
    "--fail-on-warning",
    is_flag=True,
    help="Exit with error code if any validation issues are found (not just critical).",
)
def cli(
    input_file: str,
    output_file: str | None,
    document_type: str,
    custom_css: str | None,
    title: str | None,
    author: str | None,
    date: str | None,
    pdf_engine: str,
    validate_only: bool,
    validation_report: str | None,
    fail_on_warning: bool,
) -> None:
    """Main CLI for the ATS PDF Generator."""
    try:
        _validate_input_file(input_file)
        input_path = Path(input_file)

        # Validate the document for ATS compatibility
        violations = validate_document(input_path)

        # Generate validation report if requested
        if validation_report:
            report_content = _generate_validation_report(violations, input_file)
            with open(validation_report, "w", encoding="utf-8") as f:
                f.write(report_content)
            click.secho(
                f"📄 Validation report saved to: {validation_report}", fg="green"
            )

        # Print validation summary
        _print_violations_summary(violations)

        # Handle validation-only mode
        if validate_only:
            if violations:
                critical_count = sum(
                    1 for v in violations if v.severity == Severity.CRITICAL
                )
                high_count = sum(1 for v in violations if v.severity == Severity.HIGH)

                if critical_count > 0:
                    click.secho(
                        "\n❌ Validation failed - critical issues found!",
                        fg="red",
                        bold=True,
                    )
                    sys.exit(1)
                elif fail_on_warning and (high_count > 0 or len(violations) > 0):
                    click.secho(
                        "\n⚠️  Validation failed - issues found!", fg="yellow", bold=True
                    )
                    sys.exit(1)
                else:
                    click.secho("\n✅ Validation completed with warnings", fg="yellow")
            else:
                click.secho("\n✅ Validation passed - no issues found!", fg="green")
            return

        # Check for critical violations that should prevent conversion
        critical_violations = [v for v in violations if v.severity == Severity.CRITICAL]
        if critical_violations:
            click.secho(
                "\n❌ Conversion aborted - critical ATS compatibility issues found!",
                fg="red",
                bold=True,
                err=True,
            )
            click.secho(
                "Fix the critical issues above before converting to PDF.",
                fg="red",
                err=True,
            )
            sys.exit(1)

        # Warn about high severity issues but allow conversion
        high_violations = [v for v in violations if v.severity == Severity.HIGH]
        if high_violations and not fail_on_warning:
            click.secho(
                "\n⚠️  High severity issues found - consider fixing before submitting to ATS systems.",
                fg="yellow",
                err=True,
            )

        if not output_file:
            output_file = str(input_path.with_suffix(".pdf"))

        # Prepare for preprocessing
        tmp_dir = Path("/app/tmp") if Path("/app/tmp").exists() else Path("tmp")
        tmp_dir.mkdir(exist_ok=True)
        preprocessed_file = tmp_dir / f"{input_path.stem}.preprocessed.md"

        _preprocess_markdown(input_path, preprocessed_file)

        # Build pandoc command
        cmd = ["pandoc", str(preprocessed_file), "-o", output_file]
        cmd.extend(["--pdf-engine", pdf_engine])

        css_file = _determine_css_file(document_type, custom_css)
        cmd.extend(["--css", css_file])

        # Add metadata if provided
        if title:
            cmd.extend(["--metadata", f"title={title}"])
        if author:
            cmd.extend(["--metadata", f"author={author}"])
        if date:
            cmd.extend(["--metadata", f"date={date}"])

        # Execute pandoc
        result = subprocess.run(cmd, check=True, capture_output=True, text=True)
        click.secho(
            f"Successfully converted '{input_file}' to '{output_file}'", fg="green"
        )
        if result.stdout:
            click.echo(result.stdout)

    except (ValidationError, FileOperationError, ConversionError) as e:
        click.secho(f"Error: {e}", fg="red", err=True)
        sys.exit(1)
    except subprocess.CalledProcessError as e:
        error_msg = f"Pandoc conversion failed: {e.stderr or e.stdout}"
        click.secho(error_msg, fg="red", err=True)
        sys.exit(1)
    except FileNotFoundError:
        click.secho(
            "Error: pandoc not found. Please ensure it is installed.",
            fg="red",
            err=True,
        )
        sys.exit(1)
    except Exception as e:
        click.secho(f"An unexpected error occurred: {e}", fg="red", err=True)
        sys.exit(2)
    finally:
        # Cleanup
        if "preprocessed_file" in locals() and preprocessed_file.exists():
            try:
                os.remove(preprocessed_file)
            except OSError:
                pass


if __name__ == "__main__":
    cli()
