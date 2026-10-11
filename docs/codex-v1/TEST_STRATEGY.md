# Evidence and efficient testing strategy

## Required environments

Windows 11 with Windows PowerShell 5.1 and PowerShell 7 on the active Codex machine.
Record exact builds/versions. GitHub Windows CI covers both shell families as a
supplement, not a substitute for local interactive tests or real phone playback.
No universal Windows 10, all-Android, UNC/NAS or long-path support claim without
corresponding evidence. Lack of a supported environment is a visible blocker.

## Test layers

Pure tests: date/naming/collisions, path boundaries, argument builder, progress
parser, outcome aggregation, version and package inventory. Native fault-injection
stubs: missing tool, argv capture, stderr flood, zero-exit fake output, truncated
files, invalid probe JSON, destination/promotion error. These test contracts but
cannot by themselves establish FFmpeg media correctness.

Real FFmpeg integration: keep the existing `tests/Test-AudioFileForPhone.ps1` and
its synthetic clips/cover fixture. Expand it or call focused sibling helpers. Do
not replace it with mocks. Ensure script-copy tests include any runtime helpers.
Use 0.4–3-second clips for routine matrices; cover MP3/AAC M4A/Vorbis/Opus OGG,
mono/stereo baseline, metadata and full-decode checks on short outputs.

Windows process/filesystem checks: cmd/BAT exits and metacharacters, STA picker,
read-only/unwritable paths, junctions, concurrency, actual cancellation and source
hash safety. Use controlled fixtures, not permissions changes to user directories.

Manual long-file/phone checks: a representative long podcast or audiobook (for
example over an hour) tests duration and near-end seeking; use legally held local
media without uploading it. Record output hash and private descriptive ID rather
than raw filename/content in GitHub. Check phone/player versions and actual tags,
cover, order, seeking/resume. Do not create fake screenshots or fill a template as
though tests were performed.

## Safe baseline and isolation ordering

At the T02 checkpoint, the original suite wrote into Music and timed runs to avoid collisions.
T02 captures characterization first; run only in a genuinely isolated test account
or safe owned harness. T03 adds OutputParent and moves ordinary tests to unique
TEMP roots. It may proceed while T02 execution is specifically blocked by unsafe
legacy output isolation, but it must finish baseline execution before T04.
Do not introduce a production-only environment-variable backdoor simply to fake
Music-folder isolation.

## Commands

T03 replaces the copy-only Music adapter with the public `OutputParent`
parameter. Ordinary integration checks, fixtures and output all live under
marker-owned TEMP trees. Every conversion receives a fresh output parent;
application copies preserve source bytes. The retained real-FFmpeg suite and
focused companion still check the baseline formats, tags, names, full decoding
and source inventories. Production PATH discovery is checked against the
selected installed pair. Cleanup verifies exact canonical ownership and rejects
reparse points before recursively removing only its own tree.

Recorded T04 integration/evidence commands (historical labels; do not overwrite):
Use STATUS.md or evidence/T07.md for current passing commands with fresh labels.

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Invoke-IsolatedBaseline.ps1 -FfmpegPath C:\ffmpeg\bin\ffmpeg.exe -FfprobePath C:\ffmpeg\bin\ffprobe.exe -EvidencePath .\docs\codex-v1\evidence\T04-baseline-ps51.json
pwsh -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Invoke-IsolatedBaseline.ps1 -FfmpegPath C:\ffmpeg\bin\ffmpeg.exe -FfprobePath C:\ffmpeg\bin\ffprobe.exe -EvidencePath .\docs\codex-v1\evidence\T04-baseline-ps7.json
```

For a direct retained-suite run without writing an evidence report:

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Test-AudioFileForPhone.ps1 -FfmpegPath C:\ffmpeg\bin\ffmpeg.exe -FfprobePath C:\ffmpeg\bin\ffprobe.exe
pwsh -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Test-AudioFileForPhone.ps1 -FfmpegPath C:\ffmpeg\bin\ffmpeg.exe -FfprobePath C:\ffmpeg\bin\ffprobe.exe
```

