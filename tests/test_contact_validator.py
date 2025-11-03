"""
Tests for the Contact Information Validator.

This module tests the validation of contact information formatting
for ATS compatibility as specified in Issue 8.
"""

# Standard library
import re

# First-party
from ats_pdf_generator.validation_types import SeverityLevel
from ats_pdf_generator.validator.contact_validator import ContactValidator


def test_contact_validator_regex_patterns() -> None:
    """Test that ContactValidator has proper regex pattern attributes."""
    validator = ContactValidator()

    # Test that regex patterns are compiled pattern objects
    assert isinstance(validator.EMAIL_PATTERN, re.Pattern)
    assert isinstance(validator.OBFUSCATED_EMAIL_PATTERN, re.Pattern)
    assert isinstance(validator.PHONE_PATTERN, re.Pattern)
    assert isinstance(validator.URL_PATTERN, re.Pattern)
    assert isinstance(validator.BARE_URL_PATTERN, re.Pattern)


def test_contact_validator_labels() -> None:
    """Test that ContactValidator has proper CONTACT_LABELS structure."""
    validator = ContactValidator()

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


def test_contact_validator_interface() -> None:
    """Test that ContactValidator can be instantiated and exposes validate method."""
    validator = ContactValidator()

    # Test that instance is created successfully
    assert validator is not None
    assert isinstance(validator, ContactValidator)

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
    assert violations[0].severity == SeverityLevel.HIGH


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
        assert violations[0].severity == SeverityLevel.HIGH


def test_validate_phone_without_label() -> None:
    """Test detection of phone number without proper label."""
    validator = ContactValidator()
    content = "(555) 123-4567"
    violations = validator.validate(content, 1)

    assert len(violations) == 1
    assert "without" in violations[0].message.lower()
    assert "phone:" in violations[0].suggestion.lower()
    assert violations[0].severity == SeverityLevel.HIGH


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
        assert violations[0].severity == SeverityLevel.HIGH


def test_validate_phone_format_with_label() -> None:
    """Test that phone numbers with labels but wrong format are flagged."""
    validator = ContactValidator()
    # Test phone with label but no separators
    content = "Phone: 5551234567"
    violations = validator.validate(content, 1)

    assert len(violations) == 1
    assert "standard format" in violations[0].message.lower()
    assert violations[0].severity == SeverityLevel.HIGH


def test_validate_url_without_protocol() -> None:
    """Test detection of URLs without https:// protocol."""
    validator = ContactValidator()
    content = "LinkedIn: linkedin.com/in/user"
    violations = validator.validate(content, 1)

    assert len(violations) == 1
    assert "https://" in violations[0].suggestion
    assert violations[0].severity == SeverityLevel.HIGH


def test_validate_url_with_protocol() -> None:
    """Test that URLs with proper protocol pass validation."""
    validator = ContactValidator()
    content = "LinkedIn: https://linkedin.com/in/user"
    violations = validator.validate(content, 1)

    assert len(violations) == 0


def test_validate_url_with_http_protocol() -> None:
    """Test that URLs using http:// are flagged to enforce https usage."""
    validator = ContactValidator()
    content = "LinkedIn: http://linkedin.com/in/user"
    violations = validator.validate(content, 1)

    assert len(violations) == 1
    assert violations[0].severity == SeverityLevel.HIGH
    assert "https://" in violations[0].suggestion


def test_validate_url_without_label() -> None:
    """Test detection of URLs without proper label."""
    validator = ContactValidator()
    content = "linkedin.com/in/user"
    violations = validator.validate(content, 1)

    assert len(violations) == 1
    assert "without" in violations[0].message.lower()
    assert "linkedin:" in violations[0].suggestion.lower()
    assert violations[0].severity == SeverityLevel.HIGH


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

    assert all(v.severity == SeverityLevel.HIGH for v in violations)


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
    assert violations[0].severity == SeverityLevel.HIGH


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


# Tests for _is_year_range helper method
def test_is_year_range_with_parens() -> None:
    """Test _is_year_range detects year ranges with parentheses."""
    validator = ContactValidator()
    # Pattern: (2021-2022) where phone pattern matches "021-2022"
    content = "(2021-2022)"
    # Phone pattern matches "021-2022" at positions 2-10
    start_pos = 2  # After "(2"
    end_pos = 10  # After "2022"

    result = validator._is_year_range(content, start_pos, end_pos)
    assert result is True


