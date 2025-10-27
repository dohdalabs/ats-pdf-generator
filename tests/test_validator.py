"""
Tests for the ATS document validator.
"""

from pathlib import Path

from ats_pdf_generator.validator import Severity, validate_document


def test_validate_document_clean(tmp_path: Path) -> None:
    """Test that a clean document passes validation."""
    file_path = tmp_path / "test.md"
    file_path.write_text("This is a clean document.", encoding="utf-8")
    violations = validate_document(file_path)
    assert not violations


def test_validate_document_emojis_in_contact_info(tmp_path: Path) -> None:
    """Test that emojis in contact information are detected and flagged."""
    file_path = tmp_path / "test.md"
    file_path.write_text(
        """# Resume

## Contact Information
📧 user@example.com
📱 (555) 123-4567
🔗 linkedin.com/in/user
""",
        encoding="utf-8",
    )
    violations = validate_document(file_path)

    # Should detect emojis in contact info
    emoji_violations = [
        v for v in violations if v.violation_type == "Emoji in Contact Info"
    ]
    assert len(emoji_violations) == 3  # Three emojis
    assert all(v.severity == Severity.HIGH for v in emoji_violations)


def test_validate_document_unlabeled_email(tmp_path: Path) -> None:
    """Test that unlabeled email addresses are detected."""
    file_path = tmp_path / "test.md"
    file_path.write_text(
        """# Resume

## Contact Information
user@example.com
Phone: (555) 123-4567
""",
        encoding="utf-8",
    )
    violations = validate_document(file_path)

    # Should detect unlabeled email
    email_violations = [v for v in violations if v.violation_type == "Unlabeled Email"]
    assert len(email_violations) == 1
    assert email_violations[0].severity == Severity.HIGH
    assert "user@example.com" in email_violations[0].found_text


def test_validate_document_unlabeled_phone(tmp_path: Path) -> None:
    """Test that unlabeled phone numbers are detected."""
    file_path = tmp_path / "test.md"
    file_path.write_text(
        """# Resume

## Contact Information
Email: user@example.com
(555) 123-4567
""",
        encoding="utf-8",
    )
    violations = validate_document(file_path)

    # Should detect unlabeled phone
    phone_violations = [v for v in violations if v.violation_type == "Unlabeled Phone"]
    assert len(phone_violations) == 1
    assert phone_violations[0].severity == Severity.HIGH
    assert "(555) 123-4567" in phone_violations[0].found_text


def test_validate_document_unlabeled_url(tmp_path: Path) -> None:
    """Test that unlabeled URLs are detected."""
    file_path = tmp_path / "test.md"
    file_path.write_text(
        """# Resume

## Contact Information
Email: user@example.com
Phone: (555) 123-4567
github.com/user
""",
        encoding="utf-8",
    )
    violations = validate_document(file_path)

    # Should detect unlabeled URL (not caught by protocol check since it's a different domain)
    url_violations = [v for v in violations if v.violation_type == "Unlabeled URL"]
    assert len(url_violations) == 1
    assert url_violations[0].severity == Severity.HIGH
    assert "github.com/user" in url_violations[0].found_text


def test_validate_document_labeled_contact_info(tmp_path: Path) -> None:
    """Test that properly labeled contact information passes validation."""
    file_path = tmp_path / "test.md"
    file_path.write_text(
        """# Resume

## Contact Information
Email: user@example.com
Phone: (555) 123-4567
LinkedIn: linkedin.com/in/user
GitHub: github.com/user
""",
        encoding="utf-8",
    )
    violations = validate_document(file_path)

    # Should not detect any unlabeled contact info violations
    unlabeled_violations = [v for v in violations if "Unlabeled" in v.violation_type]
    assert len(unlabeled_violations) == 0


def test_validate_document_obfuscated_emails(tmp_path: Path) -> None:
    """Test that obfuscated email formats are detected."""
    file_path = tmp_path / "test.md"
    file_path.write_text(
        """# Resume

## Contact Information
Email: user [at] example [dot] com
Phone: (555) 123-4567
""",
        encoding="utf-8",
    )
    violations = validate_document(file_path)

    # Should detect obfuscated email
    obfuscated_violations = [
        v for v in violations if v.violation_type == "Obfuscated Email"
    ]
    assert len(obfuscated_violations) == 1
    assert obfuscated_violations[0].severity == Severity.HIGH
    assert "user [at] example [dot] com" in obfuscated_violations[0].found_text


