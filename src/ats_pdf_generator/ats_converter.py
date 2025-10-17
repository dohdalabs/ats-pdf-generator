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
from typing import Optional

# Third-party
import click


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


def _determine_css_file(document_type: str, custom_css: Optional[str]) -> str:
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
        with input_path.open("r", encoding="utf-8") as f_in, output_path.open(
            "w", encoding="utf-8"
        ) as f_out:
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
@click.option("--css", "custom_css", type=click.Path(), help="Path to a custom CSS file.")
@click.option("--title", help="PDF document title.")
@click.option("--author", help="PDF document author.")
@click.option("--date", help="PDF document date (e.g., '2023-10-26').")
@click.option(
    "--pdf-engine", default="weasyprint", show_default=True, help="PDF engine to use."
)
def cli(
    input_file: str,
    output_file: Optional[str],
    document_type: str,
    custom_css: Optional[str],
    title: Optional[str],
    author: Optional[str],
    date: Optional[str],
    pdf_engine: str,
) -> None:
    """Main CLI for the ATS PDF Generator."""
    try:
        _validate_input_file(input_file)
        input_path = Path(input_file)

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
        click.secho(f"Successfully converted '{input_file}' to '{output_file}'", fg="green")
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
            "Error: pandoc not found. Please ensure it is installed.", fg="red", err=True
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