# ATS Safety Requirements Specification

**Version:** 1.0
**Purpose:** Define requirements for ATS-safe document verification in ats-pdf-generator

---

## Overview

This specification defines requirements for verifying that Markdown documents and generated PDFs are compatible with Applicant Tracking Systems (ATS). These requirements can be implemented as automated checks in the verification feature.

---

## 1. Character and Encoding Requirements

### 1.1 Emoji and Special Characters

**Requirement:** Documents MUST NOT contain emojis or decorative Unicode characters.

**Rationale:** Most ATS systems cannot parse emojis correctly, leading to corrupted or missing information.

**Check Implementation:**

- Scan for Unicode emoji ranges (U+1F300 to U+1F9FF, U+2600 to U+26FF, U+2700 to U+27BF)
- Scan for decorative Unicode blocks (dingbats, ornamental characters)
- Flag any non-standard Unicode characters outside basic Latin, Latin-1 Supplement, and common punctuation

**Examples of Violations:**

- ✅ ❌ ⭐ 🚀 📧 📱 🔗 (all emojis/symbols)
- → ← ↑ ↓ (arrow characters)
- ✓ ✗ (checkmarks and crosses)

**Exceptions:**

- Standard punctuation marks (periods, commas, hyphens, parentheses)
- Currency symbols ($, €, £) when referring to compensation
- Degree symbol (°) when referring to temperatures or angles
- Ampersands (&) in company names or technical terms

**Severity:** CRITICAL - Will likely cause parsing failures

---

### 1.2 Smart Quotes and Special Punctuation

**Requirement:** Documents SHOULD use standard ASCII punctuation, not smart quotes or special dashes.

**Rationale:** Some ATS systems misinterpret curly quotes and em/en dashes.

**Check Implementation:**

