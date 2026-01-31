Set-StrictMode -Off
$ErrorActionPreference = "Stop"

# ========================================
# 설정
# ========================================
$APP_NAME = "LaundryPointManager"
$PYTHON   = "python"

$ROOT_MARKERS = @(
    ".gitignore",
    "requirements.txt",
    "python-version.txt"
)

function Find-ProjectRoot {
    param(
        [Parameter(Mandatory = $true)]
        [string]$StartDir,
        [Parameter(Mandatory = $true)]
        [string[]]$Markers
    )

    $currentDir = $StartDir
    while ($true) {
        foreach ($marker in $Markers) {
            if (Test-Path (Join-Path $currentDir $marker)) {
                return @{
                    Root   = $currentDir
                    Marker = $marker
                }
            }
        }

        $parentDir = Split-Path $currentDir -Parent
        if (-not $parentDir -or $parentDir -eq $currentDir) {
            break
        }

        $currentDir = $parentDir
    }

    return $null
}

function Get-ProjectPaths {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot
    )

    $srcDir = Join-Path $ProjectRoot "src"
    $assetsDir = Join-Path $ProjectRoot "assets"
    $entryPoint = Join-Path $srcDir "main.py"
    $iconPath = Join-Path $assetsDir "icon.ico"

    return @{
        SrcDir    = $srcDir
        EntryPoint = $entryPoint
        AssetsDir = $assetsDir
        IconPath  = $iconPath
    }
}

function Test-PyInstaller {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Python
    )

    & $Python -m pip show pyinstaller *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[FAIL] PyInstaller not installed."
        Write-Host "[OK] Install: python -m pip install pyinstaller"
        exit 1
    }
}

function Clear-BuildArtifacts {
    Remove-Item -Recurse -Force dist, build -ErrorAction SilentlyContinue
    Get-ChildItem -Filter "*.spec" -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
}

function Read-BuildMode {
    $userInput = Read-Host "Build mode: 1=onefile, 2=onedir (default: 2)"
    if ([string]::IsNullOrWhiteSpace($userInput)) {
        return "onedir"
    }
    $value = $userInput.Trim().ToLower()
    if ($value -eq "1" -or $value -eq "onefile") {
        return "onefile"
    }
    return "onedir"
}

function Invoke-ExecutableBuild {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Python,
        [Parameter(Mandatory = $true)]
        [string]$AppName,
        [Parameter(Mandatory = $true)]
        [string]$BuildMode,
        [Parameter(Mandatory = $true)]
        [string]$EntryPoint,
        [Parameter(Mandatory = $true)]
        [string]$AssetsDir,
        [Parameter(Mandatory = $true)]
        [string]$IconPath
    )

    $piArgs = @("--noconsole", "--clean", "--name", $AppName)
    if ($BuildMode -eq "onefile") {
        $piArgs += "--onefile"
    } else {
        $piArgs += "--onedir"
    }

    if (Test-Path -LiteralPath $IconPath) {
        $piArgs += @("--icon", $IconPath)
        $piArgs += @("--add-data", "$IconPath;icon.ico")
    } else {
        Write-Host "[WARNING] icon.ico not found. Skipping --icon."
    }

    if (Test-Path -LiteralPath $AssetsDir) {
        $piArgs += @("--add-data", "$AssetsDir;assets")
    } else {
        Write-Host "[WARNING] assets folder not found. Skipping --add-data."
    }

    $piArgs += $EntryPoint

    Write-Host "[BUILD] Building with PyInstaller..."
    & $Python -m PyInstaller @piArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[FAIL] PyInstaller build failed."
        exit 1
    }
}

function Initialize-ReleasePackage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot,
        [Parameter(Mandatory = $true)]
        [string]$AppName
    )

    New-Item -ItemType Directory -Force release | Out-Null

    $distExe = Join-Path $ProjectRoot "dist\$AppName.exe"
    $distDir = Join-Path $ProjectRoot "dist\$AppName"

    $packageDir = Join-Path $ProjectRoot "release\_package"
    Remove-Item -Recurse -Force $packageDir -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force $packageDir | Out-Null

    if ($distExe -and (Test-Path -LiteralPath $distExe)) {
        Copy-Item -LiteralPath $distExe -Destination $packageDir -Force
    }
    elseif ($distDir -and (Test-Path -LiteralPath $distDir)) {
        Copy-Item -LiteralPath "$distDir\*" -Destination $packageDir -Recurse -Force
    }
    else {
        Write-Host "[FAIL] PyInstaller output not found."
        Write-Host "distExe='$distExe'"
        Write-Host "distDir='$distDir'"
        exit 1
    }

    Copy-Item -LiteralPath $packageDir -Destination (Join-Path $ProjectRoot "release\$AppName") -Recurse -Force
}

$rootInfo = Find-ProjectRoot -StartDir $PSScriptRoot -Markers $ROOT_MARKERS
if (-not $rootInfo) {
    Write-Host "[FAIL] Project root not found."
    exit 1
}

$PROJECT_ROOT = $rootInfo.Root
Set-Location $PROJECT_ROOT

$paths = Get-ProjectPaths -ProjectRoot $PROJECT_ROOT
$ENTRYPOINT  = $paths.EntryPoint
$ASSETS_DIR  = $paths.AssetsDir
$ICON_PATH   = $paths.IconPath

Write-Host "=== Package build start ==="
Ensure-PyInstaller -Python $PYTHON
Clean-BuildArtifacts

$BUILD_MODE = Read-BuildMode
Build-Executable -Python $PYTHON -AppName $APP_NAME -BuildMode $BUILD_MODE -EntryPoint $ENTRYPOINT -AssetsDir $ASSETS_DIR -IconPath $ICON_PATH

Prepare-ReleasePackage -ProjectRoot $PROJECT_ROOT -AppName $APP_NAME
Write-Host "=== Package build complete ==="