#!/usr/bin/env pwsh
#
# Troop 500G Appendix PDF Test Script
# ===================================
# 
# This script specifically tests the generation and validation of appendix PDFs.
# It can be run independently or as part of the full build process.
#

param(
    [switch]$Verbose,
    [switch]$Help
)

if ($Help) {
    Write-Host @"
Troop 500G Appendix PDF Test Script

USAGE:
    .\test-appendix-pdfs.ps1 [OPTIONS]

OPTIONS:
    -Verbose     Show detailed test output and debug information
    -Help        Show this help message

DESCRIPTION:
    This script tests the appendix PDF generation system by:
    1. Verifying all appendix markdown files are processed
    2. Checking that timestamped PDFs are generated
    3. Ensuring latest PDFs are created and current
    4. Validating PDF content (headers, formatting, required elements)
    5. Testing web accessibility of PDFs
    6. Verifying proper LaTeX template usage (unnumbered sections)

EXAMPLES:
    .\test-appendix-pdfs.ps1                    # Run all tests
    .\test-appendix-pdfs.ps1 -Verbose           # Run with detailed output
"@
    exit 0
}

Write-Host @"
Troop 500G Appendix PDF Test Suite
==================================
Testing appendix PDF generation and validation...

"@ -ForegroundColor Cyan

# Function to write verbose output
function Write-Verbose-Custom {
    param($message)
    if ($Verbose) {
        Write-Host "VERBOSE: $message" -ForegroundColor Gray
    }
}

