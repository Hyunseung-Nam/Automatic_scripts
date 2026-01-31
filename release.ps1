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
    $versionPy = Join-Path $srcDir "version.py"
    $iconPath = Join-Path $assetsDir "icon.ico"

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

function Read-YesNo {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prompt,
        [string]$Default = "Y"
    )

    $userInput = Read-Host "$Prompt [Y/N] (default: $Default)"
    if ([string]::IsNullOrWhiteSpace($userInput)) {
        $userInput = $Default
    }
    $userInput = $userInput.Trim().ToUpper()
    return ($userInput -eq "Y")
}

function Read-BuildMode {
    $userInput = Read-Host "Build mode: 1=onefile, 2=onedir (default: 1)"
    if ([string]::IsNullOrWhiteSpace($userInput)) {
        return "onefile"
    }
    $value = $userInput.Trim().ToLower()
    if ($value -eq "2" -or $value -eq "onedir") {
        return "onedir"
    }
    return "onefile"
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
    if ($BuildMode -eq "onedir") {
        $piArgs += "--onedir"
    } else {
        $piArgs += "--onefile"
    }

    if (Test-Path -LiteralPath $IconPath) {
        $piArgs += @("--icon", $IconPath)
        $piArgs += @("--add-data", "$IconPath;icon.ico")
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

function Initialize-ReleasePackage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot,
        [Parameter(Mandatory = $true)]
        [string]$AppName,
        [Parameter(Mandatory = $true)]
        [string]$BuildMode
    )

    New-Item -ItemType Directory -Force release | Out-Null
    Remove-Item -Force (Join-Path $ProjectRoot "release\$AppName.exe") -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force (Join-Path $ProjectRoot "release\_internal") -ErrorAction SilentlyContinue

    $distExe = Join-Path $ProjectRoot "dist\$AppName.exe"
    $distDir = Join-Path $ProjectRoot "dist\$AppName"
    if ($BuildMode -eq "onefile") {
        if ($distExe -and (Test-Path -LiteralPath $distExe)) {
            Copy-Item -LiteralPath $distExe -Destination (Join-Path $ProjectRoot "release\$AppName.exe") -Force
        } else {
            Write-Host "[FAIL] PyInstaller output not found: $distExe"
            exit 1
        }
    } else {
        if ($distDir -and (Test-Path -LiteralPath $distDir)) {
            Copy-Item -LiteralPath (Join-Path $distDir "$AppName.exe") -Destination (Join-Path $ProjectRoot "release\$AppName.exe") -Force
            Copy-Item -LiteralPath (Join-Path $distDir "_internal") -Destination (Join-Path $ProjectRoot "release\_internal") -Recurse -Force
        } else {
            Write-Host "[FAIL] PyInstaller output not found: $distDir"
            exit 1
        }
    }

    $releaseExe = Join-Path $ProjectRoot "release\$AppName.exe"
    if (-not (Test-Path -LiteralPath $releaseExe)) {
        Write-Host "[FAIL] Release exe not found after copy: $releaseExe"
        exit 1
    }
    if ($BuildMode -eq "onedir") {
        $releaseInternal = Join-Path $ProjectRoot "release\_internal"
        if (-not (Test-Path -LiteralPath $releaseInternal)) {
            Write-Host "[FAIL] Release _internal not found after copy: $releaseInternal"
            exit 1
        }
    }
}

function Compress-ReleasePackage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot,
        [Parameter(Mandatory = $true)]
        [string]$AppName,
        [Parameter(Mandatory = $true)]
        [string]$AppVersion,
        [Parameter(Mandatory = $true)]
        [string[]]$ZipInputs
    )

    $zipName = if ($AppVersion) { "$AppName`_v$AppVersion`.zip" } else { "$AppName`.zip" }
    $zipPath = Join-Path $ProjectRoot "release\$zipName"
    if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }

    if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot "release"))) {
        New-Item -ItemType Directory -Force (Join-Path $ProjectRoot "release") | Out-Null
    }
    foreach ($item in $ZipInputs) {
        if (-not (Test-Path -LiteralPath $item)) {
            Write-Host "[FAIL] Zip input not found: $item"
            exit 1
        }
    }

    Compress-Archive -Path $ZipInputs -DestinationPath $zipPath -Force
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[FAIL] Compress-Archive failed."
        exit 1
    }

    Write-Host "=== Release build complete ==="
    Write-Host "[OK] Output: release\$AppName.exe"
    Write-Host "[OK] Output: $zipPath"

    return $zipPath
}

