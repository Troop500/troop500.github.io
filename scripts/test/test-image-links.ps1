#!/usr/bin/env pwsh
#
# Image Links Testing Module
# ==========================
#
# This module scans webpages for <img> src attributes and validates that each
# image URL resolves successfully (HTTP 200). It can test a single page or a
# list of pages.
# Supports consolidated issue reporting for LLM review.
#

param(
    [string]$BaseUrl = "http://localhost:4000",
    [string[]]$Pages = @("/", "/handbook", "/about", "/charter-organization", "/scouting-america", "/lake-erie-council", "/events", "/contact", "/joining", "/resources"),
    [int]$TimeoutSec = 10,
    [int]$MaxConcurrency = 5,
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

    $shouldReport = $global:ReportIssues -or $ReportIssues

    if ($shouldReport -and (Get-Variable -Name "global:IssuesList" -ErrorAction SilentlyContinue)) {
        $global:IssuesList += [PSCustomObject]@{
            Timestamp   = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Category    = $Category
            Severity    = $Severity
            Description = $Description
            Location    = $Location
            Details     = $Details
            Suggestion  = $Suggestion
        }
    }
}

# Extract all image src URLs from HTML content, resolving relative paths to absolute
function Get-ImageUrls {
    param(
        [Parameter(Mandatory)]
        [string]$HtmlContent,

        [Parameter(Mandatory)]
        [string]$PageUrl,

        [switch]$ShowDetails
    )

    $pageUri = [Uri]$PageUrl
    $images = @()

    $srcPattern = '(?<![\w-])src\s*=\s*["'']([^"'']+)["'']'
    $matches = [regex]::Matches($HtmlContent, $srcPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

    if ($ShowDetails) {
        Write-Host "  [DEBUG] $($matches.Count) total src= match(es) found in HTML" -ForegroundColor DarkGray
    }

    # Image file extensions to test (excludes iframe src, scripts, etc.)
    $imageExtensions = @('.jpg', '.jpeg', '.png', '.gif', '.webp', '.svg', '.ico', '.bmp')

    foreach ($match in $matches) {
        $src = $match.Groups[1].Value.Trim()

        # Skip data URIs and empty values
        if ($src -match '^data:' -or [string]::IsNullOrWhiteSpace($src)) {
            if ($ShowDetails) { Write-Host "  [DEBUG]   SKIP (data/empty)  raw='$src'" -ForegroundColor DarkGray }
            continue
        }

        # Skip non-image URLs (e.g. Google Maps iframes, scripts)
        $ext = [System.IO.Path]::GetExtension(($src -split '[?#]')[0]).ToLower()
        if ($ext -notin $imageExtensions) {
            if ($ShowDetails) { Write-Host "  [DEBUG]   SKIP (ext='$ext')   raw='$($src.Substring(0, [Math]::Min(80,$src.Length)))'" -ForegroundColor DarkGray }
            continue
        }

        # Resolve to absolute URL
        try {
            if ($src -match '^https?://') {
                $absUrl = $src
            } elseif ($src.StartsWith('//')) {
                $absUrl = "$($pageUri.Scheme):$src"
            } elseif ($src.StartsWith('/')) {
                $absUrl = "$($pageUri.Scheme)://$($pageUri.Authority)$src"
            } else {
                # Relative path - resolve against page URL
                $base = "$($pageUri.Scheme)://$($pageUri.Authority)$($pageUri.AbsolutePath -replace '[^/]+$', '')"
                $absUrl = "$base$src"
            }
            # Only add valid http(s) URLs
            if ($absUrl -match '^https?://') {
                if ($ShowDetails) { Write-Host "  [DEBUG]   KEEP (ext='$ext')   raw='$src' -> resolved='$absUrl'" -ForegroundColor DarkGray }
                $images += $absUrl
            } else {
                Write-Host "  [WARN] src extracted but resolved to non-http URL: raw='$src' -> resolved='$absUrl'" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "  [WARN] src could not be resolved: raw='$src' error='$($_.Exception.Message)'" -ForegroundColor Yellow
            continue
        }
    }

    return @($images | Sort-Object -Unique)
}

# Test a single image URL
function Test-ImageUrl {
    param(
        [Parameter(Mandatory)]
        [string]$Url,

        [int]$TimeoutSec = 10
    )

    try {
        $response = Invoke-WebRequest -Uri $Url -Method Head -UseBasicParsing -TimeoutSec $TimeoutSec -ErrorAction Stop
        return @{ Success = $true; StatusCode = $response.StatusCode }
    } catch {
        $statusCode = $null
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
        }
        # Try GET if HEAD not supported
        if ($statusCode -eq 405) {
            try {
                $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec $TimeoutSec -ErrorAction Stop
                return @{ Success = $true; StatusCode = $response.StatusCode; Note = "HEAD not supported, GET succeeded" }
            } catch {
                $getStatusCode = $null
                if ($_.Exception.Response) { $getStatusCode = [int]$_.Exception.Response.StatusCode }
                return @{ Success = $false; Error = $_.Exception.Message; StatusCode = $getStatusCode }
            }
        }
        return @{ Success = $false; Error = $_.Exception.Message; StatusCode = $statusCode }
    }
}

# Test all images on a single page
function Test-ImageLinksFromPage {
    param(
        [Parameter(Mandatory)]
        [string]$PageUrl,

        [int]$TimeoutSec = 10,
        [int]$MaxConcurrency = 5,
        [switch]$ShowDetails
    )

    Write-Host "Scanning page: $PageUrl" -ForegroundColor Cyan

    try {
        $pageResponse = Invoke-WebRequest -Uri $PageUrl -UseBasicParsing -TimeoutSec $TimeoutSec
        $imageUrls = Get-ImageUrls -HtmlContent $pageResponse.Content -PageUrl $PageUrl -ShowDetails:$ShowDetails

        if ($imageUrls.Count -eq 0) {
            Write-Host "  No images found" -ForegroundColor Yellow
            return @{ TotalImages = 0; FailedImages = 0; Results = @() }
        }

        Write-Host "  Found $($imageUrls.Count) image(s)" -ForegroundColor Green

        $results = @()
        $failedCount = 0
        $batchSize = $MaxConcurrency

        # Split into batches
        $linkBatches = @()
        for ($i = 0; $i -lt $imageUrls.Count; $i += $batchSize) {
            $end = [Math]::Min($i + $batchSize - 1, $imageUrls.Count - 1)
            $linkBatches += ,@($imageUrls[$i..$end])
        }

        foreach ($batch in $linkBatches) {
            $jobs = @()

            foreach ($imgUrl in $batch) {
                $jobs += Start-Job -ScriptBlock {
                    param($url, $timeout)

                    function Test-ImageUrl {
                        param([string]$Url, [int]$TimeoutSec = 10)
                        try {
                            $response = Invoke-WebRequest -Uri $Url -Method Head -UseBasicParsing -TimeoutSec $TimeoutSec -ErrorAction Stop
                            return @{ Success = $true; StatusCode = $response.StatusCode }
                        } catch {
                            $statusCode = $null
                            if ($_.Exception.Response) { $statusCode = [int]$_.Exception.Response.StatusCode }
                            if ($statusCode -eq 405) {
                                try {
                                    $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec $TimeoutSec -ErrorAction Stop
                                    return @{ Success = $true; StatusCode = $response.StatusCode; Note = "HEAD not supported, GET succeeded" }
                                } catch {
                                    $getStatusCode = $null
                                    if ($_.Exception.Response) { $getStatusCode = [int]$_.Exception.Response.StatusCode }
                                    return @{ Success = $false; Error = $_.Exception.Message; StatusCode = $getStatusCode }
                                }
                            }
                            return @{ Success = $false; Error = $_.Exception.Message; StatusCode = $statusCode }
                        }
                    }

                    $result = Test-ImageUrl -Url $url -TimeoutSec $timeout
                    $result.Url = $url
                    return $result
                } -ArgumentList $imgUrl, $TimeoutSec
            }

            foreach ($job in $jobs) {
                $result = Receive-Job -Job $job -Wait
                $result.PageUrl = $PageUrl
                $result.Status = if ($result.Success) { "OK" } else { $result.Error }
                $results += $result

                if ($result.Success) {
                    if ($ShowDetails) {
                        $note = if ($result.Note) { " ($($result.Note))" } else { "" }
                        Write-Host "    [PASS] $($result.Url) (Status: $($result.StatusCode))$note" -ForegroundColor Green
                    }
                } else {
                    Write-Host "    [FAIL] $($result.Url)" -ForegroundColor Red
                    Write-Host "            Status Code : $($result.StatusCode)" -ForegroundColor Red
                    Write-Host "            Error       : $($result.Error)" -ForegroundColor Red
                    Write-Host "            Found on    : $PageUrl" -ForegroundColor Red
                    $failedCount++

                    Add-Issue -Category "Image Links" -Severity "High" `
                        -Description "Broken image: $($result.Url)" `
                        -Location $PageUrl `
                        -Details "HTTP $($result.StatusCode): $($result.Error)" `
                        -Suggestion "Verify the image file exists at the expected path and that baseurl is correctly set"
                }
            }

            $jobs | Remove-Job -Force
        }

        return @{ TotalImages = $imageUrls.Count; FailedImages = $failedCount; Results = $results }

    } catch {
        Write-Host "  [ERROR] Failed to scan page: $($_.Exception.Message)" -ForegroundColor Red
        return @{ TotalImages = 0; FailedImages = 1; Results = @() }
    }
}

# Test image links across multiple pages
function Test-ImageLinksFromWebsite {
    param(
        [string]$BaseUrl = "http://localhost:4000",
        [string[]]$Pages = @("/", "/handbook", "/about", "/charter-organization", "/scouting-america", "/lake-erie-council", "/events", "/contact", "/joining", "/resources"),
        [int]$TimeoutSec = 10,
        [int]$MaxConcurrency = 5,
        [switch]$ShowDetails
    )

    Write-Host "Testing image links from website: $BaseUrl" -ForegroundColor Cyan
    Write-Host "Pages to scan: $($Pages -join ', ')" -ForegroundColor Yellow
    Write-Host ""

    $totalImages = 0
    $totalFailed = 0
    $allResults = @()

    foreach ($page in $Pages) {
        $pageUrl = if ($page.StartsWith('http')) { $page } else { "$BaseUrl$page" }
        $pageResults = Test-ImageLinksFromPage -PageUrl $pageUrl -TimeoutSec $TimeoutSec -MaxConcurrency $MaxConcurrency -ShowDetails:$ShowDetails
        $totalImages += $pageResults.TotalImages
        $totalFailed += $pageResults.FailedImages
        $allResults += $pageResults.Results
        Write-Host ""
    }

    # Summary
    Write-Host "Image Links Summary:" -ForegroundColor Cyan
    Write-Host "  Total images tested: $totalImages" -ForegroundColor White
    Write-Host "  Failed images: $totalFailed" -ForegroundColor $(if ($totalFailed -eq 0) { "Green" } else { "Red" })
    $rate = [Math]::Round((($totalImages - $totalFailed) / [Math]::Max($totalImages, 1)) * 100, 1)
    Write-Host "  Success rate: $rate%" -ForegroundColor $(if ($totalFailed -eq 0) { "Green" } else { "Yellow" })

    if ($totalFailed -gt 0) {
        Write-Host ""
        Write-Host "Failed Images by Page:" -ForegroundColor Red
        $failedResults = $allResults | Where-Object { $_.Status -ne "OK" }
        $groupedByPage = $failedResults | Group-Object PageUrl
        foreach ($group in $groupedByPage) {
            Write-Host "  $($group.Name):" -ForegroundColor Yellow
            foreach ($failure in $group.Group) {
                Write-Host "    - $($failure.Url)" -ForegroundColor Red
                Write-Host "      Status Code : $($failure.StatusCode)" -ForegroundColor DarkRed
                Write-Host "      Error       : $($failure.Status)" -ForegroundColor DarkRed
            }
        }
    }

    return @{ TotalImages = $totalImages; FailedImages = $totalFailed; Results = $allResults }
}

# Main
if ($Help) {
    Write-Host @"
Image Links Testing Module

USAGE:
    .\test-image-links.ps1 [-BaseUrl <url>] [-Pages <pages>] [-TimeoutSec <seconds>]
                           [-MaxConcurrency <num>] [-ShowDetails] [-ReportIssues] [-Help]

OPTIONS:
    -BaseUrl         Base URL of website to test (default: http://localhost:4000)
    -Pages           Array of pages to scan
    -TimeoutSec      Timeout per image request (default: 10)
    -MaxConcurrency  Maximum concurrent requests (default: 5)
    -ShowDetails     Show pass results as well as failures
    -ReportIssues    Add failures to consolidated issues report
    -Help            Show this help message

EXAMPLES:
    .\test-image-links.ps1
    .\test-image-links.ps1 -BaseUrl "https://troop500.org" -ShowDetails
    .\test-image-links.ps1 -Pages @("/contact", "/handbook") -ShowDetails
"@
    exit 0
}

if ($MyInvocation.InvocationName -ne '.') {
    $results = Test-ImageLinksFromWebsite -BaseUrl $BaseUrl -Pages $Pages -TimeoutSec $TimeoutSec -MaxConcurrency $MaxConcurrency -ShowDetails:$ShowDetails

    if ($results.FailedImages -eq 0) {
        Write-Host "`nALL IMAGE LINKS PASSED!" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "`n$($results.FailedImages) IMAGE LINK(S) FAILED!" -ForegroundColor Red
        exit 1
    }
}
