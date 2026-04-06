# missive-chocolatey

Community-maintained [Chocolatey](https://chocolatey.org/) package source for [**Missive**](https://missiveapp.com/) (software publisher: Missive).

This repository **does not** host or redistribute the Missive Windows installer. At `choco install` time, the package downloads Missive from Missive’s official Windows download URL (`https://mail.missiveapp.com/download/win`), installs to **`%SystemDrive%\Missive`** (the same as `C:\Missive` on typical single-drive setups), and creates all-users Start Menu and Public Desktop shortcuts.

Chocolatey is used so the package can run PowerShell on the target machine for a fixed install path and shared shortcuts—behaviour that is awkward to express in WinGet alone.

### Distribution model (no app binaries in this repo)

Missive hosts the Windows installer. This repository only holds Chocolatey metadata and scripts. **You do not need GitHub Releases to ship the Missive app**—users’ machines download the installer from Missive at install time. GitHub Releases here are optional (for example to tag package-source snapshots); they are not part of the downloader flow.

## Status

* **Community maintained** — not an official Missive or Chocolatey package unless Missive adopts it.
* **Test** (`test.yml`): **manual** workflow—run it when you want a full Windows smoke test (`choco pack` → install → verify shortcuts/exe → uninstall). Nothing runs automatically on push/PR unless you add that back.
* **Check Missive** (`check-missive` workflow): on a schedule (or manually), resolves Missive’s URL and compares the installer hash to `config/state.json`. **Only when the binary changes:** runs the smoke test, commits updated `config/*.json` and `missive.nuspec`, then calls **Package and publish** to `choco pack`, upload the `.nupkg` artifact, and **optionally** `choco push` when `CHOCOLATEY_API_KEY` is set (otherwise push is skipped).
* **Package and publish** (`package-and-publish.yml`): **manual** workflow for ad-hoc pack + artifact + optional push; also **reused** by `check-missive` after an upstream change.

## Repository layout

| Path | Purpose |
|------|---------|
| `chocolatey/missive/` | `missive.nuspec` and `tools/*.ps1` (install/uninstall/helpers) |
| `config/` | `package.json` / `state.json` for automation and installer metadata |
| `scripts/` | Resolve redirect, update metadata, smoke tests |
| `.github/workflows/` | Scheduled check for upstream installer changes; package build |

See `docs/package-notes.md` and `docs/maintainer-notes.md` for architecture and maintainer workflow.

## Build (Windows)

From `chocolatey/missive`:

```powershell
choco pack .\missive.nuspec
```

Smoke test (requires Chocolatey CLI; install may need elevation):

```powershell
pwsh ./scripts/Test-Package.ps1
```

## Spec

Implementation requirements are defined in `build-spec.md` in this repository.

## License

MIT — see `LICENSE`.
