"""
ATS Document Validator

A module for validating Markdown documents to ensure they are ATS-friendly.
This includes checks for emojis, special characters, tables, dates, and other
potential parsing issues that could cause problems with Applicant Tracking Systems.
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

# Patterns for various validation checks
TABLE_PATTERN = re.compile(r"^\s*\|.*\|.*$")
MARKDOWN_TABLE_HEADER_PATTERN = re.compile(r"^\s*\|.*\|.*\n\s*\|[-\s|]+\|")
SMART_QUOTES_PATTERN = re.compile(r"[" "''" "]")
EM_DASH_PATTERN = re.compile(r"—")
EN_DASH_PATTERN = re.compile(r"–")
ELLIPSIS_PATTERN = re.compile(r"…")
ALL_CAPS_PATTERN = re.compile(r"^[A-Z\s\d\.,!?\-:;()]+$")
HIDDEN_COMMENT_PATTERN = re.compile(r"<!--.*?-->", re.DOTALL)
DATE_PATTERN = re.compile(
    r"\b(?:January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d{4}\s*[-–—]\s*(?:January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d{4}\b"
)
NON_STANDARD_DATE_PATTERN = re.compile(
    r"\b(?:Early|Mid|Late|Summer|Fall|Winter|Spring)\s+\d{4}\b|\b\d{4}\s*[-–—]\s*\d{4}\b(?!\s*\(for education only\))"
)

# Common acronyms that should not trigger ALL CAPS violations
COMMON_ACRONYMS = {
    "API",
    "AWS",
    "CSS",
    "HTML",
    "HTTP",
    "HTTPS",
    "JSON",
    "REST",
    "SQL",
    "XML",
    "UI",
    "UX",
    "CI",
    "CD",
    "SDLC",
    "IDE",
    "OS",
    "CPU",
    "GPU",
    "RAM",
    "SSD",
    "URL",
    "URI",
    "DNS",
    "SSL",
    "TLS",
    "VPN",
    "IP",
    "TCP",
    "UDP",
    "FTP",
    "SSH",
}

# Creative job titles that should be flagged
CREATIVE_TITLE_PATTERNS = [
    r"\b(?:ninja|wizard|guru|rockstar|champion|hero|expert|master|specialist)\b",
    r"\b(?:code\s+ninja|digital\s+wizard|tech\s+rockstar|code\s+guru)\b",
]

# Standard section names that are ATS-friendly
STANDARD_SECTIONS = {
    "Professional Summary",
    "Summary",
    "Career Summary",
    "Profile",
    "Professional Experience",
    "Work Experience",
    "Experience",
    "Employment History",
    "Technical Skills",
    "Skills",
    "Core Competencies",
    "Technical Proficiencies",
    "Education",
    "Academic Background",
    "Educational Qualifications",
    "Certifications",
    "Licenses and Certifications",
    "Professional Certifications",
    "Projects",
    "Key Projects",
    "Portfolio",
    "Technical Projects",
    "Publications",
    "Research",
    "Papers",
    "Articles",
    "Awards",
    "Honors",
    "Recognition",
    "Achievements",
}


def validate_document(file_path: Path) -> list[Violation]:
    """
    Comprehensive validation of a Markdown document for ATS compatibility.

    Checks for various issues that could cause problems with Applicant Tracking Systems:
    - Emojis and special characters
    - Tables and multi-column layouts
    - Non-standard date formats
    - Creative job titles
    - ALL CAPS sections
    - Hidden text and comments
    - Smart quotes and special punctuation
    - Keyword stuffing

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
    violations.extend(_check_emojis_and_special_chars(lines))
    violations.extend(_check_tables(lines))
    violations.extend(_check_smart_quotes_and_punctuation(lines))
    violations.extend(_check_all_caps_sections(lines))
    violations.extend(_check_creative_job_titles(lines))
    violations.extend(_check_date_formats(lines))
    violations.extend(_check_hidden_text(content))
    violations.extend(_check_keyword_stuffing(lines))
    violations.extend(_check_section_headers(lines))

    # Sort by severity (CRITICAL first, then HIGH, MEDIUM, LOW)
    severity_order = {
        Severity.CRITICAL: 0,
        Severity.HIGH: 1,
        Severity.MEDIUM: 2,
        Severity.LOW: 3,
    }
    violations.sort(key=lambda v: (severity_order[v.severity], v.line_number))

    return violations


