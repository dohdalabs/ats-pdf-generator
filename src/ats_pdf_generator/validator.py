"""
ATS Document Validator

A module for validating Markdown documents to ensure they are ATS-friendly.
This includes checks for contact information formatting that could cause problems
with Applicant Tracking Systems.
"""

# Standard library
import re
from enum import Enum
from pathlib import Path
from typing import NamedTuple


class Severity(Enum):
    """Severity levels for validation violations."""

    CRITICAL = "CRITICAL"
    HIGH = "HIGH"
    MEDIUM = "MEDIUM"
    LOW = "LOW"


class Violation(NamedTuple):
    """Represents a single validation violation."""

    line_number: int
    line_content: str
    violation_type: str
    severity: Severity
    message: str
    suggestion: str
    found_text: str = ""


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

# Contact information patterns
EMAIL_PATTERN = re.compile(r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b")
PHONE_PATTERN = re.compile(
    r"(?:\+?1[-.\s]?)?\(?([0-9]{3})\)?[-.\s]?([0-9]{3})[-.\s]?([0-9]{4})"
)
URL_PATTERN = re.compile(
    r"(?:https?://)?(?:www\.)?[a-zA-Z0-9-]+\.[a-zA-Z]{2,}(?:/[^\s]*)?"
)
OBFUSCATED_EMAIL_PATTERN = re.compile(
    r"\b[A-Za-z0-9._%+-]+\s*\[at\]\s*[A-Za-z0-9.-]+\s*\[dot\]\s*[A-Za-z]{2,}\b"
)

# Contact information labels
CONTACT_LABELS = {
    "email",
    "e-mail",
    "mail",
    "contact",
    "phone",
    "telephone",
    "tel",
    "mobile",
    "cell",
    "location",
    "address",
    "city",
    "state",
    "country",
    "linkedin",
    "github",
    "portfolio",
    "website",
    "url",
}


def validate_document(file_path: Path) -> list[Violation]:
    """
    Validate a Markdown document for contact information formatting issues.

    Checks for contact information patterns that could cause problems with ATS systems:
    - Emojis used instead of text labels
    - Unlabeled contact information (email, phone, URLs)
    - Obfuscated email formats
    - URLs without proper protocols

    Provides specific line numbers and formatting suggestions for ATS-friendly alternatives.

    Args:
        file_path: The path to the Markdown file to validate.

    Returns:
        A list of violations found in the document, sorted by severity.
    """
    violations: list[Violation] = []

    with file_path.open("r", encoding="utf-8") as f:
        content = f.read()
        lines = content.splitlines()

    # Run all validation checks
    violations.extend(_check_emojis_in_contact_info(lines))
    violations.extend(_check_unlabeled_contact_info(lines))
    violations.extend(_check_obfuscated_emails(lines))
    violations.extend(_check_url_formats(lines))

    # Sort by severity (CRITICAL first, then HIGH, MEDIUM, LOW)
    severity_order = {
        Severity.CRITICAL: 0,
        Severity.HIGH: 1,
        Severity.MEDIUM: 2,
        Severity.LOW: 3,
    }
    violations.sort(key=lambda v: (severity_order[v.severity], v.line_number))

    return violations


def _check_emojis_in_contact_info(lines: list[str]) -> list[Violation]:
    """Check for emojis used instead of text labels in contact information."""
    violations = []

    for i, line in enumerate(lines, 1):
        for match in EMOJI_PATTERN.finditer(line):
            matched_chars = match.group(0)
            for char in matched_chars:
                violations.append(
                    Violation(
                        line_number=i,
                        line_content=line.strip(),
                        violation_type="Emoji in Contact Info",
                        severity=Severity.HIGH,
                        message=f"Emoji used instead of text label: '{char}'",
                        suggestion="Replace emojis with explicit text labels like 'Email:', 'Phone:', 'LinkedIn:'",
                        found_text=char,
                    )
                )

    return violations


def _check_unlabeled_contact_info(lines: list[str]) -> list[Violation]:
    """Check for contact information without proper labels."""
    violations = []

    for i, line in enumerate(lines, 1):
        line_lower = line.lower().strip()

        # Skip lines that already have contact labels (with colon)
        if ":" in line_lower and any(
            label in line_lower.split(":")[0] for label in CONTACT_LABELS
        ):
            continue

        # Check for unlabeled email
        if EMAIL_PATTERN.search(line):
            violations.append(
                Violation(
                    line_number=i,
                    line_content=line.strip(),
                    violation_type="Unlabeled Email",
                    severity=Severity.HIGH,
                    message="Email address without label",
                    suggestion="Add explicit label: 'Email: user@example.com'",
                    found_text=EMAIL_PATTERN.search(line).group(),
                )
            )

        # Check for unlabeled phone
        if PHONE_PATTERN.search(line):
            violations.append(
                Violation(
                    line_number=i,
                    line_content=line.strip(),
                    violation_type="Unlabeled Phone",
                    severity=Severity.HIGH,
                    message="Phone number without label",
                    suggestion="Add explicit label: 'Phone: (555) 123-4567'",
                    found_text=PHONE_PATTERN.search(line).group(),
                )
            )

        # Check for unlabeled URL (but not email addresses)
        if not EMAIL_PATTERN.search(line):  # Skip if line contains email
            url_match = URL_PATTERN.search(line)
            if url_match:
                # Check if this URL is already labeled (has a colon and a contact label before it)
                is_labeled = ":" in line_lower and any(
                    label in line_lower.split(":")[0]
                    for label in ["linkedin", "github", "portfolio", "website", "url"]
                )
                if not is_labeled:
                    violations.append(
                        Violation(
                            line_number=i,
                            line_content=line.strip(),
                            violation_type="Unlabeled URL",
                            severity=Severity.HIGH,
                            message="URL without label",
                            suggestion="Add explicit label: 'LinkedIn: linkedin.com/in/user' or 'GitHub: github.com/user'",
                            found_text=url_match.group(),
                        )
                    )

    return violations


def _check_obfuscated_emails(lines: list[str]) -> list[Violation]:
    """Check for obfuscated email formats."""
    violations = []

    for i, line in enumerate(lines, 1):
        for match in OBFUSCATED_EMAIL_PATTERN.finditer(line):
            violations.append(
                Violation(
                    line_number=i,
                    line_content=line.strip(),
                    violation_type="Obfuscated Email",
                    severity=Severity.HIGH,
                    message="Obfuscated email format detected",
                    suggestion="Use standard email format: 'user@example.com' instead of 'user [at] example [dot] com'",
                    found_text=match.group(),
                )
            )

    return violations


def _check_url_formats(lines: list[str]) -> list[Violation]:
    """Check for URLs without proper protocols."""
    violations = []

    for i, line in enumerate(lines, 1):
        # Skip lines that contain email addresses
        if not EMAIL_PATTERN.search(line):
            line_lower = line.lower()
            # Only check URLs that are labeled (have a colon and a contact label)
            if ":" in line_lower and any(
                label in line_lower.split(":")[0]
                for label in ["linkedin", "github", "portfolio", "website", "url"]
            ):
                for match in URL_PATTERN.finditer(line):
                    url = match.group()
                    # Skip URLs that already have protocols
                    if not url.startswith(("http://", "https://")):
                        violations.append(
                            Violation(
                                line_number=i,
                                line_content=line.strip(),
                                violation_type="URL Without Protocol",
                                severity=Severity.MEDIUM,
                                message="URL missing protocol",
                                suggestion="Include protocol: 'https://linkedin.com/in/user' instead of 'linkedin.com/in/user'",
                                found_text=url,
                            )
                        )

    return violations
