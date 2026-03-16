# Test script for CI Pipeline (GitHub Actions)
# This script runs tests for all 3 project types and generates unified test/coverage reports

param(
    [string]$Configuration = "Release",
    [string]$ResultsDir = "test-results"
)

Write-Host "================================" -ForegroundColor Cyan
Write-Host "Multi-Project Test Execution" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# Create output directory if it doesn't exist
if (-not (Test-Path $ResultsDir)) {
    New-Item -ItemType Directory -Path $ResultsDir -Force | Out-Null
    Write-Host "Created output directory: $ResultsDir" -ForegroundColor Green
}

# Define test projects
$testProjects = @(
    @{
        Name = "NetFramework.Tests"
        Assembly = "PumaSecurity.SDLC.Web.NetFramework.Tests\bin\$Configuration\net472\PumaSecurity.SDLC.Web.NetFramework.Tests.dll"
        Type = "VSTest"
    },
    @{
        Name = "NetFrameworkSdk.Tests"
        Assembly = "PumaSecurity.SDLC.Web.NetFrameworkSdk.Tests\bin\$Configuration\net472\PumaSecurity.SDLC.Web.NetFrameworkSdk.Tests.dll"
        Type = "VSTest"
    },
    @{
        Name = "Net.Tests"
        Project = "PumaSecurity.SDLC.Web.Net.Tests\PumaSecurity.SDLC.Web.Net.Tests.csproj"
        Type = "DotNetTest"
    }
)

# Verify test assemblies/projects exist
Write-Host "Verifying test projects..." -ForegroundColor Yellow
$allExist = $true
foreach ($testProject in $testProjects) {
    $path = if ($testProject.Type -eq "VSTest") { $testProject.Assembly } else { $testProject.Project }
    if (-not (Test-Path $path)) {
        Write-Host "  ERROR: $($testProject.Name) not found at: $path" -ForegroundColor Red
        $allExist = $false
    } else {
        Write-Host "  Found: $($testProject.Name)" -ForegroundColor Green
    }
}

if (-not $allExist) {
    Write-Host ""
    Write-Host "ERROR: One or more test projects not found." -ForegroundColor Red
    Write-Host "Please run build.ps1 first to build all test projects." -ForegroundColor Yellow
    exit 1
}
Write-Host ""

# Find VSTest.Console.exe for Framework tests
Write-Host "Locating VSTest.Console.exe..." -ForegroundColor Yellow
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vstestPath = $null

if (Test-Path $vswhere) {
    $installPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Workload.ManagedDesktop -property installationPath
    if ($installPath) {
        $vstestPath = Join-Path $installPath "Common7\IDE\CommonExtensions\Microsoft\TestWindow\vstest.console.exe"
        if (-not (Test-Path $vstestPath)) {
            $vstestPath = Join-Path $installPath "Common7\IDE\Extensions\TestPlatform\vstest.console.exe"
        }
    }
}

if (-not $vstestPath -or -not (Test-Path $vstestPath)) {
    Write-Host "ERROR: VSTest.Console.exe not found" -ForegroundColor Red
    Write-Host "Please install Visual Studio with testing tools" -ForegroundColor Yellow
    exit 1
}

Write-Host "Found VSTest.Console at: $vstestPath" -ForegroundColor Green
Write-Host ""

# Check if dotnet-coverage tool is available
$dotnetCoveragePath = Get-Command dotnet-coverage -ErrorAction SilentlyContinue

if (-not $dotnetCoveragePath) {
    Write-Host "ERROR: dotnet-coverage not found." -ForegroundColor Red
    Write-Host "Install it with: dotnet tool install --global dotnet-coverage" -ForegroundColor Yellow
    exit 1
}

Write-Host "Using dotnet-coverage for unified code coverage collection" -ForegroundColor Green
Write-Host "Configuration: $Configuration" -ForegroundColor Gray
Write-Host "Output Directory: $ResultsDir" -ForegroundColor Gray
Write-Host ""

# Prepare coverage collection
$coverageFiles = @()
$junitFiles = @()
$testExitCodes = @()

