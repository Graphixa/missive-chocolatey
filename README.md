# missive-chocolatey

Community-maintained [Chocolatey](https://chocolatey.org/) package that helps you install [**Missive**](https://missiveapp.com/) on Windows with a fixed install location and shared shortcuts.

## Disclaimer

* **Missive** (the product) is owned and operated by **Missive**. Trademarks, copyrights, and all rights in the software belong to the Missive team. This GitHub repository is a **community** packaging effort—it is **not** an official Missive or Chocolatey product unless Missive says so.
* This repo contains **only** Chocolatey metadata and PowerShell scripts. It does **not** ship the Missive app in the repository; when someone runs `choco install`, the installer is **downloaded from Missive** at install time.

## Official Missive

* Website: [https://missiveapp.com](https://missiveapp.com)
* Terms of service: [https://missiveapp.com/terms](https://missiveapp.com/terms)

## What this package does

* Downloads the Windows installer from Missive’s official URL (`https://mail.missiveapp.com/download/win`).
* Installs under **`%SystemDrive%\Missive`** (on most PCs that is `C:\Missive`).
* Adds Start Menu and Public Desktop shortcuts.

## License (this repository)

The **packaging scripts and files in this repo** are under the [MIT License](LICENSE). That license applies to **this repository only**, not to Missive’s application.

## Development (short)

Build the `.nupkg` from `chocolatey/missive` with `choco pack .\missive.nuspec`. Optional smoke test: `pwsh ./scripts/Test-Package.ps1` on Windows with Chocolatey installed. GitHub Actions workflows under `.github/workflows/` run tests and optional packaging.
