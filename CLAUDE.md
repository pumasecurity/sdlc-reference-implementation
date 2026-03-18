# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

SDLC reference implementation for Puma Security. Demonstrates CI/CD pipelines (GitHub Actions on `windows-latest`) across three .NET project types with automated testing, code coverage, Semgrep security scanning, and SonarCloud quality analysis.

## Build & Test Commands

The SDK-style projects (.NET 8 and .NET Framework SDK) can be built and tested locally with `dotnet`. The traditional .NET Framework project requires MSBuild/Visual Studio (Windows only).

```shell
# Build SDK-style projects
dotnet build src/PumaSecurity.SDLC.Web.Net/PumaSecurity.SDLC.Web.Net.csproj
dotnet build src/PumaSecurity.SDLC.Web.NetFrameworkSdk/PumaSecurity.SDLC.Web.NetFrameworkSdk.csproj

# Run .NET 8 tests
dotnet test tests/PumaSecurity.SDLC.Web.Net.Tests/PumaSecurity.SDLC.Web.Net.Tests.csproj

# Run .NET Framework SDK tests (Windows only, requires net472 targeting pack)
dotnet test tests/PumaSecurity.SDLC.Web.NetFrameworkSdk.Tests/PumaSecurity.SDLC.Web.NetFrameworkSdk.Tests.csproj
```

The `build/` directory contains PowerShell scripts used by CI, designed for Windows runners.

## Architecture

Three parallel project types demonstrate different .NET build configurations:

| Project | Target | Build Tool | Style |
|---------|--------|------------|-------|
| `PumaSecurity.SDLC.Web.NetFramework` | .NET Framework 4.7.2 | MSBuild | Traditional (non-SDK) csproj, `packages.config` |
| `PumaSecurity.SDLC.Web.NetFrameworkSdk` | .NET Framework 4.7.2 | `dotnet build` | SDK-style csproj, `PackageReference` |
| `PumaSecurity.SDLC.Web.Net` | .NET 8.0 | `dotnet build` | SDK-style csproj, nullable enabled |

Each source project in `src/` has a corresponding MSTest test project in `tests/`. Test framework is MSTest with `JUnitXml.TestLogger` for CI report generation.

## CI Pipeline (`.github/workflows/ci.yml`)

Five jobs: Build → Test & Security Scan (parallel) → SonarCloud Analysis → Quality Gate Check. Quality gates enforce: all tests pass, ≥70% code coverage, zero critical Semgrep findings.

## Intentional Vulnerabilities

`src/PumaSecurity.SDLC.Web.Net/UserService.cs` contains deliberate security flaws (SQL injection, hardcoded credentials, MD5, command injection) for testing Semgrep detection. Do not "fix" these unless asked.

