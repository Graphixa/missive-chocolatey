<#
.SYNOPSIS
  Smoke-test the Chocolatey package on Windows (requires Chocolatey CLI; install step may require elevation).

.NOTES
  Run from repository root:  pwsh ./scripts/Test-Package.ps1
#>
param(
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'

function Write-SmokeTestLog {
    param([string]$Message)
    Write-Host "[smoke-test] $Message"
}

if ($PSVersionTable.PSVersion.Major -lt 5) {
    throw 'PowerShell 5.1 or later is required.'
}

$missiveDir = Join-Path $RepoRoot 'chocolatey\missive'
if (-not (Test-Path -LiteralPath $missiveDir)) {
    throw "Missing $missiveDir"
}

$choco = Get-Command choco -ErrorAction SilentlyContinue
if (-not $choco) {
    throw 'Chocolatey CLI (choco) not found in PATH. Install Chocolatey first.'
}

Push-Location $missiveDir
try {
    Write-Host 'Running choco pack...'
    & choco pack .\missive.nuspec
    if ($LASTEXITCODE -ne 0) {
        throw "choco pack failed with exit code $LASTEXITCODE"
    }

    $nupkg = Get-ChildItem -Path $missiveDir -Filter '*.nupkg' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $nupkg) {
        throw 'No .nupkg produced.'
    }
    Write-Host "Built: $($nupkg.Name)"

    Write-Host 'Installing package from local folder (may require admin)...'
    & choco install missive --source . -y --force
    if ($LASTEXITCODE -ne 0) {
        throw "choco install failed with exit code $LASTEXITCODE"
    }

    $installRoot = Join-Path $env:SystemDrive 'Missive'
    Write-SmokeTestLog "Install root: $installRoot"
    if (-not (Test-Path -LiteralPath $installRoot)) {
        throw "Install directory missing after install (expected $installRoot)."
    }

    $exe = Join-Path $installRoot 'Missive.exe'
    if (-not (Test-Path -LiteralPath $exe)) {
        throw "Missing $exe after install."
    }
    Write-SmokeTestLog "OK: $exe"

    $sm = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\Missive.lnk'
    $pd = Join-Path $env:Public 'Desktop\Missive.lnk'
    $shortcutChecks = @(
        @{ Path = $sm; Label = 'Start Menu' }
        @{ Path = $pd; Label = 'Public Desktop' }
    )
    foreach ($sc in $shortcutChecks) {
        if (-not (Test-Path -LiteralPath $sc.Path)) {
            throw "Missing shortcut ($($sc.Label)): $($sc.Path)"
        }
        Write-SmokeTestLog "OK: $($sc.Label) - $($sc.Path)"
    }

    Write-SmokeTestLog 'Running uninstall...'
    & choco uninstall missive -y --force
    if ($LASTEXITCODE -ne 0) {
        throw "choco uninstall failed with exit code $LASTEXITCODE"
    }

    foreach ($p in @($sm, $pd)) {
        if (Test-Path -LiteralPath $p) {
            throw "Shortcut still present after uninstall (expected removed): $p"
        }
    }

    if (Test-Path -LiteralPath (Join-Path $installRoot 'Missive.exe')) {
        throw "Missive.exe still present under $installRoot after uninstall."
    }

    Write-SmokeTestLog 'OK: shortcuts and Missive.exe removed after uninstall.'
    Write-Host 'Smoke test completed successfully.'
}
finally {
    Pop-Location
}
