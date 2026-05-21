<#
.SYNOPSIS
  Resolves the Missive installer, computes SHA256, detects version, and updates the Chocolatey package files.

.DESCRIPTION
  This repository is a Chocolatey Community downloader package. The updater:
    - downloads from the canonical redirect URL
    - follows redirects to the final installer URL
    - computes SHA256 of the downloaded installer
    - reads the installer file version when available
    - updates:
        - missive/missive.nuspec (version)
        - missive/tools/chocolateyInstall.ps1 (checksum literal)
        - missive/tools/resolved-installer.sha256
        - missive/tools/VERIFICATION.txt

.NOTES
  Run from repository root: pwsh ./scripts/Update-Package.ps1
#>
param(
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$DownloadUrl = 'https://mail.missiveapp.com/download/win'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Get-NuspecVersionString {
    <#
        Chocolatey requires mostly-numeric versions. Prefer vendor file version; fall back to UTC timestamp.
    #>
    param([Parameter(Mandatory)][string]$RawVersion)
    $clean = ($RawVersion -replace '[^\d\.]', '').Trim('.')
    if ([string]::IsNullOrWhiteSpace($clean) -or $clean -eq '0.0.0') {
        return (Get-Date).ToUniversalTime().ToString('yyyy.MM.dd.HHmm')
    }
    $parts = @($clean.Split('.') | Where-Object { $_ -ne '' })
    for ($i = 0; $i -lt $parts.Length; $i++) {
        if ($parts[$i] -notmatch '^\d+$') { $parts[$i] = '0' }
    }
    if ($parts.Length -gt 4) { $parts = $parts[0..3] }
    return ($parts -join '.')
}

function Set-XmlFirstMatchValue {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$XPath,
        [Parameter(Mandatory)][string]$Value
    )
    [xml]$xml = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    $ns = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
    $ns.AddNamespace('n', 'http://schemas.microsoft.com/packaging/2015/06/nuspec.xsd')
    $node = $xml.SelectSingleNode($XPath, $ns)
    if (-not $node) { throw "XPath not found in ${Path}: $XPath" }
    if ($node.InnerText -eq $Value) { return }
    $node.InnerText = $Value
    $xml.Save($Path)
}

function Set-InstallScriptChecksumLiteral {
    param(
        [Parameter(Mandatory)][string]$InstallScriptPath,
        [Parameter(Mandatory)][string]$Sha256LowerHex
    )
    $n = $Sha256LowerHex.Trim().ToLowerInvariant()
    if ($n -notmatch '^[a-f0-9]{64}$') { throw "Invalid SHA256: $Sha256LowerHex" }
    $raw = Get-Content -LiteralPath $InstallScriptPath -Raw -Encoding UTF8
    $pattern = "(?m)^\s*checksum\s*=\s*'([a-f0-9]{64})'\s*$"
    $m = [regex]::Match($raw, $pattern, 'IgnoreCase')
    if (-not $m.Success) {
        throw "Could not update checksum literal in $InstallScriptPath (missing checksum = '...')."
    }
    if ($m.Groups[1].Value.ToLowerInvariant() -eq $n) {
        return
    }
    $rx = [regex]"(?m)(^\s*checksum\s*=\s*')([a-f0-9]{64})(')"
    $out = $rx.Replace($raw, "`${1}$n`${3}", 1)
    Set-Content -LiteralPath $InstallScriptPath -Value $out -Encoding UTF8
}

function Write-VerificationTxt {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$DownloadUrl,
        [Parameter(Mandatory)][string]$ResolvedUrl,
        [Parameter(Mandatory)][string]$Sha256LowerHex
    )
    $content = @"
VERIFICATION

Purpose
  This file helps moderators and maintainers confirm that the SHA256 in
  tools\chocolateyInstall.ps1 matches the vendor installer the package
  is intended to download. It is the same class of information Chocolatey
  Community packages often include for downloaded binaries.

Package type
  This is a community downloader package. The nupkg does not ship the Missive
  installer. At install time, chocolateyInstall.ps1 uses Install-ChocolateyPackage
  to download from the official URL below and validates with the SHA256
  embedded in the install script.

