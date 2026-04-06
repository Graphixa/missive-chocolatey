param(
    [Parameter(Mandatory)][string]$RepoRoot,
    [Parameter(Mandatory)][string]$ResolvedInstallerUrl,
    [Parameter(Mandatory)][string]$ResolvedInstallerSha256,
    [Parameter(Mandatory)][string]$Version,
    [Parameter()][string]$DetectedFileVersion = ''
)

$ErrorActionPreference = 'Stop'

function Get-NuspecVersionString {
    <#
        Chocolatey needs a unique, mostly-numeric package version. Prefer the vendor file version;
        fall back to a UTC timestamp when missing or 0.0.0.
    #>
    param(
        [string]$RawVersion
    )
    $clean = ($RawVersion -replace '[^\d\.]', '').Trim('.')
    if ([string]::IsNullOrWhiteSpace($clean) -or $clean -eq '0.0.0') {
        return (Get-Date).ToUniversalTime().ToString('yyyy.MM.dd.HHmm')
    }
    $parts = @($clean.Split('.') | Where-Object { $_ -ne '' })
    for ($i = 0; $i -lt $parts.Length; $i++) {
        if ($parts[$i] -match '^\d+$') { continue }
        $parts[$i] = '0'
    }
    if ($parts.Length -gt 4) {
        $parts = $parts[0..3]
    }
    return ($parts -join '.')
}

function Set-ChocolateyInstallSha256Literal {
    <#
        Replaces the quoted SHA256 in Get-ChocolateyWebFile -Checksum '...' so community validation
        and the resolved-installer.sha256 file stay aligned.
    #>
    param(
        [Parameter(Mandatory)][string]$InstallScriptPath,
        [Parameter(Mandatory)][string]$Sha256LowerHex
    )
    $raw = Get-Content -LiteralPath $InstallScriptPath -Raw -Encoding UTF8
    $rx = [regex]"(?m)([\t ]*-Checksum\s+')([a-f0-9]{64})(')"
    $evaluator = [System.Text.RegularExpressions.MatchEvaluator]{
        param($match)
        $match.Groups[1].Value + $Sha256LowerHex + $match.Groups[3].Value
    }
    $updated = $rx.Replace($raw, $evaluator, 1)
    if ($updated -eq $raw) {
        throw "Could not replace -Checksum literal in $InstallScriptPath"
    }
    Set-Content -LiteralPath $InstallScriptPath -Value $updated -Encoding UTF8
}

function Set-MissiveNuspecVersion {
    param(
        [Parameter(Mandatory)][string]$NuspecPath,
        [Parameter(Mandatory)][string]$VersionString
    )
    $raw = Get-Content -LiteralPath $NuspecPath -Raw -Encoding UTF8
    $ver = $VersionString
    $evaluator = [System.Text.RegularExpressions.MatchEvaluator]{
        param($match)
        $match.Groups[1].Value + $ver + $match.Groups[2].Value
    }
    $rx = [regex]'(<version>)[^<]*(</version>)'
    $updated = $rx.Replace($raw, $evaluator, 1)
    if ($updated -eq $raw) {
        throw "Could not update version in $NuspecPath"
    }
    Set-Content -LiteralPath $NuspecPath -Value $updated -Encoding UTF8
}

function Write-JsonAtomic {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$Object
    )
    $tempPath = "$Path.tmp.$([Guid]::NewGuid().ToString('N'))"
    try {
        $json = $Object | ConvertTo-Json -Depth 20
        Set-Content -LiteralPath $tempPath -Value $json -Encoding UTF8
        Move-Item -LiteralPath $tempPath -Destination $Path -Force
    }
    finally {
        if (Test-Path -LiteralPath $tempPath) {
            Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
        }
    }
}

$utc = (Get-Date).ToUniversalTime().ToString('o')

$packagePath = Join-Path $RepoRoot 'config\package.json'
$statePath = Join-Path $RepoRoot 'config\state.json'

$package = Get-Content -LiteralPath $packagePath -Raw -Encoding UTF8 | ConvertFrom-Json
$state = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json

$nuspecVersion = Get-NuspecVersionString -RawVersion $Version

$package.version = $nuspecVersion
$package.resolvedInstallerUrl = $ResolvedInstallerUrl
$package.resolvedInstallerSha256 = $ResolvedInstallerSha256
$package.detectedFileVersion = $DetectedFileVersion
$package.lastCheckedUtc = $utc

$state.currentVersion = $nuspecVersion
$state.currentResolvedInstallerUrl = $ResolvedInstallerUrl
$state.currentResolvedInstallerSha256 = $ResolvedInstallerSha256
$state.lastCheckedUtc = $utc

Write-JsonAtomic -Path $packagePath -Object $package
Write-JsonAtomic -Path $statePath -Object $state

$nuspecPath = Join-Path $RepoRoot 'chocolatey\missive\missive.nuspec'
Set-MissiveNuspecVersion -NuspecPath $nuspecPath -VersionString $nuspecVersion

$hashNormalized = $ResolvedInstallerSha256.Trim().ToLowerInvariant()

$sha256Path = Join-Path $RepoRoot 'chocolatey\missive\tools\resolved-installer.sha256'
[System.IO.File]::WriteAllText($sha256Path, $hashNormalized)

$installScriptPath = Join-Path $RepoRoot 'chocolatey\missive\tools\chocolateyInstall.ps1'
Set-ChocolateyInstallSha256Literal -InstallScriptPath $installScriptPath -Sha256LowerHex $hashNormalized

Write-Host "Updated config, nuspec, tools/resolved-installer.sha256, and chocolateyInstall.ps1 checksum literal for package version $nuspecVersion (detected: $Version)."
