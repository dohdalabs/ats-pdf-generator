#!/usr/bin/env python3
"""
ATS Document Validator

A module for validating Markdown documents to ensure they are ATS-friendly.
This includes checks for emojis, special characters, and other potential
parsing issues.
"""

# Standard library
import re
from pathlib import Path
from typing import NamedTuple


class Violation(NamedTuple):
    """Represents a single validation violation."""

    line_number: int
    line_content: str
    message: str


# A comprehensive regex for emojis and other special characters.
# See: https://gist.github.com/Alex-Just/e86110836f3f93fe7932290526529cd1
EMOJI_PATTERN = re.compile(
    "["
    "\U0001f1e0-\U0001f1ff"  # flags (iOS)
    "\U0001f300-\U0001f5ff"  # symbols & pictographs
    "\U0001f600-\U0001f64f"  # emoticons
    "\U0001f680-\U0001f6ff"  # transport & map symbols
    "\U0001f700-\U0001f77f"  # alchemical symbols
    "\U0001f780-\U0001f7ff"  # Geometric Shapes Extended
    "\U0001f800-\U0001f8ff"  # Supplemental Arrows-C
    "\U0001f900-\U0001f9ff"  # Supplemental Symbols and Pictographs
    "\U0001fa00-\U0001fa6f"  # Chess Symbols
    "\U0001fa70-\U0001faff"  # Symbols and Pictographs Extended-A
    "\U00002702-\U000027b0"  # Dingbats
    "\U000024c2-\U0001f251"
    "\U00002190-\U000021ff"  # Arrows
    "]+"
)

# Allowed special characters
ALLOWED_CHARS = {"$", "€", "£", "°", "&"}


def validate_document(file_path: Path) -> list[Violation]:
    """
    Scans a document for emojis and other special characters that might
    cause issues with ATS parsers.

    Args:
        file_path: The path to the Markdown file to validate.

    Returns:
        A list of violations found in the document.
    """
    violations: list[Violation] = []
    with file_path.open("r", encoding="utf-8") as f:
        for i, line in enumerate(f, 1):
            for match in EMOJI_PATTERN.finditer(line):
                char = match.group(0)
                if char not in ALLOWED_CHARS:
                    violations.append(
                        Violation(
                            line_number=i,
                            line_content=line.strip(),
                            message=f"Disallowed character: '{char}'",
                        )
                    )
    return violations
