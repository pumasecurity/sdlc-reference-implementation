#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Check quality gates after all scans have completed and uploaded to SonarCloud
.DESCRIPTION
    This script runs AFTER all tests, security scans, and SonarCloud uploads complete.
    It checks for critical issues and fails the build if quality gates are not met.
    This ensures visibility in SonarCloud before failing the pipeline.

    Used by GitHub Actions CI pipeline (windows-latest runner).
.NOTES
    Quality Gates:
    - Test failures (from JUnit XML)
    - Critical security issues (ERROR severity from Semgrep)
    - SonarCloud quality gate (optional, requires API call)
#>

$ErrorActionPreference = "Continue"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Quality Gate Check" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

$hasFailures = $false
$failureReasons = @()

# Check 1: Test Results
Write-Host "Checking test results..." -ForegroundColor Yellow
$junitFile = "test-results\junit.xml"

if (Test-Path $junitFile) {
    Write-Host "  Using: $junitFile" -ForegroundColor Gray
    [xml]$junit = Get-Content $junitFile
    $totalTests = [int]$junit.testsuites.tests
    $failures = [int]$junit.testsuites.failures
    $errors = [int]$junit.testsuites.errors

    Write-Host "  Total Tests: $totalTests" -ForegroundColor Cyan
    Write-Host "  Failures: $failures" -ForegroundColor $(if ($failures -gt 0) { "Red" } else { "Green" })
    Write-Host "  Errors: $errors" -ForegroundColor $(if ($errors -gt 0) { "Red" } else { "Green" })

    if ($failures -gt 0 -or $errors -gt 0) {
        $hasFailures = $true
        $failureReasons += "Test failures: $failures failed, $errors errors"
    } else {
        Write-Host "  [OK] All tests passed" -ForegroundColor Green
    }
} else {
    Write-Host "  ERROR: Test results not found at: $junitFile" -ForegroundColor Red
    $hasFailures = $true
    $failureReasons += "Missing required test results file: junit.xml"
}

Write-Host ""

# Check 2: Security Scan Results (Semgrep)
Write-Host "Checking security scan results..." -ForegroundColor Yellow
$semgrepJson = "semgrep-results\semgrep.json"

if (Test-Path $semgrepJson) {
    Write-Host "  Using: $semgrepJson" -ForegroundColor Gray
    $semgrepResults = Get-Content $semgrepJson | ConvertFrom-Json

    $totalFindings = $semgrepResults.results.Count
    $errorFindings = @($semgrepResults.results | Where-Object { $_.extra.severity -eq "ERROR" })
    $warningFindings = @($semgrepResults.results | Where-Object { $_.extra.severity -eq "WARNING" })
    $infoFindings = @($semgrepResults.results | Where-Object { $_.extra.severity -eq "INFO" })

    Write-Host "  Total Security Findings: $totalFindings" -ForegroundColor Cyan
    Write-Host "  ERROR (Critical): $($errorFindings.Count)" -ForegroundColor $(if ($errorFindings.Count -gt 0) { "Red" } else { "Green" })
    Write-Host "  WARNING: $($warningFindings.Count)" -ForegroundColor $(if ($warningFindings.Count -gt 0) { "Yellow" } else { "Green" })
    Write-Host "  INFO: $($infoFindings.Count)" -ForegroundColor Blue

    if ($errorFindings.Count -gt 0) {
        $hasFailures = $true
        $failureReasons += "Critical security issues: $($errorFindings.Count) ERROR-level findings"

        Write-Host ""
        Write-Host "  Critical Security Issues:" -ForegroundColor Red
        foreach ($finding in $errorFindings) {
            $file = $finding.path
            $line = $finding.start.line
            $rule = $finding.check_id
            $message = $finding.extra.message
            Write-Host "    [$rule]" -ForegroundColor Red
            Write-Host "      File: $file`:$line" -ForegroundColor Gray
            Write-Host "      Issue: $message" -ForegroundColor Gray
        }
    } else {
        Write-Host "  [OK] No critical security issues" -ForegroundColor Green
    }
} else {
    Write-Host "  ERROR: Security scan results not found at: $semgrepJson" -ForegroundColor Red
    $hasFailures = $true
    $failureReasons += "Missing required security scan results file: semgrep.json"
}

Write-Host ""

# Check 3: Code Coverage (Optional Gate)
Write-Host "Checking code coverage..." -ForegroundColor Yellow
$coverageFile = "test-results\coverage.cobertura.xml"

if (Test-Path $coverageFile) {
    Write-Host "  Using: $coverageFile" -ForegroundColor Gray
    [xml]$coverage = Get-Content $coverageFile
    $lineRate = [double]$coverage.coverage.'line-rate'
    $lineCoverage = [math]::Round($lineRate * 100, 2)

    $minCoverage = 70  # Minimum coverage threshold

    Write-Host "  Line Coverage: $lineCoverage%" -ForegroundColor $(if ($lineCoverage -ge $minCoverage) { "Green" } else { "Yellow" })
    Write-Host "  Minimum Required: $minCoverage%" -ForegroundColor Gray

    if ($lineCoverage -lt $minCoverage) {
        Write-Host "  [WARNING] Coverage below threshold (not failing build)" -ForegroundColor Yellow
        # Uncomment to fail on low coverage:
        # $hasFailures = $true
        # $failureReasons += "Code coverage below minimum: $lineCoverage% < $minCoverage%"
    } else {
        Write-Host "  [OK] Coverage meets minimum threshold" -ForegroundColor Green
    }
} else {
    Write-Host "  WARNING: Coverage results not found at: $coverageFile" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan

# Final Decision
if ($hasFailures) {
    Write-Host "QUALITY GATE: FAILED" -ForegroundColor Red
    Write-Host "==========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Failure Reasons:" -ForegroundColor Red
    foreach ($reason in $failureReasons) {
        Write-Host "  - $reason" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "Note: All results have been uploaded to SonarCloud for review" -ForegroundColor Yellow
    Write-Host "View detailed analysis at: https://sonarcloud.io" -ForegroundColor Cyan
    Write-Host ""
    exit 1
} else {
    Write-Host "QUALITY GATE: PASSED" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "[OK] All quality gates passed" -ForegroundColor Green
    Write-Host ""
    exit 0
}
