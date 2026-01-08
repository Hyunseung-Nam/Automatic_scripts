# clean.ps1
# 빌드/캐시 찌꺼기 정리

$PROJECT_ROOT = Split-Path -Parent $PSScriptRoot
Set-Location $PROJECT_ROOT

Write-Host "▶ Cleaning build artifacts..."

# PyInstaller
Remove-Item -Recurse -Force dist, build -ErrorAction SilentlyContinue
Get-ChildItem -Filter "*.spec" -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue

# Python cache
Get-ChildItem -Recurse -Directory -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -eq "__pycache__" } |
    ForEach-Object { Remove-Item -Recurse -Force $_.FullName -ErrorAction SilentlyContinue }

Write-Host "✔ Clean complete."