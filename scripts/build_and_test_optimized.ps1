#!/usr/bin/env pwsh
#
# Optimized Troop 500G Build and Test Script
# ===========================================
# 
# This script provides a faster, more reliable build process with the following optimizations:
# 1. Uses cached builds when possible (--no-cache only when specified)
# 2. Parallel execution of independent operations
# 3. Better error handling and recovery
# 4. Reduced waiting times through smarter polling
# 5. Optional build steps for faster iteration
#

param(
    [switch]$NoCache,
    [switch]$SkipPDFs,
    [switch]$SkipTests,
    [switch]$Quick,
    [switch]$Help
)

if ($Help) {
    Write-Host @"
Optimized Troop 500G Build and Test Script

USAGE:
    .\build_and_test_optimized.ps1 [OPTIONS]

OPTIONS:
    -NoCache     Force rebuild all containers without cache (slower but clean)
    -SkipPDFs    Skip PDF generation (faster for web-only changes)
    -SkipTests   Skip endpoint testing (faster for build-only runs)
    -Quick       Skip both PDFs and tests (fastest option)
    -Help        Show this help message

EXAMPLES:
    .\build_and_test_optimized.ps1                    # Full build with caching
    .\build_and_test_optimized.ps1 -Quick             # Fast web-only build
    .\build_and_test_optimized.ps1 -NoCache           # Clean full rebuild
    .\build_and_test_optimized.ps1 -SkipPDFs          # Web build with tests
"@
    exit 0
}

# Set quick mode options
if ($Quick) {
    $SkipPDFs = $true
    $SkipTests = $true
}

Write-Host @"
Troop 500G Optimized Build and Test
===================================
Configuration:
  - Cache: $(if ($NoCache) { "Disabled (clean build)" } else { "Enabled (faster)" })
  - PDFs: $(if ($SkipPDFs) { "Skipped" } else { "Enabled" })
  - Tests: $(if ($SkipTests) { "Skipped" } else { "Enabled" })

"@ -ForegroundColor Cyan

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

# Function to wait for Jekyll with exponential backoff
function Wait-ForJekyll {
    param($maxAttempts = 15)
    
    Write-Host "Waiting for Jekyll to start..." -ForegroundColor Yellow
    
    for ($i = 1; $i -le $maxAttempts; $i++) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:4000" -UseBasicParsing -TimeoutSec 2
            if ($response.StatusCode -eq 200) {
                Write-Host "PASS - Jekyll is ready!" -ForegroundColor Green
                return $true
            }
        } catch {
            # Expected when Jekyll isn't ready yet
        }
        
        # Exponential backoff: 1s, 2s, 4s, 6s, 8s, then 10s max
        $sleepTime = [Math]::Min(10, [Math]::Pow(2, [Math]::Min($i, 3)))
        Write-Host "   Attempt $i/$maxAttempts - waiting ${sleepTime}s..." -ForegroundColor Yellow
        Start-Sleep -Seconds $sleepTime
    }
    
    Write-Host "FAIL - Jekyll failed to start after $maxAttempts attempts" -ForegroundColor Red
    return $false
}

# Start timer
$startTime = Get-Date

# Step 1: Prerequisites check
Write-Host "Checking prerequisites..." -ForegroundColor Cyan
$dockerComposeCmd = if (Get-Command docker-compose -ErrorAction SilentlyContinue) { "docker-compose" } else { "docker compose" }

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "FAIL - Docker not found" -ForegroundColor Red
    exit 1
}

Write-Host "Prerequisites check passed" -ForegroundColor Green

# Step 2: Clean and prepare
Write-Host "`nCleaning up..." -ForegroundColor Cyan

# Stop any running containers
& $dockerComposeCmd.Split() down 2>$null

# Clean up old files if not in quick mode
if (-not $Quick) {
    if (Test-Path "_site") {
        Remove-Item -Path "_site" -Recurse -Force
        Write-Host "Cleaned up _site directory" -ForegroundColor Green
    }
}

# Ensure PDF directories exist
@("assets/files/handbook", "assets/files/handbook/archive") | ForEach-Object {
    if (!(Test-Path $_)) {
        New-Item -Path $_ -ItemType Directory -Force | Out-Null
    }
}

Write-Host "PDF directories ready" -ForegroundColor Green

# Step 3: Build containers
Write-Host "`nBuilding containers..." -ForegroundColor Cyan
$buildArgs = $dockerComposeCmd.Split() + @("build")
if ($NoCache) {
    $buildArgs += "--no-cache"
    Write-Host "Using --no-cache for clean build" -ForegroundColor Yellow
} else {
    Write-Host "Using cached layers for faster build" -ForegroundColor Green
}

& $buildArgs[0] $buildArgs[1..($buildArgs.Length-1)]
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAIL - Container build failed" -ForegroundColor Red
    exit 1
}

