#!/usr/bin/env python3
"""
ATS Document Converter

Simple Python wrapper for pandoc with weasyprint.
Optimized for cover letters and professional profiles.
"""

import os
import subprocess
import sys
from pathlib import Path


class ATSGeneratorError(Exception):
    """Base exception for ATS PDF Generator."""


class FileOperationError(ATSGeneratorError):
    """File operation failed."""


class ConversionError(ATSGeneratorError):
    """PDF conversion failed."""


def _determine_css_file(files: list[str]) -> str:
    """Determine the appropriate CSS file based on document content.

    Args:
        files: List of markdown files to analyze

    Returns:
        Path to the appropriate CSS file
    """
    # Default to cover letter CSS
    css_file = "templates/ats-cover-letter.css"

    # Check if we can determine document type from content or filename
    if files:
        first_file = files[0]
        try:
            with open(first_file, encoding="utf-8") as f:
                content = f.read().lower()
                # Look for profile indicators
                if any(
                    keyword in content
                    for keyword in ["profile", "summary", "overview", "background"]
                ):
                    profile_css = "templates/ats-profile.css"
                    if os.path.exists(profile_css):
                        css_file = profile_css
        except OSError:
            pass  # Fall back to default CSS

    return css_file


def main() -> None:
    """Simple wrapper to call pandoc with weasyprint engine.

    Raises:
        ConversionError: If pandoc conversion fails
        FileOperationError: If file operations fail
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
    files: list[str] = [a for a in args if a.endswith(".md") and os.path.exists(a)]
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
                            f_out.write(f"{indent}- {stripped[2:]}\n")
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
        if os.path.exists(css_file):
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
