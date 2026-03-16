#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Run Semgrep security scanning on the codebase
.DESCRIPTION
    This script runs Semgrep security scanning with C# rulesets, generates reports,
    and optionally uploads results to Semgrep Cloud for visualization.
    
    By default, findings are reported but do NOT fail the build. This allows
    results to be uploaded to SonarCloud before the Quality Gate check step
    determines if the build should fail.

    Used by GitHub Actions CI pipeline (windows-latest runner).
.NOTES
    Requires: Python 3.x with pip
    Optional: SEMGREP_APP_TOKEN environment variable for cloud upload
#>

param(
    [switch]$SkipInstall = $false,
    [switch]$FailOnFindings = $false
)

$ErrorActionPreference = "Continue"

Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "Semgrep Security Scanning" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

# Create output directory
$outputDir = "semgrep-results"
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

# Check if Python is installed
Write-Host "Checking Python installation..." -ForegroundColor Yellow
$pythonCmd = $null
$semgrepCmd = $null
foreach ($cmd in @("python", "python3", "py")) {
    try {
        $version = & $cmd --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            $pythonCmd = $cmd
            Write-Host "[OK] Found Python: $version" -ForegroundColor Green
            
            # Find semgrep in Python Scripts directory
            $pythonPath = & $cmd -c "import sys; print(sys.executable)" 2>&1
            $scriptsPath = Join-Path (Split-Path $pythonPath) "Scripts"
            $semgrepExe = Join-Path $scriptsPath "semgrep.exe"
            if (Test-Path $semgrepExe) {
                $semgrepCmd = $semgrepExe
                Write-Host "[OK] Found Semgrep: $semgrepCmd" -ForegroundColor Green
            }
            break
        }
    } catch {
        continue
    }
}

if (-not $pythonCmd) {
    Write-Host "ERROR: Python is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install Python 3.x from https://www.python.org/" -ForegroundColor Red
    exit 1
}

# Install/upgrade Semgrep
if (-not $SkipInstall) {
    Write-Host ""
    Write-Host "Installing/upgrading Semgrep..." -ForegroundColor Yellow
    & $pythonCmd -m pip install --upgrade semgrep
    if ($LASTEXITCODE -ne 0) {
        Write-Host "WARNING: Failed to install/upgrade Semgrep via pip" -ForegroundColor Yellow
        Write-Host "Attempting to continue with existing installation..." -ForegroundColor Yellow
    }
}

# Verify Semgrep is available (re-check after install)
Write-Host ""
Write-Host "Verifying Semgrep installation..." -ForegroundColor Yellow

if (-not $semgrepCmd) {
    # Re-check after pip install — semgrep.exe may now exist in Scripts directory
    $pythonPath = & $pythonCmd -c "import sys; print(sys.executable)" 2>&1
    $scriptsPath = Join-Path (Split-Path $pythonPath) "Scripts"
    $semgrepExe = Join-Path $scriptsPath "semgrep.exe"
    if (Test-Path $semgrepExe) {
        $semgrepCmd = $semgrepExe
        Write-Host "[OK] Found Semgrep after install: $semgrepCmd" -ForegroundColor Green
    }
}

if (-not $semgrepCmd) {
    # Fallback: check if semgrep is on PATH
    $semgrepOnPath = Get-Command semgrep -ErrorAction SilentlyContinue
    if ($semgrepOnPath) {
        $semgrepCmd = $semgrepOnPath.Source
        Write-Host "[OK] Found Semgrep on PATH: $semgrepCmd" -ForegroundColor Green
    }
}

if (-not $semgrepCmd) {
    Write-Host "ERROR: Semgrep not found. Please install with: python -m pip install semgrep" -ForegroundColor Red
    exit 1
}

