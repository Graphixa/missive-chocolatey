# missive-chocolatey

Community-maintained [Chocolatey](https://chocolatey.org/) package source for [**Missive**](https://missiveapp.com/) (software publisher: Missive).

This repository **does not** host or redistribute the Missive Windows installer. At `choco install` time, the package downloads Missive from Missive’s official Windows download URL (`https://mail.missiveapp.com/download/win`), installs to `C:\Missive`, and creates all-users Start Menu and Public Desktop shortcuts.

Chocolatey is used so the package can run PowerShell on the target machine for a fixed install path and shared shortcuts—behaviour that is awkward to express in WinGet alone.

## Status

* **Community maintained** — not an official Missive or Chocolatey package unless Missive adopts it.
* **Public publishing** is intended to be **manual** at first: automation may build and test the `.nupkg`, but pushing to the Chocolatey Community Repository should stay a maintainer decision.

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
