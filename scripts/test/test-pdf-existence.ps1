#!/usr/bin/env pwsh
#
# PDF Existence Testing Module
# ============================
#
# Verifies that all expected PDF files were generated during the build.
# Dynamically discovers expected appendix PDFs from source markdown files.
# Can run against build artifacts (local) or be extended for URL checks.
#

param(
    [string]$PdfDirectory = "assets/files/handbook",
    [string]$SourceDirectory = "_includes/content/appendix",
    [switch]$RequireLatest,
    [switch]$ReportIssues,
    [switch]$Help
)

# Function to add issue to consolidated report (if enabled)
function Add-Issue {
    param(
        [Parameter(Mandatory)]
        [string]$Category,
        
        [Parameter(Mandatory)]
        [string]$Severity,
        
        [Parameter(Mandatory)]
        [string]$Description,
        
        [string]$Location = "",
        [string]$Details = "",
        [string]$Suggestion = ""
    )
    
    $shouldReport = $global:ReportIssues -or $ReportIssues
    
    if ($shouldReport -and (Get-Variable -Name "global:IssuesList" -ErrorAction SilentlyContinue)) {
        $global:IssuesList += [PSCustomObject]@{
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Category = $Category
            Severity = $Severity
            Description = $Description
            Location = $Location
            Details = $Details
            Suggestion = $Suggestion
        }
    }
}

if ($Help) {
    Write-Host @"
PDF Existence Testing Module

USAGE:
    .\test-pdf-existence.ps1 [-PdfDirectory <dir>] [-SourceDirectory <dir>] [-RequireLatest] [-Help]

OPTIONS:
    -PdfDirectory     Directory containing generated PDFs (default: assets/files/handbook)
    -SourceDirectory  Directory containing appendix source .md files (default: _includes/content/appendix)
    -RequireLatest    Also verify that *-latest.pdf copies exist for all PDFs
    -ReportIssues     Add failures to global issues list for consolidated reporting
    -Help             Show this help message

DESCRIPTION:
    This script dynamically discovers what PDFs should exist based on:
    1. Main PDFs: troop-handbook and contact-info (always expected)
    2. Appendix PDFs: one per .md file in the SourceDirectory

    For each expected PDF, it verifies:
    - At least one timestamped version exists (*-20*.pdf)
    - The file is non-empty (> 0 bytes)
    - Optionally, a *-latest.pdf copy exists (-RequireLatest)

EXAMPLES:
    .\test-pdf-existence.ps1
    .\test-pdf-existence.ps1 -RequireLatest
    .\test-pdf-existence.ps1 -PdfDirectory "assets/files/handbook" -SourceDirectory "_includes/content/appendix"

This module can also be imported into other scripts:
    . .\test-pdf-existence.ps1
"@
    exit 0
}

$totalChecks = 0
$passedChecks = 0
$failedChecks = 0
$warnings = 0

function Test-PdfExists {
    param(
        [string]$Directory,
        [string]$Pattern,
        [string]$Description,
        [switch]$Required
    )
    
    $script:totalChecks++
    
    if (-not (Test-Path $Directory)) {
        if ($Required) {
            Write-Host "  FAIL - $Description (directory not found: $Directory)" -ForegroundColor Red
            Add-Issue -Category "PDF Existence" -Severity "ERROR" -Description "$Description - directory not found" -Location $Directory -Suggestion "Ensure the build step completed successfully"
            $script:failedChecks++
        } else {
            Write-Host "  WARN - $Description (directory not found: $Directory)" -ForegroundColor Yellow
            $script:warnings++
        }
        return $false
    }
    
    $found = Get-ChildItem -Path $Directory -Filter $Pattern -ErrorAction SilentlyContinue |
             Where-Object { -not $_.PSIsContainer -and $_.FullName -notlike '*archive*' }
    
    if ($found -and $found.Count -gt 0) {
        # Check file is non-empty
        $nonEmpty = $found | Where-Object { $_.Length -gt 0 }
        if ($nonEmpty -and $nonEmpty.Count -gt 0) {
            $sizeKB = [Math]::Round($nonEmpty[0].Length / 1024, 1)
            Write-Host "  PASS - $Description ($($nonEmpty[0].Name), $sizeKB KB)" -ForegroundColor Green
            $script:passedChecks++
            return $true
        } else {
            Write-Host "  FAIL - $Description (file exists but is empty: $($found[0].Name))" -ForegroundColor Red
            Add-Issue -Category "PDF Existence" -Severity "ERROR" -Description "$Description - file is empty" -Location "$Directory/$($found[0].Name)" -Suggestion "Check build logs for PDF generation errors"
            $script:failedChecks++
            return $false
        }
    } else {
        if ($Required) {
            Write-Host "  FAIL - $Description (no matching files: $Pattern in $Directory)" -ForegroundColor Red
            Add-Issue -Category "PDF Existence" -Severity "ERROR" -Description "$Description - no matching files found" -Location $Directory -Details "Pattern: $Pattern" -Suggestion "Check build logs for PDF generation errors"
            $script:failedChecks++
        } else {
            Write-Host "  WARN - $Description (no matching files: $Pattern)" -ForegroundColor Yellow
            $script:warnings++
        }
        return $false
    }
}