function Compress-SourcePackage {
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

    $srcOutDir = Join-Path $sourceDir "src"
    New-Item -ItemType Directory -Force $srcOutDir | Out-Null

    Get-ChildItem $SrcDir -Recurse -File -Exclude "*.pyc", "*.pyo" |
        Where-Object { $_.FullName -notmatch "\\__pycache__\\" } |
        ForEach-Object {
            $relative = $_.FullName.Substring($SrcDir.Length).TrimStart("\")
            $destPath = Join-Path $srcOutDir $relative
            $destDir = Split-Path $destPath -Parent
            if (-not (Test-Path -LiteralPath $destDir)) {
                New-Item -ItemType Directory -Force $destDir | Out-Null
            }
            Copy-Item -LiteralPath $_.FullName -Destination $destPath -Force
        }

    $sourceZipName = if ($AppVersion) { "LaundryPointManager_source_v$AppVersion`.zip" } else { "LaundryPointManager_source.zip" }
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

Write-Host "PROJECT_ROOT = '$PROJECT_ROOT'"
Write-Host "SRC_DIR      = '$SRC_DIR'"
Write-Host "ASSETS_DIR   = '$ASSETS_DIR'"
Write-Host "ICON_PATH    = '$ICON_PATH'"

$APP_VERSION = Get-AppVersion -VersionFile $VERSION_PY

Write-Host "=== Release build start ==="
Write-Host "Project Root: $PROJECT_ROOT"
Write-Host "PSVersion: $($PSVersionTable.PSVersion)"

$BUILD_MODE = Read-BuildMode
$MAKE_EXE_ZIP = Read-YesNo -Prompt "Create exe zip (release\\${APP_NAME}_vX.zip)?" -Default "Y"
$MAKE_SOURCE_ZIP = Read-YesNo -Prompt "Create source zip (release\\${APP_NAME}_source_vX.zip)?" -Default "Y"

Ensure-PyInstaller -Python $PYTHON
Clean-BuildArtifacts
Build-Executable -Python $PYTHON -AppName $APP_NAME -BuildMode $BUILD_MODE -EntryPoint $ENTRYPOINT -AssetsDir $ASSETS_DIR -IconPath $ICON_PATH

if ($MAKE_EXE_ZIP) {
    $releaseExe = Join-Path $PROJECT_ROOT "release\$APP_NAME.exe"
    if (-not (Test-Path -LiteralPath $releaseExe)) {
        $distDir = Join-Path $PROJECT_ROOT "dist\$APP_NAME"
        $distDirExe = Join-Path $distDir "$APP_NAME.exe"
        $distInternal = Join-Path $distDir "_internal"

        if (Test-Path -LiteralPath $distDirExe) {
            Copy-Item -LiteralPath $distDirExe -Destination $releaseExe -Force
        }

        if (Test-Path -LiteralPath $distInternal) {
            Copy-Item -LiteralPath $distInternal -Destination (Join-Path $PROJECT_ROOT "release\_internal") -Recurse -Force
        }
    }

    $zipInputs = @($releaseExe)
    if ($BUILD_MODE -eq "onedir") {
        $zipInputs += (Join-Path $PROJECT_ROOT "release\_internal")
    }
    $zipPath = Build-ReleaseZip -ProjectRoot $PROJECT_ROOT -AppName $APP_NAME -AppVersion $APP_VERSION -ZipInputs $zipInputs
} else {
    Write-Host "[OK] Output: release\\$APP_NAME.exe"
}

# ---------------------------
# 소스 패키지 생성
# ---------------------------
if ($MAKE_SOURCE_ZIP) {
    Build-SourcePackage -ProjectRoot $PROJECT_ROOT -SrcDir $SRC_DIR -AssetsDir $ASSETS_DIR -AppVersion $APP_VERSION
}