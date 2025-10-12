"""ATS PDF Generator - Core conversion functionality.

This package provides tools for converting Markdown documents to ATS-optimized PDFs
for job applications, including cover letters and professional profiles.
"""

from .ats_converter import (
    ATSGeneratorError,
    ConversionError,
    FileOperationError,
    ValidationError,
    cli,
    main,
)

__version__ = "1.0.0"
__all__ = [
    "ATSGeneratorError",
    "ConversionError",
    "FileOperationError",
    "ValidationError",
    "cli",
    "main",
]
