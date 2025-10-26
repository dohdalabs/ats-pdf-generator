"""
Tests for the ATS Document Validator.
"""

# Standard library
from pathlib import Path

# First-party
from ats_pdf_generator.validator import Severity, validate_document


def test_validate_document_no_violations(tmp_path: Path) -> None:
    """
    Test that a clean document passes validation.
    """
    file_path = tmp_path / "test.md"
    file_path.write_text("This is a clean document.", encoding="utf-8")
    violations = validate_document(file_path)
    assert not violations


def test_validate_document_with_emojis(tmp_path: Path) -> None:
    """
    Test that a document with emojis fails validation.
    """
    file_path = tmp_path / "test.md"
    file_path.write_text("This is a document with an emoji: 😊", encoding="utf-8")
    violations = validate_document(file_path)
    assert len(violations) == 1
    assert violations[0].line_number == 1
    assert violations[0].message == "Disallowed character: '😊'"


def test_validate_document_with_special_characters(tmp_path: Path) -> None:
    """
    Test that a document with special characters fails validation.
    """
    file_path = tmp_path / "test.md"
    file_path.write_text(
        "This is a document with a special character: →", encoding="utf-8"
    )
    violations = validate_document(file_path)
    assert len(violations) == 1
    assert violations[0].line_number == 1
    assert violations[0].message == "Disallowed character: '→'"


def test_validate_document_with_allowed_characters(tmp_path: Path) -> None:
    """
    Test that a document with allowed special characters passes validation.

    Note: Currency symbols ($, €, £), degree symbol (°), and ampersand (&)
    are not matched by EMOJI_PATTERN, so they don't trigger violations.
    This test verifies that these characters are ignored by the validator.
    """
    file_path = tmp_path / "test.md"
    file_path.write_text(
        "This is a document with allowed characters: $ € £ ° &", encoding="utf-8"
    )
    violations = validate_document(file_path)
    assert not violations


def test_validate_document_multi_character_emoji_sequence(tmp_path: Path) -> None:
    """
    Test that multi-character emoji sequences are handled correctly.

    This test verifies the fix for the regex + quantifier issue where
    multi-character emoji sequences (like family emojis) were treated
    as single characters, causing false positives.
    """
    file_path = tmp_path / "test.md"
    file_path.write_text("Family: 👨‍👩‍👧‍👦", encoding="utf-8")
    violations = validate_document(file_path)

    # Should create separate violations for each character in the sequence
    assert len(violations) == 4
    assert all(v.line_number == 1 for v in violations)
    assert all(v.line_content == "Family: 👨‍👩‍👧‍👦" for v in violations)

    # Check that each character gets its own violation
    violation_chars = {v.message.split("'")[1] for v in violations}
    expected_chars = {"👨", "👩", "👧", "👦"}
    assert violation_chars == expected_chars


def test_validate_document_consecutive_emojis(tmp_path: Path) -> None:
    """
    Test that consecutive emojis are handled correctly.
    """
    file_path = tmp_path / "test.md"
    file_path.write_text("Celebration: 🎉🎊", encoding="utf-8")
    violations = validate_document(file_path)

    # Should create separate violations for each emoji
    assert len(violations) == 2
    assert all(v.line_number == 1 for v in violations)

    # Check that each emoji gets its own violation
    violation_chars = {v.message.split("'")[1] for v in violations}
    expected_chars = {"🎉", "🎊"}
    assert violation_chars == expected_chars


def test_validate_document_mixed_allowed_disallowed(tmp_path: Path) -> None:
    """
    Test that documents with both allowed and disallowed characters
    are handled correctly.

    Note: Currency symbols ($, €, £) are not matched by EMOJI_PATTERN,
    so they don't trigger violations. Only emojis and special Unicode
    characters that match the pattern will be flagged.
    """
    file_path = tmp_path / "test.md"
    file_path.write_text(
        "Price: $100, 😀 emoji, €50, 🎉 celebration, £30", encoding="utf-8"
    )
    violations = validate_document(file_path)

    # Should only flag the emojis, not the currency symbols (which aren't matched by EMOJI_PATTERN)
    assert len(violations) == 2
    assert all(v.line_number == 1 for v in violations)

    # Check that only the emojis are flagged
    violation_chars = {v.message.split("'")[1] for v in violations}
    expected_chars = {"😀", "🎉"}
    assert violation_chars == expected_chars


