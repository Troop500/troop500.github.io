#!/usr/bin/env pwsh
#
# PDF Links Testing Module
# ========================
# 
# This module extracts and validates links from generated PDF files.
# It can test links within handbook PDFs, appendix PDFs, or any PDF document.
# Supports consolidated issue reporting for LLM review.
#

param(
    [string[]]$PdfPaths = @(),
    [string]$PdfDirectory = "assets/files/handbook",
    [int]$TimeoutSec = 10,
    [int]$MaxConcurrency = 3,
    [switch]$IncludeLatest,
    [switch]$IncludeArchive,
    [switch]$ReportIssues,
    [switch]$Verbose,
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

# Function to check if required tools are available
function Test-PdfToolsAvailable {
    $tools = @()
    
    # Check for pdftotext (part of poppler-utils)
    if (Get-Command pdftotext -ErrorAction SilentlyContinue) {
        $tools += "pdftotext"
    }
    
    # Check for pdfgrep
    if (Get-Command pdfgrep -ErrorAction SilentlyContinue) {
        $tools += "pdfgrep"
    }
    
    # Check for PowerShell PDF modules
    try {
        Import-Module -Name PdfSharp -Force -ErrorAction SilentlyContinue
        $tools += "PdfSharp"
    } catch {
        # PdfSharp not available
    }
    
    if ($tools.Count -eq 0) {
        Write-Host "ERROR: No PDF text extraction tools found." -ForegroundColor Red
        Write-Host "Please install one of the following:" -ForegroundColor Yellow
        Write-Host "  - poppler-utils (for pdftotext)" -ForegroundColor Yellow
        Write-Host "  - pdfgrep" -ForegroundColor Yellow
        Write-Host "  - PdfSharp PowerShell module" -ForegroundColor Yellow
        return $false
    }
    
    return $tools
}

# Function to extract text from PDF using available tools
function Get-PdfText {
    param(
        [Parameter(Mandatory)]
        [string]$PdfPath
    )
    
    if (-not (Test-Path $PdfPath)) {
        throw "PDF file not found: $PdfPath"
    }
    
    # Try pdftotext first (most reliable)
    if (Get-Command pdftotext -ErrorAction SilentlyContinue) {
        try {
            $tempFile = [System.IO.Path]::GetTempFileName()
            & pdftotext $PdfPath $tempFile 2>$null
            if ($LASTEXITCODE -eq 0 -and (Test-Path $tempFile)) {
                $text = Get-Content $tempFile -Raw
                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                return $text
            }
        } catch {
            # Fall through to next method
        }
    }
    
    # Try .NET PDF reader if available
    try {
        Add-Type -AssemblyName System.Drawing
        # This is a simplified approach - in practice you'd need a proper PDF library
        # For now, return empty text with a warning
        Write-Warning "PDF text extraction requires additional tools. Please install poppler-utils."
        return ""
    } catch {
        Write-Warning "Cannot extract text from PDF: $PdfPath. No suitable tools available."
        return ""
    }
}

# Function to extract URLs from text
function Get-UrlsFromText {
    param(
        [Parameter(Mandatory)]
        [string]$Text
    )
    
    $urls = @()
    
    # Pattern to match HTTP/HTTPS URLs
    $urlPattern = 'https?://[^\s<>"]+[^\s<>".,;)]'
    $urlMatches = [regex]::Matches($Text, $urlPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    
    foreach ($match in $urlMatches) {
        $url = $match.Value.Trim()
        # Clean up common PDF extraction artifacts
        $url = $url -replace '[,.]$', ''  # Remove trailing punctuation
        $url = $url -replace '\)$', ''    # Remove trailing parenthesis
        $urls += $url
    }
    
    return $urls | Sort-Object -Unique
}

# Function to test URL availability
function Test-PdfUrl {
    param(
        [Parameter(Mandatory)]
        [string]$Url,
        
        [int]$TimeoutSec = 10
    )
    
    try {
        # Use HEAD request first for efficiency
        $response = Invoke-WebRequest -Uri $Url -Method Head -UseBasicParsing -TimeoutSec $TimeoutSec -ErrorAction Stop
        return @{
            Success = $true
            StatusCode = $response.StatusCode
            Method = "HEAD"
        }
    } catch [System.Net.WebException] {
        # If HEAD fails, try GET (some servers don't support HEAD)
        try {
            $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec $TimeoutSec -ErrorAction Stop
            return @{
                Success = $true
                StatusCode = $response.StatusCode
                Method = "GET"
                Note = "HEAD failed, GET succeeded"
            }
        } catch {
            return @{
                Success = $false
                Error = $_.Exception.Message
                StatusCode = $null
            }
        }
    } catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
            StatusCode = $null
        }
    }
}