Recorded T04 TEMP-only resolver commands (both passed their recorded payload):

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Test-OutputParent.ps1 -EvidencePath .\docs\codex-v1\evidence\T04-resolver-ps51.json
pwsh -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Test-OutputParent.ps1 -EvidencePath .\docs\codex-v1\evidence\T04-resolver-ps7.json
```

The focused `tests/Test-OutputParent.ps1` tests the actual resolver function
extracted from the functions-only runtime helper AST, injected redirected Music paths and literal
explicit output paths. Its normal mode uses TEMP only. The historical T03
`-DefaultSmoke` exercised the narrow configured-Music test in `evidence/T03.md`;
T06/T07 deferred that mode before setup; T08 ownership adaptation is below.
No registry or persistent PATH/policy change is
needed. Neither recorded mode is phone/manual playback evidence.

The wrapper writes only explicitly named `T03-<label>.json`, `T04-<label>.json`, `T05-<label>.json`, `T06-<label>.json` or `T07-<label>.json`
reports directly in `docs/codex-v1/evidence`, preserving historical reports. `-ValidateOnly`
checks copies, syntax and owned cleanup without generating media and cannot
establish codec behavior. No helper downloads tools.

T02 commands/results in `evidence/T02.md` describe the frozen T02 payload.
Its resolver-substitution helpers, including `Test-T02NameContracts.ps1`, are
historical and are not canonical commands for the changed T04 script. The
bitrate matrix, launcher observations and 24/180 name evidence remain the
selected contracts; repeat affected checks when those features change.

## T04 focused preflight checks

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Test-Preflight.ps1 -EvidencePath .\docs\codex-v1\evidence\T04-preflight-ps51.json
pwsh -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Test-Preflight.ps1 -EvidencePath .\docs\codex-v1\evidence\T04-preflight-ps7.json
```

The focused harness uses the installed C:\ffmpeg\bin pair by default, short
synthetic media, byte-identical app/helper copies and exclusively marked TEMP.
Every negative child uses -Interactive under a -NonInteractive host to prove
rejection before prompts/conversion/run creation. It includes true Windows ACL
denials only on newly owned fixture directories, restores their original ACLs,
then verifies source hashes and exact cleanup. Inert helper loading, numeric
boundaries, caller-local native exit state, real JPEG/PNG validation and internal
SkipWriteProbe/no-creation are checked separately. Raw child diagnostics remain
only in disposable TEMP; evidence contains assertions, bounded diagnostic
excerpts and controlled commands.
No ordinary Music test, disk filling, registry/policy change or manual evidence.

## T05 native execution checks

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Test-NativeProcess.ps1 -FfmpegPath C:\ffmpeg\bin\ffmpeg.exe -FfprobePath C:\ffmpeg\bin\ffprobe.exe -EvidencePath .\docs\codex-v1\evidence\T05-native-ps51-final.json
pwsh -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Test-NativeProcess.ps1 -FfmpegPath C:\ffmpeg\bin\ffmpeg.exe -FfprobePath C:\ffmpeg\bin\ffprobe.exe -EvidencePath .\docs\codex-v1\evidence\T05-native-ps7-final.json
```

The focused harness compiles a controlled C# child with the local .NET Framework
compiler inside owned TEMP. Its argv capture and native fault modes exercise both
shells independently; no test executable is shipped or committed. Real FFmpeg
tests accompany stubs. Retained baseline, preflight and resolver harnesses accept
T05 evidence filenames so their historical T03/T04 reports remain unchanged.
Native evidence uses CreateNew; repeat with a fresh T05 label instead of replacing
an existing report. The commands above record the original final runs.

## T06 discovery checks

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Test-Discovery.ps1 -FfmpegPath C:\ffmpeg\bin\ffmpeg.exe -FfprobePath C:\ffmpeg\bin\ffprobe.exe -EvidencePath .\docs\codex-v1\evidence\T06-discovery-ps51-final.json
pwsh -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Test-Discovery.ps1 -FfmpegPath C:\ffmpeg\bin\ffmpeg.exe -FfprobePath C:\ffmpeg\bin\ffprobe.exe -EvidencePath .\docs\codex-v1\evidence\T06-discovery-ps7-final2.json
```

The focused harness uses owned TEMP trees for Music-like overlap, explicit/new/legacy
output exclusions, malformed identities and similarly named user content. Real
junctions exercise loops and outside targets; a real file reparse fixture exercises
the file skip policy. Symlink creation capability is recorded separately without
changing machine settings. Owned ACL denial proves complete scan abort before
prompts/run/conversion; original ACLs, fixture hashes and exact cleanup are checked.
Repeated short real-FFmpeg runs retain default bitrate/layout/tags/full decode and
do not rescan the first generated run. Reports use CreateNew; retry with fresh labels.

Use T06 labels for ordinary retained baseline/preflight/resolver reports; preserve
all earlier reports. The retained suite now asserts empty scans create no run/log.
Historical T03 configured-Music smoke evidence remains valid for its original
payload. At T06/T07, `Test-OutputParent.ps1 -DefaultSmoke` stopped before any setup
because its pre-reserved run conflicted with production's no-reuse check. T08 uses
a successful controlled child returning its exclusive root instead. Ordinary
resolver mode remains TEMP-only.

