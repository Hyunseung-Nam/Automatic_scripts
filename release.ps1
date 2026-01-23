Set-StrictMode -Off
$ErrorActionPreference = "Stop"

# ========================================
# 설정
# ========================================
$APP_NAME = "NanoMemory_PC_Spec_Viewer"
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
    $entryPoint = Join-Path $srcDir "main.py"
    $versionPy = Join-Path $srcDir "version.py"
    $assetsDir = Join-Path $srcDir "assets"
    $iconPath = Join-Path $assetsDir "ico_out-nano-logo_blue.ico"

    return @{
        SrcDir    = $srcDir
        EntryPoint = $entryPoint
        VersionPy = $versionPy
        AssetsDir = $assetsDir
        IconPath  = $iconPath
    }
}

function Get-AppVersion {
    param(
        [Parameter(Mandatory = $true)]
        [string]$VersionFile
    )

    if (-not (Test-Path -LiteralPath $VersionFile)) {
        return ""
    }

    $content = Get-Content -LiteralPath $VersionFile -Raw
    $m = [regex]::Match($content, '__version__\s*=\s*["'']([^"'']+)["'']')
    if ($m.Success) { return $m.Groups[1].Value }
    return ""
}

function Ensure-PyInstaller {
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

function Clean-BuildArtifacts {
    Remove-Item -Recurse -Force dist, build -ErrorAction SilentlyContinue
    Get-ChildItem -Filter "*.spec" -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
}

function Build-Executable {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Python,
        [Parameter(Mandatory = $true)]
        [string]$AppName,
        [Parameter(Mandatory = $true)]
        [string]$EntryPoint,
        [Parameter(Mandatory = $true)]
        [string]$AssetsDir,
        [Parameter(Mandatory = $true)]
        [string]$IconPath
    )

    $piArgs = @("--noconsole", "--onefile", "--clean", "--name", $AppName)

    if (Test-Path -LiteralPath $IconPath) {
        $piArgs += @("--icon", $IconPath)
    } else {
        Write-Host "[WARNING] icon.ico not found. Skipping --icon."
    }

    if (Test-Path -LiteralPath $AssetsDir) {
        # Windows에서 PyInstaller add-data 구분자는 ; (src;dst)
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

function Prepare-ReleasePackage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot,
        [Parameter(Mandatory = $true)]
        [string]$AppName
    )

    New-Item -ItemType Directory -Force release | Out-Null
    Remove-Item -Force (Join-Path $ProjectRoot "release\$AppName.exe") -ErrorAction SilentlyContinue

    $distExe = Join-Path $ProjectRoot "dist\$AppName.exe"
    $distDir = Join-Path $ProjectRoot "dist\$AppName"

    $packageDir = Join-Path $ProjectRoot "release\_package"
    Remove-Item -Recurse -Force $packageDir -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force $packageDir | Out-Null

    $readmeSource = Join-Path $ProjectRoot "README.txt"
    if (Test-Path -LiteralPath $readmeSource) {
        Copy-Item -LiteralPath $readmeSource -Destination (Join-Path $packageDir "README.txt") -Force
    } else {
        Write-Host "[WARNING] README.txt not found. Skipping README.txt."
    }

    # ---- 핵심: Test-Path null 방어 + LiteralPath 사용 ----
    if ($distExe -and (Test-Path -LiteralPath $distExe)) {
        # --onefile
        Copy-Item -LiteralPath $distExe -Destination $packageDir -Force
    }
    elseif ($distDir -and (Test-Path -LiteralPath $distDir)) {
        # --onedir
        Copy-Item -LiteralPath "$distDir\*" -Destination $packageDir -Recurse -Force
    }
    else {
        Write-Host "[FAIL] PyInstaller output not found."
        Write-Host "distExe='$distExe'"
        Write-Host "distDir='$distDir'"
        exit 1
    }

    $packageExe = Join-Path $packageDir "$AppName.exe"
    if (Test-Path -LiteralPath $packageExe) {
        Copy-Item -LiteralPath $packageExe -Destination (Join-Path $ProjectRoot "release\$AppName.exe") -Force
    } else {
        Write-Host "[FAIL] Packaged exe not found: $packageExe"
        exit 1
    }

    return $packageDir
}

function Build-ReleaseZip {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot,
        [Parameter(Mandatory = $true)]
        [string]$AppName,
        [Parameter(Mandatory = $true)]
        [string]$AppVersion,
        [Parameter(Mandatory = $true)]
        [string]$PackageDir
    )

    $zipName = if ($AppVersion) { "$AppName`_v$AppVersion`.zip" } else { "$AppName`.zip" }
    $zipPath = Join-Path $ProjectRoot "release\$zipName"
    if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }

    Compress-Archive -Path "$PackageDir\*" -DestinationPath $zipPath -Force
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[FAIL] Compress-Archive failed."
        exit 1
    }

    Remove-Item -Recurse -Force $PackageDir -ErrorAction SilentlyContinue

    Write-Host "=== Release build complete ==="
    Write-Host "[OK] Output: release\$AppName.exe"
    Write-Host "[OK] Output: $zipPath"

    return $zipPath
}

