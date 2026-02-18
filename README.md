# SDLC Reference Implementation

Bitbucket Pipelines reference implementation demonstrating CI/CD for multiple .NET project types with test coverage on self-hosted Windows runners.

## Project Types

This repository demonstrates three common .NET project structures:

### 1. **PumaSecurity.SDLC.Web.NetFramework**
- Traditional ASP.NET MVC application
- .NET Framework 4.7.2
- Traditional `.csproj` format
- Builds with MSBuild
- Uses `packages.config` for NuGet packages

### 2. **PumaSecurity.SDLC.Web.NetFrameworkSdk**  
- .NET Framework 4.7.2 class library
- SDK-style `.csproj` format
- Builds with `dotnet build`
- Uses `PackageReference` for NuGet packages
- Modern project file format while targeting .NET Framework

### 3. **PumaSecurity.SDLC.Web.Net**
- Modern .NET 8 class library
- SDK-style `.csproj` format
- Builds with `dotnet build`
- Latest C# features and nullable reference types

## Prerequisites

### Self-Hosted Windows Runner Requirements
- Windows Server 2019 or later
- Visual Studio 2022 Build Tools or Professional/Enterprise
- .NET SDK 8.0 or later
- Git for Windows
- PowerShell 5.1 or later

### Required Visual Studio Workloads
- .NET desktop development
- ASP.NET and web development
- .NET Framework 4.7.2 targeting pack

## Quick Start

### Build All Projects
```powershell
.\build.ps1
```

### Run All Tests
```powershell
.\run-tests.ps1
```

### Show Coverage Report
```powershell
.\show-coverage.ps1
```

## Pipeline Structure

The Bitbucket Pipeline (`bitbucket-pipelines.yml`) runs on:
- **Pull Requests**: Full build, test, and coverage on all PRs
- **Main Branch**: Same validation for commits to main

### Pipeline Steps
1. **Environment Validation** - Verify build tools and dependencies
2. **Build** - Compile all three project types
3. **Test** - Run unit tests and collect coverage
4. **Report** - Generate test results (JUnit XML) and coverage reports (Cobertura XML)

### Test Results
- **JUnit XML** format for Bitbucket UI integration
- **Cobertura XML** format for coverage reporting
- Test results retained for 30 days in Bitbucket artifacts

## Code Coverage

Coverage is collected using Microsoft's `dotnet-coverage` tool:
- No Visual Studio Enterprise license required
- Works with MSTest, NUnit, xUnit
- Generates both binary `.coverage` and Cobertura XML formats
- Compatible with self-hosted runners

### Coverage Files
- `test-results/coverage.coverage` - Binary format (VS compatible)
- `test-results/coverage.cobertura.xml` - Cobertura XML (universal)

## Project Structure

```
sdlc-reference-implementation/
├── bitbucket-pipelines.yml          # CI/CD configuration
├── build.ps1                        # Build all projects
├── run-tests.ps1                   # Execute tests with coverage
├── show-coverage.ps1               # Display coverage summary
├── parse-test-results.ps1          # Parse JUnit results
├── coverage.runsettings            # Coverage configuration
│
├── PumaSecurity.SDLC.Web.NetFramework/           # Traditional .NET Framework MVC
│   └── PumaSecurity.SDLC.Web.NetFramework.csproj
├── PumaSecurity.SDLC.Web.NetFramework.Tests/     # Tests for traditional project
│   └── PumaSecurity.SDLC.Web.NetFramework.Tests.csproj
│
├── PumaSecurity.SDLC.Web.NetFrameworkSdk/        # SDK-style .NET Framework
│   ├── Calculator.cs
│   ├── UserService.cs
│   └── PumaSecurity.SDLC.Web.NetFrameworkSdk.csproj
├── PumaSecurity.SDLC.Web.NetFrameworkSdk.Tests/  # Tests for SDK-style Framework
│   └── PumaSecurity.SDLC.Web.NetFrameworkSdk.Tests.csproj
│
├── PumaSecurity.SDLC.Web.Net/                    # Modern .NET 8
│   ├── Calculator.cs
│   ├── UserService.cs
│   └── PumaSecurity.SDLC.Web.Net.csproj
└── PumaSecurity.SDLC.Web.Net.Tests/              # Tests for modern .NET
    └── PumaSecurity.SDLC.Web.Net.Tests.csproj
```

