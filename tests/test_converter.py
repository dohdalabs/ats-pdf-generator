"""Tests for the ATS PDF Converter."""

import subprocess
from pathlib import Path
from unittest.mock import patch

import pytest
from click.testing import CliRunner

from ats_pdf_generator.ats_converter import (
    ATSGeneratorError,
    ConversionError,
    FileOperationError,
    ValidationError,
    _create_fallback_css,
    _determine_css_file,
    _preprocess_markdown,
    _validate_input_file,
    cli,
)


@pytest.fixture
def runner() -> CliRunner:
    """Fixture for invoking command-line interfaces."""
    return CliRunner()


class TestATSConverter:
    """Test cases for the ATS converter functionality."""

    def test_exception_hierarchy(self) -> None:
        """Test that custom exceptions inherit properly."""
        assert issubclass(ValidationError, ATSGeneratorError)
        assert issubclass(FileOperationError, ATSGeneratorError)
        assert issubclass(ConversionError, ATSGeneratorError)

    def test_validate_input_file_success(self, tmp_path: Path) -> None:
        """Test successful file validation."""
        test_file = tmp_path / "test.md"
        test_file.write_text("# Test content")
        _validate_input_file(str(test_file))

    def test_validate_input_file_nonexistent(self) -> None:
        """Test validation with nonexistent file."""
        with pytest.raises(ValidationError, match="Input file does not exist"):
            _validate_input_file("nonexistent_file.md")

    def test_create_fallback_css(self, tmp_path: Path) -> None:
        """Test fallback CSS creation function."""
        css_file = tmp_path / "test-fallback.css"
        _create_fallback_css(css_file)
        assert css_file.exists()
        content = css_file.read_text()
        assert "Fallback CSS" in content

    def test_preprocess_markdown(self, tmp_path: Path) -> None:
        """Test markdown preprocessing."""
        input_file = tmp_path / "input.md"
        output_file = tmp_path / "output.md"
        input_file.write_text("• Hello\n* World")
        _preprocess_markdown(input_file, output_file)
        content = output_file.read_text()
        assert content == "- Hello\n- World"


