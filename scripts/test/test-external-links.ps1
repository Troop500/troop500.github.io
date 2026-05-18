#!/usr/bin/env pwsh
#
# External Links Testing Module
# =============================
# 
# This module scans webpages for external links and validates their availability.
# It can test a single page or crawl an entire website for external link validation.
# Supports consolidated issue reporting for LLM review.
#

param(
    [string]$BaseUrl = "http://localhost:4000",
    [string[]]$Pages = @("/", "/handbook", "/about", "/events"),
    [int]$TimeoutSec = 10,
    [int]$MaxConcurrency = 5,
    [switch]$IncludeImages,
    [switch]$ShowDetails,
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

# Function to extract external links from HTML content
function Get-ExternalLinks {
    param(
        [Parameter(Mandatory)]
        [string]$HtmlContent,
        
        [Parameter(Mandatory)]
        [string]$BaseUrl,
        
        [switch]$IncludeImages
    )
    
    $externalLinks = @()
    $baseUri = [Uri]$BaseUrl
    
    # Define local/internal hosts to exclude
    $localHosts = @(
        $baseUri.Host,
        "localhost", 
        "127.0.0.1", 
        "0.0.0.0",
        "::1"  # IPv6 localhost
    )
    
    # Extract href links
    $hrefPattern = "href\s*=\s*[`"']([^`"']+)[`"']"
    $hrefMatches = [regex]::Matches($HtmlContent, $hrefPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    
    foreach ($match in $hrefMatches) {
        $url = $match.Groups[1].Value
        if ($url -match '^https?://') {
            try {
                $linkUri = [Uri]$url
                # Check if the host is NOT in our local hosts list
                if ($linkUri.Host -notin $localHosts) {
                    $externalLinks += $url
                }
            } catch {
                # If URI parsing fails, skip this link
                continue
            }
        }
    }
    
    # Extract image sources if requested
    if ($IncludeImages) {
        $srcPattern = "src\s*=\s*[`"']([^`"']+)[`"']"
        $srcMatches = [regex]::Matches($HtmlContent, $srcPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        
        foreach ($match in $srcMatches) {
            $url = $match.Groups[1].Value
            if ($url -match '^https?://') {
                try {
                    $linkUri = [Uri]$url
                    # Check if the host is NOT in our local hosts list
                    if ($linkUri.Host -notin $localHosts) {
                        $externalLinks += $url
                    }
                } catch {
                    # If URI parsing fails, skip this link
                    continue
                }
            }
        }
    }
    
    return $externalLinks | Sort-Object -Unique
}

# Function to test external link availability
function Test-ExternalLink {
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
            ResponseTime = $null
        }
    } catch {
        # In PowerShell 7, HTTP errors throw HttpResponseException (not WebException)
        # Check status code from either exception type
        $statusCode = $null
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
        }
        # 403 means server is reachable but blocking bots - treat as warning, not failure
        if ($statusCode -eq 403) {
            return @{
                Success = $true
                Warning = $true
                StatusCode = 403
                ResponseTime = $null
                Note = "403 Forbidden (bot protection, server is reachable)"
            }
        }
        # If HEAD fails for other reasons, try GET (some servers don't support HEAD)
        try {
            $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec $TimeoutSec -ErrorAction Stop
            return @{
                Success = $true
                StatusCode = $response.StatusCode
                ResponseTime = $null
                Note = "HEAD failed, GET succeeded"
            }
        } catch {
            $getStatusCode = $null
            if ($_.Exception.Response) {
                $getStatusCode = [int]$_.Exception.Response.StatusCode
            }
            if ($getStatusCode -eq 403) {
                return @{
                    Success = $true
                    Warning = $true
                    StatusCode = 403
                    ResponseTime = $null
                    Note = "403 Forbidden (bot protection, server is reachable)"
                }
            }
            return @{
                Success = $false
                Error = $_.Exception.Message
                StatusCode = $getStatusCode
            }
        }
    }
}