def test_validate_document_url_without_protocol(tmp_path: Path) -> None:
    """Test that URLs without protocols are detected."""
    file_path = tmp_path / "test.md"
    file_path.write_text(
        """# Resume

## Contact Information
Email: user@example.com
Phone: (555) 123-4567
LinkedIn: linkedin.com/in/user
Portfolio: example.com/portfolio
""",
        encoding="utf-8",
    )
    violations = validate_document(file_path)

    # Should detect URLs without protocol
    url_violations = [
        v for v in violations if v.violation_type == "URL Without Protocol"
    ]
    assert len(url_violations) == 2  # Both LinkedIn and Portfolio URLs
    assert all(v.severity == Severity.MEDIUM for v in url_violations)


def test_validate_document_urls_with_protocol(tmp_path: Path) -> None:
    """Test that URLs with protocols pass validation."""
    file_path = tmp_path / "test.md"
    file_path.write_text(
        """# Resume

## Contact Information
Email: user@example.com
Phone: (555) 123-4567
LinkedIn: https://linkedin.com/in/user
Portfolio: https://example.com/portfolio
""",
        encoding="utf-8",
    )
    violations = validate_document(file_path)

    # Should not detect any URL protocol violations
    url_violations = [
        v for v in violations if v.violation_type == "URL Without Protocol"
    ]
    assert len(url_violations) == 0


def test_validate_document_comprehensive_contact_violations(tmp_path: Path) -> None:
    """Test a document with multiple contact information violations."""
    file_path = tmp_path / "test.md"
    file_path.write_text(
        """# Resume

## Contact Information
📧 user@example.com
📱 (555) 123-4567
🔗 linkedin.com/in/user
Portfolio: example.com/portfolio
Email: user [at] example [dot] com
""",
        encoding="utf-8",
    )
    violations = validate_document(file_path)

    # Should detect multiple types of violations
    violation_types = {v.violation_type for v in violations}
    expected_types = {
        "Emoji in Contact Info",
        "Unlabeled Email",
        "Unlabeled Phone",
        "Unlabeled URL",
        "URL Without Protocol",
        "Obfuscated Email",
    }

    # Should have at least some of each expected type
    assert len(violation_types.intersection(expected_types)) >= 4

    # Check severity distribution
    severities = {v.severity for v in violations}
    assert (
        Severity.HIGH in severities
    )  # Emojis, unlabeled contact info, obfuscated emails
    assert Severity.MEDIUM in severities  # URLs without protocol


def test_validate_document_violation_structure(tmp_path: Path) -> None:
    """Test that violations have the correct structure."""
    file_path = tmp_path / "test.md"
    file_path.write_text(
        """# Resume

## Contact Information
📧 user@example.com
""",
        encoding="utf-8",
    )
    violations = validate_document(file_path)

    assert len(violations) >= 1
    violation = violations[0]

    # Check all required fields are present
    assert isinstance(violation.line_number, int)
    assert isinstance(violation.line_content, str)
    assert isinstance(violation.violation_type, str)
    assert isinstance(violation.severity, Severity)
    assert isinstance(violation.message, str)
    assert isinstance(violation.suggestion, str)
    assert isinstance(violation.found_text, str)

    # Check specific values
    assert violation.violation_type in ["Emoji in Contact Info", "Unlabeled Email"]
    assert violation.severity in [Severity.HIGH, Severity.MEDIUM]
    assert (
        "contact" in violation.message.lower() or "emoji" in violation.message.lower()
    )
    assert (
        "label" in violation.suggestion.lower()
        or "protocol" in violation.suggestion.lower()
    )


def test_validate_document_severity_ordering(tmp_path: Path) -> None:
    """Test that violations are ordered by severity (HIGH first)."""
    file_path = tmp_path / "test.md"
    file_path.write_text(
        """# Resume

## Contact Information
📧 user@example.com
Portfolio: example.com/portfolio
""",
        encoding="utf-8",
    )
    violations = validate_document(file_path)

    # Should be ordered by severity: HIGH, MEDIUM
    severities = [v.severity for v in violations]

    # Find the first occurrence of each severity level
    high_idx = next((i for i, s in enumerate(severities) if s == Severity.HIGH), -1)
    medium_idx = next((i for i, s in enumerate(severities) if s == Severity.MEDIUM), -1)

    # HIGH should come before MEDIUM
    if high_idx != -1 and medium_idx != -1:
        assert high_idx < medium_idx