class TestCli:
    """Test cases for the command-line interface."""

    def test_cli_help(self, runner: CliRunner) -> None:
        """Test the CLI help message."""
        result = runner.invoke(cli, ["--help"])
        assert result.exit_code == 0
        assert "Usage: cli [OPTIONS] INPUT_FILE" in result.output
        assert "Convert Markdown documents" in result.output

    def test_cli_simple_conversion(self, runner: CliRunner, tmp_path: Path) -> None:
        """Test a simple conversion."""
        input_file = tmp_path / "test.md"
        input_file.write_text("# Hello")
        output_file = tmp_path / "test.pdf"

        with patch("subprocess.run") as mock_run:
            mock_run.return_value = subprocess.CompletedProcess(
                args=[], returncode=0, stdout="", stderr=""
            )
            result = runner.invoke(cli, [str(input_file), "-o", str(output_file)])

        assert result.exit_code == 0
        assert f"Successfully converted '{input_file}'" in result.output
        mock_run.assert_called_once()
        cmd = mock_run.call_args[0][0]
        assert str(output_file) in cmd
        assert "--pdf-engine" in cmd
        assert "weasyprint" in cmd

    def test_cli_no_output_file(self, runner: CliRunner, tmp_path: Path) -> None:
        """Test conversion without specifying an output file."""
        input_file = tmp_path / "test.md"
        input_file.write_text("# Hello")
        expected_output = input_file.with_suffix(".pdf")

        with patch("subprocess.run") as mock_run:
            mock_run.return_value = subprocess.CompletedProcess(
                args=[], returncode=0, stdout="", stderr=""
            )
            result = runner.invoke(cli, [str(input_file)])

        assert result.exit_code == 0
        assert str(expected_output) in result.output
        cmd = mock_run.call_args[0][0]
        assert str(expected_output) in cmd

    def test_cli_custom_css(self, runner: CliRunner, tmp_path: Path) -> None:
        """Test conversion with a custom CSS file."""
        input_file = tmp_path / "test.md"
        input_file.write_text("# Hello")
        css_file = tmp_path / "custom.css"
        css_file.write_text("body { color: red; }")

        with patch("subprocess.run") as mock_run:
            mock_run.return_value = subprocess.CompletedProcess(
                args=[], returncode=0, stdout="", stderr=""
            )
            result = runner.invoke(cli, [str(input_file), "--css", str(css_file)])

        assert result.exit_code == 0
        mock_run.assert_called_once()
        cmd = mock_run.call_args[0][0]
        assert "--css" in cmd
        assert str(css_file) in cmd

    def test_cli_pandoc_error(self, runner: CliRunner, tmp_path: Path) -> None:
        """Test how the CLI handles a pandoc error."""
        input_file = tmp_path / "test.md"
        input_file.write_text("# Hello")

        with patch("subprocess.run") as mock_run:
            mock_run.side_effect = subprocess.CalledProcessError(
                1, "pandoc", stderr="pandoc error"
            )
            result = runner.invoke(cli, [str(input_file)])

        assert result.exit_code == 1
        assert "Pandoc conversion failed" in result.output
        assert "pandoc error" in result.output

    def test_cli_metadata_parameters(self, runner: CliRunner, tmp_path: Path) -> None:
        """Test that metadata parameters are passed to pandoc."""
        input_file = tmp_path / "test.md"
        input_file.write_text("# Hello")

        with patch("subprocess.run") as mock_run:
            mock_run.return_value = subprocess.CompletedProcess(
                args=[], returncode=0, stdout="", stderr=""
            )
            result = runner.invoke(
                cli,
                [
                    str(input_file),
                    "--title",
                    "My Title",
                    "--author",
                    "My Author",
                    "--date",
                    "2023-01-01",
                ],
            )

        assert result.exit_code == 0
        mock_run.assert_called_once()
        cmd = mock_run.call_args[0][0]
        assert "--metadata" in cmd
        assert "title=My Title" in cmd
        assert "author=My Author" in cmd
        assert "date=2023-01-01" in cmd


class TestCSSDetermination:
    """Test cases for CSS file determination logic."""

    def test_determine_css_file_default(self) -> None:
        """Test that the default CSS is returned when no type is specified."""
        with patch("pathlib.Path.exists", return_value=True):
            css_file = _determine_css_file("cover-letter", None)
            assert "ats-cover-letter.css" in css_file

    def test_determine_css_file_profile(self) -> None:
        """Test that the profile CSS is returned for the 'profile' type."""
        with patch("pathlib.Path.exists", return_value=True):
            css_file = _determine_css_file("profile", None)
            assert "ats-profile.css" in css_file

    def test_determine_css_file_custom(self, tmp_path: Path) -> None:
        """Test that a custom CSS file is used when provided."""
        custom_css_file = tmp_path / "custom.css"
        custom_css_file.touch()
        css_file = _determine_css_file("cover-letter", str(custom_css_file))
        assert css_file == str(custom_css_file)

    def test_determine_css_file_custom_not_found(self) -> None:
        """Test that an error is raised if the custom CSS file doesn't exist."""
        with pytest.raises(ValidationError, match="Custom CSS file not found"):
            _determine_css_file("cover-letter", "nonexistent.css")

    def test_determine_css_fallback(self, tmp_path: Path) -> None:
        """Test that a fallback CSS is created if the default is not found."""
        with patch("pathlib.Path.exists", return_value=False):
            fallback_css = tmp_path / "templates" / "ats-fallback.css"
            with patch(
                "ats_pdf_generator.ats_converter._create_fallback_css"
            ) as mock_create:
                # To avoid modifying the real filesystem, we mock the creation
                # and just check that the correct path would be returned.
                # We also need to mock the path object for the return value
                with patch("ats_pdf_generator.ats_converter.Path") as mock_path:
                    mock_path.return_value = fallback_css
                    css_file = _determine_css_file("cover-letter", None)
                    assert css_file == str(fallback_css)
                    mock_create.assert_called_once_with(fallback_css)
