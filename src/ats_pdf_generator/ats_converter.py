#!/usr/bin/env python3
"""
ATS Document Converter

Simple Python wrapper for pandoc with weasyprint.
Optimized for cover letters and professional profiles.
"""

# Standard library
import os
import re
import subprocess
import sys
from pathlib import Path


class ATSGeneratorError(Exception):
    """Base exception for ATS PDF Generator."""


class ValidationError(ATSGeneratorError):
    """Input validation failed."""


class FileOperationError(ATSGeneratorError):
    """File operation failed."""


class ConversionError(ATSGeneratorError):
    """PDF conversion failed."""


def _create_fallback_css(css_path: str) -> None:
    """Create a fallback CSS file with basic styling.

    Args:
        css_path: Path where the fallback CSS file should be created

    Raises:
        FileOperationError: If the CSS file cannot be created
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
        with open(css_path, "w", encoding="utf-8") as f:
            f.write(fallback_content)
    except OSError as e:
        raise FileOperationError(f"Cannot create CSS file {css_path}: {e}") from e


def _determine_css_file(files: list[str]) -> str:
    """Determine the appropriate CSS file based on file content and names.

    Always returns a valid CSS file path or creates a fallback CSS file.

    Args:
        files: List of markdown files to analyze

    Returns:
        Path to the appropriate CSS file (guaranteed to exist)

    Raises:
        FileOperationError: If CSS templates directory doesn't exist and can't be created
    """
    # Define CSS templates and their associated keywords
    css_templates = {
        "templates/ats-profile.css": {
            "filename_keywords": ["profile", "summary", "overview", "background"],
            "content_keywords": [
                "profile",
                "summary",
                "overview",
                "background",
                "experience",
                "skills",
            ],
        },
        "templates/ats-cover-letter.css": {
            "filename_keywords": ["cover", "letter", "application"],
            "content_keywords": [
                "dear",
                "sincerely",
                "application",
                "position",
                "role",
            ],
        },
        "templates/ats-document.css": {
            "filename_keywords": ["document", "general"],
            "content_keywords": ["document", "content"],
        },
    }

    # Default CSS file
    default_css = "templates/ats-cover-letter.css"

    # Validate that templates directory exists
    templates_dir = Path("templates")
    if not templates_dir.exists():
        try:
            templates_dir.mkdir(exist_ok=True)
        except OSError as e:
            raise FileOperationError(f"Cannot create templates directory: {e}") from e

    # Check if any CSS templates exist
    available_templates = [
        css_path for css_path in css_templates.keys() if os.path.exists(css_path)
    ]

    # If no templates exist, create a fallback CSS file
    if not available_templates:
        fallback_css = "templates/ats-fallback.css"
        _create_fallback_css(fallback_css)
        return fallback_css

    # If no files provided, return first available template or default
    if not files:
        return default_css if os.path.exists(default_css) else available_templates[0]

    # First pass: Check filenames for definitive signals
    for file_path in files:
        filename_lower = os.path.basename(file_path).lower()

        # Check each CSS template's filename keywords
        for css_path, config in css_templates.items():
            if os.path.exists(css_path):
                for keyword in config["filename_keywords"]:
                    # Use word boundary matching, but allow keywords adjacent to file extensions
                    # Pattern: word boundary + keyword + (word boundary OR end of string OR file extension)
                    pattern = r"\b" + re.escape(keyword) + r"(?:\b|$|\.)"
                    if re.search(pattern, filename_lower):
                        return css_path

    # Second pass: Analyze content if filename didn't provide definitive match
    for file_path in files:
        try:
            with open(file_path, encoding="utf-8") as f:
                content = f.read().lower()

                # Check each CSS template's content keywords
                for css_path, config in css_templates.items():
                    if os.path.exists(css_path):
                        # Use word boundary matching for content analysis
                        for keyword in config["content_keywords"]:
                            pattern = r"\b" + re.escape(keyword) + r"\b"
                            if re.search(pattern, content):
                                return css_path

        except OSError:
            # Skip files that can't be read, continue with others
            continue

    # If no match found, return default CSS or first available template
    return default_css if os.path.exists(default_css) else available_templates[0]


def _validate_input_file(file_path: str) -> None:
    """Validate input file exists and is readable.

    Args:
        file_path: Path to the input file

    Raises:
        ValidationError: If file validation fails
        FileOperationError: If file cannot be accessed
    """
    path = Path(file_path)

    if not path.exists():
        raise ValidationError(f"Input file does not exist: {file_path}")

    if not path.is_file():
        raise ValidationError(f"Path is not a file: {file_path}")

    if not os.access(path, os.R_OK):
        raise FileOperationError(f"Cannot read file: {file_path}")


def main() -> None:
    """Simple wrapper to call pandoc with weasyprint engine.

    Raises:
        ConversionError: If pandoc conversion fails
        FileOperationError: If file operations fail
        ValidationError: If input validation fails
    """
    if len(sys.argv) < 2 or "--help" in sys.argv or "-h" in sys.argv:
        print("ATS Document Converter")
        print("Convert Markdown documents to ATS-optimized PDFs for job applications")
        print("")
        print("Usage: python3 ats_converter.py input.md [options]")
        print("")
        print("Options:")
        print("  -o FILE, --output=FILE    Output file (default: input.pdf)")
        print("  --css=FILE               Custom CSS file")
        print("  --pdf-engine=ENGINE      PDF engine (default: weasyprint)")
        print("  -h, --help               Show this help message")
        print("")
        print("Examples:")
        print("  python3 ats_converter.py cover-letter.md -o cover-letter.pdf")
        print("  python3 ats_converter.py profile.md --css custom.css")
        sys.exit(0)

    # Preprocess: convert lines beginning with a bullet '•' to markdown list '- '
    args: list[str] = sys.argv[1:]
    files: list[str] = [a for a in args if a.endswith(".md")]

    # Validate input files
    for file_path in files:
        _validate_input_file(file_path)

    temp_files: list[Path] = []
    processed_args: list[str] = []

    # Ensure tmp directory exists - use /app/tmp if available, otherwise use current directory
    tmp_dir: Path
    if Path("/app/tmp").exists():
        tmp_dir = Path("/app/tmp")
    else:
        tmp_dir = Path("tmp")
        tmp_dir.mkdir(exist_ok=True)

    for a in args:
        if a in files:
            src = Path(a)
            tmp = tmp_dir / f"{src.stem}.preprocessed.md"
            try:
                with (
                    src.open("r", encoding="utf-8") as f_in,
                    tmp.open("w", encoding="utf-8") as f_out,
                ):
                    for line in f_in:
                        # Normalize bullet chars to markdown list item
                        stripped = line.lstrip()
                        if stripped.startswith("• ") or stripped.startswith("* "):
                            indent = line[: len(line) - len(stripped)]
                            # Remove bullet and space (first 2 chars), keep rest including newline
                            content = stripped[2:]
                            f_out.write(f"{indent}- {content}")
                        else:
                            f_out.write(line)
                temp_files.append(tmp)
                processed_args.append(str(tmp))
            except OSError as e:
                raise FileOperationError(f"Failed to process file {src}: {e}") from e
        else:
            processed_args.append(a)

    # Build pandoc command
    cmd: list[str] = ["pandoc"] + processed_args

    # Ensure we use weasyprint engine if not specified
    if "--pdf-engine" not in " ".join(sys.argv):
        cmd.extend(["--pdf-engine", "weasyprint"])

    # Add default CSS if not specified
    if "--css" not in " ".join(sys.argv):
        css_file: str = _determine_css_file(files)
        cmd.extend(["--css", css_file])

    try:
        # Execute pandoc command
        result = subprocess.run(cmd, check=True, capture_output=True, text=True)
        print("Successfully converted to PDF")
        if result.stdout:
            print(result.stdout)
    except subprocess.CalledProcessError as e:
        error_msg = f"Pandoc conversion failed with return code {e.returncode}"
        if e.stderr:
            error_msg += f": {e.stderr}"
        raise ConversionError(error_msg) from e
    except FileNotFoundError as e:
        raise ConversionError(
            "Pandoc not found. Please ensure pandoc is installed."
        ) from e
    finally:
        # Cleanup temporary files
        for tmp in temp_files:
            try:
                os.remove(tmp)
            except OSError:
                pass  # Ignore cleanup errors


if __name__ == "__main__":
    main()
