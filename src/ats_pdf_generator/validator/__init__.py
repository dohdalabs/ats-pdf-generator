"""
ATS PDF Generator Validators

This package contains modular validators for ATS safety requirements.
Each validator implements specific validation rules and returns violations.
"""

# First-party
from ats_pdf_generator.validation_types import SeverityLevel, Violation
from ats_pdf_generator.validator.contact_validator import ContactValidator
from ats_pdf_generator.validator.validator import validate_document

__all__ = [
    "ContactValidator",
    "SeverityLevel",
    "Violation",
    "validate_document",
]