# Function to test URL endpoints
function Test-Url {
    param($url, $description)
    try {
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 5
        if ($response.StatusCode -eq 200) {
            Write-Host "[PASS] $description" -ForegroundColor Green
            return $true
        } else {
            Write-Host "[FAIL] $description (Status: $($response.StatusCode))" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "[FAIL] $description (Error: $($_.Exception.Message))" -ForegroundColor Red
        return $false
    }
}

# Test counter
$totalTests = 0
$passedTests = 0
$failedTests = 0

function Record-TestResult {
    param($passed, $testName)
    $script:totalTests++
    if ($passed) {
        $script:passedTests++
        Write-Host "[PASS] $testName" -ForegroundColor Green
    } else {
        $script:failedTests++
        Write-Host "[FAIL] $testName" -ForegroundColor Red
    }
}

# Test 1: Verify appendix directory structure
Write-Host "`nTest 1: Directory Structure" -ForegroundColor Yellow
Write-Host "=========================" -ForegroundColor Yellow

$appendixMdDir = "_includes/content/appendix"
$appendixPdfDir = "assets/files/handbook/appendix"

Record-TestResult (Test-Path $appendixMdDir) "Appendix markdown directory exists"
Record-TestResult (Test-Path $appendixPdfDir) "Appendix PDF output directory exists"
Record-TestResult (Test-Path "$appendixPdfDir/archive") "Appendix PDF archive directory exists"

# Test 2: Find and validate appendix markdown files
Write-Host "`nTest 2: Appendix Markdown Files" -ForegroundColor Yellow
Write-Host "===============================" -ForegroundColor Yellow

$appendixMdFiles = Get-ChildItem "$appendixMdDir/*.md" -ErrorAction SilentlyContinue
if ($appendixMdFiles.Count -eq 0) {
    Record-TestResult $false "Found appendix markdown files"
    Write-Host "ERROR: No appendix markdown files found in $appendixMdDir" -ForegroundColor Red
    exit 1
} else {
    Record-TestResult $true "Found $($appendixMdFiles.Count) appendix markdown file(s)"
    foreach ($file in $appendixMdFiles) {
        Write-Verbose-Custom "Found: $($file.Name)"
    }
}

# Test 3: PDF Generation Validation
Write-Host "`nTest 3: PDF Generation" -ForegroundColor Yellow
Write-Host "======================" -ForegroundColor Yellow

foreach ($mdFile in $appendixMdFiles) {
    $baseName = $mdFile.BaseName
    Write-Host "`nTesting appendix: $baseName" -ForegroundColor Cyan
    
    # Test 3a: Timestamped PDF exists
    $timestampedPdfs = Get-ChildItem "$appendixPdfDir/$baseName-????????_??????.pdf" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
    if ($timestampedPdfs.Count -gt 0) {
        $newestPdf = $timestampedPdfs[0]
        Record-TestResult $true "Timestamped PDF exists ($($newestPdf.Name))"
        Write-Verbose-Custom "PDF size: $([Math]::Round($newestPdf.Length / 1024, 1)) KB"
        Write-Verbose-Custom "Last modified: $($newestPdf.LastWriteTime)"
    } else {
        Record-TestResult $false "Timestamped PDF exists for $baseName"
        continue
    }
    
    # Test 3b: Latest PDF exists
    $latestPdf = "$appendixPdfDir/$baseName-latest.pdf"
    if (Test-Path $latestPdf) {
        Record-TestResult $true "Latest PDF exists ($baseName-latest.pdf)"
        $latestInfo = Get-Item $latestPdf
        Write-Verbose-Custom "Latest PDF size: $([Math]::Round($latestInfo.Length / 1024, 1)) KB"
        
        # Test 3c: Latest PDF is reasonably current
        $timeDiff = (Get-Date) - $latestInfo.LastWriteTime
        if ($timeDiff.TotalHours -lt 2) {
            Record-TestResult $true "Latest PDF is current (modified $([Math]::Round($timeDiff.TotalMinutes, 1)) minutes ago)"
        } else {
            Record-TestResult $false "Latest PDF currency (modified $([Math]::Round($timeDiff.TotalHours, 1)) hours ago)"
        }
    } else {
        Record-TestResult $false "Latest PDF exists for $baseName"
        continue
    }
    
    # Test 3d: PDF has reasonable file size (not empty or too small)
    if ($latestInfo.Length -gt 5000) {  # At least 5KB
        Record-TestResult $true "PDF has reasonable size ($([Math]::Round($latestInfo.Length / 1024, 1)) KB)"
    } else {
        Record-TestResult $false "PDF size validation ($([Math]::Round($latestInfo.Length / 1024, 1)) KB is too small)"
    }
}

# Test 4: PDF Content Validation
Write-Host "`nTest 4: PDF Content Validation" -ForegroundColor Yellow
Write-Host "===============================" -ForegroundColor Yellow

# Check if pdftotext is available
$pdfTextAvailable = $false
try {
    $null = & pdftotext -v 2>$null
    $pdfTextAvailable = $true
    Write-Verbose-Custom "pdftotext utility is available for content validation"
} catch {
    Write-Host "[WARN] pdftotext not available, skipping content validation tests" -ForegroundColor Yellow
}

if ($pdfTextAvailable) {
    foreach ($mdFile in $appendixMdFiles) {
        $baseName = $mdFile.BaseName
        $latestPdf = "$appendixPdfDir/$baseName-latest.pdf"
        
        if (-not (Test-Path $latestPdf)) { continue }
        
        Write-Host "`nValidating content for: $baseName" -ForegroundColor Cyan
        
        try {
            $tempTextFile = "$env:TEMP\test_$baseName.txt"
            & pdftotext $latestPdf $tempTextFile 2>$null
            
            if (Test-Path $tempTextFile) {
                $pdfContent = Get-Content $tempTextFile -Raw
                Remove-Item $tempTextFile -Force -ErrorAction SilentlyContinue
                
                # Test 4a: Main appendix header present and unnumbered
                if ($pdfContent -match "Appendix [A-Z]:\s*") {
                    Record-TestResult $true "Main appendix header found (unnumbered format)"
                } else {
                    Record-TestResult $false "Main appendix header validation"
                }
                
                # Test 4b: No numbered subsection headers (LaTeX template working correctly)
                $numberedHeaders = [regex]::Matches($pdfContent, '\d+\.\d+(\.\d+)*\s+[A-Z]')
                if ($numberedHeaders.Count -eq 0) {
                    Record-TestResult $true "No numbered subsection headers (correct appendix formatting)"
                } else {
                    Record-TestResult $false "Numbered subsection headers found ($($numberedHeaders.Count) instances)"
                    if ($Verbose) {
                        foreach ($match in $numberedHeaders) {
                            Write-Host "    Found: $($match.Value)" -ForegroundColor Red
                        }
                    }
                }
                
                # Test 4c: Substantial content present
                if ($pdfContent.Length -gt 500) {
                    Record-TestResult $true "PDF contains substantial content ($($pdfContent.Length) characters)"
                } else {
                    Record-TestResult $false "PDF content length ($($pdfContent.Length) characters is insufficient)"
                }
                
                # Test 4d: Specific content validation for known appendices
                if ($baseName -eq "joining-conference-template") {
                    $requiredElements = @(
                        "Template Instructions",
                        "Conference Form",
                        "Pre-Meeting Checklist",
                        "Understanding Your Scout",
                        "Information Sharing Permissions",
                        "Conference Summary"
                    )
                    
                    foreach ($element in $requiredElements) {
                        if ($pdfContent -match [regex]::Escape($element)) {
                            Record-TestResult $true "Required element present: $element"
                        } else {
                            Record-TestResult $false "Required element missing: $element"
                        }
                    }
                }
                
            } else {
                Record-TestResult $false "PDF text extraction for $baseName"
            }
        } catch {
            Record-TestResult $false "PDF content validation for $baseName (Error: $($_.Exception.Message))"
        }
    }
}

# Test 5: Web Accessibility
Write-Host "`nTest 5: Web Accessibility" -ForegroundColor Yellow
Write-Host "=========================" -ForegroundColor Yellow

# First check if Jekyll is running
try {
    $response = Invoke-WebRequest -Uri "http://localhost:4000" -UseBasicParsing -TimeoutSec 3
    if ($response.StatusCode -eq 200) {
        Write-Verbose-Custom "Jekyll server is running"
        
        foreach ($mdFile in $appendixMdFiles) {
            $baseName = $mdFile.BaseName
            $webUrl = "http://localhost:4000/assets/files/handbook/appendix/$baseName-latest.pdf"
            Record-TestResult (Test-Url $webUrl "Web access: $baseName PDF") ""
        }
    } else {
        Record-TestResult $false "Jekyll server accessibility"
        Write-Host "[WARN] Jekyll not running, skipping web accessibility tests" -ForegroundColor Yellow
    }
} catch {
    Record-TestResult $false "Jekyll server connection"
    Write-Host "[WARN] Jekyll not accessible at http://localhost:4000, skipping web tests" -ForegroundColor Yellow
}

# Test 6: LaTeX Template Validation
Write-Host "`nTest 6: LaTeX Template Validation" -ForegroundColor Yellow
Write-Host "==================================" -ForegroundColor Yellow

$appendixLatexTemplate = "templates/appendix.latex"
if (Test-Path $appendixLatexTemplate) {
    Record-TestResult $true "Appendix LaTeX template exists"
    
    $templateContent = Get-Content $appendixLatexTemplate -Raw
    
    # Test 6a: Verify secnumdepth is set to 0 (no section numbering)
    if ($templateContent -match '\\setcounter\{secnumdepth\}\{0\}') {
        Record-TestResult $true "LaTeX template disables section numbering (secnumdepth=0)"
    } else {
        Record-TestResult $false "LaTeX template section numbering configuration"
    }
    
    # Test 6b: Verify appendix-specific header
    if ($templateContent -match 'Troop 500G Handbook Appendix') {
        Record-TestResult $true "LaTeX template has appendix-specific header"
    } else {
        Record-TestResult $false "LaTeX template appendix header"
    }
    
} else {
    Record-TestResult $false "Appendix LaTeX template exists"
}

# Final Summary
Write-Host @"

Test Results Summary
===================
Total Tests: $totalTests
Passed: $passedTests
Failed: $failedTests
Success Rate: $([Math]::Round(($passedTests / $totalTests) * 100, 1))%

"@ -ForegroundColor Cyan

if ($failedTests -eq 0) {
    Write-Host "SUCCESS - All appendix PDF tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "FAILURE - $failedTests test(s) failed" -ForegroundColor Red
    Write-Host "`nRecommendations:" -ForegroundColor Yellow
    Write-Host "1. Run the full build process: .\build_and_test_optimized.ps1" -ForegroundColor White
    Write-Host "2. Check Docker containers: docker-compose ps" -ForegroundColor White
    Write-Host "3. Review PDF generation logs for errors" -ForegroundColor White
    Write-Host "4. Verify LaTeX template configuration" -ForegroundColor White
    exit 1
}
