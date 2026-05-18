#!/usr/bin/env pwsh
#
# Self URL Testing Module
# =======================
# 
# This module provides functions for testing internal website endpoint availability
# (self-hosted pages and resources). For external link validation, see test-external-links.ps1
# Supports consolidated issue reporting for LLM review.
#

param(
    [string]$BaseUrl = "http://localhost:4000",
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

# Function to test URL endpoints
function Test-Url {
    param(
        [Parameter(Mandatory)]
        [string]$Url,
        
        [Parameter(Mandatory)]
        [string]$Description,
        
        [int]$TimeoutSec = 5
    )
    
    try {
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec $TimeoutSec
        if ($response.StatusCode -eq 200) {
            Write-Host "[PASS] $Description" -ForegroundColor Green
            return $true
        } else {
            Write-Host "[FAIL] $Description (Status: $($response.StatusCode))" -ForegroundColor Red
            Add-Issue -Category "Internal Links" -Severity "High" -Description "$Description failed" -Location $Url -Details "HTTP Status Code: $($response.StatusCode)" -Suggestion "Check if the resource exists and is properly configured"
            return $false
        }
    } catch {
        Write-Host "[FAIL] $Description (Error: $($_.Exception.Message))" -ForegroundColor Red
        Add-Issue -Category "Internal Links" -Severity "High" -Description "$Description failed" -Location $Url -Details "Error: $($_.Exception.Message)" -Suggestion "Verify the URL is correct and the service is running"
        return $false
    }
}

# Function to test multiple URLs in parallel
function Test-UrlsParallel {
    param(
        [Parameter(Mandatory)]
        [hashtable[]]$Tests,
        
        [int]$TimeoutSec = 10
    )
    
    $failedTests = 0
    $testJobs = @()
    
    # Start parallel test jobs
    foreach ($test in $Tests) {
        $testJobs += Start-Job -ScriptBlock {
            param($url, $name, $timeout)
            try {
                $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec $timeout
                return @{ Success = ($response.StatusCode -eq 200); Name = $name; Status = $response.StatusCode }
            } catch {
                return @{ Success = $false; Name = $name; Error = $_.Exception.Message }
            }
        } -ArgumentList $test.Url, $test.Name, $TimeoutSec
    }
    
    # Wait for all tests and report results
    foreach ($job in $testJobs) {
        $result = Receive-Job -Job $job -Wait
        if ($result.Success) {
            Write-Host "[PASS] $($result.Name)" -ForegroundColor Green
        } else {
            Write-Host "[FAIL] $($result.Name)" -ForegroundColor Red
            $failedTests++
        }
    }
    $testJobs | Remove-Job -Force
    
    return $failedTests
}

# Function to test standard website endpoints
function Test-StandardWebsiteEndpoints {
    param(
        [string]$BaseUrl = "http://localhost:4000"
    )
    
    Write-Host "Testing website endpoints..." -ForegroundColor Cyan
    
    $tests = @(
        @{ Url = "$BaseUrl"; Name = "Homepage" },
        @{ Url = "$BaseUrl/handbook"; Name = "Handbook page" },
        @{ Url = "$BaseUrl/about"; Name = "About page" },
        @{ Url = "$BaseUrl/events"; Name = "Events page" }
    )
    
    return Test-UrlsParallel -Tests $tests
}

# Functions are automatically available when dot-sourced
# No need for Export-ModuleMember when using dot-sourcing

# Main script execution when run directly
if ($Help) {
        Write-Host @"
Self URL Testing Module

USAGE:
    .\test-self-urls.ps1 [-BaseUrl <url>] [-Help]

OPTIONS:
    -BaseUrl     Base URL to test (default: http://localhost:4000)
    -Help        Show this help message

EXAMPLES:
    .\test-self-urls.ps1                                    # Test default localhost endpoints
    .\test-self-urls.ps1 -BaseUrl "https://troop500.org"  # Test live website endpoints

This module tests internal website pages and resources. For external link validation,
use test-external-links.ps1. This module can also be imported into other scripts:
    . .\test-self-urls.ps1
    Test-Url "http://localhost:4000" "Homepage"
"@
    exit 0
}

# Run tests if not being imported as module
if ($MyInvocation.InvocationName -ne '.') {
    $failedTests = Test-StandardWebsiteEndpoints -BaseUrl $BaseUrl
    
    if ($failedTests -eq 0) {
        Write-Host "`nALL URL TESTS PASSED!" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "`n$failedTests URL TEST(S) FAILED!" -ForegroundColor Red
        exit 1
    }
}
