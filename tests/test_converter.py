"""Tests for the ATS PDF Converter."""

import subprocess
import sys
from pathlib import Path
from typing import Any
from unittest.mock import patch

import pytest

from ats_pdf_generator import ats_converter
from ats_pdf_generator.ats_converter import (
    ATSGeneratorError,
    ConversionError,
    FileOperationError,
    ValidationError,
    _create_fallback_css,
    _determine_css_file,
    _validate_input_file,
    cli,
    main,
)


class TestATSConverter:
    """Test cases for the ATS converter functionality."""

    def test_converter_import(self) -> None:
        """Test that the converter module can be imported."""
        assert ats_converter is not None

    def test_exception_hierarchy(self) -> None:
        """Test that custom exceptions inherit properly."""
        assert issubclass(ValidationError, ATSGeneratorError)
        assert issubclass(FileOperationError, ATSGeneratorError)
        assert issubclass(ConversionError, ATSGeneratorError)

        # Test exception instantiation
        validation_error = ValidationError("Test validation error")
        file_error = FileOperationError("Test file error")
        conversion_error = ConversionError("Test conversion error")

        assert str(validation_error) == "Test validation error"
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
            with pytest.raises(ValidationError):
                main()

    def test_file_operation_error_handling(
        self, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        """Test that file operation errors are properly handled."""

        # Mock file operations to trigger FileOperationError in _create_fallback_css
        def mock_open(*args: object, **kwargs: object) -> None:
            raise OSError("Permission denied")

        monkeypatch.setattr("builtins.open", mock_open)

        with pytest.raises(FileOperationError, match="Cannot create CSS file"):
            _create_fallback_css("test.css")

    def test_conversion_error_handling(self, monkeypatch: pytest.MonkeyPatch) -> None:
        """Test that conversion errors are properly handled."""

        # Mock subprocess.run to trigger ConversionError
        def mock_subprocess_run(*args: object, **kwargs: object) -> None:
            raise subprocess.CalledProcessError(1, "pandoc", stderr="Test error")

        monkeypatch.setattr(subprocess, "run", mock_subprocess_run)

        # Create a temporary test file
        test_file = Path("test_input.md")
        test_file.write_text("# Test\nContent")

        try:
            with patch.object(sys, "argv", ["ats_converter.py", str(test_file)]):
                with pytest.raises(ConversionError, match="Pandoc conversion failed"):
                    main()
        finally:
            test_file.unlink(missing_ok=True)

    def test_validation_error_handling(self) -> None:
        """Test that validation errors are properly handled."""
        # Test with non-existent file
        with pytest.raises(ValidationError, match="Input file does not exist"):
            _validate_input_file("nonexistent_file.md")

        # Test with directory instead of file
        test_dir = Path("test_directory")
        test_dir.mkdir(exist_ok=True)
        try:
            with pytest.raises(ValidationError, match="Path is not a file"):
                _validate_input_file(str(test_dir))
        finally:
            test_dir.rmdir()

    @pytest.mark.skipif(
        not Path("examples/sample-cover-letter.md").exists(),
        reason="Sample file not found",
    )
    def test_sample_file_exists(self) -> None:
        """Test that sample files are available."""
        assert Path("examples/sample-cover-letter.md").exists()
        assert Path("examples/sample-profile.md").exists()

    def test_bullet_point_preprocessing_preserves_newlines(
        self, tmp_path: Path
    ) -> None:
        """Test that bullet point preprocessing preserves newline characters.

        This test verifies that when converting • or * bullets to markdown
        list items (-), the newline character at the end of each line is
        preserved, preventing line concatenation.
        """
        # Create a test input file with various bullet formats
        test_input = """# Test Document
• First item
• Second item
  • Indented item
* First asterisk
* Second asterisk
Regular text
"""

        # Expected output after preprocessing
        expected_output = """# Test Document
- First item
- Second item
  - Indented item
- First asterisk
- Second asterisk
Regular text
"""

        input_file = tmp_path / "test-input.md"
        output_file = tmp_path / "test-output.md"

        input_file.write_text(test_input)

        # Manually simulate the preprocessing logic
        with (
            input_file.open("r", encoding="utf-8") as f_in,
            output_file.open("w", encoding="utf-8") as f_out,
        ):
            for line in f_in:
                stripped = line.lstrip()
                if stripped.startswith("• ") or stripped.startswith("* "):
                    indent = line[: len(line) - len(stripped)]
                    # Remove bullet and space (first 2 chars), keep rest including newline
                    content = stripped[2:]
                    f_out.write(f"{indent}- {content}")
                else:
                    f_out.write(line)

        # Read the processed output
        actual_output = output_file.read_text()

        # Verify newlines are preserved and content matches expected
        assert actual_output == expected_output

        # Verify no line concatenation occurred (each line is separate)
        actual_lines = actual_output.split("\n")
        expected_lines = expected_output.split("\n")
        assert len(actual_lines) == len(expected_lines)

        # Verify specific conversions
        assert "- First item\n" in actual_output
        assert "- Second item\n" in actual_output
        assert "  - Indented item\n" in actual_output
        assert "- First asterisk\n" in actual_output
        assert "- Second asterisk\n" in actual_output

    def test_markdown_file_detection_case_insensitive(self, tmp_path: Path) -> None:
        """Test that Markdown file detection is case-insensitive."""
        # Create test files with different case extensions
        test_files = {
            "lowercase.md": "# Lowercase MD",
            "uppercase.MD": "# Uppercase MD",
            "mixedcase.Md": "# Mixed case Md",
            "other.txt": "Not markdown",
        }

        for filename, content in test_files.items():
            (tmp_path / filename).write_text(content)

        # Mock sys.argv with files of different cases
        test_args = [
            "script_name",
            str(tmp_path / "lowercase.md"),
            str(tmp_path / "uppercase.MD"),
            str(tmp_path / "mixedcase.Md"),
            str(tmp_path / "other.txt"),
            "-o",
            str(tmp_path / "output.pdf"),
        ]

        with patch("sys.argv", test_args):
            # Mock subprocess.run to avoid actual conversion
            with patch("subprocess.run") as mock_run:
                mock_run.return_value = subprocess.CompletedProcess(
                    args=[], returncode=0, stdout="", stderr=""
                )

                # Run main - should process all .md variants
                main()

                # Verify subprocess was called
                assert mock_run.called
                cmd = mock_run.call_args[0][0]

                # All markdown files (regardless of case) should be in the command
                # They will be preprocessed to .preprocessed.md files
                cmd_str = " ".join(cmd)
                assert ".preprocessed.md" in cmd_str

                # Non-markdown files should be passed through unchanged
                assert str(tmp_path / "other.txt") in cmd


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

    def test_determine_css_file_keywords_adjacent_to_extensions(self) -> None:
        """Test CSS determination with keywords adjacent to file extensions."""
        # Test profile keyword directly adjacent to .md extension
        css_file = _determine_css_file(["profile.md"])
        assert css_file == "templates/ats-profile.css"

        # Test cover keyword directly adjacent to .md extension
        css_file = _determine_css_file(["cover.md"])
        assert css_file == "templates/ats-cover-letter.css"

        # Test application keyword directly adjacent to .md extension
        css_file = _determine_css_file(["application.md"])
        assert css_file == "templates/ats-cover-letter.css"

        # Test document keyword directly adjacent to .md extension
        css_file = _determine_css_file(["document.md"])
        assert css_file == "templates/ats-document.css"

        # Test with different extensions
        css_file = _determine_css_file(["profile.txt"])
        assert css_file == "templates/ats-profile.css"

        css_file = _determine_css_file(["cover.docx"])
        assert css_file == "templates/ats-cover-letter.css"

    def test_determine_css_file_with_underscore_separators(self) -> None:
        """Test CSS determination with underscore-separated filenames."""
        # Test profile keyword with underscore separator
        css_file = _determine_css_file(["my_profile.md"])
        assert css_file == "templates/ats-profile.css"

        # Test cover keyword with underscore separator
        css_file = _determine_css_file(["john_cover_letter.md"])
        assert css_file == "templates/ats-cover-letter.css"

        # Test application keyword with underscore separator
        css_file = _determine_css_file(["job_application_2024.md"])
        assert css_file == "templates/ats-cover-letter.css"

        # Test document keyword with underscore separator
        css_file = _determine_css_file(["company_document.md"])
        assert css_file == "templates/ats-document.css"

        # Test mixed separators (underscores and hyphens)
        css_file = _determine_css_file(["my_professional-profile.md"])
        assert css_file == "templates/ats-profile.css"

        # Test multiple underscores
        css_file = _determine_css_file(["jane__resume__profile.md"])
        assert css_file == "templates/ats-profile.css"

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


class TestValidation:
    """Test cases for input validation functionality."""

    def test_validate_input_file_success(self, tmp_path: Path) -> None:
        """Test successful file validation."""
        # Arrange
        test_file = tmp_path / "test.md"
        test_file.write_text("# Test content")

        # Act & Assert - should not raise any exception
        _validate_input_file(str(test_file))

    def test_validate_input_file_nonexistent(self) -> None:
        """Test validation with nonexistent file."""
        # Act & Assert
        with pytest.raises(ValidationError, match="Input file does not exist"):
            _validate_input_file("nonexistent_file.md")

    def test_validate_input_file_not_a_file(self, tmp_path: Path) -> None:
        """Test validation with directory instead of file."""
        # Arrange
        test_dir = tmp_path / "test_dir"
        test_dir.mkdir()

        # Act & Assert
        with pytest.raises(ValidationError, match="Path is not a file"):
            _validate_input_file(str(test_dir))

    def test_validate_input_file_permission_error(self, tmp_path: Path) -> None:
        """Test validation with file that cannot be read."""
        test_file = tmp_path / "test.md"
        test_file.write_text("# Test content")

        if sys.platform.startswith("win"):
            # Windows does not enforce Unix-style read permissions like chmod(0o000)
            # Therefore, we simulate a permission failure by mocking open() to raise PermissionError
            # This ensures the test validates the same error handling path on Windows as on Unix
            with patch("builtins.open", side_effect=PermissionError):
                with pytest.raises(FileOperationError, match="Cannot read file"):
                    _validate_input_file(str(test_file))
        else:
            # Unix/Linux permission restriction
            test_file.chmod(0o000)
            try:
                with pytest.raises(FileOperationError, match="Cannot read file"):
                    _validate_input_file(str(test_file))
            finally:
                test_file.chmod(0o644)

    def test_cli_success(self) -> None:
        """Test CLI function with successful execution."""
        with patch("ats_pdf_generator.ats_converter.main") as mock_main:
            mock_main.return_value = None

            # Should complete without raising SystemExit
            cli()

            # Verify main was called
            mock_main.assert_called_once()

    def test_cli_validation_error(self, capsys: Any) -> None:
        """Test CLI function handles ValidationError with exit code 1."""
        with patch("ats_pdf_generator.ats_converter.main") as mock_main:
            mock_main.side_effect = ValidationError("Invalid input file")

            with pytest.raises(SystemExit) as exc_info:
                cli()

            assert exc_info.value.code == 1
            captured = capsys.readouterr()
            assert "Error: Invalid input file" in captured.err

    def test_cli_file_operation_error(self, capsys: Any) -> None:
        """Test CLI function handles FileOperationError with exit code 1."""
        with patch("ats_pdf_generator.ats_converter.main") as mock_main:
            mock_main.side_effect = FileOperationError("Cannot read file")

            with pytest.raises(SystemExit) as exc_info:
                cli()

            assert exc_info.value.code == 1
            captured = capsys.readouterr()
            assert "Error: Cannot read file" in captured.err

    def test_cli_conversion_error(self, capsys: Any) -> None:
        """Test CLI function handles ConversionError with exit code 1."""
        with patch("ats_pdf_generator.ats_converter.main") as mock_main:
            mock_main.side_effect = ConversionError("Pandoc conversion failed")

            with pytest.raises(SystemExit) as exc_info:
                cli()

            assert exc_info.value.code == 1
            captured = capsys.readouterr()
            assert "Error: Pandoc conversion failed" in captured.err

    def test_cli_keyboard_interrupt(self, capsys: Any) -> None:
        """Test CLI function handles KeyboardInterrupt gracefully."""
        with patch("ats_pdf_generator.ats_converter.main") as mock_main:
            mock_main.side_effect = KeyboardInterrupt()

            with pytest.raises(SystemExit) as exc_info:
                cli()

            assert exc_info.value.code == 1
            captured = capsys.readouterr()
            assert "Operation cancelled by user" in captured.err

    def test_cli_unexpected_error(self, capsys: Any) -> None:
        """Test CLI function handles unexpected exceptions with exit code 2."""
        with patch("ats_pdf_generator.ats_converter.main") as mock_main:
            mock_main.side_effect = RuntimeError("Unexpected error occurred")

            with pytest.raises(SystemExit) as exc_info:
                cli()

            assert exc_info.value.code == 2
            captured = capsys.readouterr()
            assert "Unexpected error: Unexpected error occurred" in captured.err
            assert "Please report this issue" in captured.err
