param(
    [Parameter(Mandatory)][string]$RepoRoot,
    [Parameter(Mandatory)][string]$ResolvedInstallerUrl,
    [Parameter(Mandatory)][string]$ResolvedInstallerSha256,
    [Parameter(Mandatory)][string]$Version,
    [Parameter()][string]$DetectedFileVersion = ''
)

$ErrorActionPreference = 'Stop'

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

$package.version = $Version
$package.resolvedInstallerUrl = $ResolvedInstallerUrl
$package.resolvedInstallerSha256 = $ResolvedInstallerSha256
$package.detectedFileVersion = $DetectedFileVersion
$package.lastCheckedUtc = $utc

$state.currentVersion = $Version
$state.currentResolvedInstallerUrl = $ResolvedInstallerUrl
$state.currentResolvedInstallerSha256 = $ResolvedInstallerSha256
$state.lastCheckedUtc = $utc

Write-JsonAtomic -Path $packagePath -Object $package
Write-JsonAtomic -Path $statePath -Object $state

Write-Host "Updated config files for version $Version."
