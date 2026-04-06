# Missive — Chocolatey community package

**What this package does**

* Downloads the Windows installer from Missive’s URL (`https://mail.missiveapp.com/download/win`) when you run `choco install`.
* Installs under **`%SystemDrive%\Missive`** (on most PCs that is `C:\Missive`) so the app is available for all users on the machine.
* Adds Start Menu and Public Desktop shortcuts.

This repo is **only** Chocolatey metadata and PowerShell scripts. It does **not** include the Missive app; your PC fetches the installer from Missive at install time.

---

**About Missive**

[Missive](https://missiveapp.com) is team email and chat for productive teams—the product name, branding, and application are theirs. This repository is an independent community effort to package Missive for [Chocolatey](https://chocolatey.org/); it is not run by Missive unless they choose to adopt it.

* Website: [missiveapp.com](https://missiveapp.com)  
* Terms: [missiveapp.com/terms](https://missiveapp.com/terms)

---

**Disclaimer**

* Missive’s software, trademarks, and related rights belong to the Missive team. This project does not claim ownership of Missive.
* This package is **community-maintained** and may lag behind or differ from Missive’s own distribution choices.

---

**Development**

From `chocolatey/missive`: `choco pack .\missive.nuspec`. Optional smoke test on Windows: `pwsh ./scripts/Test-Package.ps1` (Chocolatey required). CI lives under `.github/workflows/`.
