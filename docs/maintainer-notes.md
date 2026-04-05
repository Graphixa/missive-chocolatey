# Maintainer notes

## Redirect resolution

`scripts/Resolve-MissiveInstaller.ps1` downloads the installer via `https://mail.missiveapp.com/download/win`, follows redirects, records the final URL, computes SHA256, and compares with `config/state.json`. If the hash changes (or was never set), it updates `config/package.json` and `config/state.json` via `scripts/Update-PackageMetadata.ps1`.

## Metadata updates

Updates run **only** when a meaningful installer change is detected—no churn on no-change runs.

## Before publishing to Chocolatey Community

Follow `build-spec.md` **§10** (testing on a clean Windows machine) and **§11** (manual review). Public push should stay **manual** until the package is proven.

## Manual package build

```powershell
cd chocolatey\missive
choco pack .\missive.nuspec
```

## Manual publish

Use the Chocolatey CLI with your API key (store as a secret; do not commit). Exact steps should be documented here once you have a Chocolatey account and package namespace approved—see **build-spec.md §16** open questions.

## If Missive contacts you

Cooperate in good faith: clarify community-maintained status, offer to align wording, and comply with any reasonable takedown or handoff request.

## Automation

* **CI** (`ci.yml`): on push/PR to `main`, runs `scripts/Test-Package.ps1` on a Windows runner so install/uninstall scripts are exercised every change.
* **check-missive** workflow: scheduled + manual; resolves Missive’s download URL, hashes the installer, and **only** rewrites `config/package.json`, `config/state.json`, and `chocolatey/missive/missive.nuspec` when the upstream binary changes. It then runs the same smoke test, **commits** those files, and **pushes to Chocolatey Community** only if the repository secret **`CHOCOLATEY_API_KEY`** is configured (otherwise the step is skipped—add the key when you are ready for automated publishes).
* **package-and-publish** workflow: manual; smoke test (optional skip), uploads `.nupkg` artifact, optional push when you enable the workflow input and have the API key secret.

Missive hosts the installer; you do **not** need GitHub Releases to distribute the application—only the Chocolatey package version in the nuspec (and Community listing) needs to advance when you publish a new package build.
