# bootstrap.ps1
# 처음 세팅: venv_setup -> check_env -> 안내

$PROJECT_ROOT = Split-Path -Parent $PSScriptRoot
Set-Location $PROJECT_ROOT

Write-Host "=== Bootstrap start ==="

# 1) venv 세팅
Write-Host "▶ Step 1) Setup venv"
& "$PROJECT_ROOT\script\venv_setup.ps1"
if ($LASTEXITCODE -ne 0) { Write-Host "[FAIL] venv_setup failed."; exit 1 }

# 2) 환경 점검
Write-Host ""
Write-Host "▶ Step 2) Check environment"
& "$PROJECT_ROOT\script\check_env.ps1"
if ($LASTEXITCODE -ne 0) { Write-Host "[FAIL] check_env failed."; exit 1 }

Write-Host ""
Write-Host "=== Bootstrap complete ==="
Write-Host "Next:"
Write-Host "  .\script\dev_start.ps1"
