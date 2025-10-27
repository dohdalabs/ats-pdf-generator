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
from ats_pdf_generator.reporter import generate_markdown_report
from ats_pdf_generator.validation_types import SeverityLevel, Violation


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

    def test_create_fallback_css_readonly_directory(self, tmp_path: Path) -> None:
        """Test fallback CSS creation fails with read-only directory."""
        readonly_dir = tmp_path / "readonly_dir"
        readonly_dir.mkdir()
        css_file = readonly_dir / "test.css"

        # Make directory read-only
        readonly_dir.chmod(0o444)

        try:
            with pytest.raises(FileOperationError, match="Cannot create CSS file"):
                _create_fallback_css(css_file)
        finally:
            # Restore permissions for cleanup
            readonly_dir.chmod(0o755)

    def test_create_fallback_css_io_error(
        self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        """Test fallback CSS creation with mocked I/O failure."""
        css_file = tmp_path / "test.css"

        # Mock Path.write_text to raise OSError
        def mock_write_text(*args: object, **kwargs: object) -> None:
            raise OSError("Mocked I/O error")

        monkeypatch.setattr(Path, "write_text", mock_write_text)

        with pytest.raises(FileOperationError, match="Cannot create CSS file"):
            _create_fallback_css(css_file)

    def test_create_fallback_css_existing_file(self, tmp_path: Path) -> None:
        """Test fallback CSS creation when target file already exists."""
        css_file = tmp_path / "existing.css"
        original_content = "/* Original content */"
        css_file.write_text(original_content)

        # Should overwrite existing file
        _create_fallback_css(css_file)
        assert css_file.exists()
        content = css_file.read_text()
        assert "Fallback CSS" in content
        assert original_content not in content

    def test_create_fallback_css_readonly_file(self, tmp_path: Path) -> None:
        """Test fallback CSS creation when target file is read-only."""
        css_file = tmp_path / "readonly.css"
        css_file.write_text("/* Original content */")

        # Make file read-only
        css_file.chmod(0o444)

        try:
            with pytest.raises(FileOperationError, match="Cannot create CSS file"):
                _create_fallback_css(css_file)
        finally:
            # Restore permissions for cleanup
            css_file.chmod(0o644)

    def test_create_fallback_css_parent_dir_creation(self, tmp_path: Path) -> None:
        """Test fallback CSS creation when parent directory doesn't exist."""
        nested_dir = tmp_path / "nested" / "deep" / "path"
        css_file = nested_dir / "test.css"

        # Should create parent directories automatically
        _create_fallback_css(css_file)
        assert css_file.exists()
        assert nested_dir.exists()
        content = css_file.read_text()
        assert "Fallback CSS" in content

    def test_create_fallback_css_parent_dir_creation_failure(
        self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        """Test fallback CSS creation when parent directory creation fails."""
        nested_dir = tmp_path / "nested" / "deep" / "path"
        css_file = nested_dir / "test.css"

        # Mock Path.mkdir to raise OSError
        def mock_mkdir(*args: object, **kwargs: object) -> None:
            raise OSError("Mocked directory creation error")

        monkeypatch.setattr(Path, "mkdir", mock_mkdir)

        with pytest.raises(FileOperationError, match="Cannot create CSS file"):
            _create_fallback_css(css_file)

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

    def test_cli_validate_only_success(self, runner: CliRunner, tmp_path: Path) -> None:
        """Test validation-only mode with no violations."""
        input_file = tmp_path / "test.md"
        input_file.write_text("# Hello")

        with patch(
            "ats_pdf_generator.ats_converter.generate_markdown_report",
            return_value="REPORT",
        ) as mock_report:
            result = runner.invoke(cli, [str(input_file), "--validate-only"])

        assert result.exit_code == 0
        assert "Validation passed" in result.output
        assert "REPORT" in result.output
        mock_report.assert_called_once()

    def test_cli_validate_only_with_report_file(
        self, runner: CliRunner, tmp_path: Path
    ) -> None:
        """Test validation-only mode writing a report to disk."""
        input_file = tmp_path / "test.md"
        input_file.write_text("# Hello")
        report_target = tmp_path / "report.md"

        with patch(
            "ats_pdf_generator.ats_converter.generate_markdown_report",
            wraps=generate_markdown_report,
        ) as mock_report:
            result = runner.invoke(
                cli,
                [
                    str(input_file),
                    "--validate-only",
                    "--report",
                    str(report_target),
                ],
            )

        assert result.exit_code == 0
        assert report_target.exists()
        assert "Validation report saved" in result.output
        mock_report.assert_called_once()

    def test_cli_validate_only_requires_report_flag(
        self, runner: CliRunner, tmp_path: Path
    ) -> None:
        """Ensure --report cannot be used without --validate-only."""
        input_file = tmp_path / "test.md"
        input_file.write_text("# Hello")
        report_target = tmp_path / "report.md"

        result = runner.invoke(
            cli,
            [str(input_file), "--report", str(report_target)],
        )

        assert result.exit_code != 0
        assert "--report option requires --validate-only" in result.output

    def test_cli_validate_only_with_violations(
        self, runner: CliRunner, tmp_path: Path
    ) -> None:
        """Test validation-only mode with violations present."""
        input_file = tmp_path / "test.md"
        input_file.write_text("# Hello")
        violations = [
            Violation(
                line_number=1,
                line_content="Hello",
                message="Problem",
                severity=SeverityLevel.CRITICAL,
                suggestion="Fix",
            )
        ]

        with (
            patch(
                "ats_pdf_generator.ats_converter.validate_document",
                return_value=violations,
            ),
            patch(
                "ats_pdf_generator.ats_converter.generate_markdown_report",
                return_value="REPORT",
            ) as mock_report,
        ):
            result = runner.invoke(cli, [str(input_file), "--validate-only"])

        assert result.exit_code == 1
        assert "Validation failed" in result.output
        assert "REPORT" in result.output
        mock_report.assert_called_once_with(violations, input_file.name, None)

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
