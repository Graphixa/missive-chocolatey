$ErrorActionPreference = 'Stop'

$MissiveDownloadUrl = 'https://mail.missiveapp.com/download/win'

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
. (Join-Path $toolsDir 'helpers.ps1')

$InstallPath = Get-MissiveInstallRoot
$ExePath = Join-Path $InstallPath 'Missive.exe'
$StartMenuShortcut = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\Missive.lnk'
$PublicDesktopShortcut = Join-Path $env:Public 'Desktop\Missive.lnk'

$tempDir = $null
$installerPath = $null

try {
    Write-MissiveLog "Preparing download from $MissiveDownloadUrl"

    $tempDir = Join-Path $env:TEMP ("missive-chocolatey-install-" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    $installerPath = Join-Path $tempDir 'MissiveSetup.exe'

    $chocoPkgName = if ($env:ChocolateyPackageName) { $env:ChocolateyPackageName } else { 'missive' }
    Get-ChocolateyWebFile -PackageName $chocoPkgName -FileFullPath $installerPath -Url $MissiveDownloadUrl

    $optionalChecksum = $null
    if ($env:MISSIVE_INSTALLER_SHA256) {
        $optionalChecksum = $env:MISSIVE_INSTALLER_SHA256.Trim()
    }
    if ($optionalChecksum) {
        $actual = Get-InstallerSha256 -FilePath $installerPath
        $expected = $optionalChecksum.ToLowerInvariant()
        if ($actual -ne $expected) {
            throw "Installer SHA256 mismatch. Expected $expected, got $actual. Refusing to install."
        }
        Write-MissiveLog 'SHA256 verification passed.'
    }

    $arguments = @(
        '/S'
        "/D=$InstallPath"
    )

    Write-MissiveLog "Running installer silent with arguments: $($arguments -join ' ')"

    $process = Start-Process -FilePath $installerPath -ArgumentList $arguments -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        throw "Missive installer exited with code $($process.ExitCode)."
    }

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
    if ($tempDir -and (Test-Path -LiteralPath $tempDir)) {
        Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
