#!/usr/bin/env python3
"""
Tests for the ATS Document Validator.
"""

# Standard library
from pathlib import Path

# First-party
from ats_pdf_generator.validator import validate_document


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
