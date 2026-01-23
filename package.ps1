$ROOT_MARKERS = @(
    ".gitignore",
    "requirements.txt",
    "python-version.txt"
)

$currentDir = $PSScriptRoot
$PROJECT_ROOT = $null
$FOUND_MARKER = $null

while ($true) {
    foreach ($marker in $ROOT_MARKERS) {
        if (Test-Path (Join-Path $currentDir $marker)) {
            $PROJECT_ROOT = $currentDir
            $FOUND_MARKER = $marker
            break
        }
    }

    if ($PROJECT_ROOT) {
        break
    }

    $parentDir = Split-Path $currentDir -Parent
    if (-not $parentDir -or $parentDir -eq $currentDir) {
        break
    }

    $currentDir = $parentDir
}

if (-not $PROJECT_ROOT) {
    Write-Host "[FAIL] Project root not found."
    Write-Host "[FAIL] None of the following files were found in any parent directory:"
    foreach ($marker in $ROOT_MARKERS) {
        Write-Host "   - $marker"
    }
    exit 1
}

Set-Location $PROJECT_ROOT
Write-Host "[OK] Project root detected at:"
Write-Host "  $PROJECT_ROOT"
Write-Host "  (marker: $FOUND_MARKER)"
Write-Host ""

# 터미널에서 .\package.ps1 로 실행

Write-Host "=== Release build start ==="
Write-Host "Project Root: $PROJECT_ROOT"

# 기존 빌드 폴더 제거
Remove-Item -Recurse -Force dist, build -ErrorAction SilentlyContinue

# PyInstaller 빌드
pyinstaller --noconsole --onedir `
  --clean `
  --icon=icon.ico `
  --add-data="assets;assets" `
  --name "LaundryPointManager" `
  src\main.py

# 릴리즈 폴더 생성
New-Item -ItemType Directory -Force release

# 결과물 이동
Copy-Item dist\LaundryPointManager release\ -Recurse

Write-Host "=== Release build complete ==="