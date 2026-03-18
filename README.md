# SDLC Reference Implementation

GitHub Actions reference implementation demonstrating CI/CD for multiple .NET project types with automated testing, code coverage, security scanning, and code quality analysis on `windows-latest` runners.

## Project Types

This repository demonstrates three common .NET project structures:

### 1. PumaSecurity.SDLC.Web.NetFramework
- Traditional ASP.NET MVC application
- .NET Framework 4.7.2
- Traditional `.csproj` format (non-SDK)
- Builds with MSBuild
- Uses `packages.config` for NuGet packages

### 2. PumaSecurity.SDLC.Web.NetFrameworkSdk
- .NET Framework 4.7.2 class library
- SDK-style `.csproj` format
- Builds with `dotnet build`
- Uses `PackageReference` for NuGet packages

### 3. PumaSecurity.SDLC.Web.Net
- Modern .NET 8 class library
- SDK-style `.csproj` format
- Builds with `dotnet build`
- Latest C# features and nullable reference types

## Pipeline Structure

The GitHub Actions workflow (`.github/workflows/ci.yml`) runs on `windows-latest` runners for both pull requests and pushes to main.

### Pipeline Jobs

```
Build
  │
  ├── Test & Coverage    (parallel)
  └── Security Scan      (parallel)
  │
  Code Quality Analysis
  │
  Quality Gate Check
```

1. **Build** — Compiles all three project types (MSBuild for traditional, `dotnet build` for SDK-style)
2. **Test & Coverage** — Runs all unit tests with `dotnet-coverage` and generates JUnit XML + Cobertura XML reports
3. **Security Scan** — Runs Semgrep with `p/security-audit` and `p/csharp` rulesets, generates JSON and SARIF reports
4. **Code Quality Analysis** — Uploads coverage and Semgrep SARIF results to SonarCloud via `dotnet-sonarscanner`
5. **Quality Gate Check** — Enforces thresholds: test pass rate, coverage minimum (70%), and zero critical Semgrep findings

Jobs 2 and 3 run in parallel. Artifacts are shared between jobs using GitHub Actions upload/download artifact actions.

## Tools & Technologies

