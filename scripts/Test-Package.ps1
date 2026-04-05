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

    $exe = 'C:\Missive\Missive.exe'
    if (-not (Test-Path -LiteralPath $exe)) {
        throw "Missing $exe after install."
    }

    $sm = 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Missive.lnk'
    $pd = 'C:\Users\Public\Desktop\Missive.lnk'
    foreach ($p in @($sm, $pd)) {
        if (-not (Test-Path -LiteralPath $p)) {
            throw "Missing shortcut: $p"
        }
    }

    Write-Host 'Shortcuts and executable present. Running uninstall...'
    & choco uninstall missive -y
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "choco uninstall exit code $LASTEXITCODE (continuing verification)"
    }

    Write-Host 'Smoke test completed successfully.'
}
finally {
    Pop-Location
}
