# Troop 500G Build and Test System

## Overview

The Troop 500G website build and test system has been updated to provide comprehensive testing with consolidated issue reporting. The system uses multiple specialized test scripts and generates a consolidated issues report in Markdown format suitable for LLM review and correction.

## Main Build Script

### `build_and_test_optimized.ps1`

This is the primary build script that orchestrates the entire build and test process.

**Usage:**
```powershell
.\build_and_test_optimized.ps1 [OPTIONS]
```

**Options:**
- `-NoCache` - Force rebuild all containers without cache (slower but clean)
- `-SkipPDFs` - Skip PDF generation (faster for web-only changes)
- `-SkipTests` - Skip all testing (faster for build-only runs)
- `-Quick` - Skip both PDFs and tests (fastest option)
- `-IssuesFile` - Path for consolidated issues report (default: test-issues-summary.md)
- `-Help` - Show help message

**Examples:**
```powershell
# Full build with testing and issue reporting
.\build_and_test_optimized.ps1

# Fast web-only build (skip PDFs and tests)
.\build_and_test_optimized.ps1 -Quick

# Clean rebuild with no cache
.\build_and_test_optimized.ps1 -NoCache

# Web build with tests but no PDF generation
.\build_and_test_optimized.ps1 -SkipPDFs

# Custom issues report location
.\build_and_test_optimized.ps1 -IssuesFile "build-issues.md"
```

## Test Scripts

All test scripts are located in the `scripts/test/` directory and can be run independently or as part of the main build process.

### `test-self-urls.ps1`
Tests internal website endpoints and pages.

**Features:**
- Tests core pages (homepage, handbook, about, events, etc.)
- Validates HTTP response codes
- Reports issues for broken internal links

### `test-external-links.ps1`
Validates external links found on website pages.

**Features:**
- Scans multiple pages for external links
- Host exclusion for local/internal links
- Concurrent testing with rate limiting
- Detailed failure reporting with page context

**Usage:**
```powershell
# Test with default settings
.\test-external-links.ps1

# Test specific pages with details
.\test-external-links.ps1 -Pages @("/", "/handbook") -ShowDetails

# Test with higher concurrency
.\test-external-links.ps1 -MaxConcurrency 10
```

### `test-pdf-links.ps1`
Extracts and validates links from generated PDF files.

**Features:**
- Tests links within handbook and appendix PDFs
- Supports latest and archived PDF files
- Requires PDF tools (pdftotext, pdfgrep)

### `test-appendix-pdfs.ps1`
Validates appendix PDF file generation and integrity.

**Features:**
- Checks for PDF file existence and validity
- Validates PDF headers and file sizes
- Tests PDF accessibility

### `test-linux-compatibility.ps1`
Tests cross-platform compatibility for Linux systems.

**Features:**
- Platform detection tests
- Path handling validation
- PowerShell Core compatibility checks

## Consolidated Issue Reporting

### Issue Report Format

The build system generates a consolidated issues report in Markdown format that includes:

1. **Summary by Category** - Overview of issues grouped by type
2. **Detailed Issue Report** - Full details for each issue with context
3. **LLM Analysis Instructions** - Guidance for automated review and correction

### Issue Categories

- **Build Process** - Container builds, Jekyll startup, dependencies
- **Internal Links** - Broken internal page links and resources
- **External Links** - Unreachable external websites and resources
- **PDF Links** - Missing or broken PDF files and internal PDF links
- **Content** - Missing or outdated content references
- **Cross-Platform** - Linux/macOS compatibility issues

### Issue Severity Levels

- **Critical** - Prevents site from building or functioning
- **High** - Affects core site functionality
- **Medium** - Impacts user experience
- **Low** - Minor issues or optimizations

### Sample Issue Report Structure

```markdown
# Troop 500G Website Build and Test Issues Report

**Generated:** 2025-01-08 15:30:45
**Total Issues Found:** 3

## Summary by Category

### External Links (2 issues)
- **Medium:** 2 issues

### PDF Links (1 issues)
- **Low:** 1 issues

## Critical Priority Issues (0)

## High Priority Issues (0)

## Medium Priority Issues (2)

### External Links: External link failed: https://example.com/broken-link

**Severity:** Medium
**Timestamp:** 2025-01-08 15:30:42
**Location:** http://localhost:4000/handbook

**Details:**
Error: The remote name could not be resolved: 'example.com'

**Suggested Resolution:**
Verify the external link is correct and the target website is accessible

---

## Low Priority Issues (1)

### PDF Links: PDF links validation found issues

**Severity:** Low
**Timestamp:** 2025-01-08 15:30:44

**Details:**
Some links within PDF files may be broken

**Suggested Resolution:**
Review PDF content and update broken links

---
```

## Using the System

### For Regular Development

```powershell
# Quick build for content changes (fastest)
.\build_and_test_optimized.ps1 -Quick

# Full build with testing (recommended)
.\build_and_test_optimized.ps1
```

### For Production Deployment

```powershell
# Clean build with full testing
.\build_and_test_optimized.ps1 -NoCache
```

### For Troubleshooting

```powershell
# Build with testing but skip PDFs to isolate issues
.\build_and_test_optimized.ps1 -SkipPDFs

# Review the generated issues report
Get-Content test-issues-summary.md
```

## Integration with CI/CD

The build system is designed to work well with continuous integration:

1. **Exit Codes** - Scripts return appropriate exit codes for CI/CD pipelines
2. **Issue Reports** - Automated issue reports can be archived or sent for review
3. **Modular Testing** - Individual test scripts can be run in parallel
4. **Cross-Platform** - Works on Windows, Linux, and macOS with PowerShell Core

## Extending the System

### Adding New Test Scripts

1. Create a new script in `scripts/test/`
2. Include the standard `Add-Issue` function for consolidated reporting
3. Add the script to the main build script imports
4. Update this documentation

### Adding New Issue Categories

Update the `Add-Issue` function calls to use new category names and update the issue report generation logic as needed.

### Customizing Issue Reporting

Modify the `Write-IssuesReport` function in `build_and_test_optimized.ps1` to change the report format or add additional analysis.
