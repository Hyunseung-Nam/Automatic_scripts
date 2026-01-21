<#
이 스크립트는 재생성 가능한 캐시만 안전하게 정리하며 사용자 데이터/소스/환경은 건드리지 않습니다.

사용 방법:
  기본 실행(월 1회 자동 스케줄 생성):
    powershell -NoProfile -ExecutionPolicy Bypass -File "C:\dev\Automatic_scripts\cleanup_all_caches.ps1"
    - 스케줄은 자동으로 매월 1일 03:00에 등록
    
  프로젝트 루트 지정:
    powershell -NoProfile -ExecutionPolicy Bypass -File "C:\dev\Automatic_scripts\cleanup_all_caches.ps1" -ProjectRoots "C:\dev" "D:\work"

  미리보기(삭제 없이 목록만):
    powershell -NoProfile -ExecutionPolicy Bypass -File "C:\dev\Automatic_scripts\cleanup_all_caches.ps1" -DryRun
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [string[]]$ProjectRoots = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "SilentlyContinue"

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message"
}

function Write-Ok {
    param([string]$Message)
    Write-Host "[OK] $Message"
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message"
}

function Test-PathSafe {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }
    return (Test-Path -LiteralPath $Path)
}

function Get-FullPathSafe {
    param([string]$Path)
    try {
        return [System.IO.Path]::GetFullPath($Path)
    } catch {
        return $null
    }
}

