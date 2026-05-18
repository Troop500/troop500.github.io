#!/usr/bin/env pwsh
#
# Appendix PDF Testing Module
# ===========================
# 
# This module provides functions for testing and validating appendix PDF files
# generated from the handbook build process.
# Supports consolidated issue reporting for LLM review.
#

param(
    [string]$BaseDir = (Get-Location),
    [switch]$TestContent,
    [switch]$Cleanup,
    [int]$KeepNewest = 3,
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
    
    # Check for global ReportIssues flag or the script parameter
    $shouldReport = $global:ReportIssues -or $ReportIssues
    
    # Only add to global issues list if reporting is enabled and global list exists
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

# Function to test appendix PDFs
function Test-AppendixPDFs {
    param(
        [string]$BaseDir = (Get-Location),
        [string]$PdfPath = "assets/files/handbook/appendix/*.pdf"
    )
    
    Write-Host "Testing appendix PDFs..." -ForegroundColor Cyan
    
    $pdfFiles = Get-ChildItem -Path (Join-Path $BaseDir $PdfPath) -ErrorAction SilentlyContinue
    
    if (-not $pdfFiles) {
        Write-Host "[FAIL] No appendix PDF files found at $PdfPath" -ForegroundColor Red
        Add-Issue -Category "PDF Links" -Severity "Medium" -Description "No appendix PDF files found" -Location $PdfPath -Suggestion "Check PDF generation process for appendix files"
        return $false
    }
    
    $allTestsPassed = $true
    
    foreach ($pdf in $pdfFiles) {
        Write-Host "Testing PDF: $($pdf.Name)" -ForegroundColor Yellow
        
        # Test 1: File exists and is not empty
        if ($pdf.Length -eq 0) {
            Write-Host "[FAIL] PDF is empty: $($pdf.Name)" -ForegroundColor Red
            Add-Issue -Category "PDF Links" -Severity "High" -Description "Empty PDF file: $($pdf.Name)" -Location $pdf.FullName -Suggestion "Regenerate this PDF file or check PDF creation process"
            $allTestsPassed = $false
            continue
        }
        Write-Host "[PASS] PDF file exists and has content" -ForegroundColor Green
        
        # Test 2: PDF is a valid PDF file (basic header check)
        try {
            $bytes = [System.IO.File]::ReadAllBytes($pdf.FullName)
            if ($bytes.Length -lt 4 -or [System.Text.Encoding]::ASCII.GetString($bytes[0..3]) -ne '%PDF') {
                Write-Host "[FAIL] Invalid PDF header: $($pdf.Name)" -ForegroundColor Red
                Add-Issue -Category "PDF Links" -Severity "High" -Description "Invalid PDF header: $($pdf.Name)" -Location $pdf.FullName -Suggestion "Regenerate this PDF file - it appears to be corrupted"
                $allTestsPassed = $false
                continue
            }
            Write-Host "[PASS] Valid PDF header detected" -ForegroundColor Green
        } catch {
            Write-Host "[FAIL] Error reading PDF file: $($_.Exception.Message)" -ForegroundColor Red
            Add-Issue -Category "PDF Links" -Severity "High" -Description "Cannot read PDF file: $($pdf.Name)" -Location $pdf.FullName -Details $_.Exception.Message -Suggestion "Check file permissions and regenerate this PDF file"
            $allTestsPassed = $false
            continue
        }
        
        # Test 3: PDF size is reasonable (between 10KB and 50MB)
        $sizeMB = [Math]::Round($pdf.Length / 1MB, 2)
        if ($pdf.Length -lt 10KB) {
            Write-Host "[FAIL] PDF too small ($sizeMB MB): $($pdf.Name)" -ForegroundColor Red
            Add-Issue -Category "PDF Links" -Severity "Medium" -Description "PDF file too small: $($pdf.Name)" -Location $pdf.FullName -Details "Size: $sizeMB MB" -Suggestion "Check if PDF content is being generated correctly"
            $allTestsPassed = $false
        } elseif ($pdf.Length -gt 50MB) {
            Write-Host "[FAIL] PDF too large ($sizeMB MB): $($pdf.Name)" -ForegroundColor Red
            $allTestsPassed = $false
        } else {
            Write-Host "[PASS] PDF size is reasonable ($sizeMB MB)" -ForegroundColor Green
        }
        
        Write-Host "" # Blank line between PDFs
    }
    
    Write-Host "Found and tested $($pdfFiles.Count) appendix PDF file(s)" -ForegroundColor Cyan
    return $allTestsPassed
}

# Function to validate PDF content using external tools
function Test-AppendixPDFContent {
    param(
        [string]$BaseDir = (Get-Location),
        [string]$PdfPath = "assets/files/handbook/appendix/*.pdf",
        [string[]]$RequiredContent = @("Joining Conference", "Template", "Troop 500")
    )
    
    Write-Host "Testing appendix PDF content..." -ForegroundColor Cyan
    
    $pdfFiles = Get-ChildItem -Path (Join-Path $BaseDir $PdfPath) -ErrorAction SilentlyContinue
    
    if (-not $pdfFiles) {
        Write-Host "[FAIL] No appendix PDF files found for content testing" -ForegroundColor Red
        return $false
    }
    
    $allTestsPassed = $true
    
    foreach ($pdf in $pdfFiles) {
        Write-Host "Testing content in: $($pdf.Name)" -ForegroundColor Yellow
        
        # Try to extract text using pdftotext (if available)
        try {
            $pdfTextCmd = Get-Command "pdftotext" -ErrorAction SilentlyContinue
            if ($pdfTextCmd) {
                $tempTxtFile = [System.IO.Path]::GetTempFileName()
                & pdftotext $pdf.FullName $tempTxtFile 2>$null
                
                if (Test-Path $tempTxtFile) {
                    $content = Get-Content $tempTxtFile -Raw
                    Remove-Item $tempTxtFile -Force
                    
                    foreach ($required in $RequiredContent) {
                        if ($content -match [regex]::Escape($required)) {
                            Write-Host "[PASS] Found required content: '$required'" -ForegroundColor Green
                        } else {
                            Write-Host "[FAIL] Missing required content: '$required'" -ForegroundColor Red
                            $allTestsPassed = $false
                        }
                    }
                } else {
                    Write-Host "[WARN] Could not extract text from PDF for content validation" -ForegroundColor Yellow
                }
            } else {
                Write-Host "[INFO] pdftotext not available, skipping content validation" -ForegroundColor Blue
            }
        } catch {
            Write-Host "[WARN] Error during PDF content extraction: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        
        Write-Host "" # Blank line between PDFs
    }
    
    return $allTestsPassed
}

# Function to clean up old appendix PDFs
function Clear-OldAppendixPDFs {
    param(
        [string]$BaseDir = (Get-Location),
        [string]$PdfPath = "assets/files/handbook/appendix/*.pdf",
        [int]$KeepNewest = 3
    )
    
    Write-Host "Cleaning up old appendix PDFs..." -ForegroundColor Cyan
    
    $pdfFiles = Get-ChildItem -Path (Join-Path $BaseDir $PdfPath) -ErrorAction SilentlyContinue | 
                Sort-Object LastWriteTime -Descending
    
    if ($pdfFiles.Count -le $KeepNewest) {
        Write-Host "No cleanup needed. Found $($pdfFiles.Count) PDF(s), keeping newest $KeepNewest" -ForegroundColor Green
        return
    }
    
    $filesToDelete = $pdfFiles | Select-Object -Skip $KeepNewest
    
    foreach ($file in $filesToDelete) {
        try {
            Remove-Item $file.FullName -Force
            Write-Host "[DELETED] $($file.Name)" -ForegroundColor Yellow
        } catch {
            Write-Host "[ERROR] Could not delete $($file.Name): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    Write-Host "Cleanup complete. Kept $KeepNewest newest PDF(s)" -ForegroundColor Green
}

# Functions are automatically available when dot-sourced
# No need for Export-ModuleMember when using dot-sourcing

# Main script execution when run directly
if ($Help) {
        Write-Host @"
Appendix PDF Testing Module

USAGE:
    .\test-appendix-pdfs.ps1 [-BaseDir <path>] [-TestContent] [-Cleanup] [-KeepNewest <n>] [-Help]

OPTIONS:
    -BaseDir      Base directory to search for PDFs (default: current directory)
    -TestContent  Also test PDF content (requires pdftotext)
    -Cleanup      Clean up old appendix PDFs, keeping only newest
    -KeepNewest   Number of newest PDFs to keep during cleanup (default: 3)
    -Help         Show this help message

EXAMPLES:
    .\test-appendix-pdfs.ps1                    # Basic PDF validation
    .\test-appendix-pdfs.ps1 -TestContent       # Include content validation
    .\test-appendix-pdfs.ps1 -Cleanup           # Clean up old PDFs

This module can also be imported into other scripts:
    . .\test-appendix-pdfs.ps1
    Test-AppendixPDFs
"@
        exit 0
    }
    
    # Run tests if not being imported as module  
    if ($MyInvocation.InvocationName -ne '.') {
        $allTestsPassed = $true
        
        # Run basic PDF tests
        if (-not (Test-AppendixPDFs -BaseDir $BaseDir)) {
            $allTestsPassed = $false
        }
        
        # Run content tests if requested
        if ($TestContent) {
            if (-not (Test-AppendixPDFContent -BaseDir $BaseDir)) {
                $allTestsPassed = $false
            }
        }
        
        # Clean up old PDFs if requested
        if ($Cleanup) {
            Clear-OldAppendixPDFs -BaseDir $BaseDir -KeepNewest $KeepNewest
        }
        
        if ($allTestsPassed) {
            Write-Host "`nALL APPENDIX PDF TESTS PASSED!" -ForegroundColor Green
            exit 0
        } else {
            Write-Host "`nSOME APPENDIX PDF TESTS FAILED!" -ForegroundColor Red
            exit 1
        }
    }

