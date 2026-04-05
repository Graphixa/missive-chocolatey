<#
.SYNOPSIS
  Verifies a Chocolatey .nupkg contains required tool scripts (same class of check as FontGet release workflow).
#>
param(
    [Parameter(Mandatory)][string]$NupkgPath
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $NupkgPath)) {
    throw "nupkg not found: $NupkgPath"
}

Add-Type -AssemblyName System.IO.Compression.FileSystem

$required = @(
    'tools/chocolateyInstall.ps1'
    'tools/chocolateyUninstall.ps1'
    'tools/helpers.ps1'
)

$zip = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $NupkgPath).Path)
try {
    $entries = $zip.Entries | ForEach-Object {
        ($_.FullName -replace '\\', '/').ToLowerInvariant()
    }
    foreach ($rel in $required) {
        $want = $rel.ToLowerInvariant()
        if ($entries -notcontains $want) {
            $sample = ($entries | Select-Object -First 8) -join ', '
            throw "nupkg missing required entry: $rel (sample entries: $sample)"
        }
    }
}
finally {
    $zip.Dispose()
}

Write-Host "nupkg structure OK: $NupkgPath"