# Run each test project with coverage
$testNumber = 0
foreach ($testProject in $testProjects) {
    $testNumber++
    Write-Host "[$testNumber/$($testProjects.Count)] Running $($testProject.Name)..." -ForegroundColor Cyan
    Write-Host "----------------------------------------" -ForegroundColor Gray
    
    $projectCoverageFile = Join-Path (Get-Location) "$ResultsDir\coverage-$($testProject.Name).coverage"
    $projectJunitFile = Join-Path (Get-Location) "$ResultsDir\junit-$($testProject.Name).xml"
    
    if ($testProject.Type -eq "VSTest") {
        # Run VSTest.Console.exe with coverage
        $vstestArgs = @(
            $testProject.Assembly,
            "/Logger:junit;LogFilePath=$projectJunitFile"
        )
        
        Write-Host "  Running VSTest with coverage..." -ForegroundColor Gray
        & dotnet-coverage collect --output $projectCoverageFile --output-format coverage -- $vstestPath @vstestArgs
        
    } else {
        # Run dotnet test with coverage
        Write-Host "  Running dotnet test with coverage..." -ForegroundColor Gray
        $loggerArg = "junit;LogFilePath=$projectJunitFile"
        & dotnet-coverage collect --output $projectCoverageFile --output-format coverage -- dotnet test $testProject.Project --configuration $Configuration --logger $loggerArg --no-build
    }
    
    $exitCode = $LASTEXITCODE
    $testExitCodes += $exitCode
    
    if ($exitCode -eq 0) {
        Write-Host "  Tests passed" -ForegroundColor Green
        if (Test-Path $projectCoverageFile) {
            $coverageFiles += $projectCoverageFile
            Write-Host "  Coverage collected: $(Split-Path -Leaf $projectCoverageFile)" -ForegroundColor Green
        }
        if (Test-Path $projectJunitFile) {
            $junitFiles += $projectJunitFile
        }
    } else {
        Write-Host "  Tests FAILED with exit code: $exitCode" -ForegroundColor Red
    }
    
    Write-Host ""
}

# Check if any tests failed
$anyFailed = $testExitCodes | Where-Object { $_ -ne 0 }
if ($anyFailed) {
    Write-Host "================================" -ForegroundColor Red
    Write-Host "TEST FAILURES DETECTED" -ForegroundColor Red
    Write-Host "================================" -ForegroundColor Red
    Write-Host ""
    for ($i = 0; $i -lt $testProjects.Count; $i++) {
        $status = if ($testExitCodes[$i] -eq 0) { "PASSED" } else { "FAILED" }
        $color = if ($testExitCodes[$i] -eq 0) { "Green" } else { "Red" }
        Write-Host "  $($testProjects[$i].Name): $status" -ForegroundColor $color
    }
    Write-Host ""
    exit 1
}

Write-Host "================================" -ForegroundColor Green
Write-Host "All Tests PASSED" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green
Write-Host ""

# Merge coverage files
if ($coverageFiles.Count -gt 0) {
    Write-Host "Merging coverage from $($coverageFiles.Count) test projects..." -ForegroundColor Cyan
    
    $mergedCoverageFile = Join-Path (Get-Location) "$ResultsDir\coverage.coverage"
    $coberturaFile = Join-Path (Get-Location) "$ResultsDir\coverage.cobertura.xml"
    
    # Merge all coverage files into one binary .coverage file
    $coverageArgs = @("merge", "--output", $mergedCoverageFile, "--output-format", "coverage") + $coverageFiles
    & dotnet-coverage @coverageArgs
    
    if (Test-Path $mergedCoverageFile) {
        Write-Host "  Merged coverage file created: $(Split-Path -Leaf $mergedCoverageFile)" -ForegroundColor Green
        
        # Convert merged coverage to Cobertura format
        Write-Host "  Converting to Cobertura XML..." -ForegroundColor Gray
        & dotnet-coverage merge --output $coberturaFile --output-format cobertura $mergedCoverageFile
        
        if (Test-Path $coberturaFile) {
            Write-Host "  Cobertura XML created: $(Split-Path -Leaf $coberturaFile)" -ForegroundColor Green
        }
    }
    Write-Host ""
}

