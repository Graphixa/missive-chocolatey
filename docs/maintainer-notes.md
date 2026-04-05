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

* **Test** (`test.yml`): **manual** only—runs `scripts/Test-Package.ps1` end-to-end on a Windows runner. Use it before merging risky script changes or when validating a machine.
* **check-missive** workflow: scheduled + manual; resolves Missive’s download URL, hashes the installer, and **only** updates `config/package.json`, `config/state.json`, and `chocolatey/missive/missive.nuspec` when the upstream binary changes. It then runs the smoke test and **commits** those files. If there was a change, it **calls** the reusable **Package and publish** workflow, which pulls the latest commit, runs `choco pack`, uploads the `.nupkg`, and **pushes to Chocolatey Community** when **`CHOCOLATEY_API_KEY`** is set (otherwise push is skipped).
* **Package and publish** (`package-and-publish.yml`): **manual** workflow for ad-hoc pack + artifact + optional push; **reused** by `check-missive` after an upstream change (smoke test skipped there because `check-missive` already ran it).

Missive hosts the installer; you do **not** need GitHub Releases to distribute the application—only the Chocolatey package version in the nuspec (and Community listing) needs to advance when you publish a new package build.
