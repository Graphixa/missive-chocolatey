# `SPEC.md` — Missive Chocolatey repository

## Overview

Build a new GitHub repository for a **community-maintained Chocolatey package** for Missive.

Suggested repository name:

```text
missive-chocolatey
```

This repository must produce and maintain a Chocolatey package that:

* downloads Missive from Missive’s official Windows URL at install time
* does **not** host, embed, or redistribute the Missive EXE in the repo or package
* installs Missive to `C:\Missive`
* creates shared shortcuts for all users:

  * `C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Missive.lnk`
  * `C:\Users\Public\Desktop\Missive.lnk`
* supports uninstall and cleanup
* is suitable for submission to the **Chocolatey Community Repository**
* is clearly described as a **community-maintained package for Missive**
* keeps **public Chocolatey publishing manual at first**, even if automation prepares the package

This repo must **not** pivot back to WinGet as the main design.

### How to use this document

1. **§1** locks decisions; do not revisit them during build.
2. **Build at a glance** (below) tracks phase completion at a high level.
3. **§17** is the detailed day-by-day task list with checkboxes—work through it in order.
4. Deeper requirements live in **§4–§16** (package model, scripts, workflows, testing, docs).
5. Before calling the repo done, complete **§18** and run through **§10** on a clean Windows machine.

---

## Table of contents

