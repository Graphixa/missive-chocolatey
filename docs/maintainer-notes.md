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
* **check-missive** workflow: scheduled + manual; resolves Missive’s download URL, hashes the installer, and **only** updates `config/package.json`, `config/state.json`, and `chocolatey/missive/missive.nuspec` when the upstream binary changes. It then runs the smoke test and **commits** those files. If there was a change, it **calls** the reusable **Package and publish** workflow, which syncs from origin, runs **`Test-Package.ps1` again** whenever a Chocolatey push is requested (so publish never happens without a fresh local install test), validates the `.nupkg` contents, uploads the artifact, and **pushes** with **`dotnet nuget push`** when **`CHOCOLATEY_API_KEY`** is set (otherwise push is skipped).
* **Package and publish** (`package-and-publish.yml`): **manual** workflow for pack + validate + artifact + optional push. Matches common practice (see [Chocolatey push docs](https://docs.chocolatey.org/en-us/create/commands/push/)): Chocolatey CLI check, full smoke before any push, `scripts/Validate-Nupkg.ps1` on the `.nupkg`, then push with `--skip-duplicate` (same idea as [FontGet’s chocolatey-release workflow](https://github.com/Graphixa/FontGet/blob/main/.github/workflows/chocolatey-release.yml)). **Artifact-only** runs can use “skip smoke” **without** publishing; you cannot publish without running the smoke test in that workflow.

Missive hosts the installer; you do **not** need GitHub Releases to distribute the application—only the Chocolatey package version in the nuspec (and Community listing) needs to advance when you publish a new package build.