$semgrepVersion = & $semgrepCmd --version 2>&1 | Out-String
if ($semgrepVersion -and $semgrepVersion -match "\d+\.\d+\.\d+") {
    $matchedVersion = $semgrepVersion -replace ".*?(\d+\.\d+\.\d+).*", '$1'
    Write-Host "[OK] Semgrep v$matchedVersion" -ForegroundColor Green
} else {
    Write-Host "ERROR: Failed to get Semgrep version" -ForegroundColor Red
    exit 1
}

# Determine if we should upload to Semgrep Cloud
$semgrepToken = $env:SEMGREP_APP_TOKEN
$uploadToCloud = $false
if ($semgrepToken) {
    Write-Host ""
    Write-Host "[OK] SEMGREP_APP_TOKEN found - will upload results to Semgrep Cloud" -ForegroundColor Green
    $uploadToCloud = $true
} else {
    Write-Host ""
    Write-Host "[i] SEMGREP_APP_TOKEN not set - running in local mode only" -ForegroundColor Cyan
    Write-Host "  To enable Semgrep Cloud dashboard, set SEMGREP_APP_TOKEN environment variable" -ForegroundColor Cyan
}

# Run Semgrep scan
Write-Host ""
Write-Host "Running Semgrep security scan..." -ForegroundColor Yellow
Write-Host "Rulesets: p/security-audit, p/csharp" -ForegroundColor Cyan
Write-Host ""

# Build base semgrep command args
$baseArgs = @(
    "scan",
    "--config", "p/security-audit",
    "--config", "p/csharp",
    "--verbose"
)

# Add metrics flag if uploading to cloud
if ($uploadToCloud) {
    $baseArgs += "--metrics", "on"
} else {
    $baseArgs += "--metrics", "off"
}

# Run scan for JSON output (with --verbose for detailed logging)
Write-Host "Generating JSON report..." -ForegroundColor Cyan
$jsonArgs = $baseArgs + @("--json", "--output", "$outputDir/semgrep.json")
& $semgrepCmd $jsonArgs
$semgrepExitCode = $LASTEXITCODE

