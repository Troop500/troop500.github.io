param(
    [string]$FeedUrl = "https://api.scouting.org/advancements/events/calendar/126388",
    [string]$OutputPath = "_data/scoutbook-events.json",
    [int]$MaxEvents = 75,
    [string]$FallbackTimeZone = "Eastern Standard Time"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Convert-IcsText {
    param([string]$Value)

    if ([string]::IsNullOrEmpty($Value)) {
        return ""
    }

    $text = $Value -replace "\\n", "`n"
    $text = $text -replace "\\,", ","
    $text = $text -replace "\\;", ";"
    $text = $text -replace "\\\\", "\\"
    return $text.Trim()
}

function Get-UnfoldedIcsLines {
    param([string]$RawContent)

    $lines = $RawContent -split "`r?`n"
    $unfolded = New-Object System.Collections.Generic.List[string]

    foreach ($line in $lines) {
        if ($line -match '^[ \t]' -and $unfolded.Count -gt 0) {
            $unfolded[$unfolded.Count - 1] += $line.Substring(1)
        }
        else {
            $unfolded.Add($line)
        }
    }

    return $unfolded
}

function Resolve-TimeZoneId {
    param([string]$RequestedId)

    $primary = $RequestedId
    if ([string]::IsNullOrWhiteSpace($primary)) {
        $primary = $FallbackTimeZone
    }

    $candidates = New-Object System.Collections.Generic.List[string]
    $candidates.Add($primary)

    switch ($primary) {
        "America/New_York" {
            $candidates.Add("Eastern Standard Time")
        }
        "US/Eastern" {
            $candidates.Add("America/New_York")
            $candidates.Add("Eastern Standard Time")
        }
        "Eastern Standard Time" {
            $candidates.Add("America/New_York")
        }
    }

    $candidates.Add("UTC")

    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        try {
            [void][TimeZoneInfo]::FindSystemTimeZoneById($candidate)
            return $candidate
        }
        catch {
            continue
        }
    }

    return "UTC"
}