def _check_emojis_and_special_chars(lines: list[str]) -> list[Violation]:
    """Check for emojis and special characters that ATS systems can't parse."""
    violations = []

    for i, line in enumerate(lines, 1):
        for match in EMOJI_PATTERN.finditer(line):
            matched_chars = match.group(0)
            for char in matched_chars:
                violations.append(
                    Violation(
                        line_number=i,
                        line_content=line.strip(),
                        violation_type="Emoji/Special Character",
                        severity=Severity.CRITICAL,
                        message=f"Disallowed character: '{char}'",
                        suggestion="Remove emojis and special Unicode characters. Use standard ASCII punctuation instead.",
                        found_text=char,
                    )
                )

    return violations


def _check_tables(lines: list[str]) -> list[Violation]:
    """Check for tables that ATS systems may not parse correctly."""
    violations = []

    for i, line in enumerate(lines, 1):
        if TABLE_PATTERN.match(line):
            violations.append(
                Violation(
                    line_number=i,
                    line_content=line.strip(),
                    violation_type="Table Usage",
                    severity=Severity.HIGH,
                    message="Table detected in document",
                    suggestion="Convert tables to lists or standard sections. ATS systems may not parse table structures correctly.",
                    found_text=line.strip(),
                )
            )

    return violations


def _check_smart_quotes_and_punctuation(lines: list[str]) -> list[Violation]:
    """Check for smart quotes and special punctuation that may cause parsing issues."""
    violations = []

    for i, line in enumerate(lines, 1):
        # Check for smart quotes
        for match in SMART_QUOTES_PATTERN.finditer(line):
            violations.append(
                Violation(
                    line_number=i,
                    line_content=line.strip(),
                    violation_type="Smart Quotes",
                    severity=Severity.MEDIUM,
                    message=f"Smart quote detected: '{match.group()}'",
                    suggestion="Use straight quotes (\" and ') instead of smart quotes.",
                    found_text=match.group(),
                )
            )

        # Check for em dashes
        for match in EM_DASH_PATTERN.finditer(line):
            violations.append(
                Violation(
                    line_number=i,
                    line_content=line.strip(),
                    violation_type="Em Dash",
                    severity=Severity.MEDIUM,
                    message=f"Em dash detected: '{match.group()}'",
                    suggestion="Use hyphens (-) instead of em dashes (—).",
                    found_text=match.group(),
                )
            )

        # Check for en dashes
        for match in EN_DASH_PATTERN.finditer(line):
            violations.append(
                Violation(
                    line_number=i,
                    line_content=line.strip(),
                    violation_type="En Dash",
                    severity=Severity.MEDIUM,
                    message=f"En dash detected: '{match.group()}'",
                    suggestion="Use hyphens (-) instead of en dashes (–).",
                    found_text=match.group(),
                )
            )

        # Check for ellipses
        for match in ELLIPSIS_PATTERN.finditer(line):
            violations.append(
                Violation(
                    line_number=i,
                    line_content=line.strip(),
                    violation_type="Ellipsis",
                    severity=Severity.MEDIUM,
                    message=f"Ellipsis character detected: '{match.group()}'",
                    suggestion="Use three periods (...) instead of ellipsis character (…).",
                    found_text=match.group(),
                )
            )

    return violations


def _check_all_caps_sections(lines: list[str]) -> list[Violation]:
    """Check for ALL CAPS sections that may indicate poor formatting."""
    violations = []

    for i, line in enumerate(lines, 1):
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue

        # Check if line is all caps (but not empty or just punctuation)
        if ALL_CAPS_PATTERN.match(stripped) and len(stripped) > 3:
            # Check if it's a common acronym
            words = stripped.split()
            if not any(word in COMMON_ACRONYMS for word in words):
                violations.append(
                    Violation(
                        line_number=i,
                        line_content=stripped,
                        violation_type="ALL CAPS",
                        severity=Severity.LOW,
                        message="ALL CAPS text detected",
                        suggestion="Use proper case instead of ALL CAPS. This improves readability and looks more professional.",
                        found_text=stripped,
                    )
                )

    return violations