def test_is_year_range_with_parens_various_years() -> None:
    """Test _is_year_range with various year formats in parentheses."""
    validator = ContactValidator()
    # Get actual match positions from phone pattern
    test_contents = [
        "(2011-2012)",
        "(1999-2000)",
        "(2020-2021)",
        "(2001-2002)",
    ]

    for content in test_contents:
        phone_match = validator.PHONE_PATTERN.search(content)
        if phone_match:
            start_pos = phone_match.start()
            end_pos = phone_match.end()
            result = validator._is_year_range(content, start_pos, end_pos)
            assert result is True, f"Failed for content: {content}"


def test_is_year_range_without_parens_space_after() -> None:
    """Test _is_year_range detects year ranges without parens, space after."""
    validator = ContactValidator()
    # Pattern: 2021-2022 where phone pattern matches "021-2022"
    content = "2021-2022 "
    phone_match = validator.PHONE_PATTERN.search(content)
    assert phone_match is not None
    start_pos = phone_match.start()
    end_pos = phone_match.end()

    result = validator._is_year_range(content, start_pos, end_pos)
    assert result is True


def test_is_year_range_without_parens_comma_after() -> None:
    """Test _is_year_range detects year ranges without parens, comma after."""
    validator = ContactValidator()
    content = "2021-2022,"
    phone_match = validator.PHONE_PATTERN.search(content)
    assert phone_match is not None
    start_pos = phone_match.start()
    end_pos = phone_match.end()

    result = validator._is_year_range(content, start_pos, end_pos)
    assert result is True


def test_is_year_range_without_parens_colon_after() -> None:
    """Test _is_year_range detects year ranges without parens, colon after."""
    validator = ContactValidator()
    content = "2021-2022:"
    phone_match = validator.PHONE_PATTERN.search(content)
    assert phone_match is not None
    start_pos = phone_match.start()
    end_pos = phone_match.end()

    result = validator._is_year_range(content, start_pos, end_pos)
    assert result is True


def test_is_year_range_without_parens_dot_after() -> None:
    """Test _is_year_range detects year ranges without parens, dot after."""
    validator = ContactValidator()
    content = "2021-2022."
    phone_match = validator.PHONE_PATTERN.search(content)
    assert phone_match is not None
    start_pos = phone_match.start()
    end_pos = phone_match.end()

    result = validator._is_year_range(content, start_pos, end_pos)
    assert result is True


def test_is_year_range_without_parens_end_of_string() -> None:
    """Test _is_year_range detects year ranges at end of string."""
    validator = ContactValidator()
    content = "Worked from 2021-2022"
    phone_match = validator.PHONE_PATTERN.search(content)
    assert phone_match is not None
    start_pos = phone_match.start()
    end_pos = phone_match.end()

    result = validator._is_year_range(content, start_pos, end_pos)
    assert result is True


def test_is_year_range_without_parens_with_closing_paren_after() -> None:
    """Test _is_year_range detects year ranges with optional closing paren."""
    validator = ContactValidator()
    content = "2021-2022)"
    phone_match = validator.PHONE_PATTERN.search(content)
    assert phone_match is not None
    start_pos = phone_match.start()
    end_pos = phone_match.end()

    result = validator._is_year_range(content, start_pos, end_pos)
    assert result is True


def test_is_year_range_false_positive_phone_number() -> None:
    """Test _is_year_range does not flag actual phone numbers."""
    validator = ContactValidator()
    # Actual phone number that might look like year range
    content = "Phone: (555) 123-4567"
    phone_match = validator.PHONE_PATTERN.search(content)
    assert phone_match is not None

    start_pos = phone_match.start()
    end_pos = phone_match.end()

    result = validator._is_year_range(content, start_pos, end_pos)
    assert result is False


def test_is_year_range_false_positive_no_digit_before() -> None:
    """Test _is_year_range returns False when no digit before match."""
    validator = ContactValidator()
    content = "-2022"
    # This won't match phone pattern, so test with start_pos at 0
    start_pos = 0
    end_pos = 5

    result = validator._is_year_range(content, start_pos, end_pos)
    assert result is False


def test_is_year_range_false_positive_no_context_after() -> None:
    """Test _is_year_range returns False when no year context after match."""
    validator = ContactValidator()
    content = "2021-2022abc"
    phone_match = validator.PHONE_PATTERN.search(content)
    assert phone_match is not None
    start_pos = phone_match.start()
    end_pos = phone_match.end()

    result = validator._is_year_range(content, start_pos, end_pos)
    assert result is False


