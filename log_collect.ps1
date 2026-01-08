# log_collect.ps1
# 로그/설정 파일 수집해서 zip 생성

param(
  [string]$AppName = "LaundryPointManager"
)

$PROJECT_ROOT = Split-Path -Parent $PSScriptRoot
Set-Location $PROJECT_ROOT

$STAMP = Get-Date -Format "yyyyMMdd_HHmmss"
$OUT_DIR = Join-Path $PROJECT_ROOT "support"
$BUNDLE_DIR = Join-Path $OUT_DIR "logs_$STAMP"
$ZIP_PATH = Join-Path $OUT_DIR "logs_$STAMP.zip"

New-Item -ItemType Directory -Force $BUNDLE_DIR | Out-Null
New-Item -ItemType Directory -Force $OUT_DIR | Out-Null

Write-Host "=== Log Collect ==="
Write-Host "Output: $ZIP_PATH"

# 1) 프로젝트 내 로그/설정 후보
$projectCandidates = @(
  "app.log",
  "logs\app.log",
  "data",
  "config.json",
  "settings.json"
)

foreach ($c in $projectCandidates) {
    if (Test-Path $c) {
        Copy-Item $c $BUNDLE_DIR -Recurse -Force
        Write-Host "✔ Collected (project): $c"
    }
}

# 2) AppData 후보 (일반적으로 여기 저장하는 경우가 많음)
$appDataCandidates = @(
  (Join-Path $env:APPDATA "$AppName\app.log"),
  (Join-Path $env:LOCALAPPDATA "$AppName\app.log"),
  (Join-Path $env:APPDATA "$AppName\logs"),
  (Join-Path $env:LOCALAPPDATA "$AppName\logs")
)

foreach ($p in $appDataCandidates) {
    if (Test-Path $p) {
        Copy-Item $p $BUNDLE_DIR -Recurse -Force
        Write-Host "✔ Collected (AppData): $p"
    }
}

# 3) 환경 정보 덤프
$envInfo = Join-Path $BUNDLE_DIR "env_info.txt"
"Collected at: $(Get-Date)" | Out-File $envInfo -Encoding utf8
"ProjectRoot: $PROJECT_ROOT" | Out-File $envInfo -Append -Encoding utf8

try { "OS: $((Get-CimInstance Win32_OperatingSystem).Caption)" | Out-File $envInfo -Append -Encoding utf8 } catch {}
try { "py: $(py --version 2>&1)" | Out-File $envInfo -Append -Encoding utf8 } catch {}
try { "python (venv): $(& "$PROJECT_ROOT\.venv\Scripts\python.exe" --version 2>&1)" | Out-File $envInfo -Append -Encoding utf8 } catch {}

# zip
if (Test-Path $ZIP_PATH) { Remove-Item $ZIP_PATH -Force }
Compress-Archive -Path "$BUNDLE_DIR\*" -DestinationPath $ZIP_PATH -Force

Write-Host "✔ Done. Send this file to developer:"
Write-Host "  $ZIP_PATH"