def _check_creative_job_titles(lines: list[str]) -> list[Violation]:
    """Check for creative job titles that may not be recognized by ATS systems."""
    violations = []

    for i, line in enumerate(lines, 1):
        for pattern in CREATIVE_TITLE_PATTERNS:
            for match in re.finditer(pattern, line, re.IGNORECASE):
                violations.append(
                    Violation(
                        line_number=i,
                        line_content=line.strip(),
                        violation_type="Creative Job Title",
                        severity=Severity.MEDIUM,
                        message=f"Creative job title detected: '{match.group()}'",
                        suggestion="Use standard job titles like 'Software Engineer', 'Developer', or 'Manager' instead of creative titles.",
                        found_text=match.group(),
                    )
                )

    return violations


def _check_date_formats(lines: list[str]) -> list[Violation]:
    """Check for non-standard date formats that may cause parsing issues."""
    violations = []

    for i, line in enumerate(lines, 1):
        # Check for non-standard date formats
        for match in NON_STANDARD_DATE_PATTERN.finditer(line):
            violations.append(
                Violation(
                    line_number=i,
                    line_content=line.strip(),
                    violation_type="Non-Standard Date Format",
                    severity=Severity.HIGH,
                    message=f"Non-standard date format detected: '{match.group()}'",
                    suggestion="Use standard date formats like 'January 2020 - March 2024' or 'Jan 2020 - Mar 2024'.",
                    found_text=match.group(),
                )
            )

    return violations


def _check_hidden_text(content: str) -> list[Violation]:
    """Check for hidden text in HTML comments."""
    violations = []

    lines = content.splitlines()
    for match in HIDDEN_COMMENT_PATTERN.finditer(content):
        # Find the line number for this match
        line_num = content[: match.start()].count("\n") + 1
        violations.append(
            Violation(
                line_number=line_num,
                line_content=lines[line_num - 1].strip()
                if line_num <= len(lines)
                else "",
                violation_type="Hidden Text",
                severity=Severity.CRITICAL,
                message="Hidden text detected in HTML comment",
                suggestion="Remove hidden text and HTML comments. ATS systems may not parse hidden content correctly.",
                found_text=match.group(),
            )
        )

    return violations


def _check_keyword_stuffing(lines: list[str]) -> list[Violation]:
    """Check for excessive keyword repetition that may indicate keyword stuffing."""
    violations = []

    # Common keywords that might be overused
    keywords = [
        "software",
        "development",
        "programming",
        "coding",
        "engineer",
        "developer",
    ]

    for i, line in enumerate(lines, 1):
        line_lower = line.lower()
        for keyword in keywords:
            # Count occurrences of the keyword in this line
            count = line_lower.count(keyword)
            if count > 2:  # More than 2 occurrences in a single line
                violations.append(
                    Violation(
                        line_number=i,
                        line_content=line.strip(),
                        violation_type="Keyword Stuffing",
                        severity=Severity.LOW,
                        message=f"Excessive repetition of '{keyword}' ({count} times)",
                        suggestion="Reduce keyword repetition. Use synonyms and vary your language to sound more natural.",
                        found_text=keyword,
                    )
                )

    return violations


def _check_section_headers(lines: list[str]) -> list[Violation]:
    """Check for non-standard section headers that may not be recognized by ATS."""
    violations = []

    for i, line in enumerate(lines, 1):
        stripped = line.strip()
        if stripped.startswith("##"):
            # Extract section name (remove ## and any leading/trailing whitespace)
            section_name = stripped[2:].strip()
            if section_name and section_name not in STANDARD_SECTIONS:
                violations.append(
                    Violation(
                        line_number=i,
                        line_content=stripped,
                        violation_type="Non-Standard Section Header",
                        severity=Severity.LOW,
                        message=f"Non-standard section header: '{section_name}'",
                        suggestion="Consider using a standard section name like 'Professional Experience' or 'Technical Skills'.",
                        found_text=section_name,
                    )
                )

    return violations
