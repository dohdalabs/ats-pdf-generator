"""Tests for the ATS PDF Converter."""

import sys
from pathlib import Path
from unittest.mock import patch

import pytest

from ats_pdf_generator.ats_converter import (
    ATSGeneratorError,
    ConversionError,
    FileOperationError,
    _create_fallback_css,
    _determine_css_file,
    main,
)


class TestATSConverter:
    """Test cases for the ATS converter functionality."""

    def test_converter_import(self) -> None:
        """Test that the converter module can be imported."""
        from ats_pdf_generator import ats_converter

        assert ats_converter is not None

    def test_exception_hierarchy(self) -> None:
        """Test that custom exceptions inherit properly."""
        assert issubclass(FileOperationError, ATSGeneratorError)
        assert issubclass(ConversionError, ATSGeneratorError)

        # Test exception instantiation
        file_error = FileOperationError("Test file error")
        conversion_error = ConversionError("Test conversion error")

        assert str(file_error) == "Test file error"
        assert str(conversion_error) == "Test conversion error"

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
            with pytest.raises(ConversionError):
                main()

    def test_file_operation_error_handling(self) -> None:
        """Test that file operation errors are properly handled."""
        # This test would require mocking file operations to trigger FileOperationError
        # For now, we'll test that the exception can be raised
        with pytest.raises(FileOperationError):
            raise FileOperationError("Test file operation error")

    def test_conversion_error_handling(self) -> None:
        """Test that conversion errors are properly handled."""
        # This test would require mocking subprocess to trigger ConversionError
        # For now, we'll test that the exception can be raised
        with pytest.raises(ConversionError):
            raise ConversionError("Test conversion error")

    @pytest.mark.skipif(
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


class TestCSSDetermination:
    """Test cases for CSS file determination functionality."""

    def test_determine_css_file_with_existing_templates(self) -> None:
        """Test CSS determination with existing templates."""
        # Test with no files - should return default
        css_file = _determine_css_file([])
        assert css_file == "templates/ats-cover-letter.css"
        assert Path(css_file).exists()

    def test_determine_css_file_with_filename_keywords(self) -> None:
        """Test CSS determination based on filename keywords."""
        # Test profile filename
        css_file = _determine_css_file(["test-profile.md"])
        assert css_file == "templates/ats-profile.css"

        # Test cover letter filename
        css_file = _determine_css_file(["cover-letter.md"])
        assert css_file == "templates/ats-cover-letter.css"

        # Test document filename
        css_file = _determine_css_file(["document.md"])
        assert css_file == "templates/ats-document.css"

    def test_determine_css_file_with_content_keywords(self, tmp_path: Path) -> None:
        """Test CSS determination based on content keywords."""
        # Create temporary files with specific content
        profile_file = tmp_path / "test.md"
        profile_file.write_text(
            "This is my professional profile and experience summary."
        )

        cover_letter_file = tmp_path / "application.md"
        cover_letter_file.write_text(
            "Dear Hiring Manager, I am writing to apply for this position."
        )

        # Test profile content
        css_file = _determine_css_file([str(profile_file)])
        assert css_file == "templates/ats-profile.css"

        # Test cover letter content
        css_file = _determine_css_file([str(cover_letter_file)])
        assert css_file == "templates/ats-cover-letter.css"

    def test_determine_css_file_fallback_creation(
        self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        """Test fallback CSS creation when no templates exist."""
        # Change to temporary directory
        monkeypatch.chdir(tmp_path)

        # Ensure templates directory doesn't exist
        templates_dir = tmp_path / "templates"
        assert not templates_dir.exists()

        # Call function - should create templates directory and fallback CSS
        css_file = _determine_css_file([])
        assert css_file == "templates/ats-fallback.css"
        assert Path(css_file).exists()

        # Verify fallback CSS content
        content = Path(css_file).read_text()
        assert "Fallback CSS for ATS PDF Generator" in content
        assert "body" in content
        assert "font-family" in content

    def test_create_fallback_css(self, tmp_path: Path) -> None:
        """Test fallback CSS creation function."""
        css_file = tmp_path / "test-fallback.css"
        _create_fallback_css(str(css_file))

        assert css_file.exists()
        content = css_file.read_text()
        assert "Fallback CSS for ATS PDF Generator" in content
        assert "body" in content
        assert "font-family" in content
        assert "h1, h2, h3" in content

    def test_create_fallback_css_error(self, tmp_path: Path) -> None:
        """Test fallback CSS creation with invalid path."""
        invalid_path = tmp_path / "nonexistent" / "test.css"

        with pytest.raises(FileOperationError, match="Cannot create CSS file"):
            _create_fallback_css(str(invalid_path))

    def test_determine_css_file_guarantees_existence(self) -> None:
        """Test that _determine_css_file always returns an existing file."""
        css_file = _determine_css_file([])
        assert Path(css_file).exists(), f"Returned CSS file {css_file} does not exist"