function Parse-IcsDateTime {
    param(
        [string]$PropertyPart,
        [string]$RawValue,
        [string]$DefaultTimeZone
    )

    $isAllDay = $PropertyPart -match "VALUE=DATE"
    $tzid = $null
    if ($PropertyPart -match "TZID=([^;:]+)") {
        $tzid = $Matches[1]
    }

    $timeZoneInput = $DefaultTimeZone
    if (-not [string]::IsNullOrWhiteSpace($tzid)) {
        $timeZoneInput = $tzid
    }

    $timezoneToUse = Resolve-TimeZoneId -RequestedId $timeZoneInput
    $tz = [TimeZoneInfo]::FindSystemTimeZoneById($timezoneToUse)

    if ($isAllDay) {
        $localDate = [datetime]::ParseExact($RawValue, "yyyyMMdd", [System.Globalization.CultureInfo]::InvariantCulture)
        $utcDate = [TimeZoneInfo]::ConvertTimeToUtc($localDate, $tz)
        return [pscustomobject]@{
            LocalDateTime = $localDate
            UtcDateTime = $utcDate
            IsAllDay = $true
        }
    }

    if ($RawValue -match "Z$") {
        $utc = [datetime]::ParseExact($RawValue, "yyyyMMdd'T'HHmmss'Z'", [System.Globalization.CultureInfo]::InvariantCulture, ([System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal))
        $localInConfiguredZone = [TimeZoneInfo]::ConvertTimeFromUtc($utc, $tz)
        return [pscustomobject]@{
            LocalDateTime = $localInConfiguredZone
            UtcDateTime = $utc
            IsAllDay = $false
        }
    }

    $local = [datetime]::ParseExact($RawValue, "yyyyMMdd'T'HHmmss", [System.Globalization.CultureInfo]::InvariantCulture)
    $utcTime = [TimeZoneInfo]::ConvertTimeToUtc($local, $tz)

    return [pscustomobject]@{
        LocalDateTime = $local
        UtcDateTime = $utcTime
        IsAllDay = $false
    }
}

function Format-DisplayLine {
    param(
        [datetime]$Start,
        [datetime]$End,
        [bool]$IsAllDay,
        [string]$Title
    )

    if ([string]::IsNullOrWhiteSpace($Title)) {
        $Title = "Untitled Event"
    }

    if ($IsAllDay) {
        if ($End -gt $Start.AddDays(1)) {
            return "{0} - {1}: {2}" -f $Start.ToString("M/d"), $End.AddDays(-1).ToString("M/d"), $Title
        }

        return "{0}: {1}" -f $Start.ToString("M/d"), $Title
    }

    if ($Start.Date -eq $End.Date) {
        return "{0} {1} - {2}: {3}" -f $Start.ToString("M/d"), $Start.ToString("h:mmtt").ToLower(), $End.ToString("h:mmtt").ToLower(), $Title
    }

    return "{0} {1} - {2} {3}: {4}" -f $Start.ToString("M/d"), $Start.ToString("h:mmtt").ToLower(), $End.ToString("M/d"), $End.ToString("h:mmtt").ToLower(), $Title
}

Write-Host "Fetching iCal feed..."
$response = Invoke-WebRequest -Uri $FeedUrl -UseBasicParsing -TimeoutSec 30
$lines = Get-UnfoldedIcsLines -RawContent $response.Content

$events = New-Object System.Collections.Generic.List[object]
$current = $null

foreach ($line in $lines) {
    if ($line -eq "BEGIN:VEVENT") {
        $current = @{}
        continue
    }

    if ($line -eq "END:VEVENT") {
        if ($null -ne $current) {
            $title = Convert-IcsText -Value ($current["SUMMARY"])
            $description = Convert-IcsText -Value ($current["DESCRIPTION"])
            $location = Convert-IcsText -Value ($current["LOCATION"])
            $url = Convert-IcsText -Value ($current["URL"])
            $uid = Convert-IcsText -Value ($current["UID"])

            if ($current.ContainsKey("DTSTART") -and $current.ContainsKey("DTEND")) {
                $startParts = $current["DTSTART"]
                $endParts = $current["DTEND"]

                $startParsed = Parse-IcsDateTime -PropertyPart $startParts.Property -RawValue $startParts.Value -DefaultTimeZone $FallbackTimeZone
                $endParsed = Parse-IcsDateTime -PropertyPart $endParts.Property -RawValue $endParts.Value -DefaultTimeZone $FallbackTimeZone

                $display = Format-DisplayLine -Start $startParsed.LocalDateTime -End $endParsed.LocalDateTime -IsAllDay $startParsed.IsAllDay -Title $title

                $events.Add([pscustomobject]@{
                    uid = $uid
                    title = $title
                    description = $description
                    location = $location
                    url = $url
                    start = $startParsed.LocalDateTime.ToString("yyyy-MM-ddTHH:mm:ss")
                    end = $endParsed.LocalDateTime.ToString("yyyy-MM-ddTHH:mm:ss")
                    allDay = $startParsed.IsAllDay
                    display = $display
                    startUtc = $startParsed.UtcDateTime
                })
            }
        }

        $current = $null
        continue
    }

    if ($null -eq $current) {
        continue
    }

    $firstColonIndex = $line.IndexOf(":")
    if ($firstColonIndex -lt 1) {
        continue
    }

    $propertyPart = $line.Substring(0, $firstColonIndex)
    $valuePart = $line.Substring($firstColonIndex + 1)
    $propertyName = $propertyPart.Split(";")[0]

    switch ($propertyName) {
        "DTSTART" {
            $current["DTSTART"] = [pscustomobject]@{ Property = $propertyPart; Value = $valuePart }
        }
        "DTEND" {
            $current["DTEND"] = [pscustomobject]@{ Property = $propertyPart; Value = $valuePart }
        }
        "SUMMARY" { $current["SUMMARY"] = $valuePart }
        "DESCRIPTION" { $current["DESCRIPTION"] = $valuePart }
        "LOCATION" { $current["LOCATION"] = $valuePart }
        "URL" { $current["URL"] = $valuePart }
        "UID" { $current["UID"] = $valuePart }
    }
}

$todayUtc = (Get-Date).ToUniversalTime().AddDays(-1)
$filtered = $events |
    Where-Object { $_.startUtc -ge $todayUtc } |
    Sort-Object startUtc |
    Select-Object -First $MaxEvents

foreach ($item in $filtered) {
    $item.PSObject.Properties.Remove("startUtc")
}

$generatedAt = Get-Date
$displayTimeZoneId = Resolve-TimeZoneId -RequestedId $FallbackTimeZone
$displayTimeZone = [TimeZoneInfo]::FindSystemTimeZoneById($displayTimeZoneId)
$generatedAtDisplay = [TimeZoneInfo]::ConvertTime($generatedAt, $displayTimeZone)
$currentAsOfLabel = "Current as of {0}" -f $generatedAtDisplay.ToString("M/d/yyyy h:mm tt")

$output = [pscustomobject]@{
    generatedAt = $generatedAt.ToString("o")
    currentAsOf = $currentAsOfLabel
    source = $FeedUrl
    count = $filtered.Count
    events = $filtered
}

$outputDir = Split-Path -Path $OutputPath -Parent
if (-not [string]::IsNullOrWhiteSpace($outputDir) -and -not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$json = $output | ConvertTo-Json -Depth 10
Set-Content -Path $OutputPath -Value $json -Encoding UTF8

Write-Host "Wrote $($filtered.Count) events to $OutputPath"
