# Parse and display test results from JUnit XML files
# This script is used by the CI Pipeline (GitHub Actions)

param(
    [string]$TestResultsPath = "test-results"
)

Write-Host "Analyzing test results..." -ForegroundColor Cyan
Write-Host ""

$junitFile = Join-Path $TestResultsPath "junit.xml"

if (-not (Test-Path $junitFile)) {
    Write-Host "No JUnit XML file found at: $junitFile" -ForegroundColor Yellow
    Write-Host "Note: Test results are uploaded as GitHub Actions artifacts." -ForegroundColor Cyan
    exit 0
}

Write-Host "Processing: junit.xml" -ForegroundColor Cyan

try {
    [xml]$xml = Get-Content $junitFile
    
    # JUnit XML format uses testsuites as root element
    $testsuites = $xml.testsuites
    
    if (-not $testsuites) {
        Write-Host "  Warning: Unexpected JUnit XML structure" -ForegroundColor Yellow
        exit 0
    }
    
    $totalTests = [int]$testsuites.tests
    $failures = [int]$testsuites.failures
    $errors = [int]$testsuites.errors
    $skipped = [int]$testsuites.skipped
    $passed = $totalTests - $failures - $errors - $skipped
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "TEST RESULTS SUMMARY" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Total Tests:  $totalTests" -ForegroundColor White
    Write-Host "Passed:       $passed" -ForegroundColor Green
    
    if ($failures -gt 0) {
        Write-Host "Failed:       $failures" -ForegroundColor Red
    } else {
        Write-Host "Failed:       0" -ForegroundColor Green
    }
    
    if ($errors -gt 0) {
        Write-Host "Errors:       $errors" -ForegroundColor Red
    }
    
    if ($skipped -gt 0) {
        Write-Host "Skipped:      $skipped" -ForegroundColor Yellow
    }
    
    Write-Host ""
    
    # Display failed test details if any
    if ($failures -gt 0 -or $errors -gt 0) {
        Write-Host "Failed Tests:" -ForegroundColor Red
        Write-Host "----------------------------------------" -ForegroundColor Red
        
        foreach ($testsuite in $testsuites.testsuite) {
            foreach ($testcase in $testsuite.testcase) {
                if ($testcase.failure -or $testcase.error) {
                    Write-Host "  $($testcase.classname).$($testcase.name)" -ForegroundColor Red
                    if ($testcase.failure) {
                        Write-Host "    $($testcase.failure.message)" -ForegroundColor DarkRed
                    }
                    if ($testcase.error) {
                        Write-Host "    $($testcase.error.message)" -ForegroundColor DarkRed
                    }
                    Write-Host ""
                }
            }
        }
        
        Write-Host ""
        Write-Host "Tests FAILED!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Note: Test results are available in GitHub Actions job summary." -ForegroundColor Cyan
        exit 1
    } else {
        Write-Host "All tests PASSED! ?" -ForegroundColor Green
        Write-Host ""
        Write-Host "Note: Test results are available in GitHub Actions job summary." -ForegroundColor Cyan
        exit 0
    }
}
catch {
    Write-Host "  Error parsing JUnit XML file: $_" -ForegroundColor Red
    Write-Host ""
    exit 1
}