- Detect curly quotes (" " ' ') and suggest straight quotes (" ')
- Detect em dashes (—) and en dashes (–) and suggest hyphens (-)
- Detect ellipses (…) and suggest three periods (...)

**Examples of Violations:**

- "quoted text" → should be "quoted text"
- Company's → should be Company's
- 2020—2024 → should be 2020-2024

**Severity:** MEDIUM - May cause parsing issues in some systems

---

### 1.3 Text Encoding

**Requirement:** Documents MUST use UTF-8 encoding without BOM.

**Rationale:** UTF-8 is universally supported; BOM can cause parsing issues.

**Check Implementation:**

- Verify file encoding is UTF-8
- Check for presence of Byte Order Mark (BOM)
- Flag if encoding is UTF-16, Latin-1, or other non-UTF-8

**Severity:** MEDIUM - May cause entire document parsing failure

---

## 2. Contact Information Formatting

### 2.1 Contact Information Labels

**Requirement:** Contact information MUST use explicit text labels, not symbols.

**Rationale:** ATS systems parse contact info by recognizing labels like "Email:" or "Phone:"

**Check Implementation:**

- Detect contact patterns without labels (email address alone, phone number alone)
- Suggest adding labels: "Email:", "Phone:", "Location:", "LinkedIn:", "GitHub:"
- Flag if emojis are used instead of labels

**Examples:**

**Violations:**

```text
📧 user@example.com
(555) 123-4567
🔗 linkedin.com/in/user
```

**Correct:**

```text
Email: user@example.com
Phone: (555) 123-4567
LinkedIn: linkedin.com/in/user
```

**Severity:** HIGH - Contact information may not be extracted correctly

---

### 2.2 Phone Number Format

**Requirement:** Phone numbers SHOULD follow standard formats with explicit separators.

**Rationale:** ATS systems look for common phone number patterns.

**Check Implementation:**

- Detect phone numbers and validate format
- Suggest standard formats: (555) 123-4567 or 555-123-4567 or +1-555-123-4567
- Flag unusual formats like 555.123.4567 or 5551234567 (no separators)

**Accepted Formats:**

- (555) 123-4567
- 555-123-4567
- +1 (555) 123-4567
- +1-555-123-4567

**Severity:** MEDIUM - Phone number may not be extracted

---

### 2.3 Email Address Format

**Requirement:** Email addresses MUST be plain text without obfuscation.

**Rationale:** ATS systems expect standard email format.

**Check Implementation:**

- Detect email addresses
- Flag obfuscated emails (user [at] example [dot] com)
- Flag emails with unusual formatting or extra spaces

**Examples of Violations:**

- user [at] example [dot] com
- user @ example . com
- user AT example DOT com

**Correct:**

- <user@example.com>

**Severity:** HIGH - Email may not be extracted

---

### 2.4 URL Format

**Requirement:** URLs SHOULD be complete and properly formatted.

**Rationale:** ATS systems may not extract incomplete URLs correctly.

**Check Implementation:**

- Detect URLs
- Check if URLs include protocol (https:// or http://)
- Flag shortened URLs (bit.ly, tinyurl) as they may not be followed
- Suggest full URLs for LinkedIn, GitHub, portfolio sites

**Examples:**

**Acceptable but could be better:**

```text
linkedin.com/in/username
github.com/username
```

**Best practice:**

```text
https://linkedin.com/in/username
https://github.com/username
```

**Violations:**

```text
bit.ly/abc123
Click here: [link]
```

**Severity:** LOW - URLs may not be clickable but text usually extracted

---

## 3. Document Structure Requirements

### 3.1 Section Headers

**Requirement:** Section headers MUST use clear, standard naming conventions.

**Rationale:** ATS systems recognize standard section names to categorize content.

**Check Implementation:**

- Detect section headers (usually markdown ## or ###)
- Validate against standard section names
- Flag creative or non-standard section names

**Standard Section Names (in order):**

1. Contact Information (in header, no section needed)
2. Professional Summary OR Summary OR Objective
3. Skills OR Technical Skills OR Core Competencies
4. Professional Experience OR Work Experience OR Experience
5. Education
6. Certifications (optional)
7. Projects (optional, but recommended for developers)
8. Publications (optional)
9. Awards (optional)

**Non-Standard Names to Flag:**

- "About Me" (use "Professional Summary")
- "What I Do" (use "Professional Summary")
- "My Skills" (use "Technical Skills")
- "Where I've Worked" (use "Professional Experience")
- "Things I've Built" (use "Projects")

**Severity:** MEDIUM - Content may be miscategorized

---

### 3.2 Header Hierarchy

**Requirement:** Headers MUST follow logical hierarchy (H1 for name, H2 for sections, H3 for subsections).

**Rationale:** ATS systems use header hierarchy to understand document structure.

**Check Implementation:**

- Verify H1 (# in Markdown) is used only for name at top
- Verify H2 (##) is used for main sections
- Verify H3 (###) is used for subsections within sections
- Flag skipped header levels (H2 → H4 without H3)
- Flag multiple H1 headers

**Examples:**

**Correct:**

```markdown
# John Doe

## Professional Summary

## Professional Experience

### Senior Engineer | Company | 2020-2024

### Engineer | Company | 2018-2020
```

**Violations:**

```markdown
# John Doe
# Professional Summary  ← Multiple H1s
#### Experience  ← Skipped from H1 to H4
```

**Severity:** MEDIUM - Document structure may be misunderstood

---

### 3.3 Date Formats

**Requirement:** Dates MUST follow consistent, standard formats.

**Rationale:** ATS systems parse dates to calculate experience duration and verify employment.

**Check Implementation:**

- Detect date patterns in experience section
- Verify consistent format throughout document
- Flag non-standard formats

**Standard Formats (in order of preference):**

1. Month Year - Month Year (e.g., "January 2020 - March 2024")
2. Month Year - Present (for current roles)
3. MM/YYYY - MM/YYYY (e.g., "01/2020 - 03/2024")
4. YYYY - YYYY (for education, less detail)

**Acceptable Month Formats:**

- Full month name: "January", "February"
- Three-letter abbreviation: "Jan", "Feb"

**Formats to Flag:**

- Numeric dates without year: "01/15 - 03/20" (ambiguous)
- Relative dates: "2 years ago - 6 months ago"
- Casual formats: "Early 2020 - Mid 2024"
- Season-only: "Summer 2020 - Fall 2024"

**Examples:**

**Correct:**

```text
January 2020 - March 2024
Jan 2020 - Mar 2024
01/2020 - 03/2024
2020 - 2024 (for education only)
January 2020 - Present
```

**Violations:**

```text
2020-2024 (no month, ambiguous for employment)
01/15 - 03/20 (ambiguous - is this month/day or month/year?)
~2020 - ~2024 (approximations)
```

**Severity:** HIGH - Experience duration may be calculated incorrectly

---

## 4. Formatting and Layout Requirements

### 4.1 Tables

**Requirement:** Documents SHOULD NOT use tables for layout or content organization.

**Rationale:** Many ATS systems cannot parse table structures correctly.

**Check Implementation:**

- Detect Markdown tables (pipes and dashes)
- Detect HTML table tags if HTML is in source
- Suggest converting tables to lists or standard sections

**Exceptions:**

- Simple skill matrices MAY be acceptable if also provided in list format
- Side-by-side comparison tables MAY be acceptable for specific use cases

**Alternative Formatting:**

- Use lists instead of tables
- Use clear section headers and bullet points
- Use white space and formatting for visual organization (will be preserved in PDF)

**Severity:** HIGH - Content in tables may be lost or scrambled

---

### 4.2 Columns

**Requirement:** Documents MUST NOT use multi-column layouts.

**Rationale:** ATS systems read left-to-right, top-to-bottom; columns cause reading order issues.

**Check Implementation:**

- This is primarily a PDF generation concern, not Markdown
- Flag if Markdown contains HTML/CSS attempting columns
- Ensure PDF generation uses single-column layout

**Severity:** CRITICAL - Reading order will be scrambled

---

### 4.3 Text Boxes and Sidebars

**Requirement:** Documents MUST NOT use text boxes, sidebars, or floating elements.

**Rationale:** ATS systems may skip or misplace content in text boxes.

**Check Implementation:**

- Flag HTML/CSS attempting to create floating elements
- Ensure PDF generation does not use text boxes

**Severity:** HIGH - Content may be lost entirely

---

### 4.4 Images and Graphics

**Requirement:** Critical information MUST NOT be embedded in images.

**Rationale:** ATS systems cannot read text in images.

**Check Implementation:**

- Detect image references in Markdown
- Warn if images appear near critical sections (contact info, experience)
- Suggest text alternatives for any content in images

**Exceptions:**

- Company logos (optional, decorative)
- Portfolio work samples (if also described in text)

**Severity:** CRITICAL - Information in images will not be extracted

---

### 4.5 Headers and Footers

**Requirement:** Critical information SHOULD NOT be in headers/footers.

**Rationale:** Some ATS systems ignore headers and footers.

**Check Implementation:**

- This is a PDF generation concern
- Ensure contact info is in document body, not PDF header
- Page numbers in footers are acceptable

**Severity:** HIGH - Information may be ignored

---

## 5. Content Formatting Requirements

### 5.1 Bullet Points

**Requirement:** Bullet points SHOULD use standard characters.

**Rationale:** ATS systems recognize standard bullets but may misinterpret decorative ones.

**Check Implementation:**

- Detect bullet point characters
- Accept: hyphen (-), asterisk (*), standard bullet (•)
- Flag: checkmarks (✓), arrows (→), custom symbols (▪ ◆ ■)

**Standard Markdown Bullets:**

```markdown
- Standard bullet
* Also standard
+ Also acceptable
```

**PDF Rendering:**

- Simple bullets (•) or hyphens (-) in PDF are safest

**Severity:** LOW - Content usually extracted, formatting may be lost

---

### 5.2 Bold and Italic

**Requirement:** Bold and italic MAY be used for emphasis but should not carry critical information.

**Rationale:** Formatting may be lost in ATS extraction; content should be understandable without it.

**Check Implementation:**

- This is informational only - no flags needed
- Verify content makes sense if all formatting removed

**Severity:** LOW - Formatting preference only

---

### 5.3 Underlines and Strikethrough

**Requirement:** Documents SHOULD NOT use underlines (except for links) or strikethrough.

**Rationale:** These can be confused with other formatting or removed entirely.

**Check Implementation:**

- Detect markdown strikethrough (~~text~~)
- Detect HTML underline tags (<u>)
- Suggest removing or using bold instead

**Severity:** LOW - Usually cosmetic issue only

---

### 5.4 ALL CAPS

**Requirement:** Documents SHOULD use standard capitalization, not ALL CAPS for emphasis.

**Rationale:** ALL CAPS is harder to read and may trigger spam filters in some systems.

**Check Implementation:**

- Detect words or phrases in ALL CAPS (excluding acronyms)
- Flag if entire section headers or sentences are ALL CAPS
- Suggest Title Case for headers

**Exceptions:**

- Acronyms (AWS, CEO, API)
- Abbreviations (MBA, PhD, USA)
- State codes (MA, CA, NY)

**Examples:**

**Violations:**

```text
PROFESSIONAL EXPERIENCE
SENIOR ENGINEER AT COMPANY (entire title in caps)
I REDUCED BUILD TIME BY 50% (sentence in caps)
```

**Correct:**

```text
Professional Experience
Senior Engineer at Company
Reduced build time by 50%
AWS, API, REST (acronyms are fine)
```

**Severity:** MEDIUM - Reduces readability, may affect keyword extraction

---

### 5.5 Line Breaks and Spacing

**Requirement:** Use single line breaks between paragraphs; avoid excessive white space.

**Rationale:** ATS systems may interpret excessive spacing as section boundaries.

**Check Implementation:**

- Detect multiple consecutive blank lines (more than 2)
- Suggest using single blank lines for paragraph separation
- Flag manual spacing attempts (multiple spaces, tabs)

**Severity:** LOW - Usually cosmetic, rarely affects parsing

---

## 6. File and Font Requirements

### 6.1 Font Selection

**Requirement:** PDFs MUST use standard, universally available fonts.

**Rationale:** ATS systems rely on font embedding or standard fonts for text extraction.

**Check Implementation:**

- This is a PDF generation setting
- Use only: Arial, Calibri, Georgia, Times New Roman, Helvetica, Verdana
- Default: Arial or Calibri for modern, clean look
- Avoid: Decorative fonts, handwriting fonts, script fonts

**Severity:** HIGH - Non-standard fonts may prevent text extraction

---

### 6.2 Font Size

**Requirement:** Body text SHOULD be 10-12pt; headers MAY be larger.

**Rationale:** Too small or too large text can indicate formatting issues to ATS.

**Check Implementation:**

- Verify font sizes in PDF generation settings
- Body text: 10-12pt
- Section headers: 14-16pt
- Name/title: 16-20pt

**Severity:** LOW - Affects readability more than parsing

---

### 6.3 PDF Properties

**Requirement:** PDFs SHOULD have proper metadata and be text-based (not scanned images).

**Rationale:** Metadata helps ATS categorize documents; scanned PDFs cannot be parsed.

**Check Implementation:**

- Verify PDF is text-based (not image-based)
- Set PDF title metadata to candidate name
- Set PDF author metadata if applicable
- Ensure PDF is not password-protected

**Severity:** CRITICAL - Image-based PDFs will fail completely

---

## 7. Keywords and Content Requirements

### 7.1 Keyword Stuffing

**Requirement:** Documents MUST NOT use hidden text or keyword stuffing.

**Rationale:** ATS systems detect and penalize keyword stuffing; may flag resume as spam.

**Check Implementation:**

- Detect white text on white background (HTML/CSS)
- Detect unusually high keyword density (same word repeated excessively)
- Detect lists of skills without context

**Examples of Violations:**

```text
<!-- Hidden text attempts -->
<span style="color: white;">Java Python JavaScript</span>

<!-- Keyword stuffing -->
Java expert, Java developer, Java programming, Java specialist,
Java architect, Java engineer, Java professional (all in a row)
```

**Severity:** CRITICAL - May be flagged as spam and auto-rejected

---

### 7.2 Relevant Keywords

**Requirement:** Documents SHOULD include relevant keywords from job descriptions naturally.

**Rationale:** ATS systems match keywords to job requirements.

**Check Implementation:**

- This is advisory/educational, not a strict check
- Suggest including job-relevant technologies, tools, methodologies
- Suggest using exact phrases from job descriptions when applicable
- Keywords should appear in context, not in isolation

**Best Practices:**

- Include technology names: specific languages, frameworks, tools
- Include methodologies: Agile, Scrum, CI/CD, DevOps
- Include measurable achievements: percentages, time savings, scale
- Use industry-standard terminology

**Severity:** N/A - Advisory for effectiveness

---

### 7.3 Consistent Terminology

**Requirement:** Documents SHOULD use consistent terminology throughout.

**Rationale:** Helps ATS systems recognize skills and reduces confusion.

**Check Implementation:**

- Detect variations of same term and suggest consistency
- Example: "JavaScript" vs "Javascript" vs "JS"
- Example: "CI/CD" vs "Continuous Integration/Continuous Deployment"

**Best Practice:**

- First mention: Full term "Continuous Integration/Continuous Deployment (CI/CD)"
- Subsequent mentions: Abbreviation "CI/CD"

**Severity:** LOW - Minor impact on keyword matching

---

## 8. Common ATS Failure Patterns

### 8.1 Creative Job Titles

**Requirement:** Job titles SHOULD use industry-standard terminology.

**Rationale:** ATS systems match job titles to seniority levels and roles.

**Check Implementation:**

- Detect unusual or creative job titles
- Suggest standard equivalents

**Examples:**

**Creative Titles (Flag):**

- Code Ninja → Software Engineer
- Data Wizard → Data Analyst
- Growth Hacker → Marketing Manager
- Rockstar Developer → Senior Software Engineer

**Standard Titles (Accepted):**

- Software Engineer, Senior Software Engineer, Staff Engineer
- Engineering Manager, Director of Engineering
- Data Scientist, Data Analyst, Data Engineer
- Product Manager, Senior Product Manager

**Severity:** MEDIUM - May affect role categorization

---

### 8.2 Pronouns and First Person

**Requirement:** Resumes SHOULD use third-person implied or avoid pronouns.

**Rationale:** Professional standard; some ATS may not handle first-person well.

**Check Implementation:**

- Detect first-person pronouns (I, me, my, we, us, our)
- Suggest removing or rephrasing

**Examples:**

**With Pronouns (Flag):**

- "I led a team of 10 engineers"
- "My responsibilities included..."
- "We built a platform that..."

**Without Pronouns (Correct):**

- "Led team of 10 engineers"
- "Responsibilities included..."
- "Built platform that..."

**Exceptions:**

- Cover letters (first person is expected)
- "About Me" sections (if used, though not recommended)

**Severity:** LOW - Style issue, minor impact on parsing

---

### 8.3 Abbreviations Without Context

**Requirement:** Abbreviations SHOULD be defined on first use.

**Rationale:** ATS systems may not recognize all abbreviations; defining helps keyword matching.

**Check Implementation:**

- Detect common abbreviations
- Verify they appear in full form at least once
- Suggest spelling out on first mention

**Examples:**

**Best Practice:**

```text
Continuous Integration/Continuous Deployment (CI/CD)
Application Programming Interface (API)
Software Development Life Cycle (SDLC)
```

**After First Mention:**

```text
Implemented CI/CD pipeline...
Designed REST API...
Improved SDLC processes...
```

**Exceptions:**

- Extremely common terms: AWS, API, HTML, CSS
- Company names: IBM, SAP
- Degrees: MBA, PhD, BS, BA

**Severity:** LOW - Improves keyword matching

---

## 9. Verification Report Structure

### 9.1 Report Format

**Requirement:** Verification reports SHOULD provide actionable feedback.

**Suggested Report Structure:**

```markdown
# ATS Safety Verification Report

## Document: [filename]
**Verification Date:** [timestamp]
**Overall Status:** PASS | FAIL | WARNING

---

## Summary
- Critical Issues: [count]
- High Severity Issues: [count]
- Medium Severity Issues: [count]
- Low Severity Issues: [count]

---

## Critical Issues (Must Fix)
[List issues with line numbers and suggestions]

## High Severity Issues (Should Fix)
[List issues with line numbers and suggestions]

## Medium Severity Issues (Consider Fixing)
[List issues with line numbers and suggestions]

## Low Severity Issues (Optional)
[List issues with line numbers and suggestions]

---

## Recommendations
[General advice for improving ATS compatibility]
```

---

### 9.2 Issue Detail Format

**Each issue should include:**

```markdown
### [Issue Type] at line [line number]

**Severity:** CRITICAL | HIGH | MEDIUM | LOW

**Found:** [exact text or pattern found]

**Issue:** [explanation of what's wrong]

**Suggestion:** [how to fix it]

**Example:**
[corrected version if applicable]
```

---

### 9.3 Pass Criteria

**Document passes ATS verification if:**

- Zero critical issues
- Zero high severity issues
- Or: All critical and high issues have manual overrides/exceptions

**Document passes with warnings if:**

- Zero critical issues
- One or more high severity issues (with recommendations to fix)
- Multiple medium/low severity issues

**Document fails if:**

- One or more critical issues
- Multiple high severity issues affecting core content

---

## 10. Implementation Priority

### Phase 1: Critical Checks (MVP)

1. Emoji detection
2. Contact information formatting
3. Table detection
4. Multi-column detection
5. Image in critical sections

### Phase 2: High Priority Checks

1. Date format validation
2. Font selection verification
3. Section header validation
4. Phone number format
5. Email format

### Phase 3: Medium Priority Checks

1. Smart quotes detection
2. ALL CAPS detection
3. Bullet point style
4. Creative job titles
5. Keyword stuffing detection

### Phase 4: Low Priority / Enhancement

1. Consistent terminology
2. Abbreviation definitions
3. Pronoun usage
4. Line spacing checks
5. Keyword optimization suggestions

---

## 11. Testing and Validation

### 11.1 Test Cases

**Create test documents with known violations:**

- Document with emojis in contact section
- Document with tables
- Document with non-standard dates
- Document with creative job titles
- Document with ALL CAPS sections
- Document with keyword stuffing
- Document with hidden text

**Verify that:**

- Each violation is detected
- Severity is correctly assigned
- Suggestions are actionable
- False positives are minimized

---

### 11.2 False Positive Management

**Common False Positives to Handle:**

- Acronyms detected as ALL CAPS violations
- Legitimate use of symbols in technical contexts (→ in diagrams)
- Company names that include special characters
- Technical terms that include numbers or special chars (C++, .NET)

**Strategy:**

- Maintain allowlist of common acronyms
- Provide override mechanisms
- Make low-severity items informational only

---

## Appendix A: Standard Section Names Reference

| ATS-Friendly Section Names | Alternative Names (Also Recognized) |
|---------------------------|-------------------------------------|
| Professional Summary | Summary, Career Summary, Profile |
| Professional Experience | Work Experience, Experience, Employment History |
| Technical Skills | Skills, Core Competencies, Technical Proficiencies |
| Education | Academic Background, Educational Qualifications |
| Certifications | Licenses and Certifications, Professional Certifications |
| Projects | Key Projects, Portfolio, Technical Projects |
| Publications | Research, Papers, Articles |
| Awards | Honors, Recognition, Achievements |

---

## Appendix B: Font Recommendations

### Highly Compatible Fonts (Use These)

- **Arial** - Modern, clean, universally compatible
- **Calibri** - Modern, professional, highly readable
- **Georgia** - Serif option, professional
- **Times New Roman** - Traditional, always compatible
- **Helvetica** - Clean, professional
- **Verdana** - Designed for screen reading

### Fonts to Avoid

- Comic Sans (unprofessional)
- Papyrus (unprofessional)
- Script fonts (hard to parse)
- Decorative fonts (may not embed correctly)
- Custom/downloaded fonts (may not be available to ATS)

---

## Version History

### Version 1.0 (October 2025)

- Initial specification
- Covers all major ATS compatibility requirements
- Designed for implementation in ats-pdf-generator tool

---

## References and Resources

- **SHRM ATS Best Practices** - Society for Human Resource Management guidelines
- **Indeed Resume Best Practices** - Common ATS patterns
- **Jobscan ATS Research** - ATS compatibility studies
- **PDF/A Standards** - ISO standards for archival PDFs
- **WCAG Accessibility Guidelines** - Many ATS requirements overlap with accessibility

---

*This specification is designed to be implemented programmatically for automated ATS safety verification in resume generation tools.*