# Function to test links in a single PDF
function Test-LinksInPdf {
    param(
        [Parameter(Mandatory)]
        [string]$PdfPath,
        
        [int]$TimeoutSec = 10,
        [int]$MaxConcurrency = 3,
        [switch]$Verbose
    )
    
    $pdfName = Split-Path $PdfPath -Leaf
    Write-Host "Scanning PDF: $pdfName" -ForegroundColor Cyan
    
    try {
        # Extract text from PDF
        $pdfText = Get-PdfText -PdfPath $PdfPath
        
        if ([string]::IsNullOrWhiteSpace($pdfText)) {
            Write-Host "  No text extracted from PDF (may be image-based or encrypted)" -ForegroundColor Yellow
            return @{ TotalLinks = 0; FailedLinks = 0; Results = @(); PdfName = $pdfName }
        }
        
        # Extract URLs from text
        $urls = Get-UrlsFromText -Text $pdfText
        
        if ($urls.Count -eq 0) {
            Write-Host "  No URLs found in PDF" -ForegroundColor Yellow
            return @{ TotalLinks = 0; FailedLinks = 0; Results = @(); PdfName = $pdfName }
        }
        
        Write-Host "  Found $($urls.Count) URL(s)" -ForegroundColor Green
        
        # Test URLs with concurrency control
        $results = @()
        $failedCount = 0
        $semaphore = [System.Threading.Semaphore]::new($MaxConcurrency, $MaxConcurrency)
        $jobs = @()
        
        foreach ($url in $urls) {
            $jobs += Start-Job -ScriptBlock {
                param($testUrl, $timeout, $semaphoreHandle)
                
                # Wait for semaphore
                $null = $semaphoreHandle.WaitOne()
                
                try {
                    # Import the function into the job context
                    function Test-PdfUrl {
                        param([string]$Url, [int]$TimeoutSec = 10)
                        try {
                            $response = Invoke-WebRequest -Uri $Url -Method Head -UseBasicParsing -TimeoutSec $TimeoutSec -ErrorAction Stop
                            return @{ Success = $true; StatusCode = $response.StatusCode; Method = "HEAD" }
                        } catch [System.Net.WebException] {
                            try {
                                $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec $TimeoutSec -ErrorAction Stop
                                return @{ Success = $true; StatusCode = $response.StatusCode; Method = "GET"; Note = "HEAD failed, GET succeeded" }
                            } catch {
                                return @{ Success = $false; Error = $_.Exception.Message; StatusCode = $null }
                            }
                        } catch {
                            return @{ Success = $false; Error = $_.Exception.Message; StatusCode = $null }
                        }
                    }
                    
                    $result = Test-PdfUrl -Url $testUrl -TimeoutSec $timeout
                    $result.Url = $testUrl
                    return $result
                } finally {
                    # Release semaphore
                    $semaphoreHandle.Release() | Out-Null
                }
            } -ArgumentList $url, $TimeoutSec, $semaphore
        }
        
        # Collect results
        foreach ($job in $jobs) {
            $result = Receive-Job -Job $job -Wait
            $results += $result
            
            if ($result.Success) {
                if ($Verbose) {
                    $note = if ($result.Note) { " ($($result.Note))" } else { "" }
                    Write-Host "    [PASS] $($result.Url) (Status: $($result.StatusCode), Method: $($result.Method))$note" -ForegroundColor Green
                }
            } else {
                Write-Host "    [FAIL] $($result.Url) - $($result.Error)" -ForegroundColor Red
                $failedCount++
            }
        }
        $jobs | Remove-Job -Force
        $semaphore.Dispose()
        
        return @{
            TotalLinks = $urls.Count
            FailedLinks = $failedCount
            Results = $results
            PdfName = $pdfName
        }
        
    } catch {
        Write-Host "  [ERROR] Failed to process PDF: $($_.Exception.Message)" -ForegroundColor Red
        return @{ TotalLinks = 0; FailedLinks = 1; Results = @(); PdfName = $pdfName }
    }
}

# Function to find PDF files to test
function Get-PdfFilesToTest {
    param(
        [string[]]$PdfPaths = @(),
        [string]$PdfDirectory = "assets/files/handbook",
        [switch]$IncludeLatest,
        [switch]$IncludeArchive
    )
    
    $pdfFiles = @()
    
    # Add explicitly specified PDF paths
    foreach ($path in $PdfPaths) {
        if (Test-Path $path) {
            $pdfFiles += (Get-Item $path).FullName
        } else {
            Write-Warning "PDF file not found: $path"
        }
    }
    
    # Add PDFs from directory if specified
    if (-not [string]::IsNullOrEmpty($PdfDirectory) -and (Test-Path $PdfDirectory)) {
        $searchPatterns = @()
        
        # Main handbook PDFs
        if ($IncludeLatest) {
            $searchPatterns += "*-latest.pdf"
        } else {
            # Include timestamped PDFs by default
            $searchPatterns += "*-20*.pdf"
        }
        
        foreach ($pattern in $searchPatterns) {
            $foundPdfs = Get-ChildItem -Path $PdfDirectory -Filter $pattern -Recurse:$IncludeArchive | Where-Object { -not $_.PSIsContainer }
            $pdfFiles += $foundPdfs.FullName
        }
    }
    
    return $pdfFiles | Sort-Object -Unique
}

