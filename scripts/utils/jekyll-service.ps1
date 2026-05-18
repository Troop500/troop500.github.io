#!/usr/bin/env pwsh
#
# Jekyll Service Management Module
# ===============================
# 
# This module provides functions for managing Jekyll services and waiting for 
# Jekyll to become available for testing purposes.
#

param(
    [ValidateSet('start', 'stop', 'restart', 'status', 'logs', 'wait', 'test-docker')]
    [string]$Action = 'status',
    
    [string]$BaseUrl = "http://localhost:4000",
    [string]$ComposeFile = "docker-compose.yml", 
    [string]$ServiceName = "jekyll",
    [int]$TimeoutSec = 60,
    [int]$LogLines = 50,
    [switch]$Wait,
    [switch]$Help
)

# Function to wait for Jekyll to become available
function Wait-ForJekyll {
    param(
        [string]$BaseUrl = "http://localhost:4000",
        [int]$TimeoutSec = 60,
        [int]$CheckIntervalSec = 2
    )
    
    Write-Host "Waiting for Jekyll to become available at $BaseUrl..." -ForegroundColor Cyan
    
    $startTime = Get-Date
    $elapsed = 0
    
    while ($elapsed -lt $TimeoutSec) {
        try {
            $response = Invoke-WebRequest -Uri $BaseUrl -UseBasicParsing -TimeoutSec 3
            if ($response.StatusCode -eq 200) {
                Write-Host "[SUCCESS] Jekyll is available (took $([Math]::Round($elapsed, 1)) seconds)" -ForegroundColor Green
                return $true
            }
        } catch {
            # Continue waiting
        }
        
        Start-Sleep -Seconds $CheckIntervalSec
        $elapsed = ((Get-Date) - $startTime).TotalSeconds
        
        # Progress indicator
        if ($elapsed % 10 -eq 0) {
            Write-Host "  Still waiting... ($([Math]::Round($elapsed, 0))s elapsed)" -ForegroundColor Yellow
        }
    }
    
    Write-Host "[TIMEOUT] Jekyll did not become available within $TimeoutSec seconds" -ForegroundColor Red
    return $false
}

