# Packaging revision 2 handover — cleaned public v1.0.1 verified

## Outcome

The owner rejected the flat distribution and asked to clean it up. The canonical
GitHub v1.0.1 ZIP now exposes only converter/setup BAT and PS1 entry points,
a short README and LICENSE, with application internals in app/. The flat layout
was an explicit build choice; it contained runtime modules, not raw test/log dumps.
Presentation is corrected without changing the original converter payload.

Release: https://github.com/PikkuJanne/AudioFileForPhone/releases/tag/v1.0.1
Download: https://github.com/PikkuJanne/AudioFileForPhone/releases/download/v1.0.1/AudioFileForPhone-v1.0.1.zip
Extract into a NEW EMPTY folder; extracting over revision1 cannot remove its old files.
Keep app/ beside the launch files. No diagnostic/helper/check scripts at root.

## Changes

New tools/Build-UserPackage.ps1 verifies the pinned original three assets and maps
all18 byte-identical payload files under app/. It generates compatible root PS1
entrypoints from the original help/parameter declarations with PSBoundParameters
and exit forwarding, redirects existing safe BAT targets, and writes a short guide.
The six root files plus app/ are independently inventoried. The core builder and
all converter/helper/setup/diagnostic runtime source files remain unchanged.

New tests/Test-UserPackage.ps1 verifies the actual distributed bytes and exercises
the generated entrypoints with real short synthetic audio. README/SECURITY and
docs/DISTRIBUTION explain the final distribution step, rather than uploading the
raw flat core payload directly. Active state/routing/decisions identify revision2;
original S14-S18 release evidence, authority and hashes remain historical revision1.
Generated-file provenance is distinct from unchanged original Git blobs.

Application-local FFmpeg now means both tools in app/, beside the implementation.
This location is documented and tested. Explicit/saved/PATH selection remains.
Root PS1 and BAT entrypoints, default64, Music destination, supported formats,
relative/date layout, source tags, exits and source-integrity behavior are retained.
No tool download or persistent host changes occur during conversion or this build.

## Exact current assets

Runtime source/tag remain d9d7129e9463de17e29c2a36752c82e326abf22e / v1.0.1.
Release429170892 is public normal AudioFileForPhone v1.0.1.

| Asset | Bytes | SHA256 |
|---|---:|---|
| AudioFileForPhone-v1.0.1.zip | 128139 | 632070cadda570bdd28eeb193abdb873e65f18edd40aa5e6ab41f499061be5e6 |
| release-manifest.json | 12118 | 8587279cddc03e31954cc747857c73ead36b8b90d777a7ca9d1ab1e684e90887 |
| SHA256SUMS.txt | 183 | 1a93c76f1473b9b67555c3e0fd1aaae8d81ca347045ea67faf89ef76c8775ee3 |

Original revision1 ZIP78ae51a2... and its manifest/checksums are privately backed
up and hash-verified. The release notes disclose the packaging correction and
new checksum. Original v1.0.0 release/tag/asset identities remain unchanged.
No released tag was moved and no alternate version was silently substituted.

## Verification

| Check | Command/artifact | Actual result / environment | Limit |
|---|---|---|---|
| Input/public backup | Anonymous original3asset downloads and recorded hashes | All3 original assets preserved privately before mutation | No private backup/raw logs in Git |
| Build | tools/Build-UserPackage.ps1 -RuntimeAssetDirectory original-public -OutputDirectory candidate-r2 | PS7 and nativePS5.1 both succeed; all24 member hashes agree | CLR compression yields different outer hashes; tested PS7 ZIP is canonical |
| Negative build | Existing output, tampered originalZIP, missing assets | Exit1 refusals; no final output; original unchanged | Validation before guide-only text change retains actual builder identity |
| Finalization | Same builder -PackageTestEvidencePath tests-local/report-final2.json | Same deterministic PS7 ZIP; external manifest binds actual report without circular hash | Does not infer client/human results |
| Local candidate | tests/Test-UserPackage.ps1 -PackageDirectory candidate-r2 -OriginalRuntimeZipPath originalZIP -EvidencePath externalreport | PASSED11cases/20real outputs; Win11Pro26H2 26300.9711 x64, PS5.1.26100.9711 and PS7.6.5 | Report SHAbaae736f94362efcaf89a45d7336c0f0b6feaf1872a7b7c15667c5b178e9d95f |
| Public bytes | Same test against anonymous canonical downloads | PASSED11cases/20real outputs; probe/full decode/metadata/layout/source/config intact | Report SHAb3602f221958266e50a23413911d7f9bc7cd027cf663e04a148daef7ded9c620 |
| Actual route coverage | Explicit+savedPS5.1/7 and actual app-localPS7 | 5batches x4outputs;62natural/drained/released subprocesses;124capture hashes per run | Only short synthetic media, no ordinary Music |
| BAT | Instrumented literal path/exit37 cases plus3actual unmodified argument refusals | Metacharacter transport preserved; zero/extra/empty arguments actualexit1 | Instrumentation is not physical Explorer/phone evidence |
| Publication cutover | Stage3unique assets, authenticated downloads, rename by checked IDs, anonymous canonical downloads, public-byte suite | Exact3current assets; temporary originals removed only after pass | Three name updates are not atomic; rollback mapping/backups retained |
| Original release | Fresh v1.0.0 metadata plus both tag refs | Equal S01 IDs/names/sizes/serverdigests/source/tag | No new old-asset download needed |
| Review/Git | Independent intended-diff and exact-byte audit; git diff --check; exact-head CI | Final feature push/ordinary reviewed main merge and fresh equality observed after containing commit | No self-referential SHA embedded |

Private evidence: C:/projects/AFP-Package-Cleanup-20261030. Full commands,
identities, digest references and original/new asset IDs are in
PACKAGING-REVISION-2.json. No binaries, media, credentials or raw captures in Git.

## Nonpasses and support limits

The first test harness failed after PS5.1 cases because it joined multiple pwsh
executable matches; select the first exact executable in the test harness only.
The failed report stays failed. An earlier guide candidate passed separately,
then the final new-empty-folder guide candidate received its own complete tests.
No observation is rebound to a later ZIP. Original missing Win10, physical
shortcut and phone observations remain explicitly owner-waived/unverified.
This packaging correction does not invent them or request another owner exercise.

## Git state and completion

Entry main f46210621ced4c0c2b07729a73fce40814471be7 had successful main CI41080918945.
Feature codex/audiofileforphone-package-cleanup carries only this packaging fix,
targeted tests and documentation. Final feature HEAD/live equality, exact-head
push/PR CI and ordinary main integration are observed after containing commit;
local main is fast-forwarded and compared to fresh advertised main. The final
response supplies actual resulting sync/CI. Tag C is distinct from later package
builder/documentation commits and remains unchanged. No force/reset/clean,
protection or visibility changes. Postmerge automatic CI is reported honestly.

## Human action and next work

Download the corrected ZIP and extract into a new empty folder. No diagnostic
commands, PATH editing, media upload or new acceptance matrix is requested.
No next numbered step remains. If this chat is interrupted during Git completion,
finish the current reviewed packaging PR and fresh main sync using active
NEXT_SESSION.md; do not rebuild or replace verified public bytes for evidence.