## Scripts

### build.ps1
Builds all three project types using appropriate build tools:
- NetFramework: MSBuild
- NetFrameworkSdk: dotnet build
- Net: dotnet build

### run-tests.ps1
Executes all test projects with code coverage:
- Uses VSTest.Console.exe for .NET Framework projects
- Uses dotnet test for .NET 8 projects
- Wraps execution with dotnet-coverage for coverage collection
- Generates JUnit XML and Cobertura XML outputs

### show-coverage.ps1
Parses and displays coverage metrics from Cobertura XML:
- Line coverage percentage
- Branch coverage percentage
- Per-file coverage breakdown

### parse-test-results.ps1
Reads JUnit XML and displays test results summary:
- Total tests
- Passed/Failed/Skipped counts
- Test execution time

## Coverage Tools

This implementation uses **Microsoft Code Coverage** (dotnet-coverage):

### Install dotnet-coverage
```powershell
dotnet tool install --global dotnet-coverage
```

### Why dotnet-coverage?
- ✅ Free (no VS Enterprise license needed)
- ✅ Cross-platform
- ✅ Works with self-hosted runners
- ✅ Supports all major test frameworks
- ✅ Generates both binary and XML formats

## Bitbucket Integration

### Test Results Tab
JUnit XML files are automatically parsed by Bitbucket for the Tests tab in PR builds.

### Artifacts
Test results and coverage files are retained for 30 days:
- `test-results/junit.xml`
- `test-results/coverage.coverage`
- `test-results/coverage.cobertura.xml`

### Coverage Visualization Options
Bitbucket Free tier doesn't include native coverage visualization. Options:
- **Codecov** (~$10/mo) - Coverage badges and PR comments
- **SonarCloud** (~$12/mo) - Coverage + code quality
- **Custom PR Comment** (free) - PowerShell script posts coverage to PR comments

## Demo Implementation

Each project includes demo Calculator and UserService classes with comprehensive tests:
- **Calculator**: Basic math operations
- **UserService**: CRUD operations with validation

These demonstrate:
- Test organization and naming conventions
- Code coverage collection
- Exception handling tests
- Arrange-Act-Assert pattern

## Local Development

### Build Individual Projects

```powershell
# Traditional .NET Framework MVC
msbuild PumaSecurity.SDLC.Web.NetFramework\PumaSecurity.SDLC.Web.NetFramework.csproj /p:Configuration=Release

# SDK-style .NET Framework
dotnet build PumaSecurity.SDLC.Web.NetFrameworkSdk\PumaSecurity.SDLC.Web.NetFrameworkSdk.csproj --configuration Release

# Modern .NET 8
dotnet build PumaSecurity.SDLC.Web.Net\PumaSecurity.SDLC.Web.Net.csproj --configuration Release
```

### Run Individual Test Projects

```powershell
# Traditional Framework tests (VSTest)
vstest.console.exe PumaSecurity.SDLC.Web.NetFramework.Tests\bin\Release\net472\PumaSecurity.SDLC.Web.NetFramework.Tests.dll

# SDK-style Framework tests (VSTest)
vstest.console.exe PumaSecurity.SDLC.Web.NetFrameworkSdk.Tests\bin\Release\net472\PumaSecurity.SDLC.Web.NetFrameworkSdk.Tests.dll

# Modern .NET 8 tests (dotnet test)
dotnet test PumaSecurity.SDLC.Web.Net.Tests\PumaSecurity.SDLC.Web.Net.Tests.csproj --configuration Release
```

## Troubleshooting

### Build Failures
- Verify Visual Studio Build Tools installed with ASP.NET workload
- Check .NET SDK version: `dotnet --version`
- Ensure .NET Framework 4.7.2 targeting pack installed

### Test Discovery Issues
- Verify test assemblies exist in `bin\Release\net472\` or `bin\Release\net8.0\`
- Check MSTest packages are restored correctly
- For traditional projects, ensure packages folder has MSTest assemblies

### Coverage Collection Issues
- Install dotnet-coverage: `dotnet tool install --global dotnet-coverage`
- Verify coverage.runsettings is properly configured
- Check that Microsoft.CodeCoverage package is referenced in test projects

## License

Internal reference implementation for Puma Security SDLC practices. Test PR
