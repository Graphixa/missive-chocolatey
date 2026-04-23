$ErrorActionPreference = 'Stop'

$MissiveDownloadUrl = 'https://mail.missiveapp.com/download/win'

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
. (Join-Path $toolsDir 'helpers.ps1')

$InstallPath = Get-MissiveInstallRoot
$ExePath = Join-Path $InstallPath 'Missive.exe'
$StartMenuShortcut = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\Missive.lnk'
$PublicDesktopShortcut = Join-Path $env:Public 'Desktop\Missive.lnk'

try {
    $chocoPkgName = if ($env:ChocolateyPackageName) { $env:ChocolateyPackageName } else { 'missive' }

    $silent = @(
        '/S'
        "/D=$InstallPath"
    ) -join ' '

    $packageArgs = @{
        packageName    = $chocoPkgName
        fileType       = 'exe'
        url            = $MissiveDownloadUrl
        silentArgs     = $silent
        checksum       = '07ea01d10ccc6a4f727ac4847c0d4895d79f1494cc4aa7beb073896c69823175'
        checksumType   = 'sha256'
        validExitCodes = @(0)
    }

    Write-MissiveLog "Installing from $MissiveDownloadUrl"
    Write-MissiveLog "Silent arguments: $silent"
    Install-ChocolateyPackage @packageArgs

    if (-not (Test-Path -LiteralPath $ExePath)) {
        throw "Expected executable not found at $ExePath after install."
    }

    Write-MissiveLog 'Creating all-users shortcuts.'
    New-MissiveShortcut -TargetPath $ExePath -ShortcutPath $StartMenuShortcut -WorkingDirectory $InstallPath
    New-MissiveShortcut -TargetPath $ExePath -ShortcutPath $PublicDesktopShortcut -WorkingDirectory $InstallPath

    foreach ($p in @($StartMenuShortcut, $PublicDesktopShortcut)) {
        if (-not (Test-Path -LiteralPath $p)) {
            throw "Shortcut was not created: $p"
        }
    }

    Write-MissiveLog 'Missive install completed successfully.'
}
finally {
}
