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
from typing import List, NamedTuple


class Violation(NamedTuple):
    """Represents a single validation violation."""
    line_number: int
    line_content: str
    message: str


# A comprehensive regex for emojis and other special characters.
# See: https://gist.github.com/Alex-Just/e86110836f3f93fe7932290526529cd1
EMOJI_PATTERN = re.compile(
    "["
    "\U0001F1E0-\U0001F1FF"  # flags (iOS)
    "\U0001F300-\U0001F5FF"  # symbols & pictographs
    "\U0001F600-\U0001F64F"  # emoticons
    "\U0001F680-\U0001F6FF"  # transport & map symbols
    "\U0001F700-\U0001F77F"  # alchemical symbols
    "\U0001F780-\U0001F7FF"  # Geometric Shapes Extended
    "\U0001F800-\U0001F8FF"  # Supplemental Arrows-C
    "\U0001F900-\U0001F9FF"  # Supplemental Symbols and Pictographs
    "\U0001FA00-\U0001FA6F"  # Chess Symbols
    "\U0001FA70-\U0001FAFF"  # Symbols and Pictographs Extended-A
    "\U00002702-\U000027B0"  # Dingbats
    "\U000024C2-\U0001F251"
    "\U00002190-\U000021FF"  # Arrows
    "]+"
)

# Allowed special characters
ALLOWED_CHARS = {"$", "€", "£", "°", "&"}


def validate_document(file_path: Path) -> List[Violation]:
    """
    Scans a document for emojis and other special characters that might
    cause issues with ATS parsers.

    Args:
        file_path: The path to the Markdown file to validate.

    Returns:
        A list of violations found in the document.
    """
    violations: List[Violation] = []
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
