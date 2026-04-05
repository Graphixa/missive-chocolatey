# Package notes

## Summary

This Chocolatey package is a **downloader package**: the `.nupkg` contains only Chocolatey metadata and PowerShell scripts. The Missive Windows installer is downloaded from Missive’s servers when the user runs `choco install missive` (or when Chocolatey installs the package).

## Architecture

* **Stable:** install/uninstall behaviour, install path (`C:\Missive`), shortcut targets, silent installer arguments (`/S` and `/D=C:\Missive` with `/D=` last).
* **Dynamic:** upstream installer URL after redirects, file hash, and detected version—tracked in `config/package.json` and `config/state.json` for automation and maintainer review.

## Install path and shortcuts

* Install directory: `C:\Missive` (explicit installer override, not the default location).
* Shortcuts (all users):

  * `C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Missive.lnk`
  * `C:\Users\Public\Desktop\Missive.lnk`

## Community maintenance

The software publisher is **Missive**. This package is maintained by the community; it is not implied to be official or endorsed by Missive unless Missive says so.