$buildTime = (Get-Date) - $startTime
Write-Host "PASS - Containers built successfully ($([Math]::Round($buildTime.TotalSeconds, 1))s)" -ForegroundColor Green

# Step 4: Start Jekyll
Write-Host "`nStarting Jekyll..." -ForegroundColor Cyan
$startArgs = $dockerComposeCmd.Split() + @("up", "-d", "jekyll")
& $startArgs[0] $startArgs[1..($startArgs.Length-1)]
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAIL - Failed to start Jekyll" -ForegroundColor Red
    exit 1
}

# Wait for Jekyll to be ready
if (-not (Wait-ForJekyll)) {
    Write-Host "FAIL - Build failed - Jekyll startup timeout" -ForegroundColor Red
    
    # Show recent logs for debugging
    Write-Host "`nRecent Jekyll logs:" -ForegroundColor Yellow
    & $dockerComposeCmd.Split() logs --tail=20 jekyll
    exit 1
}

$startupTime = (Get-Date) - $startTime
Write-Host "PASS - Jekyll started successfully ($([Math]::Round($startupTime.TotalSeconds, 1))s total)" -ForegroundColor Green

# Step 5: Generate PDFs (if not skipped)
if (-not $SkipPDFs) {
    Write-Host "`nGenerating PDFs..." -ForegroundColor Cyan
    
    # Start PDF generation as background job for better responsiveness
    $pdfJob = Start-Job -ScriptBlock {
        param($dockerComposeCmd)
        $pdfArgs = $dockerComposeCmd.Split() + @("run", "--rm", "pdf-generator")
        & $pdfArgs[0] $pdfArgs[1..($pdfArgs.Length-1)]
    } -ArgumentList $dockerComposeCmd
    
    # Show progress while PDF generation runs
    $pdfStartTime = Get-Date
    do {
        Start-Sleep -Seconds 2
        $elapsed = (Get-Date) - $pdfStartTime
        Write-Host "   PDF generation in progress... ($([Math]::Round($elapsed.TotalSeconds, 0))s)" -ForegroundColor Yellow
    } while ($pdfJob.State -eq "Running" -and $elapsed.TotalSeconds -lt 120)
    
    $pdfResult = Receive-Job -Job $pdfJob -Wait
    if ($pdfJob.State -eq "Completed") {
        Write-Host "PASS - PDF generation completed successfully!" -ForegroundColor Green
        
        # Update latest PDF files from newly generated timestamped versions
        Write-Host "Updating latest PDF files from newly generated versions..." -ForegroundColor Yellow
        
        $pdfTypes = @("troop-handbook", "contact-info")
        foreach ($pdfType in $pdfTypes) {
            $mostRecentPDF = Get-ChildItem "assets/files/handbook/$pdfType-20*.pdf" -ErrorAction SilentlyContinue | 
                             Sort-Object LastWriteTime -Descending | 
                             Select-Object -First 1
            
            $latestPath = "assets/files/handbook/$pdfType-latest.pdf"
            
            if ($mostRecentPDF) {
                # Remove existing latest file if it exists
                if (Test-Path $latestPath) {
                    Remove-Item $latestPath -Force
                }
                
                Copy-Item $mostRecentPDF.FullName $latestPath
                $sizeKB = [Math]::Round($mostRecentPDF.Length / 1024, 1)
                Write-Host "PASS - Updated $pdfType-latest.pdf from $($mostRecentPDF.Name) ($sizeKB KB)" -ForegroundColor Green
            } else {
                Write-Host "WARN - No timestamped $pdfType PDF found to copy" -ForegroundColor Yellow
            }
        }
        
        # Update handbook page with cache-busting timestamp
        Write-Host "Updating handbook page with cache-busting parameters..." -ForegroundColor Yellow
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $handbookPath = "pages/handbook.md"
        
        if (Test-Path $handbookPath) {
            $content = Get-Content $handbookPath -Raw
            
            # Update PDF links with cache-busting parameters
            $content = $content -replace 
                '\[2025 Troop Handbook\]\(/assets/files/handbook/troop-handbook-latest\.pdf[^)]*\)', 
                "[2025 Troop Handbook](/assets/files/handbook/troop-handbook-latest.pdf?v=$timestamp)"
            
            $content = $content -replace 
                '\[Contact Directory\]\(/assets/files/handbook/contact-info-latest\.pdf[^)]*\)', 
                "[Contact Directory](/assets/files/handbook/contact-info-latest.pdf?v=$timestamp)"
            
            Set-Content -Path $handbookPath -Value $content -NoNewline
            Write-Host "PASS - Updated handbook page with cache-busting timestamp: $timestamp" -ForegroundColor Green
        } else {
            Write-Host "WARN - handbook.md not found, skipping cache-busting update" -ForegroundColor Yellow
        }
    } else {
        Write-Host "FAIL - PDF generation failed or timed out" -ForegroundColor Red
        Write-Host $pdfResult
    }
    Remove-Job -Job $pdfJob -Force
} else {
    Write-Host "`nSkipping PDF generation" -ForegroundColor Yellow
    
    # Even when skipping PDF generation, ensure latest files exist from previous runs
    Write-Host "Ensuring latest PDF files exist from previous generations..." -ForegroundColor Yellow
    
    $pdfTypes = @("troop-handbook", "contact-info")
    foreach ($pdfType in $pdfTypes) {
        $latestPath = "assets/files/handbook/$pdfType-latest.pdf"
        
        if (-not (Test-Path $latestPath)) {
            # Find most recent timestamped PDF to use as latest
            $mostRecentPDF = Get-ChildItem "assets/files/handbook/$pdfType-20*.pdf" -ErrorAction SilentlyContinue | 
                             Sort-Object LastWriteTime -Descending | 
                             Select-Object -First 1
            
            if ($mostRecentPDF) {
                Copy-Item $mostRecentPDF.FullName $latestPath
                $sizeKB = [Math]::Round($mostRecentPDF.Length / 1024, 1)
                Write-Host "PASS - Created $pdfType-latest.pdf from $($mostRecentPDF.Name) ($sizeKB KB)" -ForegroundColor Green
            } else {
                # Create minimal placeholder if no PDFs exist
                $pdfContent = @"
%PDF-1.4
1 0 obj
<< /Type /Catalog /Pages 2 0 R >>
endobj
2 0 obj
<< /Type /Pages /Kids [3 0 R] /Count 1 >>
endobj
3 0 obj
<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] >>
endobj
xref
0 4
0000000000 65535 f 
0000000010 00000 n 
0000000056 00000 n 
0000000111 00000 n 
trailer
<< /Size 4 /Root 1 0 R >>
startxref
180
%%EOF
"@
                $pdfContent | Out-File -FilePath $latestPath -Encoding ASCII -NoNewline
                Write-Host "WARN - Created minimal placeholder for $pdfType-latest.pdf (no previous generation found)" -ForegroundColor Yellow
            }
        } else {
            $existingSize = [Math]::Round((Get-Item $latestPath).Length / 1024, 1)
            Write-Host "PASS - $pdfType-latest.pdf already exists ($existingSize KB)" -ForegroundColor Green
        }
    }
}

