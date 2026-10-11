# v1.0.0 package and provenance contract

## Authoritative version (T18)

`Get-AudioAppVersion` in `AudioFileForPhone.Helpers.ps1` is the single application
version source. The functions-only helper can be dot-sourced without conversion.
The banner and local manifest/log read this function; the help's version example
executes it. T19's builder must load the helper from exact commit C and use its
result for the ZIP basename, external manifest `app_version` and `v<version>` tag.
Reject a mismatch with the target release; do not maintain a second build constant
or infer the version from a banner, changelog heading or example template.

The template manifest's null `app_version` remains example data until a build fills
it from C. T18 checks this version contract; it does not build or validate a release
ZIP. Actual package building and exact-byte acceptance remain subsequent tasks.

## Required public assets

- `AudioFileForPhone-v1.0.0.zip`
- `release-manifest.json`
- `SHA256SUMS.txt`

The ZIP has application files at its root so the BAT and PS1 remain adjacent.
Use an explicit build allowlist, tested as data. Include the PS1, BAT, any runtime
helper files actually introduced, README/usage/troubleshooting as selected, MIT
license and only runtime-used icons. No FFmpeg/ffprobe binaries, personal audio,
logs, secrets, tests-only fixtures, caches, .git, Codex handoff/evidence, bulky
unused poster or complete repo snapshot. Repository tests/CI/build scripts still
belong to the frozen source commit, even when excluded from the distributable.

FFmpeg stays external. Explain setup, how version/capability checks work and that
vendor binaries have their own license/provenance. No new downloader or bundled
third-party binary supply chain is required. Signing is optional; record actual
unsigned/signed status without suggesting a checksum authenticates the publisher.

## Build from C, not the working directory

### T19 build command and input records

Invoke `tools/Build-Package.ps1` from the supplied clean detached checkout with
all six required parameters: `SourcePath`, full lowercase 40-character
`SourceCommit`, `TargetTag`, `OutputDirectory`, `DependencyProvenancePath` and
`TestEvidencePath`. `SourceCommit` must equal HEAD. Tracked changes, untracked
and ignored files are refused. Paths must be absolute ordinary Windows paths
without reparse ancestors; the new output directory must be outside the source
checkout and have an existing parent. Existing output is never replaced.

`tools/package-files.json` is reviewed data at that commit. Its eight required
members are the entry script, helper, BAT, README, SUPPORT, SECURITY, CHANGELOG and
LICENSE. The builder also enforces this bounded policy. Changing the shipped set
requires reviewing both the allowlist and build policy. Git archive stages only
these members and the two build files; each staged file must hash to the original
Git blob. The archive invocation disables ambient core.autocrlf and uses LF
through command-scoped Git overrides without changing persistent settings, so
checkout line-ending conversion cannot change package bytes. Archive attributes
cannot silently omit or substitute bytes. The staged
functions-only helper supplies the version. Ordinal member order and a fixed
1980 UTC ZIP timestamp are recorded. Compression runtimes can still differ;
compare actual builds before claiming byte reproducibility.

The two input JSON files use `schema_version: 1` and remain external:

| Input | Required fields and meaning |
| --- | --- |
| Dependency provenance | `ffmpeg` and `ffprobe` objects each contain `path` (absolute trusted external executable), `version` (full first version-response line), `sha256` (lowercase executable digest), `source_url` (HTTPS URL without credentials/query/fragment) and `license_notice` (public description without local paths). The builder rechecks executable hashes before/after the exact-C helper's version/capability queries. It preserves version/hash/source/license in the public manifest and strips executable paths. |
| Test evidence | A nonempty `tests` array of unique `reference` (safe relative/logical report identity), `tested_commit` (exact SourceCommit), `sha256` (lowercase actual report digest) and `status: "pass"`. The operator must independently inspect the original reports, their source relationships and actual bytes before creating this input. The builder validates the supplied attestations' form and commit; it does not open referenced reports or execute those tests. |

The manifest records both input-file digests and exact builder/allowlist digests.
It records per-script Authenticode status and signer thumbprint when present;
the overall signing value describes the build host's actual observation. A local
build emits the complete three-asset directory in one move after verifying the
ZIP's exact inventory, sizes and member hashes. Failure retains no published
complete-looking output; cleanup removes only explicit owned staging entries,
and any cleanup failure is reported. The command makes no Git writes, downloads,
tags or release uploads. T19 exercises build mechanics; source freeze, exact ZIP
runtime/device acceptance and publication remain T20–T27 gates.

C is the full tested integrated source commit containing final version 1.0.0 and
all shipped docs/code/test/build/CI changes. Build from a clean detached C worktree
on the active machine. Use deterministic file order/ZIP timestamps where feasible,
but never assume byte-reproducibility without comparing builds. The approved ZIP
bytes and their SHA-256 are authoritative; a rebuild producing different bytes
requires new verification and approval, even when source files match.

Stage artifacts outside the checkout. Verify filenames, sizes, required entry
points, no unexpected files, safe ZIP paths, no symlinks and per-member SHA-256.
Extract the exact ZIP into a clean location and exercise both shells/launcher with
trusted external FFmpeg. Missing dependency behavior is a separate required smoke.

## No checksum self-reference

First build ZIP, then compute its digest. Write external release-manifest.json with
repository, tag, C, ZIP name/digest, signing state, dependency versions/hashes,
actual test references and a map of ZIP member path -> SHA-256. The manifest is not
inside the ZIP, so it can safely contain the ZIP digest. Then SHA256SUMS.txt lists
the ZIP and the external manifest; it does not hash itself.

`RELEASE_CANDIDATE.json` is a tracked progress/evidence document containing C and
both artifact digests; do not ship it inside the ZIP. It is created on the evidence
branch after C, avoiding an impossible “commit its own SHA” requirement. The example
under templates has null values and is not valid release evidence.

## Continuous integration

Secure CI is supplementary to local Windows acceptance. Use reviewed action commit
SHAs and read-only test permissions; segregate any authorized release writes from
untrusted PR jobs. Record dependency provenance/digests at implementation time;
do not invent a trusted checksum in this handoff. S5 lists the official guidance.

## Scope of post-freeze changes

Only docs/codex-v1/ progress/evidence may change after C. Runtime source, README,
LICENSE, tests, workflows, build rules and shipped inventory are frozen. Fixes to
any of them require a new C, rebuild and affected retests/reapproval. Closure main
D can differ from C only by allowed evidence documents; do not move the tag.
