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


# ============================================================================
# New Comprehensive Validation Tests
# ============================================================================


def test_validate_document_markdown_tables(tmp_path: Path) -> None:
    """Test that Markdown tables are detected and flagged."""
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
    table_violations = [v for v in violations if v.violation_type == "Markdown Table"]
    assert len(table_violations) >= 2  # At least the header and one data row
    assert all(v.severity == Severity.HIGH for v in table_violations)


def test_validate_document_html_tables(tmp_path: Path) -> None:
    """Test that HTML tables are detected and flagged."""
    file_path = tmp_path / "test.md"
    file_path.write_text(
        """# Resume

## Skills
<table>
<tr><th>Category</th><th>Technologies</th></tr>
<tr><td>Languages</td><td>Python, JavaScript</td></tr>
<tr><td>Tools</td><td>Docker, Kubernetes</td></tr>
</table>
""",
        encoding="utf-8",
    )
    violations = validate_document(file_path)

    # Should detect HTML table
    table_violations = [v for v in violations if v.violation_type == "HTML Table"]
    assert len(table_violations) >= 1
    assert all(v.severity == Severity.HIGH for v in table_violations)


def test_validate_document_no_tables(tmp_path: Path) -> None:
    """Test that documents without tables pass validation."""
    file_path = tmp_path / "test.md"
    file_path.write_text(
        """# Resume

## Skills
- Python
- JavaScript
- Docker
- Kubernetes
""",
        encoding="utf-8",
    )
    violations = validate_document(file_path)

    # Should not detect any table violations
    table_violations = [v for v in violations if "Table" in v.violation_type]
    assert len(table_violations) == 0


def test_validate_document_violation_structure(tmp_path: Path) -> None:
    """Test that violations have the correct structure."""
    file_path = tmp_path / "test.md"
    file_path.write_text(
        """# Resume

## Skills
| Category | Technologies |
|----------|-------------|
| Languages | Python, JavaScript |
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
    assert violation.violation_type in ["Markdown Table", "HTML Table"]
    assert violation.severity == Severity.HIGH
    assert "table" in violation.message.lower()
    assert "Convert tables" in violation.suggestion