## T07 naming checks

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Test-NamingPlan.ps1 -FfmpegPath C:\ffmpeg\bin\ffmpeg.exe -FfprobePath C:\ffmpeg\bin\ffprobe.exe -EvidencePath .\docs\codex-v1\evidence\T07-naming-ps51-final2.json
pwsh -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Test-NamingPlan.ps1 -FfmpegPath C:\ffmpeg\bin\ffmpeg.exe -FfprobePath C:\ffmpeg\bin\ffprobe.exe -EvidencePath .\docs\codex-v1\evidence\T07-naming-ps7-final2.json
```

Current regression commands and all ten passing report labels are in
`evidence/T07.md`. Baseline/preflight/resolver accept T07 filenames; discovery
accepts T06/T07. Preserve earlier reports and use fresh labels for reruns.
Owned fixture-root/output names were shortened to fit the newly enforced path
policy; the companion checks the same shortened ownership prefix. Application
copies retain exact bytes. No production path limit or source-safety check is waived.

Focused checks cover invariant real dates and whole-basename fallback, locales,
NFC before/after filtering, permitted supplementary scalars, noncomposing marks,
malformed surrogates, complete UTF-16 suffix budgets, shuffled case/extension/NFC
collisions, canonical duplicates and zero partial plan rows. Native owned fixtures
prove actual file 259/260 and directory 247/248 boundaries, including preserved
trailing-dot/space and overlong folder aborts before prompts/output. Short real
FFmpeg conversion checks 19 outputs per shell, suffix 12, exact planned layout,
allocated/preserved title tags, 64 kbps, full decode and an actual 180-unit basename.
The future fixed-length working path is budgeted but not written until T09.

The focused harness selects the shorter existing machine/user TEMP without
settings changes, creates an exclusive root and owner marker, records recoverable
root identity, individually removes registered native fixtures nonrecursively,
then checks exact path/token/nonreparse boundaries before .NET owned-tree deletion.
Final hashes/cleanup pass. Initial failed PS5.1 report has unverified cleanup and
an unknown possible synthetic residue because its leaf was not recorded and
machine TEMP parent enumeration is denied; evidence/T07.md preserves that limit.
No broad cleanup or ACL change was attempted. Configured-Music smoke was deferred
at T07 and adapted in T08; ordinary resolver mode stays TEMP-only. No phone/manual/
release evidence.

## T08 reservation and M1 regression checks

Use fresh T08 report labels. Both shells run Test-RunReservation.ps1, the isolated
retained baseline/seven companions, Test-Preflight.ps1, Test-Discovery.ps1,
Test-NamingPlan.ps1, Test-NativeProcess.ps1 and normal Test-OutputParent.ps1.
The current exact commands/reports are in evidence/T08.md. Historical reports
remain tied to their recorded hashes, including intermediate passes and failures.
Run process-resource handle checks with reduced test load; keep their threshold
and every failed observation. They do not establish reservation race correctness.

Reservation correctness uses named ready/release events in separate processes,
forcing four helper children to contend on the same fixed timestamp/candidates.
All must signal ready before release; no sleeps avoid the race. A separate two-
child real-entry barrier verifies decoded outputs, distinct roots/logs, relative
OutputParent and a process-local FileSystem PSDrive. That production launch does
not require both wall-clock timestamps to match; the fixed-candidate helper test
is the collision proof. Existing directories/files/logs/markers/sentinels retain
SHA256, CreateNew collisions refuse writes, suffix path overflow rejects before
creation, and owned ACL failures exercise Win32/setup diagnostics and exact scope.

The configured-Music smoke runs unmodified runtime copies with one synthetic
TEMP source and no OutputParent override. Inspect only the single direct Music
root returned after successful controlled exclusive reservation. Validate the
runtime token/scope, add a CreateNew test marker, require exact allowed inventory
and nonreparse ancestry, then remove only that run. Never enumerate ordinary
Music, change its settings/ACLs, pre-reserve candidates or modify timestamps.
If child/ownership/cleanup proof fails, preserve the recorded exact candidate
instead of guessing ownership. Final source hashes and scoped cleanup are required.

## Cadence and status vocabulary

Targeted tests after each change; regression suite after M1/M2/M3 and before
integration; full suites on final C and exact ZIP. Long audio is not repeated for
every name-parser edit. If a payload change touches audio/process/path output,
rerun affected manual/phone evidence before freezing. Unchanged media-processing
payload may reuse prior manual results only with an explicit equivalence record.

Case status values: not_run, pass, fail, blocked, or not_applicable. Required cases
cannot silently become not_applicable; changing a gate requires owner-approved
scope change and honest release notes. Optional O01 cases remain not_run/deferred
and do not block the core. Every pass links concrete evidence with tested commit,
environment, commands, expected/observed result and real tester for manual cases.

Task status: todo, in_progress, blocked, verified, done, deferred. “verified” means
implementation evidence exists; “done” adds reviewed/pushed checkpoint. Record
prior verified code/evidence commit, not a self-referential current-commit hash.
A final live check is always required independently of stored status.
