"""
Type definitions for ATS PDF Generator

This module contains shared type definitions to avoid circular imports.
"""

# Standard library
from typing import NamedTuple


class Violation(NamedTuple):
    """Represents a single validation violation."""

    line_number: int
    line_content: str
    message: str
    severity: str = "MEDIUM"
    suggestion: str = ""
