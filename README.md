# Missive — Chocolatey community package

**What this package does**

* Downloads the Windows installer from Missive’s URL (`https://mail.missiveapp.com/download/win`) when you run `choco install`.
* Installs under **`%ChocolateyToolsLocation%\Missive`** (on most PCs that is `C:\tools\Missive`) so the app is available for all users on the machine.
* Adds Start Menu and Public Desktop shortcuts.

This repo is **only** Chocolatey metadata and PowerShell scripts. It does **not** include the Missive app; your PC fetches the installer from Missive at install time.

---

## Downloader package (no binaries redistributed)

- **Why there are no installers in this repo**: this is a Chocolatey Community **downloader** package. The `.nupkg` contains only PowerShell + metadata; the Missive installer is downloaded from the vendor at install time.
- **Upstream URL used at install time**: `https://mail.missiveapp.com/download/win`
- **How to verify the checksum manually**:
  - The current URL + SHA256 live in `missive/tools/VERIFICATION.txt`.
  - Download the installer from the URL above and compute:

```powershell
Get-FileHash -Algorithm SHA256 -LiteralPath ".\<downloaded-installer>.exe"
```

- **CI gates before publish**:
  - `scripts/Update-Package.ps1` resolves the final installer URL, computes SHA256, and writes the checksum **as a literal** into `missive/tools/chocolateyInstall.ps1` and `missive/tools/VERIFICATION.txt`.
  - `scripts/Test-Package.ps1` packs the `.nupkg` and verifies the **packed** `.nupkg` embeds the same checksum and includes `tools/VERIFICATION.txt`.
  - **Test** (workflow): PR / manual `pack` + verify only — no Chocolatey push.
  - **Check and publish** (workflow): runs `Update-Package.ps1` daily (and on demand). If nuspec/tools differ from `HEAD`, it runs a **full smoke test**, **commits** to GitHub, then **pack + verify again** and **pushes the `.nupkg` to Chocolatey** (if `CHOCOLATEY_API_KEY` is set). If nothing changed, it only runs **fast** pack + verify. To test **without** publishing, run the workflow manually and turn **“Push to Chocolatey”** **off** (scheduled runs always attempt push after a successful update when the secret is present).

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

From repo root:

- **Update package metadata from upstream**: `pwsh ./scripts/Update-Package.ps1`
- **Pack + validate (fast)**: `pwsh ./scripts/Test-Package.ps1`
- **Full smoke test (Windows, Chocolatey required)**: `pwsh ./scripts/Test-Package.ps1 -SmokeTest`

CI lives under `.github/workflows/`. Successful runs **upload the built `missive/*.nupkg`** as a workflow artifact (`missive-nupkg`) so you can download the exact file CI produced.
