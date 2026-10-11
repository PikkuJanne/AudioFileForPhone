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