| Section | Topic |
|--------|--------|
| [1. Final decisions](#1-final-decisions) | Locked choices (Chocolatey, URLs, paths, identity) |
| [2. Objectives](#2-objectives) | What the repository must deliver |
| [3. Repository structure](#3-repository-structure) | Directory layout |
| [4. Package model](#4-package-model) | Downloader package rules |
| [Install command requirements](#install-command-requirements) | `/S`, `/D=C:\Missive`, ordering |
| [5. Package identity and wording](#5-package-identity-and-wording) | Nuspec/README honesty |
| [6. Config files](#6-config-files) | `package.json`, `state.json` |
| [7. Chocolatey package files](#7-chocolatey-package-files) | nuspec, install, uninstall, helpers |
| [8. Update detection scripts](#8-update-detection-scripts) | Resolve, update metadata, smoke test |
| [9. Workflows](#9-workflows) | `check-missive`, `package-and-publish` |
| [10. Testing rules](#10-testing-rules-before-first-public-publish) | Pre-publish verification (checkboxes) |
| [11. First public publish](#11-rules-for-first-public-publish) | Gates before community push |
| [12. Publish strategy](#12-recommended-publish-strategy) | Manual-first and later automation |
| [13. README requirements](#13-readme-requirements) | README content |
| [14. Documentation requirements](#14-documentation-requirements) | Package and maintainer docs |
| [15. Security and integrity](#15-security-and-integrity-rules) | Integrity checklist |
| [16. Open technical questions](#16-open-technical-questions-the-agent-must-answer-in-docs) | Must answer in docs |
| [17. Suggested implementation sequence](#17-suggested-implementation-sequence) | **Phased build tasks (checkboxes)** |
| [18. Final acceptance checklist](#18-final-acceptance-checklist) | Ship criteria by area |
| [19. Short agent handoff](#19-short-agent-handoff) | One-paragraph summary for agents |

---

## Build at a glance

Tick each phase when **all** checkboxes for that phase in **§17** are complete.

* [ ] **Phase 1 — Scaffold:** repo layout, nuspec, script and config skeletons, docs skeleton, nuspec validates
* [ ] **Phase 2 — Install / uninstall:** download, silent install with explicit args, shortcuts, uninstall, local tests
* [ ] **Phase 3 — Update detection:** resolve redirect, hash, metadata/state updates only on real change
* [ ] **Phase 4 — Automation:** `check-missive` and `package-and-publish` workflows, CI build + artifact, no auto public push
* [ ] **Phase 5 — First publish prep:** full §10 testing on clean Windows, wording review, manual Chocolatey push

---

## 1. Final decisions

These are locked and should not be re-opened during implementation.

### Package manager choice

Use **Chocolatey** as the primary packaging target.

### Why Chocolatey

Chocolatey supports PowerShell-based install and uninstall logic on the target machine, which is required for:

* installing to `C:\Missive`
* creating shared Start Menu and Public Desktop shortcuts
* performing post-install actions that WinGet cannot do while still pointing directly to the vendor EXE

### Vendor source

Missive must be downloaded from Missive’s official Windows URL chain at install time:

```text
https://mail.missiveapp.com/download/win
```

### Binary hosting rule

Do **not** host or embed Missive binaries in the repository or Chocolatey package.

### Install path

Install to:

```text
C:\Missive
```

### Shared shortcuts

Create:

```text
C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Missive.lnk
C:\Users\Public\Desktop\Missive.lnk
```

### Package identity

Use:

* package name: `missive`
* software publisher: `Missive`
* project URL: `https://missiveapp.com`

### Maintenance positioning

The package is **community maintained** for Missive.
Do not describe it as vendor-maintained or official unless Missive later adopts it.

### Public publishing policy

Automation may prepare the package, build it, and test it.
**Public Chocolatey publishing must remain manual at first.**

---

## 2. Objectives

The repository must support four responsibilities:

1. **Package source**

   * nuspec
   * install/uninstall scripts
   * helpers

2. **Update detection**

   * resolve Missive redirect
   * detect when the final target changes
   * capture version/hash metadata if feasible

3. **Validation and smoke testing**

   * install test
   * shortcut verification
   * uninstall test
   * package validation

4. **Manual-first publication**

   * build package automatically
   * optionally prepare package for maintainers
   * require human approval before public Chocolatey push

---

## 3. Repository structure

Use a structure like this, unless a small simplification improves maintainability:

```text
missive-chocolatey/
├─ .github/
│  └─ workflows/
│     ├─ check-missive.yml
│     └─ package-and-publish.yml
├─ chocolatey/
│  └─ missive/
│     ├─ missive.nuspec
│     └─ tools/
│        ├─ chocolateyInstall.ps1
│        ├─ chocolateyUninstall.ps1
│        └─ helpers.ps1
├─ config/
│  ├─ package.json
│  └─ state.json
├─ scripts/
│  ├─ Resolve-MissiveInstaller.ps1
│  ├─ Update-PackageMetadata.ps1
│  └─ Test-Package.ps1
├─ docs/
│  ├─ package-notes.md
│  └─ maintainer-notes.md
├─ README.md
└─ LICENSE
```

If the agent can consolidate `Resolve-MissiveInstaller.ps1` and `Update-PackageMetadata.ps1` cleanly, that is acceptable.

---

## 4. Package model

This is a **Chocolatey downloader package**.

That means:

* the Chocolatey package contains **scripts and metadata only**
* Missive EXE is downloaded from Missive during installation
* the package does not carry Missive binaries inside the nupkg
* install logic is community maintained

This is the standard safe model for third-party packages where redistribution rights may be unclear.

---

## Install command requirements

The package must use Missive’s silent installer switches exactly as follows unless real-world testing proves a different syntax is required.

### Required install arguments

Use:

```text
/S /D=C:\Missive
```

### Meaning

* `/S` = silent install
* `/D=C:\Missive` = install path override

### Important installer rule

Treat `/D=C:\Missive` as the **last installer argument** unless testing proves otherwise.

This matters because installers in this family commonly expect `/D=` to be final.

### Spec requirement

The implementation must explicitly use the Missive silent install command with:

```text
/S /D=C:\Missive
```

and must not rely on default install location behaviour.

---

## 5. Package identity and wording

### Core package metadata

Use:

* package id/name: `missive`
* title: `Missive`
* software publisher: `Missive`
* project URL: `https://missiveapp.com`

### Required wording principles

The nuspec, README, and docs must all make clear:

* this is a **community-maintained package for Missive**
* the software publisher is **Missive**
* the package downloads from Missive’s official Windows URL
* the package does not redistribute Missive binaries
* the maintainer intends to seek Missive’s blessing after the package is live and proven
* if Missive later adopts, replaces, or requests removal, the maintainer will cooperate

### What not to say

Do not say:

* official package
* vendor-maintained package
* endorsed by Missive

unless and until Missive explicitly confirms that.

---

## 6. Config files

### `config/package.json`

Purpose:
Dynamic package metadata used by scripts and automation.

Required fields:

```json
{
  "version": "",
  "missiveRedirectUrl": "https://mail.missiveapp.com/download/win",
  "resolvedInstallerUrl": "",
  "resolvedInstallerSha256": "",
  "detectedFileVersion": "",
  "lastCheckedUtc": ""
}
```

Notes:

* `version` should represent the currently detected Missive installer version when possible
* `resolvedInstallerUrl` is the final redirected EXE URL
* `resolvedInstallerSha256` is the SHA256 of the downloaded EXE used for metadata/update purposes

### `config/state.json`

Purpose:
Automation state.

Required fields:

```json
{
  "currentVersion": "",
  "currentResolvedInstallerUrl": "",
  "currentResolvedInstallerSha256": "",
  "lastPackagedVersion": "",
  "lastPublishedVersion": "",
  "lastPublishedPackageSource": "",
  "lastCheckedUtc": ""
}
```

Notes:

* `lastPackagedVersion` means a package was built successfully
* `lastPublishedVersion` means the package was actually pushed to Chocolatey Community
* `lastPublishedPackageSource` can be used to track package artifacts if useful

---

## 7. Chocolatey package files

## 7.1 `chocolatey/missive/missive.nuspec`

### Purpose

Defines the Chocolatey package metadata.

### Requirements

Include:

* id: `missive`
* title: `Missive`
* authors: maintainer/community identifier as appropriate
* project URL: `https://missiveapp.com`
* description that clearly states:

  * downloads from Missive official Windows URL
  * installs to `C:\Missive`
  * creates all-users shortcuts
  * package is community maintained

### Acceptance criteria

* nuspec is valid
* wording is honest and non-misleading
* description does not imply official endorsement

### Implementation note

If Chocolatey conventions need author/owners fields that are different from software publisher, keep them technically correct while preserving truthful description.

---

## 7.2 `chocolatey/missive/tools/chocolateyInstall.ps1`

### Purpose

Perform install.

### Install arguments requirement

The install script must invoke the Missive installer with these arguments:

```powershell
@('/S', '/D=C:\Missive')
```

or equivalent logic that results in the same final command line.

### Acceptance criteria (installer invocation)

* install target is `C:\Missive`
* installer is silent
* installer arguments are explicitly set in code
* `/D=C:\Missive` is passed as the final argument unless testing confirms another ordering is required

### Example implementation shape

```powershell
$installPath = 'C:\Missive'
$arguments = @(
    '/S'
    "/D=$installPath"
)

$process = Start-Process -FilePath $tempExe -ArgumentList $arguments -Wait -PassThru
if ($process.ExitCode -ne 0) {
    throw "Missive installer exited with code $($process.ExitCode)."
}
```

The agent should wrap this in Chocolatey idioms (strict mode, helpers, logging, temp cleanup) as elsewhere in this spec.

### Testing rule

Before first public publish, verify on a clean Windows machine that the installer actually honours:

```text
/S /D=C:\Missive
```

and does not silently fall back to another install directory.

### Required behaviour

1. set strict error handling
2. define:

   * package name
   * official Missive URL
   * install path `C:\Missive`
3. download Missive from:

   * `https://mail.missiveapp.com/download/win`
4. follow redirect and save installer to temp
5. optionally verify SHA256 if package metadata has a trusted current checksum
6. run installer silently with:

   * `/S /D=C:\Missive`
7. verify:

   * `C:\Missive\Missive.exe`
8. create:

   * `C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Missive.lnk`
   * `C:\Users\Public\Desktop\Missive.lnk`
9. clean up temp files

### Acceptance criteria

After successful install:

* `C:\Missive\Missive.exe` exists
* both shared shortcuts exist
* install script exits successfully
* no Missive binary is permanently retained in temp

### Required implementation rules

* use `$ErrorActionPreference = 'Stop'`
* use Chocolatey helpers where appropriate
* use explicit logging
* clean up temp files in `finally`
* shortcut creation must be idempotent

### Example implementation shape (full flow)

The agent should implement using Chocolatey idioms, but broadly:

* temp file path
* `Invoke-WebRequest` or Chocolatey helper for download
* `Start-Process` with explicit argument list `@('/S', '/D=C:\Missive')` (or equivalent), with `/D=` last
* verify executable
* create `.lnk` files using WScript.Shell

---

## 7.3 `chocolatey/missive/tools/chocolateyUninstall.ps1`

### Purpose

Perform uninstall/cleanup.

### Required behaviour

1. locate vendor uninstall entry if present
2. attempt vendor uninstall silently if possible
3. remove `C:\Missive` if still present
4. remove both shared shortcuts
5. exit cleanly if targets are already absent

### Acceptance criteria

After uninstall:

* `C:\Missive` is absent or no longer contains the installed app
* both shared shortcuts are absent
* script exits cleanly

### Implementation notes

* inspect uninstall registry entries from a real install
* if vendor uninstall is unreliable, fallback cleanup must still work
* do not fail just because artefacts are already absent

---

## 7.4 `chocolatey/missive/tools/helpers.ps1`

### Purpose

Shared helper functions.

### Suggested functions

* `Ensure-Directory`
* `Remove-IfExists`
* `New-Shortcut`
* `Get-InstallerSha256`
* `Resolve-MissiveInstaller`
* `Write-Log`

### Acceptance criteria

* helpers are reusable
* no silent failure
* minimal duplication between install and uninstall scripts

---

## 8. Update detection scripts

## 8.1 `scripts/Resolve-MissiveInstaller.ps1`

### Purpose

Resolve Missive’s official redirect URL, download the EXE, compute hash, and detect changes.

### Required behaviour

1. read `config/package.json`
2. resolve:

   * `https://mail.missiveapp.com/download/win`
3. capture final redirected EXE URL
4. download the EXE to temp
5. compute SHA256
6. read file version if available
7. derive version from URL or file metadata
8. compare against `config/state.json`
9. output whether a meaningful change occurred

### Acceptance criteria

* abort if redirect resolution fails
* abort if final URL is not an EXE-like installer target
* abort if hash cannot be computed
* do not update state/config on failed resolution
* clearly log:

  * final URL
  * version
  * SHA256
  * change/no-change decision

### Output expectations

Expose enough information for workflows to determine whether:

* package metadata should be updated
* package build should run

---

## 8.2 `scripts/Update-PackageMetadata.ps1`

### Purpose

Update package metadata files when a real Missive change is detected.

### Required behaviour

* write updated `config/package.json`
* update `config/state.json`
* only run after successful resolution/hash calculation
* do nothing on no-change runs

### Acceptance criteria

* no partial writes
* no daily metadata churn when no change occurred

---

## 8.3 `scripts/Test-Package.ps1`

### Purpose

Run local or CI smoke tests for the package.

### Required behaviour

At minimum:

1. install package or invoke install script in a test-safe way
2. verify:

   * `C:\Missive\Missive.exe`
   * Start Menu shortcut exists
   * Desktop shortcut exists
3. run uninstall path
4. verify cleanup

### Acceptance criteria

* test fails fast on missing artefacts
* logs are clear
* safe to run on a fresh Windows test environment

---

## 9. Workflows

## 9.1 `.github/workflows/check-missive.yml`

### Purpose

Check whether Missive’s official installer changed.

### Trigger

* schedule
* manual dispatch

### Required behaviour

1. checkout repo
2. install prerequisites
3. resolve current Missive installer
4. if no change:

   * exit cleanly
   * do not rewrite package/state files
   * do not create commit
5. if changed:

   * update metadata files
   * optionally build and smoke-test package
   * commit metadata changes back to repo

### Acceptance criteria

* no noisy commits on no-change runs
* clear logs
* only updates repo state on genuine change

### GitHub permissions

Use:

```yaml
permissions:
  contents: write
```

### Authentication

* use `GITHUB_TOKEN` for repo writes

---

## 9.2 `.github/workflows/package-and-publish.yml`

### Purpose

Build, validate, and optionally publish the Chocolatey package.

### Trigger

* manual dispatch strongly preferred at first
* optional workflow_call if needed internally

### Required behaviour

1. checkout repo
2. build Chocolatey package
3. run package validation
4. run smoke tests
5. produce the `.nupkg` artifact
6. optionally publish, but **manual approval only at first**

### Acceptance criteria

* package builds reproducibly
* package artifact is retained for review
* public publish is not automatic by default

### Publishing rule

For the initial phase:

* **public Chocolatey push must be manual**
* maintainers review:

  * package metadata
  * smoke test results
  * logs
  * checksum/update behaviour
    before publishing

### Authentication

If public publish is enabled later:

* use a Chocolatey API key secret
* do not publish automatically until the package is proven stable

---

## 10. Testing rules before first public publish

These are mandatory.

Before the first Chocolatey Community submission, the maintainer or CI process must verify all of the following on a clean Windows test machine or equivalent controlled environment.

### Install switch verification

The maintainer must verify all of the following on a clean Windows test machine:

* [ ] The package invokes Missive with `/S /D=C:\Missive`
* [ ] Missive installs silently without blocking prompts
* [ ] Missive actually installs to `C:\Missive`
* [ ] `C:\Missive\Missive.exe` exists after install
* [ ] The installer does not redirect into another path unexpectedly

If the installer does not reliably honour these switches, the package must not be published until the implementation is corrected or the behaviour is documented and accepted.

## 10.1 Install tests

Verify:

* [ ] Package installs successfully
* [ ] Missive downloads from the official Missive Windows URL chain
* [ ] Install completes silently
* [ ] `C:\Missive\Missive.exe` exists
* [ ] No unexpected interactive prompts block installation
* [ ] Exit codes are handled correctly

## 10.2 Shortcut tests

Verify:

* [ ] `C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Missive.lnk` exists
* [ ] `C:\Users\Public\Desktop\Missive.lnk` exists
* [ ] Both shortcuts point to `C:\Missive\Missive.exe`

## 10.3 Launch sanity test

Verify:

* [ ] Installed executable launches successfully
* [ ] Basic application startup works without obvious breakage
* [ ] If Missive immediately self-updates, this is noted in maintainer docs

## 10.4 Uninstall tests

Verify:

* [ ] Uninstall script runs successfully
* [ ] Install folder is removed or cleaned appropriately
* [ ] Both shortcuts are removed
* [ ] Repeated uninstall does not cause catastrophic failure if artefacts are already absent

## 10.5 Reinstall tests

Verify:

* [ ] Install → uninstall → reinstall works cleanly
* [ ] Shortcut recreation is idempotent
* [ ] No stale broken shortcuts remain

## 10.6 Upgrade-path test

Verify:

* [ ] Package update over an existing install behaves acceptably
* [ ] Missive remains functional after package reinstall/update
* [ ] Shortcut creation does not duplicate endlessly

## 10.7 Logging review

Verify:

* [ ] Install and uninstall logs are readable
* [ ] Failure cases are diagnosable
* [ ] No silent failures or swallowed exceptions

## 10.8 Metadata validation

Verify:

* [ ] Package metadata honestly describes community-maintained status
* [ ] Description does not imply official endorsement
* [ ] Links point to Missive official site where appropriate

---

## 11. Rules for first public publish

The first public publish to Chocolatey Community must only happen after:

* [ ] Install test passes (**§10.1**)
* [ ] Uninstall test passes (**§10.4**)
* [ ] Shortcut test passes (**§10.2**)
* [ ] Reinstall test passes (**§10.5**)
* [ ] Maintainer manually reviews package metadata
* [ ] Maintainer manually reviews logs
* [ ] Package description wording is confirmed truthful and non-misleading

The first few public publishes should remain manual even if automation is capable of packaging.

---

## 12. Recommended publish strategy

### Phase 1 — manual public publishing

Automation may:

* detect Missive change
* update metadata
* build package
* run smoke tests
* attach `.nupkg` artifact

Maintainer must:

* review results
* decide whether to publish to Chocolatey Community manually

### Phase 2 — optional partial automation

Only after the package has proven stable should the maintainer consider semi-automated publication.

Even then, prefer:

* automated build/test
* manual approval gate
* manual final publish

Do not default to blind public publishing.

---

## 13. README requirements

`README.md` must explain:

* what the repository is for
* that this is a community-maintained Chocolatey package for Missive
* that Missive binaries are downloaded from Missive’s official Windows URL
* that the repo/package does not redistribute Missive binaries
* why Chocolatey is the right tool for this package
* that the package installs to `C:\Missive`
* that the package creates all-users Start Menu and Desktop shortcuts
* that the maintainer intends to seek Missive’s blessing once the package is live and proven

### Required tone

Professional, respectful, and factual.

---

## 14. Documentation requirements

## `docs/package-notes.md`

Must include:

* package architecture summary
* downloader-package model
* stable vs dynamic parts
* install path rationale
* shortcut rationale

## `docs/maintainer-notes.md`

Must include:

* how redirect resolution works
* how metadata updates work
* what to test before publish
* how to build the package manually
* how to publish manually
* what to do if Missive contacts the maintainer
* note that public publishing is manual initially

---

## 15. Security and integrity rules

The implementation must follow these rules (use as a review checklist before first publish):

* [ ] **(1)** Never redistribute the Missive EXE in the package.
* [ ] **(2)** Always download from Missive’s official Windows URL chain.
* [ ] **(3)** Use checksum verification if a reliable current checksum can be maintained.
* [ ] **(4)** Abort install on download failure.
* [ ] **(5)** Abort install on hash mismatch if checksum enforcement is active.
* [ ] **(6)** Clean up temp files in `finally`.
* [ ] **(7)** Never silently ignore failed shortcut creation.
* [ ] **(8)** Avoid daily metadata churn on no-change checks.
* [ ] **(9)** Keep public publishing manual at first.
* [ ] **(10)** Keep wording truthful about community maintenance.

---

## 16. Open technical questions the agent must answer in docs

Before considering the repo complete, the agent must document clear answers to each item below (tick when answered in `docs/` or README):

* [ ] **(1)** What exact nuspec wording best describes this as a community-maintained Missive package without implying official endorsement?
* [ ] **(2)** What is the safest checksum strategy given Missive’s redirect model and possible moving bootstrap installer behaviour?
* [ ] **(3)** Should the package enforce a fixed checksum at install time, or is there a case for metadata-only tracking with manual maintainer review before publish?
* [ ] **(4)** What exact manual steps are required to publish to Chocolatey Community?
* [ ] **(5)** What exact install/uninstall/reinstall tests were run before first submission?

---

## 17. Suggested implementation sequence

This is the **primary build checklist**. Complete phases in order unless a task explicitly allows parallel work. **Build at a glance** (above) tracks phase-level completion; this section is the granular tick list.

### Phase 1 — Scaffold repository

* [ ] Create directory layout per **§3** (`.github/workflows`, `chocolatey/missive/tools`, `config`, `scripts`, `docs`)
* [ ] Add root `LICENSE` and `README.md` (can be expanded in later phases)
* [ ] Add `chocolatey/missive/missive.nuspec` with required id, title, project URL, and honest **§5** / **§7.1** description
* [ ] Add `chocolatey/missive/tools/chocolateyInstall.ps1` (skeleton loads; strict mode placeholder OK)
* [ ] Add `chocolatey/missive/tools/chocolateyUninstall.ps1` (skeleton)
* [ ] Add `chocolatey/missive/tools/helpers.ps1` (skeleton or minimal shared functions)
* [ ] Add `config/package.json` and `config/state.json` with required fields per **§6**
* [ ] Add `docs/package-notes.md` and `docs/maintainer-notes.md` (skeleton headings)
* [ ] Validate nuspec (e.g. `choco pack` dry run or equivalent) — package metadata parses

**Phase 1 done when:** structure exists, nuspec is valid, scripts are present and parse, config files match **§6**.

### Phase 2 — Install, uninstall, shortcuts

* [ ] Implement download from `https://mail.missiveapp.com/download/win` with redirect handling
* [ ] Implement installer invocation per **Install command requirements** and **§7.2**: explicit `@('/S', '/D=C:\Missive')` or equivalent; `/D=` last
* [ ] Verify `C:\Missive\Missive.exe` after install; fail on missing binary
* [ ] Create `C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Missive.lnk` (idempotent)
* [ ] Create `C:\Users\Public\Desktop\Missive.lnk` (idempotent)
* [ ] Implement temp download cleanup in `finally`; `$ErrorActionPreference = 'Stop'` per **§7.2**
* [ ] Implement **§7.3** uninstall: vendor uninstall if present, remove `C:\Missive` and both shortcuts, tolerate missing artefacts
* [ ] Flesh out **§7.4** helpers as needed; avoid duplication between install/uninstall
* [ ] Run local install test: silent, correct path, shortcuts, exit codes
* [ ] Run local uninstall test: cleanup and no spurious failures

**Phase 2 done when:** **§7** acceptance criteria met on a dev/test Windows machine; **§10** install-switch verification and **10.1–10.4** can be executed successfully.

### Phase 3 — Update detection and metadata

* [ ] Implement `scripts/Resolve-MissiveInstaller.ps1` per **§8.1** (redirect, download, SHA256, version, change detection)
* [ ] Implement `scripts/Update-PackageMetadata.ps1` per **§8.2** (update `package.json` / `state.json` only after successful resolution; no partial writes)
* [ ] Confirm no-change runs do not rewrite files or churn metadata (**§8**, **§15**)
* [ ] Implement `scripts/Test-Package.ps1` per **§8.3** (or equivalent smoke harness)

**Phase 3 done when:** change detection is reliable; metadata updates only on real upstream change; **§16** questions (2)–(3) answered in maintainer docs.

### Phase 4 — GitHub Actions and CI

* [ ] Add `.github/workflows/check-missive.yml` per **§9.1** (schedule + manual; no noisy commits on no-change)
* [ ] Add `.github/workflows/package-and-publish.yml` per **§9.2** (build, validate, smoke tests, artifact; **no** automatic public Chocolatey push by default)
* [ ] Configure `permissions` and `GITHUB_TOKEN` as in **§9.1**
* [ ] Confirm `.nupkg` artifact is produced and retained for review
* [ ] Document any secrets placeholders for future optional publish (**§9.2** authentication)

**Phase 4 done when:** CI builds the package reproducibly; workflows match **§9** acceptance criteria; public push remains manual.

### Phase 5 — First community submission

* [ ] Complete **§10** (including **Install switch verification** and **10.1–10.8**) on a **clean Windows** test machine or equivalent
* [ ] Complete **§11** gates (tests + manual metadata/log review)
* [ ] Finalize **§13** README and **§14** docs; answer **§16** items (1)–(5) in repo docs
* [ ] Run through **§18** final checklist
* [ ] Perform first **manual** push to Chocolatey Community per **§12** / **§9.2** (maintainer-controlled)

**Phase 5 done when:** package is published (or ready for publish) with evidence of tests and reviews; **§18** all items checked.

---


## 18. Final acceptance checklist

The implementation is not complete until **every** item below is checked. Use this after **§17 Phase 5** and **§10** testing.

### Installer and install path

* [ ] Package invokes Missive with `/S /D=C:\Missive`
* [ ] `/D=C:\Missive` is passed as the final installer argument unless testing proves otherwise
* [ ] Missive actually installs to `C:\Missive`
* [ ] Install is silent and non-interactive
* [ ] Install script downloads from Missive official Windows URL (`https://mail.missiveapp.com/download/win`)
* [ ] `C:\Missive\Missive.exe` exists after install

### Package model and repository

* [ ] Repository structure is clean and maintainable (per **§3**)
* [ ] Package uses Chocolatey **downloader** model (scripts + metadata only; no embedded Missive EXE)
* [ ] Missive binaries are not embedded or redistributed in repo or nupkg

### Shortcuts and uninstall

* [ ] Start Menu shortcut is created (`C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Missive.lnk`)
* [ ] Public Desktop shortcut is created (`C:\Users\Public\Desktop\Missive.lnk`)
* [ ] Uninstall removes install folder and shortcuts appropriately
* [ ] Reinstall works cleanly (see **§10.5**)

### Update detection and CI

* [ ] Update detection resolves Missive redirect correctly
* [ ] Metadata updates only on real change (no daily churn on no-change)
* [ ] Check workflow does not create noisy no-change commits
* [ ] Package build workflow produces valid `.nupkg` artifact

### Documentation, wording, and publish policy

* [ ] README truthfully describes community-maintained status (**§13**)
* [ ] Maintainer notes explain publish and testing process (**§14**)
* [ ] Nuspec wording does not imply official endorsement (**§5**, **§7.1**)
* [ ] Public Chocolatey publish is **manual** initially (**§1**, **§9.2**, **§12**)

---

## 19. Short agent handoff

Treat Missive installer arguments as a **hard requirement**: required switches `/S /D=C:\Missive`; `/D=` must be the final argument unless testing proves otherwise; testing must explicitly confirm the installer honours that path and remains silent. See **Install command requirements** and **section 7.2** for details.

**Execution order:** follow **Build at a glance** and **§17** (phased checkboxes), validate with **§10** on clean Windows, then **§18**.

Build a new repository called `missive-chocolatey` for a community-maintained Chocolatey package for Missive. The package must use the downloader-package model: at install time it downloads Missive from `https://mail.missiveapp.com/download/win`, installs to `C:\Missive`, and creates shared Start Menu and Public Desktop shortcuts. The repo must not host or redistribute the Missive EXE. Add install, uninstall, update-detection, and smoke-test logic, plus GitHub Actions for change detection and package building. Keep public Chocolatey publishing manual at first, even if automation prepares the package and builds the artifact. All wording must clearly state that the software publisher is Missive and that the package is currently community maintained rather than officially vendor maintained.