def test_validate_document_complex_emoji_sequences(tmp_path: Path) -> None:
    """
    Test that complex emoji sequences with zero-width joiners are handled correctly.
    """
    file_path = tmp_path / "test.md"
    file_path.write_text("Complex: 👨‍💻 and 👩‍🔬", encoding="utf-8")
    violations = validate_document(file_path)

    # Should create separate violations for each base emoji character
    # (ignoring the zero-width joiners and modifiers)
    assert len(violations) == 4
    assert all(v.line_number == 1 for v in violations)

    # Check that each base emoji character gets its own violation
    violation_chars = {v.message.split("'")[1] for v in violations}
    expected_chars = {"👨", "👩", "💻", "🔬"}
    assert violation_chars == expected_chars


def test_validate_document_multiple_lines_with_emojis(tmp_path: Path) -> None:
    """
    Test that emojis on multiple lines are handled correctly.
    """
    file_path = tmp_path / "test.md"
    file_path.write_text("Line 1: 😊\nLine 2: 🎉🎊\nLine 3: $100", encoding="utf-8")
    violations = validate_document(file_path)

    # Should create violations for each emoji on each line
    assert len(violations) == 3

    # Check line numbers
    line_numbers = {v.line_number for v in violations}
    assert line_numbers == {1, 2}

    # Check that line 1 has 1 violation, line 2 has 2 violations
    line_1_violations = [v for v in violations if v.line_number == 1]
    line_2_violations = [v for v in violations if v.line_number == 2]

    assert len(line_1_violations) == 1
    assert len(line_2_violations) == 2

    # Check that line 3 (with allowed character) has no violations
    line_3_violations = [v for v in violations if v.line_number == 3]
    assert len(line_3_violations) == 0


def test_validate_document_previously_matched_characters_now_allowed(
    tmp_path: Path,
) -> None:
    """
    Test that characters that were previously matched by the overly broad range
    U+24C2-U+1F251 are no longer flagged as violations.

    This test verifies the fix for the overly broad Unicode range that included
    many non-emoji characters like circled letters, enclosed alphanumerics,
    and other symbols that shouldn't be flagged for ATS compatibility.
    """
    file_path = tmp_path / "test.md"
    # Test characters that were previously matched by the broad range:
    # U+24C2 (Ⓜ), U+24C7 (Ⓡ), U+24D0 (ⓐ), U+24E9 (ⓩ), U+1F251 (🉑)
    file_path.write_text(
        "Test characters: Ⓜ Ⓡ ⓐ ⓩ 🉑 (these should not be flagged)", encoding="utf-8"
    )
    violations = validate_document(file_path)

    # These characters should no longer be flagged as violations
    # None of these characters are in the current emoji ranges, so no violations
    assert len(violations) == 0


def test_validate_document_complete_dingbats_range(tmp_path: Path) -> None:
    """
    Test that the complete Dingbats range U+2700-U+27BF is properly matched.

    This test verifies that characters from the previously missing ranges
    U+2700-U+2701 and U+27B1-U+27BF are now properly flagged as violations.
    """
    file_path = tmp_path / "test.md"
    # Test characters from the complete Dingbats range:
    # U+2700 (✀), U+2701 (✁), U+2702 (✂), U+27B0 (➰), U+27B1 (➱), U+27BF (➿)
    file_path.write_text(
        "Dingbats test: ✀ ✁ ✂ ➰ ➱ ➿ (these should be flagged)", encoding="utf-8"
    )
    violations = validate_document(file_path)

    # All these characters should be flagged as violations
    assert len(violations) == 6
    assert all(v.line_number == 1 for v in violations)

    # Check that each character gets its own violation
    violation_chars = {v.message.split("'")[1] for v in violations}
    expected_chars = {"✀", "✁", "✂", "➰", "➱", "➿"}
    assert violation_chars == expected_chars


