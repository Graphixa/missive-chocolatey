param(
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$packagePath = Join-Path $RepoRoot 'config\package.json'
$statePath = Join-Path $RepoRoot 'config\state.json'
$resultPath = Join-Path $RepoRoot '.resolve-result.json'

if (-not (Test-Path -LiteralPath $packagePath)) {
    throw "Missing $packagePath"
}
if (-not (Test-Path -LiteralPath $statePath)) {
    throw "Missing $statePath"
}

$package = Get-Content -LiteralPath $packagePath -Raw -Encoding UTF8 | ConvertFrom-Json
$state = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json

$url = $package.missiveRedirectUrl
if (-not $url) {
    throw 'package.json missiveRedirectUrl is required.'
}

$tempDir = Join-Path $env:TEMP ("missive-resolve-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
$installer = Join-Path $tempDir 'MissiveSetup.exe'

try {
    Write-Host "Resolving and downloading: $url"

    try {
        $request = [System.Net.HttpWebRequest]::Create($url)
        $request.AllowAutoRedirect = $true
        $request.Method = 'GET'
        $request.UserAgent = 'missive-chocolatey-resolve/1.0'
        $response = $request.GetResponse()
        $finalUrl = $response.ResponseUri.AbsoluteUri
        try {
            $stream = $response.GetResponseStream()
            $fileStream = [System.IO.File]::Create($installer)
            try {
                $stream.CopyTo($fileStream)
            }
            finally {
                $fileStream.Dispose()
            }
        }
        finally {
            $response.Dispose()
        }
    } catch {
        throw "Failed to download installer: $($_.Exception.Message)"
    }

    if ($finalUrl -notmatch '\.(exe|msi)(\?|$|#)' -and $finalUrl -notmatch '\.exe$') {
        Write-Warning "Final URL may not look like an installer: $finalUrl"
    }

    if (-not (Test-Path -LiteralPath $installer)) {
        throw 'Download did not produce a file.'
    }

    $sha256 = (Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash

    $fileVersion = ''
    try {
        $verInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($installer)
        if ($verInfo.FileVersion) {
            $fileVersion = $verInfo.FileVersion.Trim()
        }
    } catch {
        Write-Warning "Could not read file version: $($_.Exception.Message)"
    }

    $version = $fileVersion
    if (-not $version) {
        $version = '0.0.0'
    }

    $previousSha = $state.currentResolvedInstallerSha256
    $changed = ($previousSha -ne $sha256) -or [string]::IsNullOrWhiteSpace($previousSha)

    Write-Host "Final URL: $finalUrl"
    Write-Host "SHA256:    $sha256"
    Write-Host "Version:   $version (file: $fileVersion)"
    Write-Host "Changed:   $changed"

    if ($changed) {
        $updateScript = Join-Path $RepoRoot 'scripts\Update-PackageMetadata.ps1'
        & $updateScript `
            -RepoRoot $RepoRoot `
            -ResolvedInstallerUrl $finalUrl `
            -ResolvedInstallerSha256 $sha256 `
            -Version $version `
            -DetectedFileVersion $fileVersion
    }

    $out = [ordered]@{
        Changed               = [bool]$changed
        FinalUrl              = $finalUrl
        Sha256                = $sha256
        Version               = $version
        DetectedFileVersion   = $fileVersion
    }
    $out | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $resultPath -Encoding UTF8
}
finally {
    if (Test-Path -LiteralPath $tempDir) {
        Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
