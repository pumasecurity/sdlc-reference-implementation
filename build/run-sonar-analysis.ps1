# SonarCloud Analysis Script for .NET Projects
# This script runs SonarCloud analysis with code coverage

param(
    [string]$SonarToken = $env:SONAR_TOKEN,
    [string]$Configuration = "Release",
    [string]$BranchName = $env:GITHUB_HEAD_REF,
    [string]$PrKey
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "SonarCloud Analysis" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Auto-detect PR number from GitHub Actions environment
if (-not $PrKey -and $env:GITHUB_REF -match 'refs/pull/(\d+)/merge') {
    $PrKey = $Matches[1]
}
if (-not $BranchName -and $env:GITHUB_REF -match 'refs/heads/(.+)') {
    $BranchName = $Matches[1]
}

# Validate SonarCloud token
if (-not $SonarToken) {
    Write-Host "ERROR: SONAR_TOKEN environment variable not set" -ForegroundColor Red
    Write-Host "Please set SONAR_TOKEN in GitHub Repository Secrets" -ForegroundColor Yellow
    exit 1
}

# Check if dotnet-sonarscanner is installed
$scannerInstalled = dotnet tool list --global | Select-String "dotnet-sonarscanner"

if (-not $scannerInstalled) {
    Write-Host "Installing dotnet-sonarscanner..." -ForegroundColor Yellow
    dotnet tool install --global dotnet-sonarscanner --version 11.2.0
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Failed to install dotnet-sonarscanner" -ForegroundColor Red
        exit 1
    }
    Write-Host "dotnet-sonarscanner installed successfully" -ForegroundColor Green
} else {
    Write-Host "dotnet-sonarscanner already installed" -ForegroundColor Green
}

Write-Host ""

# Read project key from sonar-project.properties
$projectKey = ""
$orgKey = ""

if (Test-Path "sonar-project.properties") {
    $content = Get-Content "sonar-project.properties"
    foreach ($line in $content) {
        if ($line -match "^sonar\.projectKey=(.+)$") {
            $projectKey = $Matches[1]
        }
        if ($line -match "^sonar\.organization=(.+)$") {
            $orgKey = $Matches[1]
        }
    }
}

if (-not $projectKey -or $projectKey -eq "YOUR_ORG_YOUR_PROJECT_KEY") {
    Write-Host "ERROR: Please update sonar-project.properties with your SonarCloud project key" -ForegroundColor Red
    exit 1
}

if (-not $orgKey -or $orgKey -eq "YOUR_ORG_KEY") {
    Write-Host "ERROR: Please update sonar-project.properties with your SonarCloud organization key" -ForegroundColor Red
    exit 1
}

Write-Host "Project Key: $projectKey" -ForegroundColor Gray
Write-Host "Organization: $orgKey" -ForegroundColor Gray
Write-Host ""

# Build SonarScanner begin arguments
$beginArgs = @(
    "begin",
    "/k:$projectKey",
    "/o:$orgKey",
    "/d:sonar.host.url=https://sonarcloud.io",
    "/d:sonar.login=$SonarToken",
    "/d:sonar.cs.vscoveragexml.reportsPaths=test-results/coverage.xml"
)

# Add PR-specific parameters if this is a PR build
if ($PrKey) {
    Write-Host "Pull Request Build - PR #$PrKey" -ForegroundColor Cyan
    $beginArgs += "/d:sonar.pullrequest.key=$PrKey"
    $beginArgs += "/d:sonar.pullrequest.branch=$BranchName"
    $beginArgs += "/d:sonar.pullrequest.base=main"
} elseif ($BranchName -and $BranchName -ne "main") {
    Write-Host "Branch Build - $BranchName" -ForegroundColor Cyan
    $beginArgs += "/d:sonar.branch.name=$BranchName"
} else {
    Write-Host "Main Branch Build" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "Starting SonarScanner analysis..." -ForegroundColor Yellow

# Begin SonarScanner analysis
& dotnet sonarscanner @beginArgs

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: SonarScanner begin failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Building projects..." -ForegroundColor Yellow

# Build all projects (SonarScanner monitors this)
& "$PSScriptRoot\build.ps1"

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Build failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Running tests with coverage..." -ForegroundColor Yellow

# Run tests with coverage
& "$PSScriptRoot\run-tests.ps1"

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Tests failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Converting coverage to XML format for SonarCloud..." -ForegroundColor Yellow

# Convert .coverage to XML format that SonarCloud can read
if (Test-Path "test-results\coverage.coverage") {
    & dotnet-coverage merge --output test-results\coverage.xml --output-format xml test-results\coverage.coverage
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Coverage converted successfully" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Ending SonarScanner analysis and uploading to SonarCloud..." -ForegroundColor Yellow

# End SonarScanner analysis (uploads results)
& dotnet sonarscanner end /d:sonar.login=$SonarToken

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: SonarScanner end failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "SonarCloud Analysis Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "View results at: https://sonarcloud.io/project/overview?id=$projectKey" -ForegroundColor Cyan
Write-Host ""

exit 0