def test_validate_document_miscellaneous_symbols_range(tmp_path: Path) -> None:
    """
    Test that the Miscellaneous Symbols range U+2600-U+26FF is properly matched.

    This test verifies that symbols like ☀, ★, ✈ are now properly flagged as violations.
    """
    file_path = tmp_path / "test.md"
    # Test characters from the Miscellaneous Symbols range:
    # U+2600 (☀), U+2605 (★), U+2708 (✈), U+26A0 (⚠), U+26BD (⚽), U+26C4 (⛄)
    file_path.write_text(
        "Misc symbols test: ☀ ★ ✈ ⚠ ⚽ ⛄ (these should be flagged)", encoding="utf-8"
    )
    violations = validate_document(file_path)

    # All these characters should be flagged as violations
    assert len(violations) == 6
    assert all(v.line_number == 1 for v in violations)

    # Check that each character gets its own violation
    violation_chars = {v.message.split("'")[1] for v in violations}
    expected_chars = {"☀", "★", "✈", "⚠", "⚽", "⛄"}
    assert violation_chars == expected_chars


# ============================================================================
# New Comprehensive Validation Tests
# ============================================================================


def test_validate_document_tables(tmp_path: Path) -> None:
    """Test that tables are detected and flagged."""
    file_path = tmp_path / "test.md"
    file_path.write_text(
        """# Resume

## Skills
| Category | Technologies |
|----------|-------------|
| Languages | Python, JavaScript |
| Tools | Docker, Kubernetes |
""",
        encoding="utf-8",
    )
    violations = validate_document(file_path)

    # Should detect table rows
    table_violations = [v for v in violations if v.violation_type == "Table Usage"]
    assert len(table_violations) >= 2  # At least the header and one data row
    assert all(v.severity == Severity.HIGH for v in table_violations)


def test_validate_document_smart_quotes(tmp_path: Path) -> None:
    """Test that smart quotes are detected and flagged."""
    file_path = tmp_path / "test.md"
    file_path.write_text(
        "This has \"smart quotes\" and 'single smart quotes' and — em dash and – en dash and … ellipsis",
        encoding="utf-8",
    )
    violations = validate_document(file_path)

    # Should detect smart quotes, em dash, en dash, and ellipsis
    assert len(violations) == 5
    assert all(v.severity == Severity.MEDIUM for v in violations)

    violation_types = {v.violation_type for v in violations}
    expected_types = {"Smart Quotes", "Em Dash", "En Dash", "Ellipsis"}
    assert violation_types == expected_types


def test_validate_document_all_caps(tmp_path: Path) -> None:
    """Test that ALL CAPS sections are detected and flagged."""
    file_path = tmp_path / "test.md"
    file_path.write_text(
        """# Resume

## CONTACT INFORMATION
- EMAIL: TEST@EMAIL.COM

## PROFESSIONAL SUMMARY
EXPERIENCED SOFTWARE ENGINEER

## Skills
- PYTHON, JAVASCRIPT, DOCKER
""",
        encoding="utf-8",
    )
    violations = validate_document(file_path)

    # Should detect ALL CAPS violations (but not common acronyms)
    all_caps_violations = [v for v in violations if v.violation_type == "ALL CAPS"]
    assert len(all_caps_violations) >= 2  # At least the contact and summary sections
    assert all(v.severity == Severity.LOW for v in all_caps_violations)


def test_validate_document_all_caps_with_acronyms(tmp_path: Path) -> None:
    """Test that common acronyms don't trigger ALL CAPS violations."""
    file_path = tmp_path / "test.md"
    file_path.write_text(
        "Skills: API, AWS, CSS, HTML, HTTP, JSON, REST, SQL, XML, UI, UX, CI, CD",
        encoding="utf-8",
    )
    violations = validate_document(file_path)

    # Should not trigger ALL CAPS violations for common acronyms
    all_caps_violations = [v for v in violations if v.violation_type == "ALL CAPS"]
    assert len(all_caps_violations) == 0


