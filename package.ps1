# 항상 프로젝트 루트 기준으로 실행
$PROJECT_ROOT = Split-Path -Parent $PSScriptRoot
Set-Location $PROJECT_ROOT

# 터미널에서 .\release.ps1 로 실행

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