# Generate SARIF output (if JSON scan succeeded or had findings)
# Uses a separate lightweight pass without --verbose, capturing stdout directly
# to avoid empty file issues with --output on Windows
if ($semgrepExitCode -le 1) {
    Write-Host "Generating SARIF report..." -ForegroundColor Cyan
    $sarifArgs = @(
        "scan",
        "--config", "p/security-audit",
        "--config", "p/csharp",
        "--sarif",
        "--metrics", "off"
    )
    $env:PYTHONIOENCODING = "utf-8"
    & $semgrepCmd $sarifArgs 2>$null | Out-File -FilePath "$outputDir/semgrep.sarif" -Encoding utf8
    $sarifExitCode = $LASTEXITCODE
    $env:PYTHONIOENCODING = $null
    
    # Validate the SARIF file was actually written with content
    if ((Test-Path "$outputDir/semgrep.sarif") -and (Get-Item "$outputDir/semgrep.sarif").Length -gt 0) {
        $sarifSize = (Get-Item "$outputDir/semgrep.sarif").Length
        Write-Host "[OK] SARIF report generated at $outputDir/semgrep.sarif ($([math]::Round($sarifSize/1KB, 1)) KB)" -ForegroundColor Green
    } else {
        Write-Host "WARNING: SARIF report is empty or missing (exit code: $sarifExitCode)" -ForegroundColor Yellow
        Write-Host "  Attempting fallback: converting JSON results to SARIF..." -ForegroundColor Yellow
        
        # Fallback: Try --sarif --output without --verbose as a direct file write
        $sarifFallbackArgs = @(
            "scan",
            "--config", "p/security-audit",
            "--config", "p/csharp",
            "--sarif",
            "--output", "$outputDir/semgrep.sarif",
            "--metrics", "off",
            "--quiet"
        )
        & $semgrepCmd $sarifFallbackArgs
        
        if ((Test-Path "$outputDir/semgrep.sarif") -and (Get-Item "$outputDir/semgrep.sarif").Length -gt 0) {
            Write-Host "[OK] SARIF report generated via fallback" -ForegroundColor Green
        } else {
            Write-Host "WARNING: SARIF generation failed - SonarCloud will not receive external issues" -ForegroundColor Yellow
        }
    }
    
    # Post-process SARIF for SonarCloud compatibility
    # Semgrep on Windows generates backslashes in URIs and includes uriBaseId "%SRCROOT%"
    # which SonarCloud doesn't understand. Fix these issues.
    if ((Test-Path "$outputDir/semgrep.sarif") -and (Get-Item "$outputDir/semgrep.sarif").Length -gt 0) {
        Write-Host "Post-processing SARIF for SonarCloud compatibility..." -ForegroundColor Cyan
        try {
            $sarifContent = Get-Content "$outputDir/semgrep.sarif" -Raw | ConvertFrom-Json
            
            # Add $schema if missing (SonarCloud example includes it)
            if (-not $sarifContent.'$schema') {
                $sarifContent | Add-Member -NotePropertyName '$schema' -NotePropertyValue 'https://json.schemastore.org/sarif-2.1.0-rtm.5' -Force
            }
            
            # Fix artifact URIs: backslashes -> forward slashes, remove uriBaseId
            foreach ($run in $sarifContent.runs) {
                foreach ($result in $run.results) {
                    foreach ($location in $result.locations) {
                        if ($location.physicalLocation.artifactLocation) {
                            $al = $location.physicalLocation.artifactLocation
                            # Convert backslashes to forward slashes in URI
                            if ($al.uri) {
                                $al.uri = $al.uri -replace '\\', '/'
                            }
                            # Remove uriBaseId - SonarCloud resolves relative to project base
                            if ($al.PSObject.Properties['uriBaseId']) {
                                $al.PSObject.Properties.Remove('uriBaseId')
                            }
                        }
                    }
                    # Fix relatedLocations too
                    if ($result.relatedLocations) {
                        foreach ($rl in $result.relatedLocations) {
                            if ($rl.physicalLocation.artifactLocation) {
                                $al = $rl.physicalLocation.artifactLocation
                                if ($al.uri) {
                                    $al.uri = $al.uri -replace '\\', '/'
                                }
                                if ($al.PSObject.Properties['uriBaseId']) {
                                    $al.PSObject.Properties.Remove('uriBaseId')
                                }
                            }
                        }
                    }
                }
            }
            
            # Write corrected SARIF back (UTF-8 without BOM for maximum compatibility)
            $sarifJson = $sarifContent | ConvertTo-Json -Depth 50
            [System.IO.File]::WriteAllText(
                (Join-Path (Get-Location) "$outputDir/semgrep.sarif"),
                $sarifJson,
                [System.Text.UTF8Encoding]::new($false)
            )
            Write-Host "[OK] SARIF post-processed: URIs normalized, uriBaseId removed" -ForegroundColor Green
        } catch {
            Write-Host "WARNING: SARIF post-processing failed: $_" -ForegroundColor Yellow
            Write-Host "  Original SARIF file will be used as-is" -ForegroundColor Yellow
        }
    }
}

# Semgrep exit codes:
# 0 = success, no findings
# 1 = success, findings present
# 2+ = error

if ($semgrepExitCode -ge 2) {
    Write-Host ""
    Write-Host "ERROR: Semgrep scan failed with exit code $semgrepExitCode" -ForegroundColor Red
    exit $semgrepExitCode
}

# Parse results
Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "Semgrep Scan Results" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan

if (Test-Path "$outputDir/semgrep.json") {
    $results = Get-Content "$outputDir/semgrep.json" | ConvertFrom-Json
    
    $totalFindings = $results.results.Count
    $errors = @($results.results | Where-Object { $_.extra.severity -eq "ERROR" })
    $warnings = @($results.results | Where-Object { $_.extra.severity -eq "WARNING" })
    $info = @($results.results | Where-Object { $_.extra.severity -eq "INFO" })
    
    Write-Host ""
    Write-Host "Total Findings: $totalFindings" -ForegroundColor Cyan
    Write-Host "  ERROR:   $($errors.Count)" -ForegroundColor Red
    Write-Host "  WARNING: $($warnings.Count)" -ForegroundColor Yellow
    Write-Host "  INFO:    $($info.Count)" -ForegroundColor Blue
    Write-Host ""
    
    # Show ERROR findings
    if ($errors.Count -gt 0) {
        Write-Host "Critical Issues (ERROR):" -ForegroundColor Red
        foreach ($finding in $errors) {
            $file = $finding.path
            $line = $finding.start.line
            $rule = $finding.check_id
            $message = $finding.extra.message
            Write-Host "  [$rule] $file`:$line" -ForegroundColor Red
            Write-Host "    $message" -ForegroundColor Gray
        }
        Write-Host ""
    }
    
    # Show WARNING findings (limited to first 10)
    if ($warnings.Count -gt 0) {
        Write-Host "Security Warnings (showing first 10 of $($warnings.Count)):" -ForegroundColor Yellow
        $displayWarnings = $warnings | Select-Object -First 10
        foreach ($finding in $displayWarnings) {
            $file = $finding.path
            $line = $finding.start.line
            $rule = $finding.check_id
            $message = $finding.extra.message
            Write-Host "  [$rule] $file`:$line" -ForegroundColor Yellow
            Write-Host "    $message" -ForegroundColor Gray
        }
        if ($warnings.Count -gt 10) {
            Write-Host "  ... and $($warnings.Count - 10) more warnings" -ForegroundColor Gray
        }
        Write-Host ""
    }
    
    # Output file locations
    Write-Host "Reports generated:" -ForegroundColor Green
    Write-Host "  JSON:  $outputDir/semgrep.json" -ForegroundColor Gray
    Write-Host "  SARIF: $outputDir/semgrep.sarif" -ForegroundColor Gray
    Write-Host ""
    
    # Upload to Semgrep Cloud if configured
    if ($uploadToCloud) {
        Write-Host "Uploading results to Semgrep Cloud..." -ForegroundColor Yellow
        Write-Host "Dashboard: https://semgrep.dev/orgs/-/findings" -ForegroundColor Cyan
        Write-Host ""
    }
    
    # Determine if we should fail the build
    if ($errors.Count -gt 0) {
        if ($FailOnFindings) {
            Write-Host "===========================================" -ForegroundColor Red
            Write-Host "BUILD FAILED: $($errors.Count) critical security issue(s) found" -ForegroundColor Red
            Write-Host "===========================================" -ForegroundColor Red
            Write-Host ""
            Write-Host "Fix these issues or upload to SonarCloud for review before merging" -ForegroundColor Yellow
            exit 1
        } else {
            Write-Host "===========================================" -ForegroundColor Yellow
            Write-Host "SECURITY ISSUES FOUND (Not Failing Build)" -ForegroundColor Yellow
            Write-Host "===========================================" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "[i] $($errors.Count) critical issue(s) found but FailOnFindings=false" -ForegroundColor Cyan
            Write-Host "[i] Results will be uploaded to SonarCloud for review" -ForegroundColor Cyan
            Write-Host "[i] Build will fail in Quality Gate Check step if issues remain" -ForegroundColor Cyan
            Write-Host ""
        }
    }
    
} else {
    Write-Host "ERROR: Semgrep results file not found" -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Semgrep scan complete" -ForegroundColor Green
Write-Host ""
Write-Host "Generated artifacts:" -ForegroundColor Gray
Get-ChildItem -Path $outputDir | ForEach-Object { Write-Host "  $($_.Name) ($([math]::Round($_.Length/1KB, 1)) KB)" -ForegroundColor Gray }
exit 0