def test_validate_document_creative_job_titles(tmp_path: Path) -> None:
    """Test that creative job titles are detected and flagged."""
    file_path = tmp_path / "test.md"
    file_path.write_text(
        """# Resume

## Experience
- Code Ninja at TechCorp (2020-2024)
- Digital Wizard at StartupCo (2018-2020)
- Tech Rockstar at InnovationLabs (2016-2018)
- Software Guru at BigTech (2014-2016)
""",
        encoding="utf-8",
    )
    violations = validate_document(file_path)

    # Should detect creative job titles
    creative_violations = [
        v for v in violations if v.violation_type == "Creative Job Title"
    ]
    assert len(creative_violations) >= 4
    assert all(v.severity == Severity.MEDIUM for v in creative_violations)


def test_validate_document_non_standard_dates(tmp_path: Path) -> None:
    """Test that non-standard date formats are detected and flagged."""
    file_path = tmp_path / "test.md"
    file_path.write_text(
        """# Resume

## Experience
- Software Engineer at TechCorp (Early 2020 - Mid 2024)
- Developer at StartupCo (Summer 2018 - Fall 2020)
- Intern at BigTech (2016-2018)
""",
        encoding="utf-8",
    )
    violations = validate_document(file_path)

    # Should detect non-standard date formats
    date_violations = [
        v for v in violations if v.violation_type == "Non-Standard Date Format"
    ]
    assert len(date_violations) >= 2  # At least the Early/Mid and Summer/Fall dates
    assert all(v.severity == Severity.HIGH for v in date_violations)


def test_validate_document_hidden_text(tmp_path: Path) -> None:
    """Test that hidden text in HTML comments is detected and flagged."""
    file_path = tmp_path / "test.md"
    file_path.write_text(
        """# Resume

## Professional Summary
Experienced software engineer.

<!-- This is hidden text that shouldn't be visible -->
<!-- Keywords: software engineer, developer, programming -->

## Experience
Software Engineer at TechCorp (2020-2024)
""",
        encoding="utf-8",
    )
    violations = validate_document(file_path)

    # Should detect hidden text
    hidden_violations = [v for v in violations if v.violation_type == "Hidden Text"]
    assert len(hidden_violations) >= 2  # At least the two comment blocks
    assert all(v.severity == Severity.CRITICAL for v in hidden_violations)


def test_validate_document_keyword_stuffing(tmp_path: Path) -> None:
    """Test that keyword stuffing is detected and flagged."""
    file_path = tmp_path / "test.md"
    file_path.write_text(
        """# Resume

## Professional Summary
Experienced software engineer software developer programmer with extensive experience in software development programming coding. Skilled in software engineering software development programming and coding.

## Skills
- Software development programming coding
- Software engineering software development
""",
        encoding="utf-8",
    )
    violations = validate_document(file_path)

    # Should detect keyword stuffing
    keyword_violations = [
        v for v in violations if v.violation_type == "Keyword Stuffing"
    ]
    assert len(keyword_violations) >= 1  # At least one instance of excessive repetition
    assert all(v.severity == Severity.LOW for v in keyword_violations)


def test_validate_document_non_standard_section_headers(tmp_path: Path) -> None:
    """Test that non-standard section headers are detected and flagged."""
    file_path = tmp_path / "test.md"
    file_path.write_text(
        """# Resume

## Contact Info
- Email: test@email.com

## Work History
- Software Engineer at TechCorp

## Tech Skills
- Python, JavaScript

## Education Background
- BS Computer Science
""",
        encoding="utf-8",
    )
    violations = validate_document(file_path)

    # Should detect non-standard section headers
    section_violations = [
        v for v in violations if v.violation_type == "Non-Standard Section Header"
    ]
    assert len(section_violations) >= 2  # At least some non-standard headers
    assert all(v.severity == Severity.LOW for v in section_violations)


def test_validate_document_standard_section_headers(tmp_path: Path) -> None:
    """Test that standard section headers don't trigger violations."""
    file_path = tmp_path / "test.md"
    file_path.write_text(
        """# Resume

## Professional Summary
Experienced software engineer.

## Professional Experience
- Software Engineer at TechCorp

## Technical Skills
- Python, JavaScript

## Education
- BS Computer Science
""",
        encoding="utf-8",
    )
    violations = validate_document(file_path)

    # Should not trigger section header violations for standard names
    section_violations = [
        v for v in violations if v.violation_type == "Non-Standard Section Header"
    ]
    assert len(section_violations) == 0


