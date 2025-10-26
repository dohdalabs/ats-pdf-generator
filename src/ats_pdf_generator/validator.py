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


# Patterns for table detection
TABLE_PATTERN = re.compile(r"^\s*\|.*\|.*$")
MARKDOWN_TABLE_HEADER_PATTERN = re.compile(r"^\s*\|.*\|.*\n\s*\|[-\s|]+\|")
HTML_TABLE_PATTERN = re.compile(r"<table[^>]*>.*?</table>", re.DOTALL | re.IGNORECASE)


def validate_document(file_path: Path) -> list[Violation]:
    """
    Validate a Markdown document for table usage that may cause ATS compatibility issues.

    Checks for table structures that could cause problems with Applicant Tracking Systems:
    - Markdown tables (pipes and dashes)
    - HTML table tags

    Provides specific line numbers and conversion suggestions for ATS-friendly alternatives.

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
    violations.extend(_check_tables(lines))
    violations.extend(_check_html_tables(content))

    # Sort by severity (CRITICAL first, then HIGH, MEDIUM, LOW)
    severity_order = {
        Severity.CRITICAL: 0,
        Severity.HIGH: 1,
        Severity.MEDIUM: 2,
        Severity.LOW: 3,
    }
    violations.sort(key=lambda v: (severity_order[v.severity], v.line_number))

    return violations


def _check_tables(lines: list[str]) -> list[Violation]:
    """Check for tables that ATS systems may not parse correctly.

    Detects both Markdown tables (pipes and dashes) and HTML table tags.
    Provides specific line numbers and conversion suggestions.
    """
    violations = []

    # Check for Markdown tables
    for i, line in enumerate(lines, 1):
        if TABLE_PATTERN.match(line):
            violations.append(
                Violation(
                    line_number=i,
                    line_content=line.strip(),
                    violation_type="Markdown Table",
                    severity=Severity.HIGH,
                    message="Markdown table detected in document",
                    suggestion="Convert tables to lists or standard sections. ATS systems may not parse table structures correctly.",
                    found_text=line.strip(),
                )
            )

    return violations


def _check_html_tables(content: str) -> list[Violation]:
    """Check for HTML table tags in the document content."""
    violations = []

    lines = content.splitlines()
    for match in HTML_TABLE_PATTERN.finditer(content):
        # Find the line number for this match
        line_num = content[: match.start()].count("\n") + 1
        violations.append(
            Violation(
                line_number=line_num,
                line_content=lines[line_num - 1].strip()
                if line_num <= len(lines)
                else "",
                violation_type="HTML Table",
                severity=Severity.HIGH,
                message="HTML table detected in document",
                suggestion="Convert tables to lists or standard sections. ATS systems may not parse table structures correctly.",
                found_text=match.group()[:100] + "..."
                if len(match.group()) > 100
                else match.group(),
            )
        )

    return violations
