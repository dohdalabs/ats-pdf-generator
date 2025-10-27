"""
Main Document Validator

This module contains the main document validation function that coordinates
all validator modules.
"""

# Standard library
import re
from pathlib import Path

# First-party
from ats_pdf_generator.validation_types import SeverityLevel, Violation
from ats_pdf_generator.validator.contact_validator import ContactValidator

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
    "\U00002600-\U000026ff"  # Miscellaneous Symbols
    "\U00002700-\U000027bf"  # Dingbats
    "\U00002190-\U000021ff"  # Arrows
    "]+"
)


def validate_document(file_path: Path) -> list[Violation]:
    """
    Scans a document for ATS compatibility issues including emojis,
    special characters, and contact information formatting problems.

    Args:
        file_path: The path to the Markdown file to validate.

    Returns:
        A list of violations found in the document.
    """
    violations: list[Violation] = []

    # Initialize validators
    contact_validator = ContactValidator()

    with file_path.open("r", encoding="utf-8") as f:
        for i, line in enumerate(f, 1):
            line_content = line.strip()

            # Check for emojis and special characters
            for match in EMOJI_PATTERN.finditer(line):
                violations.append(
                    Violation(
                        line_number=i,
                        line_content=line_content,
                        message=f"Disallowed characters: '{match.group(0)}'",
                        severity=SeverityLevel.CRITICAL,
                        suggestion="Remove emojis and special characters",
                    )
                )

            # Check contact information formatting
            contact_violations = contact_validator.validate(line, i)
            violations.extend(contact_violations)

    return violations
