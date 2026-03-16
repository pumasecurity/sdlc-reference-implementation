# Build script for CI Pipeline (GitHub Actions)
# Builds all three project types: Traditional .NET Framework, SDK-style Framework, and Modern .NET
# Requires: Visual Studio (MSBuild), .NET 8 SDK, NuGet CLI

param(
    [string]$Configuration = "Release"
)

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Build Script - Multiple .NET Project Types" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$buildErrors = @()

# ===================================================================
# PART 1: Build Traditional .NET Framework MVC Project (MSBuild)
# ===================================================================
Write-Host "STEP 1: Building Traditional .NET Framework MVC Project" -ForegroundColor Yellow
Write-Host "Project: PumaSecurity.SDLC.Web.NetFramework" -ForegroundColor Gray
Write-Host ""

# Find Visual Studio and MSBuild using vswhere
$vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"

if (-not (Test-Path $vswhere)) {
    Write-Host "ERROR: vswhere.exe not found" -ForegroundColor Red
    $buildErrors += "Visual Studio not found"
} else {
    $installPath = & $vswhere -latest -requires Microsoft.Component.MSBuild -property installationPath
    
    if (-not $installPath) {
        Write-Host "ERROR: Could not locate Visual Studio installation" -ForegroundColor Red
        $buildErrors += "Visual Studio installation not found"
    } else {
        $msbuildPath = "$installPath\MSBuild\Current\Bin\MSBuild.exe"
        
        if (Test-Path $msbuildPath) {
            Write-Host "Found MSBuild at: $msbuildPath" -ForegroundColor Green
            
            # Find NuGet for package restore
            $nugetPath = ".\nuget.exe"
            if (-not (Test-Path $nugetPath)) {
                Write-Host "Downloading NuGet.exe..." -ForegroundColor Yellow
                $nugetUrl = "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe"
                try {
                    $ProgressPreference = 'SilentlyContinue'
                    Invoke-WebRequest -Uri $nugetUrl -OutFile $nugetPath -UseBasicParsing
                    $ProgressPreference = 'Continue'
                    Write-Host "NuGet.exe downloaded" -ForegroundColor Green
                } catch {
                    Write-Host "ERROR: Failed to download NuGet.exe" -ForegroundColor Red
                    $buildErrors += "NuGet download failed"
                }
            }
            
            if (Test-Path $nugetPath) {
                # Restore packages
                Write-Host "Restoring NuGet packages..." -ForegroundColor Yellow
                & $nugetPath restore PumaSecurity.SDLC.Web.sln -NonInteractive
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "Package restore completed" -ForegroundColor Green
                    
                    # Build the project
                    Write-Host "Building NetFramework MVC project..." -ForegroundColor Yellow
                    & $msbuildPath PumaSecurity.SDLC.Web.NetFramework\PumaSecurity.SDLC.Web.NetFramework.csproj /p:Configuration=$Configuration /t:Rebuild /v:minimal /nologo
                    
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "[OK] NetFramework MVC build successful" -ForegroundColor Green
                        
                        # Build the test project
                        Write-Host ""
                        Write-Host "Building NetFramework.Tests..." -ForegroundColor Yellow
                        & $msbuildPath PumaSecurity.SDLC.Web.NetFramework.Tests\PumaSecurity.SDLC.Web.NetFramework.Tests.csproj /p:Configuration=$Configuration /t:Rebuild /v:minimal /nologo
                        
                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "[OK] NetFramework.Tests build successful" -ForegroundColor Green
                        } else {
                            Write-Host "[FAIL] NetFramework.Tests build failed" -ForegroundColor Red
                            $buildErrors += "NetFramework.Tests build failed"
                        }
                    } else {
                        Write-Host "[FAIL] NetFramework MVC build failed" -ForegroundColor Red
                        $buildErrors += "NetFramework MVC build failed"
                    }
                } else {
                    Write-Host "? Package restore failed" -ForegroundColor Red
                    $buildErrors += "NetFramework package restore failed"
                }
            }
        } else {
            Write-Host "ERROR: MSBuild.exe not found" -ForegroundColor Red
            $buildErrors += "MSBuild not found"
        }
    }
}

Write-Host ""

# ===================================================================
# PART 2: Build SDK-Style .NET Framework Projects (dotnet build)
# ===================================================================
Write-Host "STEP 2: Building SDK-Style .NET Framework 4.7.2 Projects" -ForegroundColor Yellow
Write-Host "Projects: NetFrameworkSdk + NetFrameworkSdk.Tests" -ForegroundColor Gray
Write-Host ""

