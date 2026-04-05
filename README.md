# missive-chocolatey

Community-maintained [Chocolatey](https://chocolatey.org/) package source for [**Missive**](https://missiveapp.com/) (software publisher: Missive).

This repository **does not** host or redistribute the Missive Windows installer. At `choco install` time, the package downloads Missive from Missive’s official Windows download URL (`https://mail.missiveapp.com/download/win`), installs to `C:\Missive`, and creates all-users Start Menu and Public Desktop shortcuts.

Chocolatey is used so the package can run PowerShell on the target machine for a fixed install path and shared shortcuts—behaviour that is awkward to express in WinGet alone.

### Distribution model (no app binaries in this repo)

Missive hosts the Windows installer. This repository only holds Chocolatey metadata and scripts. **You do not need GitHub Releases to ship the Missive app**—users’ machines download the installer from Missive at install time. GitHub Releases here are optional (for example to tag package-source snapshots); they are not part of the downloader flow.

## Status

* **Community maintained** — not an official Missive or Chocolatey package unless Missive adopts it.
* **CI** runs a full Windows smoke test on every push/PR to `main` (`choco pack` → install → verify shortcuts/exe → uninstall).
* **Upstream checks** (`check-missive` workflow): on a schedule (or manually), the workflow resolves Missive’s URL, compares the installer hash to `config/state.json`, and only when the binary **changes**: runs the same smoke test, commits updated `config/*.json` and `missive.nuspec`, then **optionally** pushes the new `.nupkg` to the Chocolatey Community Repository if the `CHOCOLATEY_API_KEY` repository secret is set. If the secret is absent, the workflow still tests and commits; push is skipped until you add the key or run **Package Chocolatey artifact** manually.

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
