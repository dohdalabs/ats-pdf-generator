"""
Tests for the Contact Information Validator.

This module tests the validation of contact information formatting
for ATS compatibility as specified in Issue 8.
"""

# Standard library
import re

# First-party
from ats_pdf_generator.validator.contact_validator import ContactValidator


def test_contact_validator_initialization() -> None:
    """Test that ContactValidator initializes with proper patterns and labels."""
    validator = ContactValidator()

    # Test that instance is created successfully
    assert validator is not None
    assert isinstance(validator, ContactValidator)

    # Test that regex patterns are compiled pattern objects
    assert isinstance(validator.EMAIL_PATTERN, re.Pattern)
    assert isinstance(validator.OBFUSCATED_EMAIL_PATTERN, re.Pattern)
    assert isinstance(validator.PHONE_PATTERN, re.Pattern)
    assert isinstance(validator.URL_PATTERN, re.Pattern)
    assert isinstance(validator.BARE_URL_PATTERN, re.Pattern)

    # Test that CONTACT_LABELS dictionary is properly initialized
    assert validator.CONTACT_LABELS is not None
    assert isinstance(validator.CONTACT_LABELS, dict)

    # Test that CONTACT_LABELS has expected structure
    expected_keys = {"email", "phone", "linkedin", "github", "location", "website"}
    assert set(validator.CONTACT_LABELS.keys()) == expected_keys

    # Test that each key maps to a non-empty list of labels
    for _key, labels in validator.CONTACT_LABELS.items():
        assert isinstance(labels, list)
        assert len(labels) > 0
        assert all(isinstance(label, str) for label in labels)

    # Test that the class has the required validate method
    assert hasattr(validator, "validate")
    assert callable(validator.validate)


def test_validate_email_without_label() -> None:
    """Test detection of email address without proper label."""
    validator = ContactValidator()
    content = "user@example.com"
    violations = validator.validate(content, 1)

    assert len(violations) == 1
    assert violations[0].line_number == 1
    assert "without" in violations[0].message.lower()
    assert "email:" in violations[0].suggestion.lower()
    assert violations[0].severity == "HIGH"


def test_validate_email_with_label() -> None:
    """Test that email with proper label passes validation."""
    validator = ContactValidator()
    content = "Email: user@example.com"
    violations = validator.validate(content, 1)

    assert len(violations) == 0


def test_validate_obfuscated_email() -> None:
    """Test detection of obfuscated email patterns."""
    validator = ContactValidator()
    test_cases = [
        "user [at] example [dot] com",
        "user(at)example(dot)com",
        "user AT example DOT com",
    ]

    for content in test_cases:
        violations = validator.validate(content, 1)
        assert len(violations) >= 1
        assert "obfuscated" in violations[0].message.lower()
        assert violations[0].severity == "HIGH"


def test_validate_phone_without_label() -> None:
    """Test detection of phone number without proper label."""
    validator = ContactValidator()
    content = "(555) 123-4567"
    violations = validator.validate(content, 1)

    assert len(violations) == 1
    assert "without" in violations[0].message.lower()
    assert "phone:" in violations[0].suggestion.lower()
    assert violations[0].severity == "HIGH"


def test_validate_phone_with_label() -> None:
    """Test that phone number with proper label passes validation."""
    validator = ContactValidator()
    content = "Phone: (555) 123-4567"
    violations = validator.validate(content, 1)

    assert len(violations) == 0


def test_validate_standard_phone_formats() -> None:
    """Test that standard phone formats are accepted when properly labeled."""
    validator = ContactValidator()
    standard_formats = [
        "Phone: (555) 123-4567",
        "Phone: 555-123-4567",
        "Phone: +1-555-123-4567",
        "Phone: +1 (555) 123-4567",
    ]

    for content in standard_formats:
        violations = validator.validate(content, 1)
        assert len(violations) == 0


def test_validate_non_standard_phone_formats() -> None:
    """Test that non-standard phone formats are flagged."""
    validator = ContactValidator()
    non_standard_formats = ["555.123.4567", "5551234567", "555 123 4567"]

    for content in non_standard_formats:
        violations = validator.validate(content, 1)
        assert len(violations) >= 1
        # Non-standard formats without labels should be flagged as "without proper label"
        # since they don't have proper labels first
        assert "without" in violations[0].message.lower()
        assert "phone:" in violations[0].suggestion.lower()
        assert violations[0].severity == "HIGH"


def test_validate_phone_format_with_label() -> None:
    """Test that phone numbers with labels but wrong format are flagged."""
    validator = ContactValidator()
    # Test phone with label but no separators
    content = "Phone: 5551234567"
    violations = validator.validate(content, 1)

    assert len(violations) == 1
    assert "standard format" in violations[0].message.lower()
    assert violations[0].severity == "HIGH"