# Function to test external links from a webpage
function Test-ExternalLinksFromPage {
    param(
        [Parameter(Mandatory)]
        [string]$PageUrl,
        
        [string]$BaseUrl,
        
        [int]$TimeoutSec = 10,
        [int]$MaxConcurrency = 5,
        [switch]$IncludeImages,
        [switch]$ShowDetails
    )
    
    Write-Host "Scanning page: $PageUrl" -ForegroundColor Cyan
    
    try {
        # Get the page content
        $pageResponse = Invoke-WebRequest -Uri $PageUrl -UseBasicParsing -TimeoutSec $TimeoutSec
        $externalLinks = Get-ExternalLinks -HtmlContent $pageResponse.Content -BaseUrl $BaseUrl -IncludeImages:$IncludeImages
        
        if ($externalLinks.Count -eq 0) {
            Write-Host "  No external links found" -ForegroundColor Yellow
            return @{ TotalLinks = 0; FailedLinks = 0; Results = @() }
        }
        
        Write-Host "  Found $($externalLinks.Count) external link(s)" -ForegroundColor Green
        
        # Test external links with concurrency control
        $results = @()
        $failedCount = 0
        
        # Use batch processing instead of semaphore for PowerShell compatibility
        $batchSize = $MaxConcurrency
        $linkBatches = @()
        
        # Split links into batches
        for ($i = 0; $i -lt $externalLinks.Count; $i += $batchSize) {
            $endIndex = [Math]::Min($i + $batchSize - 1, $externalLinks.Count - 1)
            $linkBatches += ,@($externalLinks[$i..$endIndex])
        }
        
        # Process each batch
        foreach ($batch in $linkBatches) {
            $jobs = @()
            
            foreach ($link in $batch) {
                $jobs += Start-Job -ScriptBlock {
                    param($url, $timeout)
                    
                    # Import the function into the job context
                    function Test-ExternalLink {
                        param([string]$Url, [int]$TimeoutSec = 10)
                        try {
                            $response = Invoke-WebRequest -Uri $Url -Method Head -UseBasicParsing -TimeoutSec $TimeoutSec -ErrorAction Stop
                            return @{ Success = $true; StatusCode = $response.StatusCode; ResponseTime = $null }
                        } catch {
                            $statusCode = $null
                            if ($_.Exception.Response) { $statusCode = [int]$_.Exception.Response.StatusCode }
                            if ($statusCode -eq 403) {
                                return @{ Success = $true; Warning = $true; StatusCode = 403; ResponseTime = $null; Note = "403 Forbidden (bot protection, server is reachable)" }
                            }
                            try {
                                $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec $TimeoutSec -ErrorAction Stop
                                return @{ Success = $true; StatusCode = $response.StatusCode; ResponseTime = $null; Note = "HEAD failed, GET succeeded" }
                            } catch {
                                $getStatusCode = $null
                                if ($_.Exception.Response) { $getStatusCode = [int]$_.Exception.Response.StatusCode }
                                if ($getStatusCode -eq 403) {
                                    return @{ Success = $true; Warning = $true; StatusCode = 403; ResponseTime = $null; Note = "403 Forbidden (bot protection, server is reachable)" }
                                }
                                return @{ Success = $false; Error = $_.Exception.Message; StatusCode = $getStatusCode }
                            }
                        }
                    }
                    
                    $result = Test-ExternalLink -Url $url -TimeoutSec $timeout
                    $result.Url = $url
                    return $result
                } -ArgumentList $link, $TimeoutSec
            }
            
            # Wait for batch to complete
            foreach ($job in $jobs) {
                $result = Receive-Job -Job $job -Wait
                $result.PageUrl = $PageUrl  # Add page URL to result
                
                # Add a standardized Status property for summary reporting
                if ($result.Success) {
                    $result.Status = "OK"
                } else {
                    $result.Status = $result.Error
                }
                
                $results += $result
                
                if ($result.Success) {
                    if ($result.Warning) {
                        $note = if ($result.Note) { " ($($result.Note))" } else { "" }
                        Write-Host "    [WARN] $($result.Url) (Status: $($result.StatusCode))$note" -ForegroundColor Yellow
                    } elseif ($ShowDetails) {
                        $note = if ($result.Note) { " ($($result.Note))" } else { "" }
                        Write-Host "    [PASS] $($result.Url) (Status: $($result.StatusCode))$note" -ForegroundColor Green
                    }
                } else {
                    Write-Host "    [FAIL] $($result.Url) - $($result.Error)" -ForegroundColor Red
                    $failedCount++
                    
                    # Add issue to consolidated report if enabled
                    Add-Issue -Category "External Links" -Severity "Medium" -Description "External link failed: $($result.Url)" -Location $PageUrl -Details $result.Error -Suggestion "Verify the external link is correct and the target website is accessible"
                }
            }
            $jobs | Remove-Job -Force
        }
        
        return @{
            TotalLinks = $externalLinks.Count
            FailedLinks = $failedCount
            Results = $results
        }
        
    } catch {
        Write-Host "  [ERROR] Failed to scan page: $($_.Exception.Message)" -ForegroundColor Red
        return @{ TotalLinks = 0; FailedLinks = 1; Results = @() }
    }
}

