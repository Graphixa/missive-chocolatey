# Shared helpers for Missive Chocolatey package (dot-sourced by install/uninstall scripts).

function Get-MissiveInstallRoot {
    <#
        Uses the Windows system drive (e.g. C: or D:) so installs work when Windows is not on C:.
    #>
    return (Join-Path $env:SystemDrive 'Missive')
}

function Write-MissiveLog {
    param([string]$Message)
    Write-Host "[missive-chocolatey] $Message"
}

function Ensure-Directory {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Remove-IfExists {
    param([Parameter(Mandatory)][string]$Path)
    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
    }
}

function Get-InstallerSha256 {
    param([Parameter(Mandatory)][string]$FilePath)
    $hash = Get-FileHash -LiteralPath $FilePath -Algorithm SHA256 -ErrorAction Stop
    return $hash.Hash.ToLowerInvariant()
}

function New-MissiveShortcut {
    param(
        [Parameter(Mandatory)][string]$TargetPath,
        [Parameter(Mandatory)][string]$ShortcutPath,
        [string]$WorkingDirectory = ''
    )
    $parent = Split-Path -Parent $ShortcutPath
    Ensure-Directory -Path $parent
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($ShortcutPath)
    $shortcut.TargetPath = $TargetPath
    if ($WorkingDirectory) {
        $shortcut.WorkingDirectory = $WorkingDirectory
    }
    $shortcut.Save()
}

function Get-MissiveVendorUninstallerPath {
    <#
        Missive ships the uninstall bootstrap as 'Uninstall Missive.exe' (with a space), not only Uninstall.exe.
    #>
    param([Parameter(Mandatory)][string]$InstallPath)
    foreach ($name in @('Uninstall Missive.exe', 'Uninstall.exe')) {
        $full = Join-Path $InstallPath $name
        if (Test-Path -LiteralPath $full) {
            return $full
        }
    }
    return $null
}

function Get-MissiveUninstallEntry {
    <#
        Finds an uninstall registry entry for Missive under the Missive install root or display name.
    #>
    $missiveRoot = Get-MissiveInstallRoot
    $roots = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall'
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
    )
    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        foreach ($item in (Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue)) {
            $key = Get-ItemProperty -LiteralPath $item.PSPath -ErrorAction SilentlyContinue
            if (-not $key) { continue }
            $loc = $key.InstallLocation
            $name = $key.DisplayName
            if (($loc -and $loc.Trim().StartsWith($missiveRoot, [System.StringComparison]::OrdinalIgnoreCase)) -or
                ($name -and $name -like '*Missive*')) {
                return $key
            }
        }
    }
    return $null
}
