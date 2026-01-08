# check_env.ps1
# 실행/빌드 전 환경 점검

param(
  [switch]$VerboseOutput
)

$PROJECT_ROOT = Split-Path -Parent $PSScriptRoot
Set-Location $PROJECT_ROOT

$VENV_DIR = ".venv"
$PYVER_FILE = "python-version.txt"

function Ok($msg){ Write-Host "✔ $msg" }
function Warn($msg){ Write-Host "⚠ $msg" }
function Fail($msg){ Write-Host "[FAIL] $msg"; $script:HAS_FAIL = $true }

$HAS_FAIL = $false

Write-Host "=== Environment Check ==="
Write-Host "Project Root: $PROJECT_ROOT"

# Windows 버전
try {
    $os = (Get-CimInstance Win32_OperatingSystem)
    Ok "OS: $($os.Caption) ($($os.Version))"
} catch {
    Warn "OS info not available."
}

# python-version.txt
if (-not (Test-Path $PYVER_FILE)) {
    Fail "$PYVER_FILE not found."
} else {
    $req = (Get-Content $PYVER_FILE -TotalCount 1).Trim()
    if (-not $req) { Fail "$PYVER_FILE is empty." } else { Ok "Required Python: $req" }
}

# py launcher
try {
    $pyv = py --version 2>&1
    Ok "py launcher: $pyv"
} catch {
    Fail "py launcher not found. Install Python from python.org."
}

# 해당 파이썬 버전 설치 여부
if (Test-Path $PYVER_FILE) {
    $req = (Get-Content $PYVER_FILE -TotalCount 1).Trim()
    if ($req) {
        $pyPath = py -$req -c "import sys; print(sys.executable)" 2>$null
        if ($pyPath) { Ok "Python $req found: $pyPath" } else { Fail "Python $req not installed. (Check: py -0)" }
    }
}

# venv 존재/버전
$venvPy = Join-Path $PROJECT_ROOT "$VENV_DIR\Scripts\python.exe"
if (-not (Test-Path $venvPy)) {
    Warn ".venv not found. (Run: .\script\venv_setup.ps1)"
} else {
    $venvVer = & $venvPy -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>$null
    if ($venvVer) { Ok ".venv Python: $venvVer" } else { Warn "Could not read .venv python version." }
}

# requirements.txt
if (Test-Path "requirements.txt") { Ok "requirements.txt exists" } else { Warn "requirements.txt not found" }

# PyInstaller (빌드용)
if (Test-Path $venvPy) {
    & $venvPy -m pip show pyinstaller *> $null
    if ($LASTEXITCODE -eq 0) { Ok "PyInstaller installed in venv" } else { Warn "PyInstaller not installed in venv (release.ps1 needs it)" }
}

# 진입점 확인
if (Test-Path "src\main.py") { Ok "Entry exists: src\main.py" } else { Fail "Entry missing: src\main.py" }

# 리소스(선택)
if (Test-Path "assets") { Ok "assets folder exists" } else { Warn "assets folder not found (ok if not used)" }
if (Test-Path "icon.ico") { Ok "icon.ico exists" } else { Warn "icon.ico not found (ok if not used)" }

Write-Host ""
if ($HAS_FAIL) {
    Write-Host "=== Result: FAIL ==="
    exit 1
} else {
    Write-Host "=== Result: OK (with possible warnings) ==="
    exit 0
}
