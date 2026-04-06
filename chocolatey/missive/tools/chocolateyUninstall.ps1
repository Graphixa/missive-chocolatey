$ErrorActionPreference = 'Stop'

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
. (Join-Path $toolsDir 'helpers.ps1')

$InstallPath = Get-MissiveInstallRoot
$StartMenuShortcut = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\Missive.lnk'
$PublicDesktopShortcut = Join-Path $env:Public 'Desktop\Missive.lnk'

Write-MissiveLog 'Starting Missive package uninstall.'

$entry = Get-MissiveUninstallEntry
if ($entry) {
    $quiet = $entry.QuietUninstallString
    $uninstall = $entry.UninstallString
    if ($quiet) {
        Write-MissiveLog 'Running QuietUninstallString from registry.'
        try {
            cmd.exe /c $quiet | Out-Null
        } catch {
            Write-MissiveLog "Quiet uninstall reported: $($_.Exception.Message)"
        }
    }
    elseif ($uninstall) {
        Write-MissiveLog 'Running UninstallString from registry (best-effort silent).'
        $exe = $uninstall
        $args = ''
        if ($uninstall -match '^"([^"]+)"\s*(.*)$') {
            $exe = $Matches[1]
            $args = $Matches[2]
        }
        elseif ($uninstall -match '^(\S+)\s+(.*)$') {
            $exe = $Matches[1]
            $args = $Matches[2]
        }
        if ($exe -and (Test-Path -LiteralPath $exe)) {
            $silent = if ($args) { "$args /S" } else { '/S' }
            try {
                Start-Process -FilePath $exe -ArgumentList $silent -Wait -PassThru | Out-Null
            } catch {
                Write-MissiveLog "Uninstall runner: $($_.Exception.Message)"
            }
        }
    }
}

$uninstallExe = Join-Path $InstallPath 'Uninstall.exe'
if (Test-Path -LiteralPath $uninstallExe) {
    Write-MissiveLog "Running Uninstall.exe under $InstallPath if present."
    try {
        $p = Start-Process -FilePath $uninstallExe -ArgumentList '/S' -Wait -PassThru -ErrorAction SilentlyContinue
        if ($p -and $p.ExitCode -ne 0) {
            Write-MissiveLog "Uninstall.exe exit code: $($p.ExitCode)"
        }
    } catch {
        Write-MissiveLog "Uninstall.exe: $($_.Exception.Message)"
    }
}

if (Test-Path -LiteralPath $InstallPath) {
    Write-MissiveLog "Removing remaining install directory: $InstallPath"
    try {
        Remove-IfExists -Path $InstallPath
    } catch {
        Write-MissiveLog "Could not fully remove $InstallPath : $($_.Exception.Message)"
    }
}

foreach ($lnk in @($StartMenuShortcut, $PublicDesktopShortcut)) {
    if (Test-Path -LiteralPath $lnk) {
        Remove-Item -LiteralPath $lnk -Force -ErrorAction SilentlyContinue
    }
}

Write-MissiveLog 'Uninstall script finished.'