def test_validate_url_without_protocol() -> None:
    """Test detection of URLs without https:// protocol."""
    validator = ContactValidator()
    content = "LinkedIn: linkedin.com/in/user"
    violations = validator.validate(content, 1)

    assert len(violations) == 1
    assert "https://" in violations[0].suggestion
    assert violations[0].severity == "HIGH"


def test_validate_url_with_protocol() -> None:
    """Test that URLs with proper protocol pass validation."""
    validator = ContactValidator()
    content = "LinkedIn: https://linkedin.com/in/user"
    violations = validator.validate(content, 1)

    assert len(violations) == 0


def test_validate_url_without_label() -> None:
    """Test detection of URLs without proper label."""
    validator = ContactValidator()
    content = "linkedin.com/in/user"
    violations = validator.validate(content, 1)

    assert len(violations) == 1
    assert "without" in violations[0].message.lower()
    assert "linkedin:" in violations[0].suggestion.lower()
    assert violations[0].severity == "HIGH"


def test_validate_emoji_as_label() -> None:
    """Test detection of emojis used instead of text labels."""
    validator = ContactValidator()
    content = "📧 user@example.com"
    violations = validator.validate(content, 1)

    # Should detect both email without label and emoji as label
    assert len(violations) == 2

    # Check that we get both types of violations
    messages = [v.message.lower() for v in violations]
    assert any("emoji" in msg for msg in messages)
    assert any("email" in msg and "without" in msg for msg in messages)

    assert all(v.severity == "HIGH" for v in violations)


def test_validate_multiple_contact_types() -> None:
    """Test validation of document with multiple contact information types."""
    validator = ContactValidator()
    content = """user@example.com
(555) 123-4567
linkedin.com/in/user"""

    violations = validator.validate(content, 1)
    assert len(violations) == 3  # Email, phone, and URL without labels


def test_validate_properly_formatted_contact_info() -> None:
    """Test that properly formatted contact information passes validation."""
    validator = ContactValidator()
    content = """Email: user@example.com
Phone: (555) 123-4567
LinkedIn: https://linkedin.com/in/user
GitHub: https://github.com/user"""

    violations = validator.validate(content, 1)
    assert len(violations) == 0


def test_validate_mixed_content() -> None:
    """Test validation with mixed valid and invalid contact information."""
    validator = ContactValidator()
    content = """Email: user@example.com
(555) 123-4567
LinkedIn: https://linkedin.com/in/user
github.com/user"""

    violations = validator.validate(content, 1)
    assert len(violations) == 2  # Phone without label, GitHub URL without label


def test_validate_line_number_tracking() -> None:
    """Test that violations report correct line numbers."""
    validator = ContactValidator()
    content_lines = [
        "Email: user@example.com",  # Line 1: Valid
        "(555) 123-4567",  # Line 2: Phone without label
        "linkedin.com/in/user",  # Line 3: URL without label
        "Phone: (555) 987-6543",  # Line 4: Valid
        "user@example.com",  # Line 5: Email without label
    ]

    all_violations = []
    for line_number, line in enumerate(content_lines, 1):
        violations = validator.validate(line, line_number)
        all_violations.extend(violations)

    assert len(all_violations) == 3
    line_numbers = {v.line_number for v in all_violations}
    assert line_numbers == {2, 3, 5}


def test_validate_empty_content() -> None:
    """Test validation of empty content."""
    validator = ContactValidator()
    content = ""
    violations = validator.validate(content, 1)

    assert len(violations) == 0


def test_validate_no_contact_info() -> None:
    """Test validation of content without contact information."""
    validator = ContactValidator()
    content = "This is a regular paragraph without any contact information."
    violations = validator.validate(content, 1)

    assert len(violations) == 0


def test_validate_url_with_non_url_label() -> None:
    """Test that URLs with non-URL labels (like Email:) are flagged as missing proper labels."""
    validator = ContactValidator()
    content = "Email: github.com/user"
    violations = validator.validate(content, 1)

    # Should be flagged as URL without proper label (not just missing protocol)
    # because "Email:" is not a URL-specific label
    assert len(violations) == 1
    assert "without proper label" in violations[0].message.lower()
    assert (
        "linkedin:" in violations[0].suggestion.lower()
        or "github:" in violations[0].suggestion.lower()
    )
    assert violations[0].severity == "HIGH"


def test_validate_url_with_url_specific_label() -> None:
    """Test that URLs with URL-specific labels are only flagged for missing protocol."""
    validator = ContactValidator()

    # Test with GitHub label
    content_github = "GitHub: github.com/user"
    violations_github = validator.validate(content_github, 1)

    # Should only be flagged for missing protocol, not missing label
    assert len(violations_github) == 1
    assert "https://" in violations_github[0].suggestion
    assert "without proper label" not in violations_github[0].message.lower()

    # Test with Website label
    content_website = "Website: example.com/site"
    violations_website = validator.validate(content_website, 1)

    # Should only be flagged for missing protocol, not missing label
    assert len(violations_website) == 1
    assert "https://" in violations_website[0].suggestion
    assert "without proper label" not in violations_website[0].message.lower()