Install-time download URL
  (used in chocolateyInstall.ps1; may redirect to a versioned .exe on the vendor CDN)
  $DownloadUrl

Resolved URL
  (final URL after redirects, recorded at the time this package metadata was
  last updated; use this to fetch the same file the checksum is based on)
  $ResolvedUrl

Algorithm
  SHA256

Checksum:
  $Sha256LowerHex

How to verify
  1) Download the installer (same bytes as a normal install) from the
     Install-time download URL or Resolved URL above.
  2) Save the file locally (name does not matter).
  3) In PowerShell 5+:
     Get-FileHash -Algorithm SHA256 -LiteralPath ".\<your-downloaded-file>.exe"
  4) The Hash line must match the Checksum (hex, case-insensitive).
"@
    $existing = if (Test-Path -LiteralPath $Path) {
        (Get-Content -LiteralPath $Path -Raw -Encoding UTF8)
    } else {
        ''
    }
    if ($existing -ceq $content) { return }
    Set-Content -LiteralPath $Path -Value $content -Encoding UTF8
}

$nuspecPath = Join-Path $RepoRoot 'missive\missive.nuspec'
$toolsDir = Join-Path $RepoRoot 'missive\tools'
$installScriptPath = Join-Path $toolsDir 'chocolateyInstall.ps1'
$shaPath = Join-Path $toolsDir 'resolved-installer.sha256'
$verificationPath = Join-Path $toolsDir 'VERIFICATION.txt'

foreach ($p in @($nuspecPath, $installScriptPath, $shaPath, $verificationPath)) {
    if (-not (Test-Path -LiteralPath $p)) { throw "Missing required path: $p" }
}

$tempDir = Join-Path $env:TEMP ("missive-update-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
$installer = Join-Path $tempDir 'MissiveSetup.exe'

try {
    Write-Host "Downloading installer (follow redirects): $DownloadUrl"

    $request = [System.Net.HttpWebRequest]::Create($DownloadUrl)
    $request.AllowAutoRedirect = $true
    $request.Method = 'GET'
    $request.UserAgent = 'missive-chocolatey-update/1.0'
    $response = $request.GetResponse()
    try {
        $resolvedUrl = $response.ResponseUri.AbsoluteUri
        $stream = $response.GetResponseStream()
        $fileStream = [System.IO.File]::Create($installer)
        try { $stream.CopyTo($fileStream) } finally { $fileStream.Dispose() }
    }
    finally {
        $response.Dispose()
    }

    if (-not (Test-Path -LiteralPath $installer)) {
        throw 'Download did not produce an installer file.'
    }

    $sha256 = ((Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash).ToLowerInvariant()
    if ($sha256 -notmatch '^[a-f0-9]{64}$') { throw "Unexpected SHA256 output: $sha256" }

    $fileVersion = ''
    try {
        $verInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($installer)
        if ($verInfo.FileVersion) { $fileVersion = $verInfo.FileVersion.Trim() }
    } catch { }

    $rawVersion = if ($fileVersion) { $fileVersion } else { '0.0.0' }
    $nuspecVersion = Get-NuspecVersionString -RawVersion $rawVersion

    Write-Host "Resolved URL: $resolvedUrl"
    Write-Host "SHA256:       $sha256"
    Write-Host "FileVersion:  $fileVersion"
    Write-Host "NuspecVer:    $nuspecVersion"

    Set-XmlFirstMatchValue -Path $nuspecPath -XPath '/n:package/n:metadata/n:version' -Value $nuspecVersion
    $existingSha = (Get-Content -LiteralPath $shaPath -Raw -Encoding UTF8).Trim()
    if ($existingSha -cne $sha256) {
        [System.IO.File]::WriteAllText($shaPath, $sha256)
    }
    Set-InstallScriptChecksumLiteral -InstallScriptPath $installScriptPath -Sha256LowerHex $sha256
    Write-VerificationTxt -Path $verificationPath -DownloadUrl $DownloadUrl -ResolvedUrl $resolvedUrl -Sha256LowerHex $sha256

    Write-Host 'Update complete.'
}
finally {
    if (Test-Path -LiteralPath $tempDir) {
        Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

