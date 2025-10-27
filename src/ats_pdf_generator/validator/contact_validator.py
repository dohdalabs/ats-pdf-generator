"""
Contact Information Validator

Validates contact information formatting for ATS compatibility.
Implements Issue 8: Contact Information Formatting Validation.
"""

# Standard library
import re

# First-party
from ..validation_types import SeverityLevel, Violation


class ContactValidator:
    """Validates contact information formatting for ATS compatibility."""

    def __init__(self) -> None:
        """Initialize the ContactValidator with pre-compiled regex patterns."""
        # Email patterns
        self.EMAIL_PATTERN = re.compile(
            r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b"
        )
        self.OBFUSCATED_EMAIL_PATTERN = re.compile(
            r"\[at\]|\[dot\]|\(at\)|\(dot\)| AT | DOT ", re.IGNORECASE
        )

        # Phone patterns
        self.PHONE_PATTERN = re.compile(
            r"(\+\d{1,3}[-.\s]?)?(\(?\d{3}\)?[-.\s]?)?\d{3}[-.\s]?\d{4}"
        )

        # URL patterns
        self.URL_PATTERN = re.compile(r"\bhttps?://\S+\b", re.IGNORECASE)
        self.BARE_URL_PATTERN = re.compile(
            r"\b(?!(?:https?://|www\.))\w+\.\w+/\S+\b", re.IGNORECASE
        )

        # Contact label patterns
        self.CONTACT_LABELS = {
            "email": ["email:", "e-mail:", "mail:"],
            "phone": ["phone:", "tel:", "telephone:", "mobile:", "cell:"],
            "linkedin": ["linkedin:", "linked-in:"],
            "github": ["github:", "git-hub:"],
            "location": ["location:", "address:", "city:", "where:"],
            "website": ["website:", "web:", "portfolio:", "site:"],
        }

        # Emoji pattern for label validation
        self.EMOJI_PATTERN = re.compile(
            "["
            "\U0001f1e0-\U0001f1ff"  # flags
            "\U0001f300-\U0001f5ff"  # symbols & pictographs
            "\U0001f600-\U0001f64f"  # emoticons
            "\U0001f680-\U0001f6ff"  # transport & map symbols
            "\U00002700-\U000027bf"  # Dingbats
            "\u200d"  # ZWJ
            "\ufe0f"  # VS16
            "\U0001f3fb-\U0001f3ff"  # skin tone modifiers
            "]+"
        )

    def validate(self, content: str, line_number: int) -> list[Violation]:
        """
        Validate contact information formatting in the given content.

        Args:
            content: The line content to validate (may be multi-line)
            line_number: The starting line number for violation reporting

        Returns:
            List of violations found in the content
        """
        violations: list[Violation] = []

        # Handle multi-line content by splitting into individual lines
        lines = content.split("\n")
        current_line = line_number

        for line in lines:
            if line.strip():  # Only process non-empty lines
                violations.extend(self._validate_email_formatting(line, current_line))
                violations.extend(self._validate_phone_formatting(line, current_line))
                violations.extend(self._validate_url_formatting(line, current_line))
                violations.extend(self._validate_contact_labels(line, current_line))
            current_line += 1

        return violations

    def _validate_email_formatting(
        self, content: str, line_number: int
    ) -> list[Violation]:
        """Validate email formatting and detect obfuscation."""
        violations: list[Violation] = []

        # Check for obfuscated emails
        if self.OBFUSCATED_EMAIL_PATTERN.search(content):
            violations.append(
                Violation(
                    line_number=line_number,
                    line_content=content.strip(),
                    message="Obfuscated email address detected",
                    severity=SeverityLevel.HIGH,
                    suggestion="Use standard email format: user@example.com",
                )
            )
            return violations  # Don't check other email patterns if obfuscated

        # Check for emails without labels
        if self.EMAIL_PATTERN.search(content):
            has_label = any(
                label in content.lower() for label in self.CONTACT_LABELS["email"]
            )

            if not has_label:
                violations.append(
                    Violation(
                        line_number=line_number,
                        line_content=content.strip(),
                        message="Email address without proper label",
                        severity=SeverityLevel.HIGH,
                        suggestion="Add 'Email:' label before the address",
                    )
                )

        return violations

    def _validate_phone_formatting(
        self, content: str, line_number: int
    ) -> list[Violation]:
        """Validate phone number formatting."""
        violations: list[Violation] = []

        if self.PHONE_PATTERN.search(content):
            phone_match = self.PHONE_PATTERN.search(content)
            if phone_match:
                phone = phone_match.group(0)

                # Check if phone has proper label
                has_label = any(
                    any(label in content.lower() for label in labels)
                    for label, labels in self.CONTACT_LABELS.items()
                    if "phone" in label
                )

                if not has_label:
                    violations.append(
                        Violation(
                            line_number=line_number,
                            line_content=content.strip(),
                            message="Phone number without proper label",
                            severity=SeverityLevel.HIGH,
                            suggestion="Add 'Phone:' label before the number",
                        )
                    )
                else:
                    # Check for non-standard formats even with proper labels
                    # Check for formats without separators (no dashes, spaces, or parentheses)
                    cleaned_phone = (
                        phone.replace("-", "")
                        .replace(" ", "")
                        .replace(".", "")
                        .replace("(", "")
                        .replace(")", "")
                    )
                    if re.match(r"\d{10,}", cleaned_phone) and not any(
                        sep in phone for sep in ["-", " ", "(", ")"]
                    ):
                        violations.append(
                            Violation(
                                line_number=line_number,
                                line_content=content.strip(),
                                message="Phone number should use standard format",
                                severity=SeverityLevel.HIGH,
                                suggestion="Use format: (555) 123-4567 or 555-123-4567",
                            )
                        )

        return violations

    def _validate_url_formatting(
        self, content: str, line_number: int
    ) -> list[Violation]:
        """Validate URL formatting and protocol usage."""
        violations: list[Violation] = []

        # Check for URLs with protocol
        if self.URL_PATTERN.search(content):
            # URLs with https:// or http:// should pass validation
            return violations  # No violations for properly formatted URLs

        # Check for URLs without protocol (bare URLs)
        if self.BARE_URL_PATTERN.search(content):
            # Only consider URL-specific labels, not all contact labels
            url_labels = []
            for key in ["linkedin", "github", "website"]:
                url_labels.extend(self.CONTACT_LABELS.get(key, []))

            has_label = any(label in content.lower() for label in url_labels)

            if not has_label:
                violations.append(
                    Violation(
                        line_number=line_number,
                        line_content=content.strip(),
                        message="URL without proper label",
                        severity=SeverityLevel.HIGH,
                        suggestion="Add appropriate label (LinkedIn:, GitHub:, Website:)",
                    )
                )
            else:
                violations.append(
                    Violation(
                        line_number=line_number,
                        line_content=content.strip(),
                        message="URL should include https:// protocol",
                        severity=SeverityLevel.HIGH,
                        suggestion="Add https:// to the beginning of the URL",
                    )
                )

        return violations

    def _validate_contact_labels(
        self, content: str, line_number: int
    ) -> list[Violation]:
        """Validate that contact information uses proper text labels instead of emojis."""
        violations: list[Violation] = []

        # Check for emoji characters that might be used as labels
        emoji_pattern = self.EMOJI_PATTERN

        if emoji_pattern.search(content):
            # Check if it's likely being used as a contact label
            # Look for emojis at the beginning of the line followed by space and then contact info
            stripped = content.strip()
            # Only flag if emoji is at the very beginning and followed by contact info
            # Check for both space-separated and immediately followed patterns
            if (
                stripped
                and emoji_pattern.match(stripped[:1])
                and len(stripped) > 1
                and (
                    stripped[1] == " "
                    or any(
                        indicator in stripped[1:].lower()
                        for indicator in ["@", "com", "org", "net", "phone", "email"]
                    )
                )
                and any(
                    indicator in stripped[1:].lower()
                    for indicator in ["@", "com", "org", "net", "phone", "email"]
                )
            ):
                violations.append(
                    Violation(
                        line_number=line_number,
                        line_content=content.strip(),
                        message="Emoji used instead of text label",
                        severity=SeverityLevel.HIGH,
                        suggestion="Use text labels like 'Email:', 'Phone:', 'LinkedIn:'",
                    )
                )

        return violations
