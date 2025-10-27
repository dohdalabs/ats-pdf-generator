"""
Type definitions for ATS PDF Generator

This module contains shared type definitions to avoid circular imports.
"""

# Standard library
from enum import Enum
from typing import NamedTuple


class SeverityLevel(str, Enum):
    """Severity levels for validation violations."""

    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"
    CRITICAL = "CRITICAL"


class Violation(NamedTuple):
    """Represents a single validation violation."""

    line_number: int
    line_content: str
    message: str
    severity: SeverityLevel = SeverityLevel.MEDIUM
    suggestion: str = ""