# Function to test external links across multiple pages
function Test-ExternalLinksFromWebsite {
    param(
        [string]$BaseUrl = "http://localhost:4000",
        [string[]]$Pages = @("/", "/handbook", "/about", "/events"),
        [int]$TimeoutSec = 10,
        [int]$MaxConcurrency = 5,
        [switch]$IncludeImages,
        [switch]$ShowDetails
    )
    
    Write-Host "Testing external links from website: $BaseUrl" -ForegroundColor Cyan
    Write-Host "Pages to scan: $($Pages -join ', ')" -ForegroundColor Yellow
    Write-Host ""
    
    $totalLinks = 0
    $totalFailed = 0
    $allResults = @()
    
    foreach ($page in $Pages) {
        $pageUrl = if ($page.StartsWith('http')) { $page } else { "$BaseUrl$page" }
        
        $pageResults = Test-ExternalLinksFromPage -PageUrl $pageUrl -BaseUrl $BaseUrl -TimeoutSec $TimeoutSec -MaxConcurrency $MaxConcurrency -IncludeImages:$IncludeImages -ShowDetails:$ShowDetails
        
        $totalLinks += $pageResults.TotalLinks
        $totalFailed += $pageResults.FailedLinks
        $allResults += $pageResults.Results
        
        Write-Host ""
    }
    
    # Summary
    Write-Host "External Links Summary:" -ForegroundColor Cyan
    Write-Host "  Total external links tested: $totalLinks" -ForegroundColor White
    Write-Host "  Failed links: $totalFailed" -ForegroundColor $(if ($totalFailed -eq 0) { "Green" } else { "Red" })
    Write-Host "  Success rate: $([Math]::Round((($totalLinks - $totalFailed) / [Math]::Max($totalLinks, 1)) * 100, 1))%" -ForegroundColor $(if ($totalFailed -eq 0) { "Green" } else { "Yellow" })
    
    # Failed links by page
    if ($totalFailed -gt 0) {
        Write-Host ""
        Write-Host "Failed Links by Page:" -ForegroundColor Red
        $failedResults = $allResults | Where-Object { $_.Status -ne "OK" }
        $groupedByPage = $failedResults | Group-Object PageUrl
        
        foreach ($group in $groupedByPage) {
            Write-Host "  $($group.Name):" -ForegroundColor Yellow
            foreach ($failure in $group.Group) {
                Write-Host "    - $($failure.Url) ($($failure.Status))" -ForegroundColor Red
            }
        }
    }
    
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
External Links Testing Module

USAGE:
    .\test-external-links.ps1 [-BaseUrl <url>] [-Pages <pages>] [-TimeoutSec <seconds>] 
                              [-MaxConcurrency <num>] [-IncludeImages] [-ShowDetails] [-ReportIssues] [-Help]

OPTIONS:
    -BaseUrl         Base URL of website to test (default: http://localhost:4000)
    -Pages           Array of pages to scan (default: /, /handbook, /about, /events)
    -TimeoutSec      Timeout for each link test (default: 10)
    -MaxConcurrency  Maximum concurrent link tests (default: 5)
    -IncludeImages   Include external image sources in testing
    -ShowDetails     Show detailed results for each link
    -ReportIssues    Add failures to consolidated issues report (when run from main build script)
    -Help            Show this help message

EXAMPLES:
    .\test-external-links.ps1                                    # Test default pages
    .\test-external-links.ps1 -BaseUrl "https://troop500.org"   # Test live website
    .\test-external-links.ps1 -Pages @("/", "/handbook") -ShowDetails # Test specific pages with details
    .\test-external-links.ps1 -IncludeImages -MaxConcurrency 10  # Include images with higher concurrency

This module can also be imported into other scripts:
    . .\test-external-links.ps1
    Test-ExternalLinksFromWebsite -BaseUrl "http://localhost:4000"
"@
    exit 0
}

# Run tests if not being imported as module
if ($MyInvocation.InvocationName -ne '.') {
    $results = Test-ExternalLinksFromWebsite -BaseUrl $BaseUrl -Pages $Pages -TimeoutSec $TimeoutSec -MaxConcurrency $MaxConcurrency -IncludeImages:$IncludeImages -ShowDetails:$ShowDetails
    
    # Add summary issues if failures occurred
    if ($results.FailedLinks -gt 0 -and $ReportIssues) {
        Add-Issue -Category "External Links" -Severity "High" -Description "Multiple external link failures detected" -Details "Found $($results.FailedLinks) failed external links out of $($results.TotalLinks) total links" -Suggestion "Review failed external links and update or remove broken links"
    }
    
    if ($results.FailedLinks -eq 0) {
        Write-Host "`nALL EXTERNAL LINKS PASSED!" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "`n$($results.FailedLinks) EXTERNAL LINK(S) FAILED!" -ForegroundColor Red
        exit 1
    }
}
