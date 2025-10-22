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
    """
    file_path = tmp_path / "test.md"
    file_path.write_text(
        "This is a document with allowed characters: $ € £ ° &", encoding="utf-8"
    )
    violations = validate_document(file_path)
    assert not violations
