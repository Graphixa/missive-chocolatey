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

* **check-missive** workflow: scheduled + manual; updates config when the upstream installer changes.
* **package-and-publish** workflow: builds `.nupkg` and uploads an artifact; does **not** push to Chocolatey by default.
