"""Tests for the ATS PDF Converter."""

import sys
from pathlib import Path
from unittest.mock import patch

import pytest

from ats_pdf_generator.ats_converter import main


class TestATSConverter:
    """Test cases for the ATS converter functionality."""

    def test_converter_import(self) -> None:
        """Test that the converter module can be imported."""
        from ats_pdf_generator import ats_converter

        assert ats_converter is not None

    def test_help_output(self, capsys: pytest.CaptureFixture[str]) -> None:
        """Test that help output is generated correctly."""
        with patch.object(sys, "argv", ["ats_converter.py"]):
            with pytest.raises(SystemExit):
                main()

        captured = capsys.readouterr()
        assert "Usage:" in captured.out
        assert "ATS Document Converter" in captured.out
        assert "Convert Markdown documents to ATS-optimized PDFs" in captured.out

    def test_invalid_input_file(self) -> None:
        """Test that invalid input files are handled properly."""
        with patch.object(sys, "argv", ["ats_converter.py", "nonexistent_file.md"]):
            with pytest.raises(SystemExit):
                main()

    @pytest.mark.skipif(  # type: ignore[misc]
        not Path("examples/sample-cover-letter.md").exists(),
        reason="Sample file not found",
    )
    def test_sample_file_exists(self) -> None:
        """Test that sample files are available."""
        assert Path("examples/sample-cover-letter.md").exists()
        assert Path("examples/sample-profile.md").exists()


class TestCSSFiles:
    """Test cases for CSS template files."""

    def test_css_files_exist(self) -> None:
        """Test that required CSS files exist."""
        css_files = [
            "templates/ats-cover-letter.css",
            "templates/ats-profile.css",
            "templates/ats-document.css",
        ]

        for css_file in css_files:
            assert Path(css_file).exists(), f"CSS file {css_file} not found"

    def test_css_files_readable(self) -> None:
        """Test that CSS files are readable and contain content."""
        css_files = [
            "templates/ats-cover-letter.css",
            "templates/ats-profile.css",
            "templates/ats-document.css",
        ]

        for css_file in css_files:
            content = Path(css_file).read_text()
            assert len(content) > 0, f"CSS file {css_file} is empty"
            assert "body" in content, f"CSS file {css_file} missing basic styling"