function Build-SourcePackage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot,
        [Parameter(Mandatory = $true)]
        [string]$SrcDir,
        [Parameter(Mandatory = $true)]
        [string]$AssetsDir,
        [Parameter(Mandatory = $true)]
        [string]$AppVersion
    )

    $sourceDir = Join-Path $ProjectRoot "release\_source"
    Remove-Item -Recurse -Force $sourceDir -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force $sourceDir | Out-Null

    Copy-Item -LiteralPath (Join-Path $ProjectRoot "requirements.txt") -Destination $sourceDir -Force -ErrorAction SilentlyContinue
    Copy-Item -LiteralPath (Join-Path $ProjectRoot "README_DELIVERY.md") -Destination $sourceDir -Force -ErrorAction SilentlyContinue

    if (Test-Path -LiteralPath $AssetsDir) {
        Copy-Item -LiteralPath $AssetsDir -Destination (Join-Path $sourceDir "assets") -Recurse -Force
    }

    $coreDir = Join-Path $sourceDir "core"
    if (Test-Path -LiteralPath (Join-Path $SrcDir "core")) {
        New-Item -ItemType Directory -Force $coreDir | Out-Null
        Get-ChildItem (Join-Path $SrcDir "core") -Recurse -File -Exclude "*.pyc", "*.pyo" |
            Where-Object { $_.FullName -notmatch "\\__pycache__\\" } |
            Copy-Item -Destination $coreDir -Force
    }

    $uiDir = Join-Path $sourceDir "ui"
    if (Test-Path -LiteralPath (Join-Path $SrcDir "ui")) {
        New-Item -ItemType Directory -Force $uiDir | Out-Null
        Get-ChildItem (Join-Path $SrcDir "ui") -Recurse -File -Exclude "*.pyc", "*.pyo" |
            Where-Object { $_.FullName -notmatch "\\__pycache__\\" } |
            Copy-Item -Destination $uiDir -Force
    }

    Copy-Item -LiteralPath (Join-Path $SrcDir "controller.py") -Destination $sourceDir -Force -ErrorAction SilentlyContinue
    Copy-Item -LiteralPath (Join-Path $SrcDir "logger.py") -Destination $sourceDir -Force -ErrorAction SilentlyContinue
    Copy-Item -LiteralPath (Join-Path $SrcDir "main.py") -Destination $sourceDir -Force -ErrorAction SilentlyContinue
    Copy-Item -LiteralPath (Join-Path $SrcDir "version.py") -Destination $sourceDir -Force -ErrorAction SilentlyContinue

    $sourceZipName = if ($AppVersion) { "NanoMemory_PC_Spec_Viewer_source_v$AppVersion`.zip" } else { "NanoMemory_PC_Spec_Viewer_source.zip" }
    $sourceZipPath = Join-Path $ProjectRoot "release\$sourceZipName"
    if (Test-Path -LiteralPath $sourceZipPath) { Remove-Item -LiteralPath $sourceZipPath -Force }

    Compress-Archive -Path "$sourceDir\*" -DestinationPath $sourceZipPath -Force
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[FAIL] Compress-Archive (source) failed."
        exit 1
    }

    Remove-Item -Recurse -Force $sourceDir -ErrorAction SilentlyContinue
    Write-Host "[OK] Output: $sourceZipPath"
}

$rootInfo = Find-ProjectRoot -StartDir $PSScriptRoot -Markers $ROOT_MARKERS
if (-not $rootInfo) {
    Write-Host "[FAIL] Project root not found."
    Write-Host "[FAIL] None of the following files were found in any parent directory:"
    foreach ($marker in $ROOT_MARKERS) {
        Write-Host "   - $marker"
    }
    exit 1
}

$PROJECT_ROOT = $rootInfo.Root
$FOUND_MARKER = $rootInfo.Marker

Set-Location $PROJECT_ROOT
Write-Host "[OK] Project root detected at:"
Write-Host "  $PROJECT_ROOT"
Write-Host "  (marker: $FOUND_MARKER)"
Write-Host ""

$paths = Get-ProjectPaths -ProjectRoot $PROJECT_ROOT
$SRC_DIR     = $paths.SrcDir
$ENTRYPOINT  = $paths.EntryPoint
$VERSION_PY  = $paths.VersionPy
$ASSETS_DIR  = $paths.AssetsDir
$ICON_PATH   = $paths.IconPath

Write-Host "SCRIPT_PATH  = '$SCRIPT_PATH'"
Write-Host "PROJECT_ROOT = '$PROJECT_ROOT'"
Write-Host "SRC_DIR      = '$SRC_DIR'"
Write-Host "ASSETS_DIR   = '$ASSETS_DIR'"
Write-Host "ICON_PATH    = '$ICON_PATH'"

$APP_VERSION = Get-AppVersion -VersionFile $VERSION_PY

Write-Host "=== Release build start ==="
Write-Host "Project Root: $PROJECT_ROOT"
Write-Host "PSVersion: $($PSVersionTable.PSVersion)"

Ensure-PyInstaller -Python $PYTHON
Clean-BuildArtifacts
Build-Executable -Python $PYTHON -AppName $APP_NAME -EntryPoint $ENTRYPOINT -AssetsDir $ASSETS_DIR -IconPath $ICON_PATH

$packageDir = Prepare-ReleasePackage -ProjectRoot $PROJECT_ROOT -AppName $APP_NAME
$zipPath = Build-ReleaseZip -ProjectRoot $PROJECT_ROOT -AppName $APP_NAME -AppVersion $APP_VERSION -PackageDir $packageDir

# ---------------------------
# 소스 패키지 생성
# ---------------------------
Build-SourcePackage -ProjectRoot $PROJECT_ROOT -SrcDir $SRC_DIR -AssetsDir $ASSETS_DIR -AppVersion $APP_VERSION