# Function to check Jekyll service status
function Test-JekyllService {
    param(
        [string]$BaseUrl = "http://localhost:4000",
        [int]$TimeoutSec = 5
    )
    
    try {
        $response = Invoke-WebRequest -Uri $BaseUrl -UseBasicParsing -TimeoutSec $TimeoutSec
        if ($response.StatusCode -eq 200) {
            Write-Host "[RUNNING] Jekyll service is running at $BaseUrl" -ForegroundColor Green
            return $true
        } else {
            Write-Host "[ERROR] Jekyll returned status $($response.StatusCode)" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "[NOT RUNNING] Jekyll service not available: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to start Jekyll service via Docker Compose
function Start-JekyllService {
    param(
        [string]$ComposeFile = "docker-compose.yml",
        [string]$ServiceName = "jekyll",
        [switch]$Wait
    )
    
    Write-Host "Starting Jekyll service..." -ForegroundColor Cyan
    
    if (-not (Test-Path $ComposeFile)) {
        Write-Host "[ERROR] Docker Compose file not found: $ComposeFile" -ForegroundColor Red
        return $false
    }
    
    try {
        # Start the Jekyll service
        & docker-compose -f $ComposeFile up -d $ServiceName
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[ERROR] Failed to start Jekyll service" -ForegroundColor Red
            return $false
        }
        
        Write-Host "[SUCCESS] Jekyll service started" -ForegroundColor Green
        
        # Wait for service to become available if requested
        if ($Wait) {
            return Wait-ForJekyll
        }
        
        return $true
    } catch {
        Write-Host "[ERROR] Exception starting Jekyll: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to stop Jekyll service
function Stop-JekyllService {
    param(
        [string]$ComposeFile = "docker-compose.yml",
        [string]$ServiceName = "jekyll"
    )
    
    Write-Host "Stopping Jekyll service..." -ForegroundColor Cyan
    
    try {
        & docker-compose -f $ComposeFile stop $ServiceName
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[SUCCESS] Jekyll service stopped" -ForegroundColor Green
            return $true
        } else {
            Write-Host "[ERROR] Failed to stop Jekyll service" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "[ERROR] Exception stopping Jekyll: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to restart Jekyll service
function Restart-JekyllService {
    param(
        [string]$ComposeFile = "docker-compose.yml",
        [string]$ServiceName = "jekyll",
        [switch]$Wait
    )
    
    Write-Host "Restarting Jekyll service..." -ForegroundColor Cyan
    
    # Stop first
    Stop-JekyllService -ComposeFile $ComposeFile -ServiceName $ServiceName
    Start-Sleep -Seconds 2
    
    # Start again
    return Start-JekyllService -ComposeFile $ComposeFile -ServiceName $ServiceName -Wait:$Wait
}

# Function to get Jekyll service logs
function Get-JekyllLogs {
    param(
        [string]$ComposeFile = "docker-compose.yml",
        [string]$ServiceName = "jekyll",
        [int]$Lines = 50
    )
    
    Write-Host "Getting Jekyll service logs (last $Lines lines)..." -ForegroundColor Cyan
    
    try {
        & docker-compose -f $ComposeFile logs --tail $Lines $ServiceName
        return $true
    } catch {
        Write-Host "[ERROR] Failed to get Jekyll logs: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to check if Docker and Docker Compose are available
function Test-DockerEnvironment {
    $dockerAvailable = $false
    $composeAvailable = $false
    
    try {
        & docker --version > $null 2>&1
        if ($LASTEXITCODE -eq 0) {
            $dockerAvailable = $true
            Write-Host "[AVAILABLE] Docker is installed" -ForegroundColor Green
        }
    } catch {
        Write-Host "[NOT AVAILABLE] Docker is not installed or not in PATH" -ForegroundColor Red
    }
    
    try {
        & docker-compose --version > $null 2>&1
        if ($LASTEXITCODE -eq 0) {
            $composeAvailable = $true
            Write-Host "[AVAILABLE] Docker Compose is installed" -ForegroundColor Green
        }
    } catch {
        Write-Host "[NOT AVAILABLE] Docker Compose is not installed or not in PATH" -ForegroundColor Red
    }
    
    return ($dockerAvailable -and $composeAvailable)
}

# Functions are automatically available when dot-sourced
# No need for Export-ModuleMember when using dot-sourcing

# Main script execution when run directly
if ($Help) {
        Write-Host @"
Jekyll Service Management Module

USAGE:
    .\jekyll-service.ps1 [-Action <action>] [OPTIONS] [-Help]

ACTIONS:
    start        Start Jekyll service via Docker Compose
    stop         Stop Jekyll service
    restart      Restart Jekyll service
    status       Check Jekyll service status
    logs         Show Jekyll service logs
    wait         Wait for Jekyll to become available
    test-docker  Test Docker environment

OPTIONS:
    -BaseUrl      Base URL for Jekyll (default: http://localhost:4000)
    -ComposeFile  Docker Compose file path (default: docker-compose.yml)
    -ServiceName  Docker service name (default: jekyll)
    -TimeoutSec   Timeout in seconds for wait operations (default: 60)
    -LogLines     Number of log lines to show (default: 50)
    -Wait         Wait for service to become available after start/restart
    -Help         Show this help message

EXAMPLES:
    .\jekyll-service.ps1 -Action start -Wait     # Start Jekyll and wait for availability
    .\jekyll-service.ps1 -Action status          # Check if Jekyll is running
    .\jekyll-service.ps1 -Action logs            # Show recent logs
    .\jekyll-service.ps1 -Action restart -Wait   # Restart and wait

This module can also be imported into other scripts:
    . .\jekyll-service.ps1
    Wait-ForJekyll
    Test-JekyllService
"@
    exit 0
}

# Main command execution if not being imported as module
if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "Jekyll Service Management" -ForegroundColor Cyan
    Write-Host "=========================" -ForegroundColor Cyan
    
    switch ($Action) {
        'start' {
            if (Start-JekyllService -ComposeFile $ComposeFile -ServiceName $ServiceName -Wait:$Wait) {
                exit 0
            } else {
                exit 1
            }
        }
        
        'stop' {
            if (Stop-JekyllService -ComposeFile $ComposeFile -ServiceName $ServiceName) {
                exit 0
            } else {
                exit 1
            }
        }
        
        'restart' {
            if (Restart-JekyllService -ComposeFile $ComposeFile -ServiceName $ServiceName -Wait:$Wait) {
                exit 0
            } else {
                exit 1
            }
        }
        
        'status' {
            if (Test-JekyllService -BaseUrl $BaseUrl) {
                exit 0
            } else {
                exit 1
            }
        }
        
        'logs' {
            if (Get-JekyllLogs -ComposeFile $ComposeFile -ServiceName $ServiceName -Lines $LogLines) {
                exit 0
            } else {
                exit 1
            }
        }
        
        'wait' {
            if (Wait-ForJekyll -BaseUrl $BaseUrl -TimeoutSec $TimeoutSec) {
                exit 0
            } else {
                exit 1
            }
        }
        
        'test-docker' {
            if (Test-DockerEnvironment) {
                Write-Host "`nDocker environment is ready for Jekyll operations" -ForegroundColor Green
                exit 0
            } else {
                Write-Host "`nDocker environment is not properly configured" -ForegroundColor Red
                exit 1
            }
        }
        
        default {
            Write-Host "Unknown action: $Action" -ForegroundColor Red
            Write-Host "Use -Help for usage information" -ForegroundColor Yellow
            exit 1
        }
    }
}