### Testing
- [MSTest](https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-with-mstest) — Test framework for all three project types
- [Microsoft.CodeCoverage](https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-code-coverage) — Code coverage data collector (generates `.coverage` files)
- [dotnet-coverage](https://learn.microsoft.com/en-us/dotnet/core/additional-tools/dotnet-coverage) — CLI tool to collect, merge, and convert coverage across all test runners
- [JUnitXml.TestLogger](https://github.com/spekt/junit.testlogger) — MSTest logger that outputs JUnit XML for test result parsing
- [VSTest.Console.exe](https://learn.microsoft.com/en-us/visualstudio/test/vstest-console-options) — Test runner for .NET Framework 4.7.2 assemblies (ships with Visual Studio)

### Security Scanning
- [Semgrep OSS](https://semgrep.dev/docs/) — Static analysis security scanner with C# and general security rulesets, outputs JSON and SARIF

### Code Quality
- [SonarCloud](https://docs.sonarsource.com/sonarqube-cloud/) — Cloud-based code quality and security platform; performs static analysis and imports coverage and SARIF reports
- [dotnet-sonarscanner](https://docs.sonarsource.com/sonarqube-cloud/advanced-setup/ci-based-analysis/sonarscanner-for-dotnet/) — CLI tool that wraps MSBuild to send analysis data to SonarCloud

## Project Structure

```
sdlc-reference-implementation/
├── .github/workflows/ci.yml                        # CI/CD pipeline configuration
├── PumaSecurity.SDLC.Web.sln                       # Solution file
│
├── build/                                          # All pipeline automation scripts
│   ├── build.ps1                                   # Build all projects
│   ├── run-tests.ps1                               # Execute tests with coverage
│   ├── run-semgrep.ps1                             # Semgrep security scanning
│   ├── upload-to-sonarcloud.ps1                    # SonarCloud upload (coverage + SARIF)
│   ├── check-quality-gates.ps1                     # Quality gate enforcement
│   ├── run-sonar-analysis.ps1                      # Standalone SonarCloud analysis
│   ├── show-coverage.ps1                           # Display coverage summary
│   ├── parse-test-results.ps1                      # Parse JUnit results
│   ├── post-coverage-comment.ps1                   # Post coverage to PR comments
│   └── coverage.runsettings                        # Coverage configuration
│
├── src/
│   ├── PumaSecurity.SDLC.Web.NetFramework/         # Traditional .NET Framework MVC app
│   ├── PumaSecurity.SDLC.Web.NetFrameworkSdk/      # SDK-style .NET Framework class library
│   └── PumaSecurity.SDLC.Web.Net/                  # Modern .NET 8 class library
│
├── tests/
│   ├── PumaSecurity.SDLC.Web.NetFramework.Tests/   # Tests for traditional project
│   ├── PumaSecurity.SDLC.Web.NetFrameworkSdk.Tests/ # Tests for SDK-style Framework
│   └── PumaSecurity.SDLC.Web.Net.Tests/            # Tests for modern .NET
│
├── test-results/                                   # Generated test & coverage output
└── semgrep-results/                                # Generated Semgrep scan output
```

## Quick Start

### Build All Projects
```powershell
.\build\build.ps1
```

### Run All Tests with Coverage
```powershell
.\build\run-tests.ps1
```

### Run Security Scan
```powershell
.\build\run-semgrep.ps1
```

### Show Coverage Report
```powershell
.\build\show-coverage.ps1
```

## Pipeline Scripts

### build.ps1
Builds all three project types using appropriate build tools:
- NetFramework: MSBuild (via Visual Studio)
- NetFrameworkSdk: `dotnet build`
- Net: `dotnet build`

### run-tests.ps1
Executes all test projects with code coverage:
- Uses `vstest.console.exe` for .NET Framework projects
- Uses `dotnet test` for .NET 8 projects
- Wraps all execution with `dotnet-coverage` for unified coverage collection
- Merges coverage from all projects into a single `.coverage` file
- Generates JUnit XML (test results) and Cobertura XML (coverage) outputs

### run-semgrep.ps1
Runs Semgrep security scanning:
- Scans with `p/security-audit` and `p/csharp` rulesets
- Generates JSON report for quality gate parsing
- Generates SARIF report for SonarCloud import
- Post-processes SARIF to fix Windows backslash URIs for SonarCloud compatibility
- Does not fail the build by default (findings are reported in quality gate)

### upload-to-sonarcloud.ps1
Uploads analysis data to SonarCloud:
- Converts `.coverage` to VS Coverage XML format for SonarCloud
- Passes Semgrep SARIF via `sonar.sarifReportPaths` for external issue import
- Runs `dotnet sonarscanner begin` / MSBuild rebuild / `dotnet sonarscanner end`
- Supports PR analysis and branch analysis

### check-quality-gates.ps1
Enforces quality gates after SonarCloud upload:
- Parses JUnit XML for test pass/fail status
- Parses Semgrep JSON for critical (ERROR severity) security findings
- Checks Cobertura XML for minimum coverage threshold (70%)
- Fails the build if any gate is not met

### post-coverage-comment.ps1
Posts coverage and test result summary as a GitHub PR comment:
- Uses `gh` CLI with `GITHUB_TOKEN` for authentication
- Shows line and branch coverage percentages
- Shows test pass/fail counts

## Code Coverage

Coverage is collected using Microsoft's `dotnet-coverage` tool across all project types:

### Coverage Pipeline
1. Each test project produces a `.coverage` file via `dotnet-coverage collect`
2. All `.coverage` files are merged into `test-results/coverage.coverage`
3. Merged file is converted to Cobertura XML for local quality gates
4. Merged file is converted to VS Coverage XML for SonarCloud upload

### Coverage Files
- `test-results/coverage.coverage` — Merged binary format
- `test-results/coverage.cobertura.xml` — Cobertura XML (quality gate checks)
- `test-results/coverage.xml` — VS Coverage XML (SonarCloud)

## Security Scanning

Semgrep OSS scans the codebase for security vulnerabilities:

### Scan Output
- `semgrep-results/semgrep.json` — Full results for quality gate parsing
- `semgrep-results/semgrep.sarif` — SARIF format for SonarCloud import (post-processed for compatibility)

### Intentional Test Vulnerabilities
`src/PumaSecurity.SDLC.Web.Net/UserService.cs` contains intentional vulnerabilities for testing Semgrep detection:
- SQL injection (string concatenation in SQL command)
- Hardcoded credentials
- Weak cryptography (MD5)
- Command injection (unsanitized input to `Process.Start`)

## Environment Variables

### Required (GitHub Repository Secrets)
| Variable | Description |
|---|---|
| `SONAR_TOKEN` | SonarCloud authentication token |
| `SONAR_PROJECT_KEY` | SonarCloud project key |
| `SONAR_ORGANIZATION` | SonarCloud organization |

### Optional
| Variable | Description |
|---|---|
| `SEMGREP_APP_TOKEN` | Semgrep Cloud token (for dashboard upload) |

## Prerequisites

### GitHub Actions Runner (`windows-latest`)
The `windows-latest` runner comes pre-installed with:
- Visual Studio 2022 (MSBuild, VSTest)
- .NET SDK 8.0
- .NET Framework 4.7.2 targeting pack
- Python 3.x
- NuGet CLI
- Git

The workflow also uses setup actions for explicit version pinning:
- `actions/setup-dotnet@v4` — .NET 8.x SDK
- `microsoft/setup-msbuild@v2` — MSBuild
- `nuget/setup-nuget@v2` — NuGet CLI
- `actions/setup-python@v5` — Python 3.x

### Required .NET Global Tools
```powershell
dotnet tool install --global dotnet-coverage
dotnet tool install --global dotnet-sonarscanner
```

### Semgrep Installation
```powershell
python -m pip install semgrep
```

## Local Development

### Build Individual Projects
```powershell
# Traditional .NET Framework MVC
msbuild src\PumaSecurity.SDLC.Web.NetFramework\PumaSecurity.SDLC.Web.NetFramework.csproj /p:Configuration=Release

# SDK-style .NET Framework
dotnet build src\PumaSecurity.SDLC.Web.NetFrameworkSdk\PumaSecurity.SDLC.Web.NetFrameworkSdk.csproj --configuration Release

# Modern .NET 8
dotnet build src\PumaSecurity.SDLC.Web.Net\PumaSecurity.SDLC.Web.Net.csproj --configuration Release
```

### Run Individual Test Projects
```powershell
# Traditional Framework tests (VSTest)
vstest.console.exe tests\PumaSecurity.SDLC.Web.NetFramework.Tests\bin\Release\net472\PumaSecurity.SDLC.Web.NetFramework.Tests.dll

# SDK-style Framework tests (VSTest)
vstest.console.exe tests\PumaSecurity.SDLC.Web.NetFrameworkSdk.Tests\bin\Release\net472\PumaSecurity.SDLC.Web.NetFrameworkSdk.Tests.dll

# Modern .NET 8 tests (dotnet test)
dotnet test tests\PumaSecurity.SDLC.Web.Net.Tests\PumaSecurity.SDLC.Web.Net.Tests.csproj --configuration Release
```

## Troubleshooting

### Build Failures
- Verify Visual Studio Build Tools installed with ASP.NET workload
- Check .NET SDK version: `dotnet --version`
- Ensure .NET Framework 4.7.2 targeting pack is installed

### Test Discovery Issues
- Verify test assemblies exist in `bin\Release\net472\` or `bin\Release\net8.0\`
- Check MSTest packages are restored correctly

### Coverage Collection Issues
- Install dotnet-coverage: `dotnet tool install --global dotnet-coverage`
- Verify `Microsoft.CodeCoverage` package is referenced in test projects

### Semgrep Issues
- Verify Python is in PATH: `python --version`
- Install/upgrade Semgrep: `python -m pip install --upgrade semgrep`
- SARIF file empty: ensure `--verbose` is not used on the SARIF generation pass

### SonarCloud Issues
- Verify `SONAR_TOKEN`, `SONAR_PROJECT_KEY`, `SONAR_ORGANIZATION` are set
- Check SonarScanner logs for SARIF import messages
- External issues appear under the Security category in SonarCloud, not on the Rules page

## License

Internal reference implementation for Puma Security SDLC practices.