# Function to test links in multiple PDFs
function Test-LinksInPdfs {
    param(
        [string[]]$PdfPaths = @(),
        [string]$PdfDirectory = "assets/files/handbook",
        [int]$TimeoutSec = 10,
        [int]$MaxConcurrency = 3,
        [switch]$IncludeLatest,
        [switch]$IncludeArchive,
        [switch]$Verbose
    )
    
    # Check if PDF tools are available
    $availableTools = Test-PdfToolsAvailable
    if (-not $availableTools) {
        return @{ TotalLinks = 0; FailedLinks = 1; Results = @() }
    }
    
    Write-Host "PDF text extraction tools available: $($availableTools -join ', ')" -ForegroundColor Green
    
    # Find PDF files to test
    $pdfFiles = Get-PdfFilesToTest -PdfPaths $PdfPaths -PdfDirectory $PdfDirectory -IncludeLatest:$IncludeLatest -IncludeArchive:$IncludeArchive
    
    if ($pdfFiles.Count -eq 0) {
        Write-Host "No PDF files found to test" -ForegroundColor Yellow
        return @{ TotalLinks = 0; FailedLinks = 0; Results = @() }
    }
    
    Write-Host "Testing links in $($pdfFiles.Count) PDF file(s)" -ForegroundColor Cyan
    Write-Host ""
    
    $totalLinks = 0
    $totalFailed = 0
    $allResults = @()
    
    foreach ($pdfFile in $pdfFiles) {
        $pdfResults = Test-LinksInPdf -PdfPath $pdfFile -TimeoutSec $TimeoutSec -MaxConcurrency $MaxConcurrency -Verbose:$Verbose
        
        $totalLinks += $pdfResults.TotalLinks
        $totalFailed += $pdfResults.FailedLinks
        $allResults += $pdfResults.Results
        
        Write-Host ""
    }
    
    # Summary
    Write-Host "PDF Links Summary:" -ForegroundColor Cyan
    Write-Host "  Total PDF files tested: $($pdfFiles.Count)" -ForegroundColor White
    Write-Host "  Total links tested: $totalLinks" -ForegroundColor White
    Write-Host "  Failed links: $totalFailed" -ForegroundColor $(if ($totalFailed -eq 0) { "Green" } else { "Red" })
    Write-Host "  Success rate: $([Math]::Round((($totalLinks - $totalFailed) / [Math]::Max($totalLinks, 1)) * 100, 1))%" -ForegroundColor $(if ($totalFailed -eq 0) { "Green" } else { "Yellow" })
    
    return @{
        TotalLinks = $totalLinks
        FailedLinks = $totalFailed
        Results = $allResults
    }
}

# Functions are automatically available when dot-sourced

# Main script execution when run directly
if ($Help) {
    Write-Host @"
PDF Links Testing Module

USAGE:
    .\test-pdf-links.ps1 [-PdfPaths <paths>] [-PdfDirectory <dir>] [-TimeoutSec <seconds>] 
                         [-MaxConcurrency <num>] [-IncludeLatest] [-IncludeArchive] [-Verbose] [-Help]

OPTIONS:
    -PdfPaths        Specific PDF file paths to test
    -PdfDirectory    Directory to scan for PDFs (default: assets/files/handbook)
    -TimeoutSec      Timeout for each link test (default: 10)
    -MaxConcurrency  Maximum concurrent link tests (default: 3)
    -IncludeLatest   Include *-latest.pdf files instead of timestamped versions
    -IncludeArchive  Include archive subdirectories in search
    -Verbose         Show detailed results for each link
    -Help            Show this help message

PREREQUISITES:
    This script requires PDF text extraction tools. Install one of:
    - poppler-utils (for pdftotext command)
    - pdfgrep
    - PdfSharp PowerShell module

EXAMPLES:
    .\test-pdf-links.ps1                                    # Test timestamped PDFs in default directory
    .\test-pdf-links.ps1 -IncludeLatest -Verbose           # Test latest PDFs with detailed output
    .\test-pdf-links.ps1 -PdfPaths @("path/to/file.pdf")   # Test specific PDF file
    .\test-pdf-links.ps1 -IncludeArchive -MaxConcurrency 5 # Test all PDFs including archives

This module can also be imported into other scripts:
    . .\test-pdf-links.ps1
    Test-LinksInPdfs -PdfDirectory "assets/files/handbook"
"@
    exit 0
}

# Run tests if not being imported as module
if ($MyInvocation.InvocationName -ne '.') {
    $results = Test-LinksInPdfs -PdfPaths $PdfPaths -PdfDirectory $PdfDirectory -TimeoutSec $TimeoutSec -MaxConcurrency $MaxConcurrency -IncludeLatest:$IncludeLatest -IncludeArchive:$IncludeArchive -Verbose:$Verbose
    
    if ($results.FailedLinks -eq 0) {
        Write-Host "`nALL PDF LINKS PASSED!" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "`n$($results.FailedLinks) PDF LINK(S) FAILED!" -ForegroundColor Red
        exit 1
    }
}
