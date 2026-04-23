<#
.SYNOPSIS
  Pack and validate the Chocolatey package (optionally install/uninstall smoke test).

.NOTES
  Run from repository root:
    - Fast (pack + validate .nupkg contents): pwsh ./scripts/Test-Package.ps1
    - Full smoke (also install/uninstall):    pwsh ./scripts/Test-Package.ps1 -SmokeTest
#>
param(
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot),
    [switch]$SmokeTest
)

$ErrorActionPreference = 'Stop'

function Write-TestLog {
    param([string]$Message)
    Write-Host "[test-package] $Message"
}

if ($PSVersionTable.PSVersion.Major -lt 5) {
    throw 'PowerShell 5.1 or later is required.'
}

$missiveDir = Join-Path $RepoRoot 'missive'
if (-not (Test-Path -LiteralPath $missiveDir)) {
    throw "Missing $missiveDir"
}

$choco = Get-Command choco -ErrorAction SilentlyContinue
if (-not $choco) {
    throw 'Chocolatey CLI (choco) not found in PATH. Install Chocolatey first.'
}

function Get-RepoInstallChecksum {
    param([Parameter(Mandatory)][string]$InstallScriptPath)
    $raw = Get-Content -LiteralPath $InstallScriptPath -Raw -Encoding UTF8
    $m = [regex]::Match($raw, "(?m)^\s*checksum\s*=\s*'([a-f0-9]{64})'\s*$", 'IgnoreCase')
    if (-not $m.Success) {
        throw "Install script must contain a checksum literal: $InstallScriptPath"
    }
    return $m.Groups[1].Value.ToLowerInvariant()
}

function Get-RepoVerificationChecksum {
    param([Parameter(Mandatory)][string]$VerificationPath)
    $lines = Get-Content -LiteralPath $VerificationPath -Encoding UTF8
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim().ToLowerInvariant() -eq 'checksum:') {
            $j = $i + 1
            while ($j -lt $lines.Count -and [string]::IsNullOrWhiteSpace($lines[$j])) { $j++ }
            if ($j -ge $lines.Count) { break }
            $candidate = ($lines[$j].Trim() -replace '\s', '').ToLowerInvariant()
            if ($candidate -match '^[a-f0-9]{64}$') {
                return $candidate
            }
        }
    }
    throw "Could not find a SHA256 checksum in $VerificationPath"
}

function Assert-Equal {
    param(
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][string]$A,
        [Parameter(Mandatory)][string]$B
    )
    if ($A -ne $B) {
        throw "$Label mismatch: '$A' vs '$B'"
    }
}

function Get-ZipEntryText {
    param(
        [Parameter(Mandatory)][System.IO.Compression.ZipArchive]$Zip,
        [Parameter(Mandatory)][string]$RelativePath
    )
    $want = $RelativePath.Replace('\', '/').ToLowerInvariant()
    $entry = $Zip.Entries | Where-Object {
        ($_.FullName -replace '\\', '/').ToLowerInvariant() -eq $want
    } | Select-Object -First 1
    if (-not $entry) {
        throw "nupkg missing entry: $RelativePath"
    }
    $sr = [System.IO.StreamReader]::new($entry.Open(), [System.Text.Encoding]::UTF8)
    try { $sr.ReadToEnd() } finally { $sr.Dispose() }
}

Push-Location $missiveDir
try {
    $installScriptPath = Join-Path $missiveDir 'tools\chocolateyInstall.ps1'
    $verificationPath = Join-Path $missiveDir 'tools\VERIFICATION.txt'

    $expectedFromInstall = Get-RepoInstallChecksum -InstallScriptPath $installScriptPath
    $expectedFromVerification = Get-RepoVerificationChecksum -VerificationPath $verificationPath
    Assert-Equal -Label 'Repo checksum (install vs verification)' -A $expectedFromInstall -B $expectedFromVerification

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

    Add-Type -AssemblyName System.IO.Compression.FileSystem

    $zip = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $nupkg.FullName).Path)
    try {
        $required = @(
            'tools/chocolateyInstall.ps1'
            'tools/chocolateyUninstall.ps1'
            'tools/helpers.ps1'
            'tools/VERIFICATION.txt'
        )
        $entries = $zip.Entries | ForEach-Object { ($_.FullName -replace '\\', '/').ToLowerInvariant() }
        foreach ($rel in $required) {
            if ($entries -notcontains $rel.ToLowerInvariant()) {
                throw "nupkg missing required entry: $rel"
            }
        }

        $nupkgInstall = Get-ZipEntryText -Zip $zip -RelativePath 'tools/chocolateyInstall.ps1'
        $nupkgVerification = Get-ZipEntryText -Zip $zip -RelativePath 'tools/VERIFICATION.txt'

        $m = [regex]::Match($nupkgInstall, "(?m)^\s*checksum\s*=\s*'([a-f0-9]{64})'\s*$", 'IgnoreCase')
        if (-not $m.Success) { throw 'nupkg tools/chocolateyInstall.ps1 is missing checksum literal.' }
        $fromNupkgInstall = $m.Groups[1].Value.ToLowerInvariant()

        if ($nupkgVerification -notmatch [regex]::Escape($expectedFromInstall)) {
            throw 'nupkg tools/VERIFICATION.txt does not include the expected checksum.'
        }

        Assert-Equal -Label 'nupkg checksum (repo vs nupkg install)' -A $expectedFromInstall -B $fromNupkgInstall
    }
    finally {
        $zip.Dispose()
    }

    Write-TestLog 'OK: packed nupkg embeds checksum + VERIFICATION.txt'

    if ($SmokeTest) {
        Write-Host 'Installing package from local folder (may require admin)...'
        & choco install missive --source . -y --force
        if ($LASTEXITCODE -ne 0) {
            throw "choco install failed with exit code $LASTEXITCODE"
        }

        $installRoot = Join-Path $env:SystemDrive 'Missive'
        Write-TestLog "Install root: $installRoot"
        if (-not (Test-Path -LiteralPath $installRoot)) {
            throw "Install directory missing after install (expected $installRoot)."
        }

        $exe = Join-Path $installRoot 'Missive.exe'
        if (-not (Test-Path -LiteralPath $exe)) {
            throw "Missing $exe after install."
        }
        Write-TestLog "OK: $exe"

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
            Write-TestLog "OK: $($sc.Label) - $($sc.Path)"
        }

        Write-TestLog 'Running uninstall...'
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

        Write-TestLog 'OK: shortcuts and Missive.exe removed after uninstall.'
        Write-Host 'Smoke test completed successfully.'
    }
}
finally {
    Pop-Location
}
