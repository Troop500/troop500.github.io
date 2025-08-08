#!/usr/bin/env pwsh
#
# Linux Compatibility Test Script
# ===============================
# 
# This script tests the basic functionality on Linux systems
# Run this after installing PowerShell Core on Linux
# Supports consolidated issue reporting for LLM review.
#

param(
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

Write-Host "🐧 Testing Troop 500G Build System on Linux" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

# Test 1: Check PowerShell Core availability and version
Write-Host "`n1. PowerShell Core Version:" -ForegroundColor Yellow
Write-Host "   Version: $($PSVersionTable.PSVersion)" -ForegroundColor Green
Write-Host "   Edition: $($PSVersionTable.PSEdition)" -ForegroundColor Green

# Test 2: Platform detection
Write-Host "`n2. Platform Detection:" -ForegroundColor Yellow
if ($PSVersionTable.PSVersion.Major -ge 6) {
    Write-Host "   Windows: $($IsWindows)" -ForegroundColor Green
    Write-Host "   Linux: $($IsLinux)" -ForegroundColor Green  
    Write-Host "   macOS: $($IsMacOS)" -ForegroundColor Green
} else {
    Write-Host "   Running Windows PowerShell (not cross-platform)" -ForegroundColor Red
}

# Test 3: Path handling
Write-Host "`n3. Cross-Platform Path Handling:" -ForegroundColor Yellow
$testPath = Join-Path $PSScriptRoot "test-self-urls.ps1"
Write-Host "   Test script path: $testPath" -ForegroundColor Green
Write-Host "   Exists: $(Test-Path $testPath)" -ForegroundColor $(if (Test-Path $testPath) { "Green" } else { "Red" })

# Test 4: Docker availability
Write-Host "`n4. Docker Availability:" -ForegroundColor Yellow
$dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
if ($dockerCmd) {
    Write-Host "   Docker: Available at $($dockerCmd.Source)" -ForegroundColor Green
    try {
        $dockerVersion = & docker --version 2>$null
        Write-Host "   Version: $dockerVersion" -ForegroundColor Green
    } catch {
        Write-Host "   Version: Could not determine" -ForegroundColor Yellow
    }
} else {
    Write-Host "   Docker: Not found" -ForegroundColor Red
}

# Test 5: Docker Compose availability
Write-Host "`n5. Docker Compose Availability:" -ForegroundColor Yellow
$dockerComposeCmd = Get-Command docker-compose -ErrorAction SilentlyContinue
$dockerComposePlugin = if (-not $dockerComposeCmd) { Get-Command docker -ErrorAction SilentlyContinue } else { $null }

if ($dockerComposeCmd) {
    Write-Host "   docker-compose: Available at $($dockerComposeCmd.Source)" -ForegroundColor Green
} elseif ($dockerComposePlugin) {
    Write-Host "   docker compose: Available as plugin" -ForegroundColor Green
} else {
    Write-Host "   Docker Compose: Not found" -ForegroundColor Red
}

# Test 6: Module imports
Write-Host "`n6. Module Import Test:" -ForegroundColor Yellow
try {
    . (Join-Path $PSScriptRoot "test-self-urls.ps1")
    Write-Host "   test-self-urls.ps1: Imported successfully" -ForegroundColor Green
    
    . (Join-Path $PSScriptRoot "test-appendix-pdfs.ps1")
    Write-Host "   test-appendix-pdfs.ps1: Imported successfully" -ForegroundColor Green
    
    . (Join-Path (Split-Path $PSScriptRoot) (Join-Path "utils" "jekyll-service.ps1"))
    Write-Host "   jekyll-service.ps1: Imported successfully" -ForegroundColor Green
} catch {
    Write-Host "   Module import failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 7: Build script availability
Write-Host "`n7. Build Scripts:" -ForegroundColor Yellow
$buildScripts = @(
    "build/build-handbook-simple.sh",
    "build/build-handbook-pandoc.sh", 
    "build/build-appendix-pdfs.sh"
)

foreach ($script in $buildScripts) {
    $scriptPath = Join-Path (Split-Path $PSScriptRoot) $script
    $exists = Test-Path $scriptPath
    $executable = if ($exists -and (-not $IsWindows)) { 
        (Get-Item $scriptPath).Mode -match "x" 
    } else { 
        $true  # Windows doesn't use executable permissions
    }
    
    Write-Host "   $script`: Exists=$exists" -ForegroundColor $(if ($exists) { "Green" } else { "Red" }) -NoNewline
    if ($exists -and (-not $IsWindows)) {
        Write-Host ", Executable=$executable" -ForegroundColor $(if ($executable) { "Green" } else { "Yellow" })
    } else {
        Write-Host ""
    }
}

# Summary
Write-Host "`n🏁 Linux Compatibility Summary:" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

$issues = @()
if ($PSVersionTable.PSVersion.Major -lt 6) {
    $issues += "PowerShell Core required (found Windows PowerShell)"
}
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    $issues += "Docker not available"
}
if (-not (Get-Command docker-compose -ErrorAction SilentlyContinue) -and -not (Get-Command docker -ErrorAction SilentlyContinue)) {
    $issues += "Docker Compose not available"
}

if ($issues.Count -eq 0) {
    Write-Host "✅ System appears ready for Linux builds!" -ForegroundColor Green
    Write-Host "   Run: ./build_and_test_pdf_first.ps1 -Quick" -ForegroundColor Green
} else {
    Write-Host "⚠️  Issues found:" -ForegroundColor Yellow
    foreach ($issue in $issues) {
        Write-Host "   - $issue" -ForegroundColor Red
    }
    Write-Host "`n   Install missing components and re-run this test." -ForegroundColor Yellow
}