def test_validate_document_comprehensive_violations(tmp_path: Path) -> None:
    """Test a document with multiple types of violations."""
    file_path = tmp_path / "test.md"
    file_path.write_text(
        """# Resume

## Contact Information 📧
- EMAIL: TEST@EMAIL.COM 📱

## Professional Summary
EXPERIENCED SOFTWARE ENGINEER with "smart quotes" and — em dash.

## Experience
- Code Ninja at TechCorp (Early 2020 - Mid 2024)
- Digital Wizard at StartupCo (2018-2020)

## Skills
| Category | Technologies |
|----------|-------------|
| Languages | Python, JavaScript |

<!-- Hidden text: software engineer, developer -->

## Work History
- Software Engineer at BigTech (2016-2018)
""",
        encoding="utf-8",
    )
    violations = validate_document(file_path)

    # Should detect multiple types of violations
    violation_types = {v.violation_type for v in violations}
    expected_types = {
        "Emoji/Special Character",
        "ALL CAPS",
        "Smart Quotes",
        "Em Dash",
        "Creative Job Title",
        "Non-Standard Date Format",
        "Table Usage",
        "Hidden Text",
        "Non-Standard Section Header",
    }

    # Should have at least some of each expected type
    assert len(violation_types.intersection(expected_types)) >= 5

    # Check severity distribution
    severities = {v.severity for v in violations}
    assert Severity.CRITICAL in severities  # Emojis and hidden text
    assert Severity.HIGH in severities  # Tables and dates
    assert Severity.MEDIUM in severities  # Smart quotes and creative titles
    assert Severity.LOW in severities  # ALL CAPS and section headers


def test_validate_document_violation_structure(tmp_path: Path) -> None:
    """Test that violations have the correct structure."""
    file_path = tmp_path / "test.md"
    file_path.write_text("This has an emoji: 😊", encoding="utf-8")
    violations = validate_document(file_path)

    assert len(violations) == 1
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
    assert violation.line_number == 1
    assert violation.violation_type == "Emoji/Special Character"
    assert violation.severity == Severity.CRITICAL
    assert "😊" in violation.message
    assert "Remove emojis" in violation.suggestion
    assert violation.found_text == "😊"


def test_validate_document_severity_ordering(tmp_path: Path) -> None:
    """Test that violations are ordered by severity (CRITICAL first)."""
    file_path = tmp_path / "test.md"
    file_path.write_text(
        """# Resume

## ALL CAPS SECTION
This is in all caps.

## Experience
- Code Ninja at TechCorp (Early 2020 - Mid 2024)

## Skills
| Category | Technologies |
|----------|-------------|
| Languages | Python |

This has an emoji: 😊
""",
        encoding="utf-8",
    )
    violations = validate_document(file_path)

    # Should be ordered by severity: CRITICAL, HIGH, MEDIUM, LOW
    severities = [v.severity for v in violations]

    # Find the first occurrence of each severity level
    critical_idx = next(
        (i for i, s in enumerate(severities) if s == Severity.CRITICAL), -1
    )
    high_idx = next((i for i, s in enumerate(severities) if s == Severity.HIGH), -1)
    medium_idx = next((i for i, s in enumerate(severities) if s == Severity.MEDIUM), -1)
    low_idx = next((i for i, s in enumerate(severities) if s == Severity.LOW), -1)

    # CRITICAL should come before HIGH, MEDIUM, and LOW
    if critical_idx != -1 and high_idx != -1:
        assert critical_idx < high_idx
    if critical_idx != -1 and medium_idx != -1:
        assert critical_idx < medium_idx
    if critical_idx != -1 and low_idx != -1:
        assert critical_idx < low_idx

    # HIGH should come before MEDIUM and LOW
    if high_idx != -1 and medium_idx != -1:
        assert high_idx < medium_idx
    if high_idx != -1 and low_idx != -1:
        assert high_idx < low_idx

    # MEDIUM should come before LOW
    if medium_idx != -1 and low_idx != -1:
        assert medium_idx < low_idx