# Step 6: Test website (if not skipped)
if (-not $SkipTests) {
    Write-Host "`nTesting website endpoints..." -ForegroundColor Cyan
    $failedTests = 0
    
    # Core pages (run in parallel for speed)
    $testJobs = @()
    $tests = @(
        @{ Url = "http://localhost:4000"; Name = "Homepage" },
        @{ Url = "http://localhost:4000/handbook"; Name = "Handbook page" },
        @{ Url = "http://localhost:4000/about"; Name = "About page" },
        @{ Url = "http://localhost:4000/events"; Name = "Events page" }
    )
    
    foreach ($test in $tests) {
        $testJobs += Start-Job -ScriptBlock {
            param($url, $name)
            try {
                $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 10
                return @{ Success = ($response.StatusCode -eq 200); Name = $name; Status = $response.StatusCode }
            } catch {
                return @{ Success = $false; Name = $name; Error = $_.Exception.Message }
            }
        } -ArgumentList $test.Url, $test.Name
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
    
    # Test PDF files (if they were generated)
    if (-not $SkipPDFs) {
        if (-not (Test-Url "http://localhost:4000/assets/files/handbook/troop-handbook-latest.pdf" "Latest handbook PDF")) { $failedTests++ }
        if (-not (Test-Url "http://localhost:4000/assets/files/handbook/contact-info-latest.pdf" "Latest contact info PDF")) { $failedTests++ }
    }
    
    # Report test results
    Write-Host ""
    if ($failedTests -eq 0) {
        Write-Host "PASS - All tests passed!" -ForegroundColor Green
    } else {
        Write-Host "FAIL - $failedTests test(s) failed" -ForegroundColor Red
    }
} else {
    Write-Host "`nSkipping endpoint tests" -ForegroundColor Yellow
    $failedTests = 0
}

# Final summary
$totalTime = (Get-Date) - $startTime
Write-Host @"

Build Summary
=============
Total time: $([Math]::Round($totalTime.TotalMinutes, 1)) minutes
Build type: $(if ($NoCache) { "Clean (no cache)" } else { "Incremental (cached)" })
PDFs: $(if ($SkipPDFs) { "Skipped" } else { "Generated" })
Tests: $(if ($SkipTests) { "Skipped" } else { if ($failedTests -eq 0) { "PASS" } else { "FAIL ($failedTests failed)" } })

Jekyll is running at: http://localhost:4000
Container status:
"@ -ForegroundColor Cyan

& $dockerComposeCmd.Split() ps

if ($failedTests -eq 0) {
    Write-Host "`nSUCCESS - Build completed successfully!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`nWARNING - Build completed with issues" -ForegroundColor Yellow
    exit 1
}
