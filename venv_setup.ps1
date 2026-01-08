# ================================
# venv_setup.ps1
# Python Virtual Environment Setup (Versioned)
# ================================

# 항상 프로젝트 루트 기준으로 실행
$PROJECT_ROOT = Split-Path -Parent $PSScriptRoot
Set-Location $PROJECT_ROOT

# 🔧 설정 영역 -------------------
$VENV_DIR = ".venv"
$PYTHON_VERSION_FILE = "python-version.txt"
# --------------------------------

Write-Host "========================================"
Write-Host " Python Virtual Environment Setup"
Write-Host "========================================"

# 0️⃣ python-version.txt 존재 확인 + 버전 로드
if (-not (Test-Path $PYTHON_VERSION_FILE)) {
    Write-Host "❌ $PYTHON_VERSION_FILE not found in project root."
    Write-Host "👉 Create $PYTHON_VERSION_FILE and put a version like: 3.12"
    exit 1
}

$PYTHON_VERSION = (Get-Content $PYTHON_VERSION_FILE -TotalCount 1).Trim()

if (-not $PYTHON_VERSION) {
    Write-Host "❌ $PYTHON_VERSION_FILE is empty."
    Write-Host "👉 Put a version like: 3.12"
    exit 1
}

Write-Host "Target Python Version: $PYTHON_VERSION"
Write-Host "Project Root: $PROJECT_ROOT"
Write-Host ""

# 1️⃣ py launcher 존재 여부
try {
    $pyVersion = py --version 2>&1
    Write-Host "✔ py launcher detected: $pyVersion"
} catch {
    Write-Host "❌ py launcher not found."
    Write-Host "👉 Install Python from python.org (includes py launcher)."
    exit 1
}

# 2️⃣ 해당 Python 버전 존재 여부 확인
$pythonPath = py -$PYTHON_VERSION -c "import sys; print(sys.executable)" 2>$null
if (-not $pythonPath) {
    Write-Host "❌ Python $PYTHON_VERSION is not installed (or not registered to py launcher)."
    Write-Host "👉 Install Python $PYTHON_VERSION first."
    Write-Host "👉 Check installed versions with: py -0"
    exit 1
}

Write-Host "✔ Python $PYTHON_VERSION detected at:"
Write-Host "  $pythonPath"
Write-Host ""

# 3️⃣ .venv 존재 여부 + 버전 일치 검사
if (Test-Path $VENV_DIR) {
    $venvPythonExe = Join-Path $PROJECT_ROOT "$VENV_DIR\Scripts\python.exe"

    if (-not (Test-Path $venvPythonExe)) {
        Write-Host "❌ Existing $VENV_DIR found, but python.exe is missing:"
        Write-Host "  $venvPythonExe"
        Write-Host "👉 Delete $VENV_DIR and run again."
        exit 1
    }

    $venvPyVer = & $venvPythonExe -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>$null

    if (-not $venvPyVer) {
        Write-Host "❌ Could not read Python version from existing $VENV_DIR."
        Write-Host "👉 Delete $VENV_DIR and run again."
        exit 1
    }

    if ($venvPyVer -ne $PYTHON_VERSION) {
        Write-Host "❌ Existing $VENV_DIR uses Python $venvPyVer, but required is $PYTHON_VERSION."
        Write-Host "👉 Delete $VENV_DIR and run again."
        exit 1
    }

    Write-Host "✔ $VENV_DIR already exists and matches Python $PYTHON_VERSION. Skipping creation."
} else {
    Write-Host "▶ Creating virtual environment ($VENV_DIR)..."
    py -$PYTHON_VERSION -m venv $VENV_DIR

    if (-not (Test-Path $VENV_DIR)) {
        Write-Host "❌ Failed to create virtual environment."
        exit 1
    }

    Write-Host "✔ Virtual environment created."
}

Write-Host ""

# 4️⃣ 가상환경 활성화
$activateScript = Join-Path $PROJECT_ROOT "$VENV_DIR\Scripts\Activate.ps1"

if (-not (Test-Path $activateScript)) {
    Write-Host "❌ Activation script not found:"
    Write-Host "  $activateScript"
    exit 1
}

Write-Host "▶ Activating virtual environment..."
try {
    & $activateScript
} catch {
    Write-Host "❌ Failed to run Activate.ps1 (PowerShell execution policy might block scripts)."
    Write-Host "👉 Try this in PowerShell (CurrentUser scope):"
    Write-Host "   Set-ExecutionPolicy -Scope CurrentUser RemoteSigned"
    exit 1
}

Write-Host ""

# 5️⃣ pip 최신화 (python -m pip 권장)
Write-Host "▶ Upgrading pip..."
python -m pip install --upgrade pip
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ pip upgrade failed."
    exit 1
}

# 6️⃣ requirements.txt 설치
if (Test-Path "requirements.txt") {
    Write-Host "▶ Installing dependencies from requirements.txt..."
    python -m pip install -r requirements.txt

    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Dependency installation failed."
        exit 1
    }

    Write-Host "✔ Dependencies installed successfully."
} else {
    Write-Host "⚠ requirements.txt not found. Skipping dependency install."
}

# 7️⃣ 완료
Write-Host ""
Write-Host "========================================"
Write-Host " ✔ Virtual environment setup completed!"
Write-Host "========================================"
Write-Host "To activate manually next time:"
Write-Host "  $VENV_DIR\Scripts\Activate.ps1"
