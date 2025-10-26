# ATS Safety Verification Report

## Document: table_layout.md

**Verification Date:** 2025-10-26 13:45:42
**Overall Status:** WARNING

---

## Summary

- Critical Issues: 0
- High Severity Issues: 6
- Medium Severity Issues: 0
- Low Severity Issues: 1

---

## High Severity Issues (Should Fix)

### Table Usage at line 9

**Severity:** HIGH

**Found:** | Category | Technologies |

**Issue:** Table detected in document

**Suggestion:** Convert tables to lists or standard sections. ATS systems may not parse table structures correctly.

**Example:** | Category | Technologies |

### Table Usage at line 10

**Severity:** HIGH

**Found:** |----------|-------------|

**Issue:** Table detected in document

**Suggestion:** Convert tables to lists or standard sections. ATS systems may not parse table structures correctly.

**Example:** |----------|-------------|

### Table Usage at line 11

**Severity:** HIGH

**Found:** | Languages | Python, JavaScript, Go |

**Issue:** Table detected in document

**Suggestion:** Convert tables to lists or standard sections. ATS systems may not parse table structures correctly.

**Example:** | Languages | Python, JavaScript, Go |

### Table Usage at line 12

**Severity:** HIGH

**Found:** | Frameworks | Django, React, Vue |

**Issue:** Table detected in document

**Suggestion:** Convert tables to lists or standard sections. ATS systems may not parse table structures correctly.

**Example:** | Frameworks | Django, React, Vue |

### Table Usage at line 13

**Severity:** HIGH

**Found:** | Tools | Docker, Kubernetes, AWS |

**Issue:** Table detected in document

**Suggestion:** Convert tables to lists or standard sections. ATS systems may not parse table structures correctly.

**Example:** | Tools | Docker, Kubernetes, AWS |

### Non-Standard Date Format at line 16

**Severity:** HIGH

**Found:** 2020-2024

**Issue:** Non-standard date format detected: '2020-2024'

**Suggestion:** Use standard date formats like 'January 2020 - March 2024' or 'Jan 2020 - Mar 2024'.

**Example:** Software Engineer at TechCorp (2020-2024)

## Low Severity Issues (Optional)

### Non-Standard Section Header at line 3

**Severity:** LOW

**Found:** Contact Information

**Issue:** Non-standard section header: 'Contact Information'

**Suggestion:** Consider using a standard section name like 'Professional Experience' or 'Technical Skills'.

**Example:** ## Contact Information

---

## Recommendations

For best ATS compatibility:

- Use standard fonts (Arial, Calibri, Times New Roman)
- Avoid tables, columns, and complex layouts
- Use standard section headers
- Include relevant keywords naturally
- Use standard date formats (Month YYYY - Month YYYY)
- Avoid emojis, special characters, and creative formatting
