# Compare two npm audit JSON reports
# Detects newly introduced advisories and severity increases

param(
    [Parameter(Mandatory = $true)]
    [string]$BaselineFile,

    [Parameter(Mandatory = $true)]
    [string]$CurrentFile
)

$baseline = Get-Content $BaselineFile -Raw | ConvertFrom-Json
$current = Get-Content $CurrentFile -Raw | ConvertFrom-Json

Write-Host "======================================"
Write-Host "       NPM AUDIT SECURITY GATE"
Write-Host "======================================"

Write-Host ""
Write-Host "Baseline vulnerabilities : $($baseline.metadata.vulnerabilities.total)"
Write-Host "Current vulnerabilities  : $($current.metadata.vulnerabilities.total)"
Write-Host ""

# --------------------------------------------------
# 1. Extract advisory IDs from an npm audit report
# --------------------------------------------------

function Get-AdvisoryIds($report) {

    $advisories = @{}

    foreach ($package in $report.vulnerabilities.PSObject.Properties) {

        $packageName = $package.Name
        $packageData = $package.Value

        foreach ($item in @($packageData.via)) {

            # npm audit "via" can contain either:
            # - an advisory object
            # - a dependency/package name

            if ($item -is [string]) {
                continue
            }

            if ($null -ne $item.source) {

                $advisoryId = [string]$item.source

                $advisories[$advisoryId] = [PSCustomObject]@{
                    Package  = $packageName
                    Severity = $item.severity
                    Title    = $item.title
                }
            }
        }
    }

    return $advisories
}

$baselineAdvisories = Get-AdvisoryIds $baseline
$currentAdvisories = Get-AdvisoryIds $current

# --------------------------------------------------
# 2. Detect newly introduced advisories
# --------------------------------------------------

$newAdvisories = @(
    $currentAdvisories.Keys | Where-Object {
        $_ -notin $baselineAdvisories.Keys
    }
)

# --------------------------------------------------
# 3. Detect severity increases
# --------------------------------------------------

$severityOrder = @{
    info     = 0
    low      = 1
    moderate = 2
    high     = 3
    critical = 4
}

$severityIncreases = @()

foreach ($advisoryId in $currentAdvisories.Keys) {

    if ($advisoryId -in $baselineAdvisories.Keys) {

        $baselineSeverity = $baselineAdvisories[$advisoryId].Severity
        $currentSeverity = $currentAdvisories[$advisoryId].Severity

        if (
            $severityOrder.ContainsKey($baselineSeverity) -and
            $severityOrder.ContainsKey($currentSeverity) -and
            $severityOrder[$currentSeverity] -gt $severityOrder[$baselineSeverity]
        ) {

            $severityIncreases += [PSCustomObject]@{
                Advisory = $advisoryId
                Package  = $currentAdvisories[$advisoryId].Package
                From     = $baselineSeverity
                To       = $currentSeverity
            }
        }
    }
}

# --------------------------------------------------
# 4. Display newly introduced advisories
# --------------------------------------------------

if ($newAdvisories.Count -gt 0) {

    Write-Host "New advisories detected:"
    Write-Host ""

    foreach ($advisoryId in $newAdvisories) {

        $advisory = $currentAdvisories[$advisoryId]

        Write-Host "Advisory : $advisoryId"
        Write-Host "Package  : $($advisory.Package)"
        Write-Host "Severity : $($advisory.Severity)"
        Write-Host "Title    : $($advisory.Title)"
        Write-Host ""
    }
}

# --------------------------------------------------
# 5. Display severity increases
# --------------------------------------------------

if ($severityIncreases.Count -gt 0) {

    Write-Host "Severity increases detected:"
    Write-Host ""

    foreach ($item in $severityIncreases) {

        Write-Host "$($item.Advisory) | $($item.Package) | $($item.From) -> $($item.To)"
    }

    Write-Host ""
}

# --------------------------------------------------
# 6. Security Gate
# --------------------------------------------------

if (
    $newAdvisories.Count -eq 0 -and
    $severityIncreases.Count -eq 0
) {

    Write-Host "PASS: No new advisories or severity increases detected."

    exit 0
}

# Check for newly introduced Critical advisories
$newCritical = @(
    $newAdvisories | Where-Object {
        $currentAdvisories[$_].Severity -eq "critical"
    }
)

# Check for severity increases to Critical
$criticalIncrease = @(
    $severityIncreases | Where-Object {
        $_.To -eq "critical"
    }
)

if (
    $newCritical.Count -gt 0 -or
    $criticalIncrease.Count -gt 0
) {

    Write-Host "FAIL: New critical vulnerabilities detected."

    exit 1
}

Write-Host "WARNING: New vulnerabilities detected, but none are critical."

exit 0