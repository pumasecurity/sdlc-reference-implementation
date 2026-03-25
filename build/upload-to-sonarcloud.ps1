# Upload existing test results and coverage to SonarCloud
# This script assumes build and tests have already been run
#
# Used by GitHub Actions CI pipeline (windows-latest runner)
#
# Automatically imports:
#   - Code coverage from test-results/coverage.coverage
#   - Semgrep security findings from semgrep-results/semgrep.sarif (if available)

param(
    [string]$SonarToken = $env:SONAR_TOKEN,
    [string]$ProjectKey = $env:SONAR_PROJECT_KEY,
    [string]$Organization = $env:SONAR_ORGANIZATION
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "SonarCloud Upload" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Validate SonarCloud token
if (-not $SonarToken) {
    Write-Host "WARNING: SONAR_TOKEN environment variable not set" -ForegroundColor Yellow
    Write-Host "Skipping SonarCloud upload. To enable:" -ForegroundColor Yellow
    Write-Host "  1. Set SONAR_TOKEN in GitHub Repository Secrets" -ForegroundColor Gray
    Write-Host "  2. Set SONAR_PROJECT_KEY (e.g., 'your-org_your-project')" -ForegroundColor Gray
    Write-Host "  3. Set SONAR_ORGANIZATION (e.g., 'your-org')" -ForegroundColor Gray
    Write-Host ""
    exit 0
}

# Validate project configuration
if (-not $ProjectKey) {
    Write-Host "ERROR: SONAR_PROJECT_KEY environment variable not set" -ForegroundColor Red
    Write-Host "Please set in GitHub Repository Secrets" -ForegroundColor Yellow
    exit 1
}

if (-not $Organization) {
    Write-Host "ERROR: SONAR_ORGANIZATION environment variable not set" -ForegroundColor Red
    Write-Host "Please set in GitHub Repository Secrets" -ForegroundColor Yellow
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

Write-Host "Project Key: $ProjectKey" -ForegroundColor Gray
Write-Host "Organization: $Organization" -ForegroundColor Gray
Write-Host ""

# Check if test results exist (GitHub Actions downloads artifacts to specified paths)
$coverageFile = $null
if (Test-Path "test-results\coverage.coverage") {
    $coverageFile = (Resolve-Path "test-results\coverage.coverage").Path
    Write-Host "Found coverage file: $coverageFile" -ForegroundColor Green
} else {
    Write-Host "WARNING: No coverage file found." -ForegroundColor Yellow
    Write-Host "SonarCloud will analyze code quality without coverage metrics." -ForegroundColor Yellow
}

# Convert coverage to XML format for SonarCloud
if ($coverageFile) {
    Write-Host "Converting coverage to XML format for SonarCloud..." -ForegroundColor Yellow
    & dotnet-coverage merge --output test-results\coverage.xml --output-format xml $coverageFile

    if ($LASTEXITCODE -ne 0) {
        Write-Host "WARNING: Coverage conversion failed" -ForegroundColor Yellow
        $coverageFile = $null
    }
} else {
    Write-Host "Skipping coverage conversion (no coverage file available)" -ForegroundColor Gray
}

# Check for Semgrep SARIF results
$semgrepSarif = $null
if (Test-Path "semgrep-results\semgrep.sarif") {
    $semgrepSarif = (Resolve-Path "semgrep-results\semgrep.sarif").Path
    $sarifSize = (Get-Item $semgrepSarif).Length
    Write-Host "Found Semgrep SARIF results ($([math]::Round($sarifSize/1KB, 1)) KB)" -ForegroundColor Green
    Write-Host "  Path: $semgrepSarif" -ForegroundColor Gray
} else {
    Write-Host "No Semgrep results found (optional)" -ForegroundColor Gray
}

Write-Host ""

# Build SonarScanner begin arguments
$beginArgs = @(
    "begin",
    "/k:$ProjectKey",
    "/o:$Organization",
    "/d:sonar.host.url=https://sonarcloud.io",
    "/d:sonar.token=$SonarToken"
)

# Add coverage if available
if ($coverageFile -and (Test-Path "test-results\coverage.xml")) {
    $beginArgs += "/d:sonar.cs.vscoveragexml.reportsPaths=test-results/coverage.xml"
}

# Add Semgrep SARIF results if available (use forward slashes for SonarScanner)
if ($semgrepSarif) {
    $sarifPathForSonar = $semgrepSarif -replace '\\', '/'
    Write-Host "SARIF path for SonarScanner: $sarifPathForSonar" -ForegroundColor Gray
    $beginArgs += "/d:sonar.sarifReportPaths=$sarifPathForSonar"
}

# Detect PR vs branch build from GitHub Actions environment
$prNumber = $null
$branchName = $null

if ($env:GITHUB_EVENT_NAME -eq "pull_request") {
    # Extract PR number from GITHUB_REF (refs/pull/<number>/merge)
    if ($env:GITHUB_REF -match 'refs/pull/(\d+)/merge') {
        $prNumber = $Matches[1]
    }
    $branchName = $env:GITHUB_HEAD_REF
    $baseBranch = $env:GITHUB_BASE_REF
} else {
    # Push event - extract branch name from GITHUB_REF (refs/heads/<branch>)
    if ($env:GITHUB_REF -match 'refs/heads/(.+)') {
        $branchName = $Matches[1]
    }
}

# Add PR-specific parameters if this is a PR build
if ($prNumber) {
    Write-Host "Pull Request Build - PR #$prNumber" -ForegroundColor Cyan
    $beginArgs += "/d:sonar.pullrequest.key=$prNumber"
    $beginArgs += "/d:sonar.pullrequest.branch=$branchName"
    $beginArgs += "/d:sonar.pullrequest.base=$baseBranch"
} elseif ($branchName -and $branchName -ne "main") {
    Write-Host "Branch Build - $branchName" -ForegroundColor Cyan
    $beginArgs += "/d:sonar.branch.name=$branchName"
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
Write-Host "Re-building solution for SonarScanner analysis..." -ForegroundColor Yellow
Write-Host "(SonarScanner needs to monitor the build process)" -ForegroundColor Gray

# SonarScanner requires building to analyze the code
# Use MSBuild for solution-level build
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path $vswhere) {
    $installPath = & $vswhere -latest -requires Microsoft.Component.MSBuild -property installationPath
    $msbuildPath = "$installPath\MSBuild\Current\Bin\MSBuild.exe"

    if (Test-Path $msbuildPath) {
        & $msbuildPath PumaSecurity.SDLC.Web.sln /t:Rebuild /p:Configuration=Release /v:quiet /nologo
    }
}

Write-Host ""
Write-Host "Ending SonarScanner analysis and uploading to SonarCloud..." -ForegroundColor Yellow

# End SonarScanner analysis (uploads results)
& dotnet sonarscanner end /d:sonar.token=$SonarToken

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: SonarScanner end failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "SonarCloud Upload Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "View results at: https://sonarcloud.io/project/overview?id=$ProjectKey" -ForegroundColor Cyan
Write-Host ""

exit 0