$dotnetPath = Get-Command dotnet -ErrorAction SilentlyContinue

if (-not $dotnetPath) {
    Write-Host "ERROR: dotnet CLI not found" -ForegroundColor Red
    $buildErrors += "dotnet CLI not found"
} else {
    Write-Host "Found dotnet CLI: $($dotnetPath.Path)" -ForegroundColor Green
    Write-Host "Building NetFrameworkSdk library..." -ForegroundColor Yellow
    
    & dotnet build PumaSecurity.SDLC.Web.NetFrameworkSdk\PumaSecurity.SDLC.Web.NetFrameworkSdk.csproj --configuration $Configuration --nologo
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] NetFrameworkSdk library build successful" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] NetFrameworkSdk library build failed" -ForegroundColor Red
        $buildErrors += "NetFrameworkSdk library build failed"
    }
    
    Write-Host ""
    Write-Host "Building NetFrameworkSdk.Tests..." -ForegroundColor Yellow
    & dotnet build PumaSecurity.SDLC.Web.NetFrameworkSdk.Tests\PumaSecurity.SDLC.Web.NetFrameworkSdk.Tests.csproj --configuration $Configuration --nologo
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] NetFrameworkSdk.Tests build successful" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] NetFrameworkSdk.Tests build failed" -ForegroundColor Red
        $buildErrors += "NetFrameworkSdk.Tests build failed"
    }
}

Write-Host ""

# ===================================================================
# PART 3: Build Modern .NET 8 Projects (dotnet build)
# ===================================================================
Write-Host "STEP 3: Building Modern .NET 8 Projects" -ForegroundColor Yellow
Write-Host "Projects: Net + Net.Tests" -ForegroundColor Gray
Write-Host ""

if (-not $dotnetPath) {
    Write-Host "ERROR: dotnet CLI not found" -ForegroundColor Red
    $buildErrors += "dotnet CLI not found for .NET 8"
} else {
    Write-Host "Building .NET 8 library..." -ForegroundColor Yellow
    & dotnet build PumaSecurity.SDLC.Web.Net\PumaSecurity.SDLC.Web.Net.csproj --configuration $Configuration --nologo
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] .NET 8 library build successful" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] .NET 8 library build failed" -ForegroundColor Red
        $buildErrors += ".NET 8 library build failed"
    }
    
    Write-Host ""
    Write-Host "Building .NET 8 Tests..." -ForegroundColor Yellow
    & dotnet build PumaSecurity.SDLC.Web.Net.Tests\PumaSecurity.SDLC.Web.Net.Tests.csproj --configuration $Configuration --nologo
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] .NET 8 Tests build successful" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] .NET 8 Tests build failed" -ForegroundColor Red
        $buildErrors += ".NET 8 Tests build failed"
    }
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Build Summary" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

if ($buildErrors.Count -eq 0) {
    Write-Host "[OK] All projects built successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Build Artifacts:" -ForegroundColor Yellow
    Write-Host "  Libraries:" -ForegroundColor Cyan
    Write-Host "    - NetFramework:    PumaSecurity.SDLC.Web.NetFramework\bin\$Configuration\" -ForegroundColor Gray
    Write-Host "    - NetFrameworkSdk: PumaSecurity.SDLC.Web.NetFrameworkSdk\bin\$Configuration\net472\" -ForegroundColor Gray
    Write-Host "    - Net:             PumaSecurity.SDLC.Web.Net\bin\$Configuration\net8.0\" -ForegroundColor Gray
    Write-Host "  Test Projects:" -ForegroundColor Cyan
    Write-Host "    - NetFramework.Tests:    PumaSecurity.SDLC.Web.NetFramework.Tests\bin\$Configuration\net472\" -ForegroundColor Gray
    Write-Host "    - NetFrameworkSdk.Tests: PumaSecurity.SDLC.Web.NetFrameworkSdk.Tests\bin\$Configuration\net472\" -ForegroundColor Gray
    Write-Host "    - Net.Tests:             PumaSecurity.SDLC.Web.Net.Tests\bin\$Configuration\net8.0\" -ForegroundColor Gray
    exit 0
} else {
    Write-Host "[ERROR] Build completed with errors:" -ForegroundColor Red
    foreach ($err in $buildErrors) {
        Write-Host "  - $err" -ForegroundColor Red
    }
    exit 1
}

