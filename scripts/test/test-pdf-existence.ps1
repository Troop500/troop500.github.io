#!/usr/bin/env pwsh
#
# PDF Existence Testing Module
# ============================
#
# Verifies that all expected PDF files were generated during the build.
# Dynamically discovers expected appendix PDFs from source markdown files.
#

param(
    [string]$PdfDirectory = "assets/files/handbook",
    [string]$SourceDirectory = "_includes/content/appendix",
    [ValidateSet('All', 'Handbook', 'Appendix')]
    [string]$Mode = "All",
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
    .\test-pdf-existence.ps1 [-PdfDirectory <dir>] [-SourceDirectory <dir>] [-Mode All|Handbook|Appendix] [-Help]

OPTIONS:
    -PdfDirectory     Directory containing generated PDFs (default: assets/files/handbook)
    -SourceDirectory  Directory containing appendix source .md files (default: _includes/content/appendix)
    -Mode             What to check: All (default), Handbook, or Appendix
    -ReportIssues     Add failures to global issues list for consolidated reporting
    -Help             Show this help message

DESCRIPTION:
    This script verifies that expected PDFs exist and are non-empty.
    1. Handbook: checks for troop-handbook.pdf
    2. Appendix: checks for {name}.pdf for each .md file in SourceDirectory

EXAMPLES:
    .\test-pdf-existence.ps1                           # Test all PDFs
    .\test-pdf-existence.ps1 -Mode Handbook             # Test handbook only
    .\test-pdf-existence.ps1 -Mode Appendix             # Test appendix PDFs only
    .\test-pdf-existence.ps1 -PdfDirectory "assets/files/handbook" -SourceDirectory "_includes/content/appendix"
"@
    exit 0
}

$totalChecks = 0
$passedChecks = 0
$failedChecks = 0
$warnings = 0

function Test-PdfExists {
    param(
        [string]$FilePath,
        [string]$Description,
        [switch]$Required
    )
    
    $script:totalChecks++
    
    if (-not (Test-Path $FilePath)) {
        if ($Required) {
            Write-Host "  FAIL - $Description (not found: $FilePath)" -ForegroundColor Red
            Add-Issue -Category "PDF Existence" -Severity "ERROR" -Description "$Description - not found" -Location $FilePath -Suggestion "Ensure the build step completed successfully"
            $script:failedChecks++
        } else {
            Write-Host "  WARN - $Description (not found: $FilePath)" -ForegroundColor Yellow
            $script:warnings++
        }
        return $false
    }
    
    $file = Get-Item $FilePath
    if ($file.Length -gt 0) {
        $sizeKB = [Math]::Round($file.Length / 1024, 1)
        Write-Host "  PASS - $Description ($($file.Name), $sizeKB KB)" -ForegroundColor Green
        $script:passedChecks++
        return $true
    } else {
        Write-Host "  FAIL - $Description (file exists but is empty: $($file.Name))" -ForegroundColor Red
        Add-Issue -Category "PDF Existence" -Severity "ERROR" -Description "$Description - file is empty" -Location $FilePath -Suggestion "Check build logs for PDF generation errors"
        $script:failedChecks++
        return $false
    }
}

Write-Host "PDF Existence Verification" -ForegroundColor Cyan
Write-Host "==========================" -ForegroundColor Cyan
Write-Host ""

# --- Main PDFs ---
if ($Mode -eq 'All' -or $Mode -eq 'Handbook') {
    Write-Host "Main PDFs ($PdfDirectory):" -ForegroundColor Cyan

    Test-PdfExists -FilePath (Join-Path $PdfDirectory "troop-handbook.pdf") -Description "Troop Handbook" -Required

    Write-Host ""
}

# --- Appendix PDFs ---
if ($Mode -ne 'Handbook') {
    $appendixPdfDir = Join-Path $PdfDirectory "appendix"

    Write-Host "Appendix PDFs ($appendixPdfDir):" -ForegroundColor Cyan

    if (Test-Path $SourceDirectory) {
        $appendixMdFiles = Get-ChildItem -Path $SourceDirectory -Filter "*.md" -ErrorAction SilentlyContinue

        if ($appendixMdFiles -and $appendixMdFiles.Count -gt 0) {
            Write-Host "  Found $($appendixMdFiles.Count) appendix source file(s): $($appendixMdFiles.BaseName -join ', ')" -ForegroundColor White
            Write-Host ""

            foreach ($mdFile in $appendixMdFiles) {
                $baseName = $mdFile.BaseName
                Test-PdfExists -FilePath (Join-Path $appendixPdfDir "$baseName.pdf") -Description "Appendix: $baseName" -Required
            }
        } else {
            Write-Host "  No appendix source files found in $SourceDirectory" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  Source directory not found: $SourceDirectory" -ForegroundColor Yellow
        Write-Host "  Falling back to checking existing PDFs in output directory..." -ForegroundColor Yellow

        # Fallback: just verify any PDFs in appendix dir are non-empty
        if (Test-Path $appendixPdfDir) {
            $existingPdfs = Get-ChildItem -Path $appendixPdfDir -Filter "*.pdf" -ErrorAction SilentlyContinue
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
} # end if Mode ne Handbook

# --- File listing ---
Write-Host ""
Write-Host "All PDF files found:" -ForegroundColor Cyan
if (Test-Path $PdfDirectory) {
    $allPdfs = Get-ChildItem -Path $PdfDirectory -Filter "*.pdf" -Recurse -ErrorAction SilentlyContinue
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