# Merge JUnit XML files
if ($junitFiles.Count -gt 1) {
    Write-Host "Merging JUnit XML files..." -ForegroundColor Cyan
    $mergedJunitFile = Join-Path $ResultsDir "junit.xml"
    
    # Create merged XML document
    $mergedXml = New-Object System.Xml.XmlDocument
    $rootElement = $mergedXml.CreateElement("testsuites")
    $mergedXml.AppendChild($rootElement) | Out-Null
    
    $totalTests = 0
    $totalFailures = 0
    $totalErrors = 0
    $totalSkipped = 0
    $totalTime = 0.0
    
    foreach ($junitFile in $junitFiles) {
        if (Test-Path $junitFile) {
            try {
                [xml]$junit = Get-Content $junitFile
                # Get all testsuite elements
                foreach ($testsuite in $junit.testsuites.testsuite) {
                    # Import the testsuite node into merged document
                    $imported = $mergedXml.ImportNode($testsuite, $true)
                    $mergedXml.DocumentElement.AppendChild($imported) | Out-Null
                    
                    # Accumulate totals
                    $totalTests += [int]$testsuite.tests
                    $totalFailures += [int]$testsuite.failures
                    $totalErrors += [int]$testsuite.errors
                    if ($testsuite.skipped) {
                        $totalSkipped += [int]$testsuite.skipped
                    }
                    if ($testsuite.time) {
                        $totalTime += [double]$testsuite.time
                    }
                }
            }
            catch {
                Write-Host "  Warning: Could not parse $(Split-Path -Leaf $junitFile): $_" -ForegroundColor Yellow
            }
        }
    }
    
    # Add summary attributes to testsuites root
    $mergedXml.DocumentElement.SetAttribute("tests", $totalTests.ToString())
    $mergedXml.DocumentElement.SetAttribute("failures", $totalFailures.ToString())
    $mergedXml.DocumentElement.SetAttribute("errors", $totalErrors.ToString())
    $mergedXml.DocumentElement.SetAttribute("skipped", $totalSkipped.ToString())
    $mergedXml.DocumentElement.SetAttribute("time", $totalTime.ToString("F3"))
    
    $mergedXml.Save($mergedJunitFile)
    Write-Host "  Merged JUnit XML created: $(Split-Path -Leaf $mergedJunitFile)" -ForegroundColor Green
    Write-Host ""
} elseif ($junitFiles.Count -eq 1) {
    # Just copy the single file
    Copy-Item $junitFiles[0] (Join-Path $ResultsDir "junit.xml") -Force
}

# Display summary
Write-Host "================================" -ForegroundColor Cyan
Write-Host "Test Results Summary" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

$finalJunitFile = Join-Path $ResultsDir "junit.xml"
if (Test-Path $finalJunitFile) {
    try {
        [xml]$junit = Get-Content $finalJunitFile
        $totalTests = [int]$junit.testsuites.tests
        $failures = [int]$junit.testsuites.failures
        $errors = [int]$junit.testsuites.errors
        $skipped = [int]$junit.testsuites.skipped
        
        Write-Host "  Total Tests: $totalTests" -ForegroundColor White
        Write-Host "  Passed:      $($totalTests - $failures - $errors - $skipped)" -ForegroundColor Green
        Write-Host "  Failures:    $failures" -ForegroundColor $(if ($failures -eq 0) { "Green" } else { "Red" })
        Write-Host "  Errors:      $errors" -ForegroundColor $(if ($errors -eq 0) { "Green" } else { "Red" })
        if ($skipped -gt 0) {
            Write-Host "  Skipped:     $skipped" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "  (Unable to parse JUnit XML details)" -ForegroundColor DarkGray
    }
}

Write-Host ""
Write-Host "Output Files:" -ForegroundColor Cyan
Write-Host "  JUnit XML:      $ResultsDir\junit.xml" -ForegroundColor Gray
Write-Host "  Cobertura XML:  $ResultsDir\coverage.cobertura.xml" -ForegroundColor Gray
Write-Host "  Coverage File:  $ResultsDir\coverage.coverage" -ForegroundColor Gray
Write-Host ""
Write-Host "All tests passed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Note: Test results and coverage are uploaded as GitHub Actions artifacts." -ForegroundColor Cyan
exit 0
