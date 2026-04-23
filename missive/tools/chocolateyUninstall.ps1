$ErrorActionPreference = 'Stop'

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
. (Join-Path $toolsDir 'helpers.ps1')

$InstallPath = Get-MissiveInstallRoot
$StartMenuShortcut = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\Missive.lnk'
$PublicDesktopShortcut = Join-Path $env:Public 'Desktop\Missive.lnk'

Write-MissiveLog 'Starting Missive package uninstall.'

$vendorUninstall = Get-MissiveVendorUninstallerPath -InstallPath $InstallPath
if ($vendorUninstall) {
    $chocoPkgName = if ($env:ChocolateyPackageName) { $env:ChocolateyPackageName } else { 'missive' }
    Write-MissiveLog "Running vendor uninstaller via Chocolatey helper: $vendorUninstall"
    $packageArgs = @{
        packageName    = $chocoPkgName
        fileType       = 'exe'
        file           = $vendorUninstall
        silentArgs     = '/S'
        validExitCodes = @(0)
    }
    try {
        Uninstall-ChocolateyPackage @packageArgs
    } catch {
        Write-MissiveLog "Vendor uninstall helper reported: $($_.Exception.Message)"
    }
}

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
