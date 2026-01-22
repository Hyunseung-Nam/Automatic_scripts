# ================================
# venv_setup.ps1
# Python Virtual Environment Setup (Versioned)
# ================================

# 설정 영역 -------------------
$VENV_DIR = ".venv"
$PYTHON_VERSION_FILE = "python-version.txt"
# --------------------------------


# ========================================
# 프로젝트 루트 탐색
# (.gitignore / requirements.txt / python-version.txt
#  중 하나라도 있으면 루트로 간주)
# ========================================

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
    Write-Host "[OK] None of the following files(.gitignore, requirement.txt, python-version.py) were found in any parent directory:"
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


# ========================================
# 배너 출력
# ========================================

Write-Host "========================================"
Write-Host " Python Virtual Environment Setup"
Write-Host "========================================"
Write-Host ""


# ========================================
# python-version.txt 확인
# ========================================

if (-not (Test-Path $PYTHON_VERSION_FILE)) {
    Write-Host "[FAIL] $PYTHON_VERSION_FILE not found in project root."
    Write-Host "[OK] Create $PYTHON_VERSION_FILE and put a version like: 3.12"
    exit 1
}

$PYTHON_VERSION = (Get-Content $PYTHON_VERSION_FILE -TotalCount 1).Trim()

if (-not $PYTHON_VERSION) {
    Write-Host "[FAIL] $PYTHON_VERSION_FILE is empty."
    Write-Host "[OK] Put a version like: 3.12"
    exit 1
}

Write-Host "Target Python Version: $PYTHON_VERSION"
Write-Host ""


# ========================================
# py launcher 확인
# ========================================

try {
    $pyVersion = py --version 2>&1
    Write-Host "✔ py launcher detected: $pyVersion"
} catch {
    Write-Host "[FAIL] py launcher not found."
    Write-Host "[OK] Install Python from python.org (includes py launcher)."
    exit 1
}


# ========================================
# 해당 Python 버전 설치 여부 확인
# ========================================

$pythonPath = py -$PYTHON_VERSION -c "import sys; print(sys.executable)" 2>$null
if (-not $pythonPath) {
    Write-Host "[FAIL] Python $PYTHON_VERSION is not installed (or not registered to py launcher)."
    Write-Host "[OK] Install Python $PYTHON_VERSION first."
    Write-Host "[OK] Check installed versions with: py -0"
    exit 1
}

Write-Host "[OK] Python $PYTHON_VERSION detected at:"
Write-Host "  $pythonPath"
Write-Host ""


# ========================================
# 기존 venv 검사 / 생성
# ========================================

if (Test-Path $VENV_DIR) {
    $venvPythonExe = Join-Path $PROJECT_ROOT "$VENV_DIR\Scripts\python.exe"

    if (-not (Test-Path $venvPythonExe)) {
        Write-Host "[FAIL] Existing $VENV_DIR found, but python.exe is missing."
        Write-Host "[OK] Delete $VENV_DIR and run again."
        exit 1
    }

    $venvPyVer = & $venvPythonExe -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>$null

    if (-not $venvPyVer) {
        Write-Host "[FAIL] Could not read Python version from existing $VENV_DIR."
        exit 1
    }

    if ($venvPyVer -ne $PYTHON_VERSION) {
        Write-Host "[FAIL] Existing $VENV_DIR uses Python $venvPyVer, but required is $PYTHON_VERSION."
        Write-Host "[OK] Delete $VENV_DIR and run again."
        exit 1
    }

    Write-Host "[OK] $VENV_DIR already exists and matches Python $PYTHON_VERSION."
} else {
    Write-Host "Creating virtual environment ($VENV_DIR)..."
    py -$PYTHON_VERSION -m venv $VENV_DIR

    if (-not (Test-Path $VENV_DIR)) {
        Write-Host "[FAIL] Failed to create virtual environment."
        exit 1
    }

    Write-Host "[OK] Virtual environment created."
}

Write-Host ""


# ========================================
# 가상환경 활성화 (dot-sourcing)
# ========================================

$activateScript = Join-Path $PROJECT_ROOT "$VENV_DIR\Scripts\Activate.ps1"

if (-not (Test-Path $activateScript)) {
    Write-Host "[FAIL] Activation script not found:"
    Write-Host "  $activateScript"
    exit 1
}

Write-Host "Activating virtual environment..."
try {
    . $activateScript
} catch {
    Write-Host "[FAIL] Failed to activate virtual environment."
    Write-Host "[OK] Try this once:"
    Write-Host "   Set-ExecutionPolicy -Scope CurrentUser RemoteSigned"
    exit 1
}


# ========================================
# venv Python 사용 중인지 강제 검증
# ========================================

$activePython = python -c "import sys; print(sys.executable)" 2>$null
if (-not $activePython -or ($activePython -notlike "*$VENV_DIR*")) {
    Write-Host "[FAIL] Python is not running from virtual environment."
    Write-Host "Detected:"
    Write-Host "  $activePython"
    exit 1
}

Write-Host "[OK] Virtual environment active:"
Write-Host "  $activePython"
Write-Host ""


# ========================================
# pip 업그레이드
# ========================================

Write-Host "Upgrading pip..."
python -m pip install --upgrade pip
if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] pip upgrade failed."
    exit 1
}


# ========================================
# requirements.txt 설치
# ========================================

if (Test-Path "requirements.txt") {
    Write-Host "Installing dependencies from requirements.txt..."
    python -m pip install -r requirements.txt

    if ($LASTEXITCODE -ne 0) {
        Write-Host "[FAIL] Dependency installation failed."
        exit 1
    }

    Write-Host "[OK] Dependencies installed successfully."
} else {
    Write-Host "[WARNING] requirements.txt not found. Skipping dependency install."
}


# ========================================
# 완료
# ========================================

Write-Host ""
Write-Host "========================================"
Write-Host "[OK] Virtual environment setup completed!"
Write-Host "========================================"
Write-Host "To activate manually next time:"
Write-Host "  .\$VENV_DIR\Scripts\Activate.ps1"
