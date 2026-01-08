# release.ps1
# clean -> pyinstaller -> release 폴더 복사 -> zip

$PROJECT_ROOT = Split-Path -Parent $PSScriptRoot
Set-Location $PROJECT_ROOT

$APP_NAME    = "LaundryPointManager"
$ENTRYPOINT  = "src\main.py"
$VENV_DIR    = ".venv"
$VENV_PY     = Join-Path $PROJECT_ROOT "$VENV_DIR\Scripts\python.exe"
$ACTIVATE    = Join-Path $PROJECT_ROOT "$VENV_DIR\Scripts\Activate.ps1"

# 선택 리소스
$ICON_PATH   = "icon.ico"
$ASSETS_DIR  = "assets"

# 버전(선택): version.py가 루트에 있으면 APP_VERSION 읽어서 zip 이름에 사용
$APP_VERSION = ""
if (Test-Path "version.py") {
    $content = Get-Content "version.py" -Raw
    $m = [regex]::Match($content, 'APP_VERSION\s*=\s*["'']([^"'']+)["'']')
    if ($m.Success) { $APP_VERSION = $m.Groups[1].Value }
}
$STAMP = Get-Date -Format "yyyyMMdd_HHmm"

Write-Host "=== Release build start ==="
Write-Host "Project Root: $PROJECT_ROOT"

if (-not (Test-Path $VENV_PY)) {
    Write-Host "[FAIL] .venv not found. Run: .\script\venv_setup.ps1"
    exit 1
}

# venv 활성화(환경변수/콘솔 스무스용)
try { & $ACTIVATE } catch { }

# PyInstaller가 venv에 없으면 설치 안내
& $VENV_PY -m pip show pyinstaller *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] PyInstaller not installed in venv."
    Write-Host "[OK] Install: python -m pip install pyinstaller"
    exit 1
}

# 기존 빌드 제거
Remove-Item -Recurse -Force dist, build -ErrorAction SilentlyContinue
Get-ChildItem -Filter "*.spec" -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue

# PyInstaller 옵션 구성
$piArgs = @("--noconsole","--onedir","--clean","--name",$APP_NAME)

if (Test-Path $ICON_PATH) {
    $piArgs += @("--icon",$ICON_PATH)
} else {
    Write-Host "⚠ icon.ico not found. Skipping --icon."
}

if (Test-Path $ASSETS_DIR) {
    # Windows에서 PyInstaller add-data 구분자는 ; (src;dst)
    $piArgs += @("--add-data","$ASSETS_DIR;$ASSETS_DIR")
} else {
    Write-Host "⚠ assets folder not found. Skipping --add-data."
}

$piArgs += $ENTRYPOINT

Write-Host "▶ Building with PyInstaller..."
& $VENV_PY -m PyInstaller @piArgs
if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] PyInstaller build failed."
    exit 1
}

# 릴리즈 폴더 생성/정리
New-Item -ItemType Directory -Force release | Out-Null
Remove-Item -Recurse -Force "release\$APP_NAME" -ErrorAction SilentlyContinue

# 결과물 이동
Copy-Item "dist\$APP_NAME" "release\" -Recurse -Force

# zip 생성
$zipName = if ($APP_VERSION) { "$APP_NAME`_v$APP_VERSION`_$STAMP.zip" } else { "$APP_NAME`_$STAMP.zip" }
$zipPath = Join-Path $PROJECT_ROOT "release\$zipName"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

Compress-Archive -Path "release\$APP_NAME\*" -DestinationPath $zipPath -Force

Write-Host "=== Release build complete ==="
Write-Host "✔ Output: $zipPath"