Write-Host "PDF Existence Verification" -ForegroundColor Cyan
Write-Host "==========================" -ForegroundColor Cyan
Write-Host ""

# --- Main PDFs ---
Write-Host "Main PDFs ($PdfDirectory):" -ForegroundColor Cyan

# Handbook PDF
Test-PdfExists -Directory $PdfDirectory -Pattern "troop-handbook-20*.pdf" -Description "Troop Handbook (timestamped)" -Required
if ($RequireLatest) {
    Test-PdfExists -Directory $PdfDirectory -Pattern "troop-handbook-latest.pdf" -Description "Troop Handbook (latest)" -Required
}

Write-Host ""

# --- Appendix PDFs ---
$appendixPdfDir = Join-Path $PdfDirectory "appendix"

Write-Host "Appendix PDFs ($appendixPdfDir):" -ForegroundColor Cyan

if (Test-Path $SourceDirectory) {
    $appendixMdFiles = Get-ChildItem -Path $SourceDirectory -Filter "*.md" -ErrorAction SilentlyContinue
    
    if ($appendixMdFiles -and $appendixMdFiles.Count -gt 0) {
        Write-Host "  Found $($appendixMdFiles.Count) appendix source file(s): $($appendixMdFiles.BaseName -join ', ')" -ForegroundColor White
        Write-Host ""
        
        foreach ($mdFile in $appendixMdFiles) {
            $baseName = $mdFile.BaseName
            Test-PdfExists -Directory $appendixPdfDir -Pattern "$baseName-20*.pdf" -Description "Appendix: $baseName (timestamped)" -Required
            if ($RequireLatest) {
                Test-PdfExists -Directory $appendixPdfDir -Pattern "$baseName-latest.pdf" -Description "Appendix: $baseName (latest)" -Required
            }
        }
    } else {
        Write-Host "  No appendix source files found in $SourceDirectory" -ForegroundColor Yellow
    }
} else {
    Write-Host "  Source directory not found: $SourceDirectory" -ForegroundColor Yellow
    Write-Host "  Falling back to checking existing PDFs in output directory..." -ForegroundColor Yellow
    
    # Fallback: just verify any PDFs in appendix dir are non-empty
    if (Test-Path $appendixPdfDir) {
        $existingPdfs = Get-ChildItem -Path $appendixPdfDir -Filter "*.pdf" -ErrorAction SilentlyContinue |
                        Where-Object { $_.FullName -notlike '*archive*' }
        if ($existingPdfs -and $existingPdfs.Count -gt 0) {
            Write-Host "  Found $($existingPdfs.Count) appendix PDF(s) in output directory" -ForegroundColor White
            foreach ($pdf in $existingPdfs) {
                $script:totalChecks++
                $sizeKB = [Math]::Round($pdf.Length / 1024, 1)
                if ($pdf.Length -gt 0) {
                    Write-Host "  PASS - $($pdf.Name) ($sizeKB KB)" -ForegroundColor Green
                    $script:passedChecks++
                } else {
                    Write-Host "  FAIL - $($pdf.Name) (empty file)" -ForegroundColor Red
                    $script:failedChecks++
                }
            }
        } else {
            Write-Host "  No appendix PDFs found in $appendixPdfDir" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  Appendix output directory not found: $appendixPdfDir" -ForegroundColor Yellow
    }
}

# --- File listing ---
Write-Host ""
Write-Host "All PDF files found:" -ForegroundColor Cyan
if (Test-Path $PdfDirectory) {
    $allPdfs = Get-ChildItem -Path $PdfDirectory -Filter "*.pdf" -Recurse -ErrorAction SilentlyContinue |
               Where-Object { $_.FullName -notlike '*archive*' }
    if ($allPdfs -and $allPdfs.Count -gt 0) {
        foreach ($pdf in $allPdfs) {
            $relativePath = $pdf.FullName.Replace((Resolve-Path $PdfDirectory).Path, "").TrimStart([IO.Path]::DirectorySeparatorChar)
            $sizeKB = [Math]::Round($pdf.Length / 1024, 1)
            $status = if ($pdf.Length -gt 0) { "OK" } else { "EMPTY" }
            $color = if ($pdf.Length -gt 0) { "White" } else { "Red" }
            Write-Host "  [$status] $relativePath ($sizeKB KB)" -ForegroundColor $color
        }
    } else {
        Write-Host "  (none)" -ForegroundColor Yellow
    }
}

# --- Summary ---
Write-Host ""
Write-Host "PDF Existence Summary:" -ForegroundColor Cyan
Write-Host "  Total checks: $totalChecks" -ForegroundColor White
Write-Host "  Passed: $passedChecks" -ForegroundColor Green
Write-Host "  Failed: $failedChecks" -ForegroundColor $(if ($failedChecks -eq 0) { "Green" } else { "Red" })
if ($warnings -gt 0) {
    Write-Host "  Warnings: $warnings" -ForegroundColor Yellow
}

if ($failedChecks -eq 0) {
    Write-Host "`nALL PDF EXISTENCE CHECKS PASSED!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n$failedChecks PDF EXISTENCE CHECK(S) FAILED!" -ForegroundColor Red
    exit 1
}