function Test-UnderProgramFiles {
    param([string]$Path)
    $full = Get-FullPathSafe $Path
    if (-not $full) { return $false }
    $pf = $env:ProgramFiles
    $pf86 = ${env:ProgramFiles(x86)}
    if ($pf -and $full.StartsWith((Get-FullPathSafe $pf), [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    if ($pf86 -and $full.StartsWith((Get-FullPathSafe $pf86), [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    return $false
}

function Remove-ItemSafe {
    param([string]$Path)
    if (-not (Test-PathSafe $Path)) { return }
    if ($DryRun) {
        Write-Info "DryRun: remove $Path"
        return
    }
    Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue
    Write-Ok "Removed $Path"
}

function Remove-FileSafe {
    param([string]$Path)
    if (-not (Test-PathSafe $Path)) { return }
    if ($DryRun) {
        Write-Info "DryRun: remove $Path"
        return
    }
    Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    Write-Ok "Removed $Path"
}

function Invoke-ExternalCommand {
    param(
        [string]$Command,
        [string[]]$Arguments
    )
    $cmd = Get-Command $Command -ErrorAction SilentlyContinue
    if (-not $cmd) {
        Write-Warn "$Command not found. Skipping."
        return
    }
    if ($DryRun) {
        Write-Info "DryRun: run $Command $($Arguments -join ' ')"
        return
    }
    try {
        & $Command @Arguments | Out-Null
        Write-Ok "Ran $Command $($Arguments -join ' ')"
    } catch {
        Write-Warn "Failed to run $($Command): $($_.Exception.Message)"
    }
}

function Register-MonthlyScheduledTask {
    param(
        [string]$TaskName = "CleanupAllCachesMonthly",
        [string]$At = "03:00"
    )
    $scriptPath = $MyInvocation.MyCommand.Path
    if (-not (Test-PathSafe $scriptPath)) {
        Write-Warn "Script path not found for scheduling."
        return
    }
    try {
        $existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    } catch {
        Write-Warn "ScheduledTasks module not available. Skipping task creation."
        return
    }
    if ($existing) {
        Write-Info "Scheduled task '$TaskName' already exists."
        return
    }

    $projectArgs = ""
    foreach ($root in $ProjectRoots) {
        if (-not [string]::IsNullOrWhiteSpace($root)) {
            $projectArgs += " -ProjectRoots `"$root`""
        }
    }

    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument (
        "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"$projectArgs"
    )
    $trigger = New-ScheduledTaskTrigger -Monthly -DaysOfMonth 1 -At $At
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

    try {
        Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Description "Monthly cleanup of reproducible caches" | Out-Null
        Write-Ok "Scheduled task '$TaskName' created (monthly, day 1 at $At)."
    } catch {
        Write-Warn "Failed to create scheduled task: $($_.Exception.Message)"
    }
}

Write-Info "Starting cache cleanup. DryRun=$DryRun"

if ($env:APPDATA) {
    $appDataRoots = @($env:APPDATA, $env:LOCALAPPDATA) | Where-Object { $_ }
    $cacheFolderNames = @("Cache", "Code Cache", "GPUCache")
    foreach ($root in $appDataRoots) {
        Write-Info "Scanning app cache roots: $root"
        try {
            Get-ChildItem -LiteralPath $root -Directory -Recurse -Force -ErrorAction SilentlyContinue |
                Where-Object { $cacheFolderNames -contains $_.Name } |
                ForEach-Object { Remove-ItemSafe $_.FullName }
        } catch {
            Write-Warn "Failed to scan $($root): $($_.Exception.Message)"
        }
    }
}

$vscodePaths = @(
    (Join-Path $env:APPDATA "Code\Cache"),
    (Join-Path $env:APPDATA "Code\CachedData"),
    (Join-Path $env:APPDATA "Code\GPUCache")
)
foreach ($p in $vscodePaths) { Remove-ItemSafe $p }

$cursorPaths = @(
    (Join-Path $env:APPDATA "Cursor\Cache"),
    (Join-Path $env:APPDATA "Cursor\Code Cache"),
    (Join-Path $env:APPDATA "Cursor\GPUCache"),
    (Join-Path $env:LOCALAPPDATA "Cursor\Cache"),
    (Join-Path $env:LOCALAPPDATA "Cursor\Code Cache"),
    (Join-Path $env:LOCALAPPDATA "Cursor\GPUCache")
)
foreach ($p in $cursorPaths) { Remove-ItemSafe $p }

$jetBrainsRoot = Join-Path $env:LOCALAPPDATA "JetBrains"
if (Test-PathSafe $jetBrainsRoot) {
    Get-ChildItem -LiteralPath $jetBrainsRoot -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
        $ideRoot = $_.FullName
        $paths = @(
            (Join-Path $ideRoot "caches"),
            (Join-Path $ideRoot "system\caches"),
            (Join-Path $ideRoot "system\index")
        )
        foreach ($p in $paths) { Remove-ItemSafe $p }
    }
}

Invoke-ExternalCommand -Command "pip" -Arguments @("cache", "purge")
Invoke-ExternalCommand -Command "npm" -Arguments @("cache", "clean", "--force")

$tempRoots = @($env:TEMP, $env:TMP) | Where-Object { $_ }
foreach ($temp in $tempRoots) {
    Write-Info "Cleaning temp contents: $temp"
    try {
        Get-ChildItem -LiteralPath $temp -Force -ErrorAction SilentlyContinue | ForEach-Object {
            Remove-ItemSafe $_.FullName
        }
    } catch {
        Write-Warn "Failed to clean temp at $($temp): $($_.Exception.Message)"
    }
}

$projectCacheDirNames = @("__pycache__", ".pytest_cache", ".mypy_cache", ".ruff_cache", ".cache", ".tox", ".nox")
$projectCacheFileNames = @(".coverage", "coverage.xml")
$projectExcludeDirNames = @(".git", "node_modules", "venv", ".venv", "env", "dist", "build", ".idea", ".vscode")

foreach ($root in $ProjectRoots) {
    if ([string]::IsNullOrWhiteSpace($root)) { continue }
    if (-not (Test-PathSafe $root)) {
        Write-Warn "Project root not found: $root"
        continue
    }
    if (Test-UnderProgramFiles $root) {
        Write-Warn "Skipping Program Files path: $root"
        continue
    }

    $resolvedRoot = Get-FullPathSafe $root
    Write-Info "Scanning project root: $resolvedRoot"

    $stack = New-Object System.Collections.Generic.Stack[System.IO.DirectoryInfo]
    try {
        $stack.Push((Get-Item -LiteralPath $resolvedRoot))
    } catch {
        Write-Warn "Failed to access project root: $root"
        continue
    }

    while ($stack.Count -gt 0) {
        $dir = $stack.Pop()
        try {
            $childDirs = Get-ChildItem -LiteralPath $dir.FullName -Directory -Force -ErrorAction SilentlyContinue
            $childFiles = Get-ChildItem -LiteralPath $dir.FullName -File -Force -ErrorAction SilentlyContinue
        } catch {
            continue
        }

        foreach ($childDir in $childDirs) {
            if ($projectExcludeDirNames -contains $childDir.Name) {
                continue
            }
            if ($projectCacheDirNames -contains $childDir.Name) {
                Remove-ItemSafe $childDir.FullName
                continue
            }
            $stack.Push($childDir)
        }

        foreach ($childFile in $childFiles) {
            if ($projectCacheFileNames -contains $childFile.Name) {
                Remove-FileSafe $childFile.FullName
            }
        }
    }
}

Register-MonthlyScheduledTask
Write-Info "Cleanup complete."