def test_is_year_range_false_positive_phone_with_dash() -> None:
    """Test _is_year_range does not flag phone numbers with dashes."""
    validator = ContactValidator()
    content = "555-123-4567"
    phone_match = validator.PHONE_PATTERN.search(content)
    assert phone_match is not None

    start_pos = phone_match.start()
    end_pos = phone_match.end()

    result = validator._is_year_range(content, start_pos, end_pos)
    assert result is False


def test_is_year_range_at_start_of_string() -> None:
    """Test _is_year_range handles year range at start of content."""
    validator = ContactValidator()
    content = "(2021-2022) worked here"
    phone_match = validator.PHONE_PATTERN.search(content)
    assert phone_match is not None
    start_pos = phone_match.start()
    end_pos = phone_match.end()

    result = validator._is_year_range(content, start_pos, end_pos)
    assert result is True


def test_is_year_range_single_digit_before() -> None:
    """Test _is_year_range with single digit year before match."""
    validator = ContactValidator()
    content = "1-2022"
    start_pos = 1
    end_pos = 7

    result = validator._is_year_range(content, start_pos, end_pos)
    # Single digit is not a valid year range
    assert result is False


def test_is_year_range_four_digit_before() -> None:
    """Test _is_year_range with four digit year before match."""
    validator = ContactValidator()
    content = "2021-2022"
    phone_match = validator.PHONE_PATTERN.search(content)
    assert phone_match is not None
    start_pos = phone_match.start()
    end_pos = phone_match.end()

    result = validator._is_year_range(content, start_pos, end_pos)
    assert result is True


# Tests for _validate_phone_formatting with year range detection
def test_validate_phone_formatting_skips_year_ranges_with_parens() -> None:
    """Test that phone validation skips year ranges with parentheses."""
    validator = ContactValidator()
    # This should match phone pattern but be recognized as year range
    content = "(2021-2022)"
    violations = validator._validate_phone_formatting(content, 1)

    # Should not generate violations for year ranges
    assert len(violations) == 0


def test_validate_phone_formatting_skips_year_ranges_without_parens() -> None:
    """Test that phone validation skips year ranges without parentheses."""
    validator = ContactValidator()
    content = "Worked 2021-2022"
    violations = validator._validate_phone_formatting(content, 1)

    # Should not generate violations for year ranges
    assert len(violations) == 0


def test_validate_phone_formatting_skips_year_ranges_in_context() -> None:
    """Test that phone validation skips year ranges in various contexts."""
    validator = ContactValidator()
    test_cases = [
        "Employment: (2021-2022)",
        "Years: 2021-2022",
        "Duration: 2011-2012, worked on project",
        "Period: 1999-2000.",
    ]

    for content in test_cases:
        violations = validator._validate_phone_formatting(content, 1)
        assert len(violations) == 0, f"Should not flag year range: {content}"


def test_validate_phone_formatting_flags_actual_phones() -> None:
    """Test that phone validation still flags actual phone numbers."""
    validator = ContactValidator()
    content = "(555) 123-4567"
    violations = validator._validate_phone_formatting(content, 1)

    # Should generate violation for phone without label
    assert len(violations) == 1
    assert "without" in violations[0].message.lower()
    assert violations[0].severity == SeverityLevel.HIGH


def test_validate_phone_formatting_year_range_vs_phone() -> None:
    """Test differentiation between year ranges and actual phone numbers."""
    validator = ContactValidator()
    # Year range - should not be flagged
    year_range = "2021-2022"
    violations_year = validator._validate_phone_formatting(year_range, 1)
    assert len(violations_year) == 0

    # Actual phone - should be flagged
    phone = "555-123-4567"
    violations_phone = validator._validate_phone_formatting(phone, 1)
    assert len(violations_phone) >= 1


def test_validate_phone_formatting_year_range_at_end() -> None:
    """Test that year ranges at end of string are properly detected."""
    validator = ContactValidator()
    content = "Software Engineer 2021-2022"
    violations = validator._validate_phone_formatting(content, 1)

    assert len(violations) == 0


def test_validate_phone_formatting_year_range_with_label() -> None:
    """Test that year ranges are skipped even if they contain phone-like patterns."""
    validator = ContactValidator()
    # Year range that could match phone pattern
    content = "Period: (2021-2022)"
    violations = validator._validate_phone_formatting(content, 1)

    assert len(violations) == 0
